// Trạng thái và luồng ván cờ cho cả 3 chế độ (port từ site/js/app.js).
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/data.dart';
import '../engine/engine.dart';
import '../engine/engine_service.dart';
import 'analysis.dart';
import 'constants.dart';

enum Mode { play, puzzle, games }

class Arrow {
  final int m;
  final String kind; // best | alt | bad | played
  const Arrow(this.m, this.kind);
}

class OpeningInfo {
  final String name;
  final String? tip;
  const OpeningInfo(this.name, this.tip);
}

class Coach {
  String title;
  String? cls;
  List<String> lines;
  bool busy;
  OpeningInfo? opening;
  bool confirm;
  bool gmNext;
  Coach(this.title, {this.cls, List<String>? lines, this.busy = false, this.opening, this.confirm = false, this.gmNext = false})
    : lines = lines ?? [];
}

class SavedCoach {
  final String title;
  final String? cls;
  final List<String> lines;
  final String? opening;
  SavedCoach(this.title, this.cls, this.lines, this.opening);
  Map<String, dynamic> toJson() => {'title': title, 'cls': cls, 'lines': lines, 'opening': opening};
  static SavedCoach? fromJson(dynamic j) => j == null
      ? null
      : SavedCoach(j['title'] as String, j['cls'] as String?, (j['lines'] as List).cast<String>(), j['opening'] as String?);
}

class HistEntry {
  final int m;
  final String name;
  final String by; // user | ai
  Pos before;
  String? cls;
  int? loss, acc, best;
  String? bestName;
  SavedCoach? coach;
  HistEntry(this.m, this.name, this.by, this.before, {this.cls, this.coach});
}

class Options {
  bool warn, threats, han, sound;
  Options({this.warn = true, this.threats = true, this.han = true, this.sound = true});
}

class GameResult {
  final int winner;
  final String text;
  GameResult(this.winner, this.text);
}

/// Lưu trữ đơn giản trên SharedPreferences, khóa "cotuong.*" như bản web.
class Store {
  final SharedPreferences sp;
  Store(this.sp);
  T get<T>(String k, T d) {
    try {
      final v = sp.getString('cotuong.$k');
      return v == null ? d : jsonDecode(v) as T;
    } catch (_) {
      return d;
    }
  }

  void set(String k, Object? v) => sp.setString('cotuong.$k', jsonEncode(v));
}

class GameController extends ChangeNotifier {
  final Store store;
  final EngineService engine = EngineService();
  final _rnd = math.Random();

  Mode mode = Mode.play;
  Pos pos = Pos.start();
  int userSide = RED;
  int level = 3;
  List<HistEntry> hist = [];
  String state = 'user';
  Future<SearchResult?>? _pre;
  SearchResult? _confirmPre;
  int tok = 0;
  int selected = -1;
  List<Arrow> arrows = [];
  int view = -1;
  Coach? coach;
  int hintsUsed = 0;
  GameResult? result;
  int lastScore = 0;
  late Options opt;

  /// Tăng mỗi khi có nước đi mới, để bàn cờ biết khi nào cần chạy hiệu ứng.
  int moveSerial = 0;

  /// Bằng [moveSerial] khi thay đổi gần nhất là một nước đi mới (bàn cờ chạy hiệu ứng);
  /// khác đi khi đi lại, chuyển bài, tua ván… (bàn cờ nhảy thẳng, không hiệu ứng).
  int animSerial = -1;

  /// Callback phát âm thanh/rung (UI gắn vào).
  void Function(String kind)? onFx;

  ProBook? pro;

  // Bài tập
  List<CollectionInfo> pzCols = [];
  PuzzleCollection? pzCol;
  int pzIdx = 0;
  Puzzle? pzCur;
  int pzFails = 0, pzHintStep = 0;
  final Map<String, PuzzleCollection> _pzCache = {};
  late Set<String> pzSolved;

  // Ván đại sư
  List<CollectionInfo>? gmIndex;
  GameCollection? gmCol;
  MasterGame? gmGame;
  int gmGi = 0;
  List<int> gmMoves = [];
  Pos? _gmStart;
  int gmPly = 0;
  bool gmGuess = false;
  int gmSide = RED;
  int gmOk = 0, gmNear = 0, gmTot = 0;
  final Map<String, GameCollection> _gmCache = {};
  String gmFilter = '';
  ({String title, String? cls, int n})? _gmFlash;

  GameController(this.store) {
    level = store.get<int>('level', 3);
    userSide = store.get<int>('side', RED);
    final o = store.get<Map<String, dynamic>>('opt', {});
    opt = Options(
      warn: o['warn'] as bool? ?? true,
      threats: o['threats'] as bool? ?? true,
      han: o['han'] as bool? ?? true,
      sound: o['sound'] as bool? ?? true,
    );
    pzSolved = store.get<List<dynamic>>('solved', []).map((x) => x is int ? 'thuc-chien:${x - 1}' : x as String).toSet();
  }

  Future<void> init() async {
    ProBook.load()
        .then((b) {
          pro = b;
          notifyListeners();
        })
        .catchError((_) {});
    loadPuzzleIndex()
        .then((l) {
          pzCols = l;
          notifyListeners();
        })
        .catchError((_) {});
    // --dart-define=START_MODE=puzzle|games: mở thẳng một chế độ (dùng khi chụp màn hình)
    const forced = String.fromEnvironment('START_MODE');
    final m0 = forced.isNotEmpty ? forced : store.get<String>('mode', 'play');
    final m = Mode.values.firstWhere((x) => x.name == m0, orElse: () => Mode.play);
    _mode = null;
    await setMode(m);
  }

  Mode? _mode;

  @override
  void dispose() {
    engine.dispose();
    super.dispose();
  }

  void _render() => notifyListeners();
  void _fx(String k, [int delayMs = 0]) {
    if (!opt.sound || onFx == null) return;
    if (delayMs <= 0) {
      onFx!(k);
    } else {
      Future.delayed(Duration(milliseconds: delayMs), () => onFx?.call(k));
    }
  }

  /// Ghi nhận nước [m] vừa đi trên [p]: bàn cờ chạy hiệu ứng, tiếng quân phát lúc chạm bàn.
  void _moved(Pos p, int m, bool capture) {
    moveSerial++;
    animSerial = moveSerial;
    final kind = p.inCheck(p.side)
        ? 'check'
        : capture
        ? 'capture'
        : 'move';
    _fx(kind, moveAnimMs(m) - 15);
  }

  /// Chờ quân trượt xong (để việc phân tích nặng không làm giật hiệu ứng).
  Future<void> _settle(int m) => Future.delayed(Duration(milliseconds: moveAnimMs(m) + 30));

  // ---------- Tiện ích ----------
  List<String> histNames() => [for (final h in hist) h.name];
  Pos get shownPos => view >= 0 ? hist[view].before : pos;
  bool get flipped => userSide == BLACK;

  List<BookMove>? proMoves(Pos p) => pro?.movesFor(p);

  OpeningInfo? _ecoOf() {
    final b = pro;
    if (b == null) return null;
    final ps = [for (final h in hist) h.before, pos];
    for (var i = ps.length - 1; i >= 0; i--) {
      final c = b.eco[ps[i].key];
      if (c != null) return OpeningInfo('$c · ${b.names[c] ?? ''}', null);
    }
    return null;
  }

  OpeningInfo? get eco => _ecoOf();

  String proLine(List<BookMove> pm, int k) => pm.take(k).map((x) => '${x.name} (${pct(x.share)}, thắng ${pct(x.w / x.n)})').join(' · ');

  List<int> bookMoves(Pos p, List<String> names) {
    final pm = proMoves(p);
    if (pm != null)
      return [
        for (final x in pm)
          if (x.share >= 0.05 && x.n >= 10) x.m,
      ];
    if (pro != null) return [];
    if (names.length >= 10) return [];
    final legal = p.legalMoves(), out = <int>{};
    for (final line in smallBook) {
      if (line.length <= names.length) continue;
      var ok = true;
      for (var i = 0; i < names.length; i++) {
        if (line[i] != names[i]) {
          ok = false;
          break;
        }
      }
      if (!ok) continue;
      for (final x in legal) {
        if (p.moveName(x) == line[names.length]) {
          out.add(x);
          break;
        }
      }
    }
    return out.toList();
  }

  Opening? _oldOpening(List<String> names) {
    Opening? best;
    for (final o in openings) {
      if (o.seq.length > names.length) continue;
      var ok = true;
      for (var i = 0; i < o.seq.length; i++) {
        if (names[i] != o.seq[i]) {
          ok = false;
          break;
        }
      }
      if (ok && (best == null || o.seq.length > best.seq.length)) best = o;
    }
    return best;
  }

  OpeningInfo? openingOf(List<String> names) {
    final e = _ecoOf();
    final old = _oldOpening(names);
    if (e != null) return OpeningInfo(e.name, old?.tip);
    return old == null ? null : OpeningInfo(old.name, old.tip);
  }

  // ---------- Luồng ván cờ ----------
  void _save() {
    if (mode != Mode.play) return;
    store.set('game', {
      'side': userSide,
      'moves': [
        for (final h in hist) {'m': h.m, 'by': h.by, 'cls': h.cls, 'coach': h.coach?.toJson()},
      ],
      'hints': hintsUsed,
    });
  }

  void newGame({bool keepSide = false}) {
    tok++;
    engine.reset();
    if (!keepSide) userSide = store.get<int>('side', RED);
    pos = Pos.start();
    hist = [];
    selected = -1;
    arrows = [];
    view = -1;
    result = null;
    hintsUsed = 0;
    lastScore = 0;
    moveSerial++;
    coach = Coach(
      'Bắt đầu ván mới',
      lines: [
        'Bạn cầm quân ${sideName(userSide)}. ${userSide == RED ? 'Bạn đi trước.' : 'Máy đi trước.'}',
        'Bấm "Gợi ý" bất cứ lúc nào để xem nước nên đi và lý do. Sau mỗi nước, thầy sẽ chấm điểm nước của bạn.',
      ],
    );
    _save();
    _render();
    if (pos.side == userSide) {
      _startUserTurn();
    } else {
      _aiTurn();
    }
  }

  bool _restore() {
    final g = store.get<Map<String, dynamic>?>('game', null);
    if (g == null || g['moves'] == null || (g['moves'] as List).isEmpty) return false;
    try {
      userSide = g['side'] as int;
      final p = Pos.start();
      final h = <HistEntry>[];
      for (final e in g['moves'] as List) {
        final m = e['m'] as int;
        if (!p.isLegal(m)) throw StateError('bad');
        final before = p.clone();
        h.add(HistEntry(m, p.moveName(m), e['by'] as String, before, cls: e['cls'] as String?, coach: SavedCoach.fromJson(e['coach'])));
        p.make(m);
      }
      pos = p;
      hist = h;
      hintsUsed = g['hints'] as int? ?? 0;
      selected = -1;
      arrows = [];
      view = -1;
      result = null;
      moveSerial++;
      coach = Coach('Tiếp tục ván cũ', lines: ['Ván cờ trước đã được khôi phục.']);
      _render();
      if (!_checkOver()) {
        if (pos.side == userSide) {
          _startUserTurn();
        } else {
          _aiTurn();
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _checkOver() {
    if (pos.legalMoves().isEmpty) {
      final winner = -pos.side;
      final inC = pos.inCheck(pos.side);
      result = GameResult(winner, '${winner == userSide ? 'Bạn thắng! ' : 'Máy thắng. '}${inC ? 'Chiếu bí.' : 'Hết nước đi.'}');
    } else if (pos.repCount() >= 3) {
      result = GameResult(0, 'Hòa do lặp lại thế cờ 3 lần.');
    } else if (hist.length >= 300) {
      result = GameResult(0, 'Hòa do ván cờ quá dài.');
    }
    if (result != null) {
      state = 'over';
      arrows = [];
      coach = _summaryCoach();
      _fx(result!.winner == userSide ? 'win' : 'end', 480);
      _save();
      _render();
      return true;
    }
    return false;
  }

  Coach _summaryCoach() {
    final mine = hist.where((h) => h.by == 'user' && h.cls != null).toList();
    final cnt = <String, int>{};
    var acc = 0;
    for (final h in mine) {
      cnt[h.cls!] = (cnt[h.cls!] ?? 0) + 1;
      acc += h.acc ?? accOf[h.cls!]!;
    }
    final lines = [result!.text];
    if (mine.isNotEmpty) {
      lines.add('Độ chính xác của bạn: ${(acc / mine.length).round()}%');
      lines.add(cls.keys.where((k) => cnt[k] != null).map((k) => '${cls[k]!.icon} ${cls[k]!.short}: ${cnt[k]}').join(' · '));
      if (hist.any((h) => h.by == 'user' && (h.cls == 'mistake' || h.cls == 'blunder'))) {
        lines.add('Bấm vào các nước đánh dấu ? hoặc ?? trong danh sách nước đi để xem lại nên đi thế nào.');
      }
    }
    if (hintsUsed > 0) lines.add('Số lần dùng gợi ý: $hintsUsed');
    return Coach('Kết thúc ván', lines: lines);
  }

  void _startUserTurn() {
    state = 'user';
    selected = -1;
    final p = pos.clone(), t = tok;
    final f = engine.search(p, const SearchOpts(timeMs: coachMs, multipv: 3));
    _pre = f;
    f.then((r) {
      if (r != null && t == tok && state == 'user' && r.multi.isNotEmpty) {
        lastScore = r.multi[0].score;
        _render();
      }
    });
    _render();
  }

  Future<void> _onUserMove(int m) async {
    final t = tok, before = pos.clone();
    final name = pos.moveName(m), names = histNames();
    final book = bookMoves(before, names);
    final preP = _pre!;
    final capture = pos.b[m >> 7] != 0;
    pos.make(m);
    _moved(pos, m, capture);
    final entry = HistEntry(m, name, 'user', before);
    hist.add(entry);
    state = 'ai';
    selected = -1;
    arrows = [];
    coach = Coach('Thầy đang xem nước của bạn…', busy: true);
    _render();
    final over = pos.legalMoves().isEmpty;
    await _settle(m);
    if (t != tok) return;
    final pre = await preP;
    if (t != tok || pre == null || pre.multi.isEmpty) return;
    final best = pre.multi[0];
    int userScore;
    int? reply;
    PvLine? found;
    for (final x in pre.multi) {
      if (x.move == m) found = x;
    }
    if (over) {
      userScore = MATE - 1;
    } else if (found != null) {
      userScore = found.score;
      if (found.pv.length > 1) reply = found.pv[1];
    } else {
      final r = await engine.search(pos.clone(), SearchOpts(timeMs: (coachMs * 0.8).round(), multipv: 1));
      if (t != tok || r == null || r.multi.isEmpty) return;
      userScore = -r.multi[0].score;
      reply = r.multi[0].move;
    }
    final loss = math.max(0, clampS(best.score) - clampS(userScore));
    String c;
    if (m == best.move) {
      c = 'best';
    } else if (book.contains(m) && loss <= 120) {
      c = 'book';
    } else if (loss <= 20) {
      c = 'best';
    } else if (loss <= 60) {
      c = 'good';
    } else if (loss <= 150) {
      c = 'inacc';
    } else if (loss <= 320) {
      c = 'mistake';
    } else {
      c = 'blunder';
    }
    // đang thắng/thua quá rõ thì không bắt lỗi khắt khe
    if (clampS(userScore) > 1500 && c != 'blunder' && !(best.score > MATE - 500 && userScore < MATE - 500)) {
      c = c == 'best' ? 'best' : 'good';
    }
    if (best.score > MATE - 500 && userScore < MATE - 500 && c != 'blunder') c = 'mistake';
    entry.cls = c;
    entry.loss = loss;
    entry.acc = (100 * math.exp(-loss / 280)).round();
    entry.bestName = before.moveName(best.move);
    entry.best = best.move;
    lastScore = userScore;

    final lines = <String>[];
    if (c == 'best' || c == 'book' || c == 'good') {
      if (c == 'best' && m == best.move) lines.add('Đúng nước máy chọn.');
      if (c == 'book') {
        final pm = proMoves(before);
        BookMove? x;
        for (final y in pm ?? <BookMove>[]) {
          if (y.m == m) x = y;
        }
        lines.add(
          x != null
              ? 'Nước của đại sư: ${fmtInt(x.n)} ván giải đấu đã đi nước này (${pct(x.share)}), bên đi thắng ${pct(x.w / x.n)}, hòa ${pct(x.d / x.n)}.'
              : 'Nước đi theo bài bản khai cuộc.',
        );
      }
      lines.addAll(explain(before, m, score: userScore).map((x) => '• $x'));
      if (c == 'good' && m != best.move) lines.add('Máy thích ${entry.bestName} hơn một chút.');
    } else {
      lines.add('Bạn mất khoảng ${(loss / 100).toStringAsFixed(1)} Tốt lợi thế.');
      if (reply != null) {
        final aft = pos.clone();
        if (aft.isLegal(reply)) {
          lines.add('Vì đối phương có thể đáp ${aft.moveName(reply)}: ${lc(explain(aft, reply, short: true).join(' '))}');
        }
      }
      lines.add('Nước tốt hơn: ${entry.bestName}.');
      final pmB = proMoves(before);
      if (pmB != null && pmB.isNotEmpty) lines.add('Đại sư thường đi: ${proLine(pmB, 3)}.');
      lines.addAll(explain(before, best.move, score: best.score).map((x) => '• $x'));
    }
    final op = openingOf(histNames());
    final co = Coach('${cls[c]!.icon} $name: ${cls[c]!.label}', cls: c, lines: lines);
    if (op != null && hist.length <= 30) co.opening = op;
    entry.coach = SavedCoach(co.title, c, lines, co.opening?.name);
    coach = co;
    if (c != 'best' && c != 'book' && c != 'good') arrows = [Arrow(best.move, 'best')];
    _save();
    _render();
    if (_checkOver()) return;
    if (c == 'blunder' && opt.warn) {
      state = 'confirm';
      coach!.confirm = true;
      _confirmPre = pre;
      _render();
      return;
    }
    _aiTurn();
  }

  void confirmBlunder(bool undo) {
    if (state != 'confirm') return;
    if (undo) {
      pos.unmake();
      hist.removeLast();
      moveSerial++;
      arrows = [];
      state = 'user';
      _pre = Future.value(_confirmPre);
      coach = Coach('Đã đi lại', lines: ['Hãy tìm nước tốt hơn. Bấm "Gợi ý" nếu cần.']);
      _save();
      _render();
    } else {
      coach!.confirm = false;
      arrows = [];
      _aiTurn();
    }
  }

  Future<void> _aiTurn() async {
    final t = tok;
    if (_checkOver()) return;
    state = 'ai';
    _render();
    final L = levels[level]!;
    final sw = Stopwatch()..start();
    final names = histNames();
    final p = pos;
    final book = level >= 2 ? bookMoves(p, names) : <int>[];
    final pmA = level >= 2 ? proMoves(p) : null;
    int move, score;
    if (pmA != null && pmA.isNotEmpty && pmA.fold<int>(0, (s, x) => s + x.n) >= 20 && _rnd.nextDouble() < 0.95) {
      // chọn nước theo tần suất đại sư; cấp cao ưu tiên nước có thành tích tốt
      final pool = pmA.where((x) => x.n >= 3 && (level < 4 || (x.w + x.d / 2) / x.n >= 0.4)).toList();
      final ws = [for (final x in (pool.isNotEmpty ? pool : pmA)) (x, math.pow(x.n, level >= 4 ? 1.4 : 1).toDouble())];
      var r0 = _rnd.nextDouble() * ws.fold<double>(0, (s, x) => s + x.$2);
      move = ws.last.$1.m;
      for (final (x, w) in ws) {
        r0 -= w;
        if (r0 <= 0) {
          move = x.m;
          break;
        }
      }
      final r = await engine.search(p.clone(), const SearchOpts(timeMs: 250, multipv: 1));
      if (t != tok || r == null) return;
      score = r.multi.isNotEmpty ? r.multi[0].score : 0;
    } else if (book.isNotEmpty && _rnd.nextDouble() < 0.85) {
      move = book[_rnd.nextInt(book.length)];
      final r = await engine.search(p.clone(), const SearchOpts(timeMs: 250, multipv: 1));
      if (t != tok || r == null) return;
      score = r.multi.isNotEmpty ? r.multi[0].score : 0;
    } else {
      final r = await engine.search(p.clone(), L.opts);
      if (t != tok || r == null || r.multi.isEmpty) return;
      var cands = r.multi.where((x) => x.score >= r.multi[0].score - L.margin && x.score > -MATE + 500).toList();
      if (cands.isEmpty) cands = [r.multi[0]];
      var pick = cands[_rnd.nextInt(cands.length)];
      int pickMove = pick.move, pickScore = pick.score;
      if (r.multi[0].score > MATE - 500) {
        pickMove = r.multi[0].move;
        pickScore = r.multi[0].score;
      } else if (L.randomChance > 0 && _rnd.nextDouble() < L.randomChance && r.all.length > 1) {
        final safe = r.all.where((x) => x.score > -MATE + 500).toList();
        if (safe.isNotEmpty) {
          final s = safe[_rnd.nextInt(math.min(safe.length, 10))];
          pickMove = s.move;
          pickScore = s.score;
        }
      }
      move = pickMove;
      score = pickScore;
    }
    final wait = 450 - sw.elapsedMilliseconds;
    if (wait > 0) await Future.delayed(Duration(milliseconds: wait));
    if (t != tok) return;
    final before = p.clone(), name = p.moveName(move);
    final capture = p.b[move >> 7] != 0;
    p.make(move);
    _moved(p, move, capture);
    hist.add(HistEntry(move, name, 'ai', before));
    lastScore = -score;
    final op = openingOf(histNames());
    if (coach != null && !coach!.busy && op != null && hist.length <= 30) coach!.opening = op;
    _save();
    if (!_checkOver()) {
      _startUserTurn();
    } else {
      _render();
    }
  }

  Future<void> _showHint() async {
    if (state != 'user' || view >= 0) return;
    final t = tok, p = pos.clone();
    hintsUsed++;
    coach = Coach('Đang phân tích…', busy: true);
    _render();
    final pre = await _pre;
    if (t != tok || pre == null || state != 'user' || pre.multi.isEmpty) return;
    final lines = <String>[];
    String? threatLine;
    if (p.inCheck(p.side)) {
      threatLine = 'Bạn đang bị chiếu! Phải đỡ chiếu trước.';
    } else {
      final np = p.clone()..makeNull();
      final th = await engine.search(np, const SearchOpts(timeMs: 350, multipv: 1));
      if (t != tok || th == null) return;
      if (th.multi.isNotEmpty) {
        final tm = th.multi[0];
        if (tm.score + pre.multi[0].score > 150 || tm.score > MATE - 500) {
          final what = lc(explain(np, tm.move, score: tm.score, short: true).join(' '));
          threatLine = 'Chú ý: đối phương đang dọa ${np.moveName(tm.move)} (${what.replaceAll(RegExp(r'\.$'), '')}).';
        }
      }
    }
    if (threatLine != null) lines.add(threatLine);
    final book = bookMoves(p, histNames());
    final best = pre.multi[0];
    lines.add('Nên đi: ${p.moveName(best.move)}  (${fmtScore(best.score)})');
    lines.addAll(explain(p, best.move, score: best.score).map((x) => '• $x'));
    if (best.pv.length > 1) {
      final p2 = p.clone(), seq = <String>[];
      for (final mv in best.pv.take(5)) {
        if (!p2.isLegal(mv)) break;
        seq.add(p2.moveName(mv));
        p2.make(mv);
      }
      if (seq.length > 1) lines.add('Diễn biến dự kiến: ${seq.join(' → ')}');
    }
    final alts = pre.multi.skip(1).where((x) => x.score > best.score - 120).toList();
    if (alts.isNotEmpty) lines.add('Cũng được: ${alts.map((x) => '${p.moveName(x.move)} (${fmtScore(x.score)})').join(', ')}');
    final pmH = proMoves(p);
    if (pmH != null && pmH.isNotEmpty) {
      lines.add('Đại sư thường đi: ${proLine(pmH, 3)}. Xem bảng "Khai cuộc đại sư" bên dưới.');
    } else {
      final bookOnly = book.where((m) => m != best.move && !alts.any((a) => a.move == m)).toList();
      if (bookOnly.isNotEmpty) lines.add('Theo bài bản khai cuộc: ${bookOnly.map((m) => p.moveName(m)).join(', ')}');
    }
    arrows = [Arrow(best.move, 'best'), for (final x in alts) Arrow(x.move, 'alt')];
    coach = Coach('💡 Gợi ý', lines: lines);
    _render();
  }

  void _undo() {
    if (view >= 0) {
      view = -1;
      _render();
      return;
    }
    if (state == 'confirm') {
      confirmBlunder(true);
      return;
    }
    if (state != 'user' && state != 'over') return;
    var i = hist.length - 1;
    while (i >= 0 && hist[i].by != 'user') {
      i--;
    }
    if (i < 0) return;
    tok++;
    engine.reset();
    hist = hist.sublist(0, i);
    _rebuildPos();
    moveSerial++;
    result = null;
    arrows = [];
    coach = Coach('Đã đi lại', lines: ['Hãy thử một nước khác.']);
    _save();
    _startUserTurn();
  }

  void _rebuildPos() {
    final p = Pos.start();
    for (final h in hist) {
      h.before = p.clone();
      p.make(h.m);
    }
    pos = p;
  }

  bool get canUndo {
    if (mode == Mode.puzzle) return state != 'ai';
    if (mode == Mode.games) return gmGame != null && gmPly > 0 && state != 'ai';
    return hist.any((h) => h.by == 'user') && state != 'ai';
  }

  bool get canHint {
    if (mode == Mode.games) return gmGame != null && gmPly < gmMoves.length && state != 'ai' && state != 'user';
    return state == 'user' && view < 0;
  }

  /// Nút chính (Gợi ý / Tiến)
  void primaryAction() {
    if (mode == Mode.puzzle) {
      _puzzleHint();
    } else if (mode == Mode.games) {
      if (state == 'reveal') coach?.gmNext = false;
      gmGoto(gmPly + 1);
    } else {
      _showHint();
    }
  }

  /// Nút phụ (Đi lại / Làm lại bài / Lùi)
  void secondaryAction() {
    if (mode == Mode.puzzle) {
      loadPuzzle(pzIdx);
    } else if (mode == Mode.games) {
      gmGoto(gmGuess ? math.max(0, gmPly - 2) : gmPly - 1);
    } else {
      _undo();
    }
  }

  String get statusText {
    if (mode == Mode.games) {
      if (gmGame == null) return 'Đang tải…';
      if (state == 'user') return 'Đến lượt ${sideName(gmSide)}: đại sư sẽ đi nước nào?';
      if (state == 'ai') return 'Đang so sánh…';
      if (state == 'reveal') return 'Xem nước đại sư rồi bấm Tiếp tục';
      if (gmPly >= gmMoves.length) return 'Hết ván';
      return 'Nước $gmPly/${gmMoves.length}';
    }
    if (mode == Mode.puzzle) {
      final left = pzCur != null ? pzCur!.n - _usedMoves() : 0;
      if (view >= 0) return 'Đang xem lại nước ${view + 1}';
      return switch (state) {
        'user' => 'Bài ${pzIdx + 1}: chiếu bí trong $left nước',
        'ai' => 'Máy đang tìm cách đỡ…',
        'fail' => 'Chưa đúng, thử lại nhé',
        'done' => 'Đã chiếu bí!',
        'demo' => 'Đang xem lời giải…',
        _ => '',
      };
    }
    if (view >= 0) return 'Đang xem lại nước ${view + 1}';
    if (state == 'over') return result?.text ?? '';
    if (state == 'ai') return coach != null && coach!.busy ? 'Thầy đang chấm nước của bạn…' : 'Máy đang nghĩ…';
    if (state == 'confirm') return 'Bạn có chắc muốn đi nước này?';
    return pos.inCheck(pos.side) ? 'Bạn đang bị chiếu!' : 'Đến lượt bạn (${sideName(userSide)})';
  }

  bool get statusThinking => state == 'ai' || state == 'demo';
  bool get statusAlert => mode == Mode.play && state == 'user' && view < 0 && pos.inCheck(pos.side);

  /// Thông tin hiển thị khi đang xem lại một nước
  Coach? get shownCoach {
    if (view < 0 || mode != Mode.play) return coach;
    final h = hist[view];
    if (h.by == 'user' && h.coach != null) {
      return Coach(
        'Xem lại · ${h.coach!.title}',
        cls: h.coach!.cls,
        lines: ['Mũi tên cam: nước bạn đã đi. Mũi tên xanh: nước máy đề xuất.', ...h.coach!.lines],
        opening: h.coach!.opening == null ? null : OpeningInfo(h.coach!.opening!, null),
      );
    }
    return Coach('Xem lại · ${h.by == 'ai' ? 'Máy' : 'Bạn'}: ${h.name}', lines: ['Thế cờ trước nước này.']);
  }

  List<Arrow> get shownArrows {
    if (view >= 0) {
      final h = hist[view];
      final bad = h.by == 'user' && h.cls != null && !['best', 'good', 'book'].contains(h.cls);
      return [Arrow(h.m, bad ? 'bad' : 'played'), if (h.best != null && h.best != h.m) Arrow(h.best!, 'best')];
    }
    return arrows;
  }

  HistEntry? get lastMove => view >= 0 || hist.isEmpty ? null : hist.last;

  // ---------- Thao tác trên bàn cờ ----------
  void tapSquare(int sq) {
    if (view >= 0) {
      view = -1;
      _render();
      return;
    }
    if (state != 'user' || sq < 0) return;
    final p = pos.b[sq];
    if (selected >= 0) {
      final m = selected | (sq << 7);
      if (pos.isLegal(m)) {
        if (mode == Mode.puzzle) {
          _onPuzzleMove(m);
        } else if (mode == Mode.games) {
          _onGuessMove(m);
        } else {
          _onUserMove(m);
        }
        return;
      }
    }
    if (p != 0 && sgn(p) == userSide) {
      selected = sq == selected ? -1 : sq;
      if (selected >= 0) _fx('select');
    } else {
      selected = -1;
    }
    _render();
  }

  List<int> get selectedDests {
    if (selected < 0 || view >= 0) return const [];
    return [
      for (final m in pos.legalMoves())
        if ((m & 127) == selected) m >> 7,
    ];
  }

  void tapMoveInList(int i) {
    if (mode == Mode.games) {
      if (state != 'ai') {
        gmGuess = false;
        userSide = RED;
        gmGoto(i + 1);
      }
      return;
    }
    if (state == 'ai') return;
    view = view == i ? -1 : i;
    _render();
  }

  void exitView() {
    view = -1;
    _render();
  }

  void toggleProArrow(int m) {
    arrows = arrows.length == 1 && arrows[0].m == m ? [] : [Arrow(m, 'alt')];
    _render();
  }

  // ---------- Cài đặt ----------
  void setLevel(int l) {
    level = l;
    store.set('level', l);
    _render();
  }

  void setSide(int s) {
    userSide = s;
    store.set('side', s);
    newGame(keepSide: true);
  }

  void setOptions({bool? warn, bool? threats, bool? hanChars, bool? sound}) {
    opt.warn = warn ?? opt.warn;
    opt.threats = threats ?? opt.threats;
    opt.han = hanChars ?? opt.han;
    opt.sound = sound ?? opt.sound;
    store.set('opt', {'warn': opt.warn, 'threats': opt.threats, 'han': opt.han, 'sound': opt.sound});
    _render();
  }

  List<int> get hanging {
    final userTurn = state == 'user' && view < 0;
    return opt.threats && userTurn ? hangingSet(shownPos, userSide) : const [];
  }

  Future<void> setMode(Mode m) async {
    if (_mode == m) return;
    tok++;
    engine.reset();
    _mode = m;
    mode = m;
    store.set('mode', m.name);
    view = -1;
    arrows = [];
    selected = -1;
    result = null;
    if (m == Mode.puzzle) {
      userSide = RED;
      await openCollection(store.get<String>('pzCol', 'thuc-chien'), store.get<int>('pzIdx', 0));
    } else if (m == Mode.games) {
      await _gmEnter();
    } else {
      userSide = store.get<int>('side', RED);
      if (!_restore()) newGame();
    }
  }

  // ---------- Bài tập sát cục ----------
  int _usedMoves() => hist.where((h) => h.by == 'user').length;
  String _pzKey(int i) => '${pzCol!.id}:$i';
  bool isSolved(int i) => pzCol != null && pzSolved.contains(_pzKey(i));
  int get solvedCount => pzCol == null
      ? 0
      : [
          for (var i = 0; i < pzCol!.items.length; i++)
            if (isSolved(i)) i,
        ].length;

  Future<void> openCollection(String id, [int idx = 0]) async {
    var col = _pzCache[id];
    if (col == null) {
      try {
        col = await loadPuzzleCollection(id);
      } catch (_) {
        col = await loadPuzzleCollection('thuc-chien');
      }
      _pzCache[col.id] = col;
    }
    pzCol = col;
    store.set('pzCol', col.id);
    loadPuzzle(idx);
  }

  void loadPuzzle(int i) {
    final items = pzCol?.items;
    if (items == null || items.isEmpty) return;
    tok++;
    i = i.clamp(0, items.length - 1);
    pzIdx = i;
    pzCur = items[i];
    store.set('pzIdx', i);
    pzHintStep = 0;
    pzFails = 0;
    userSide = RED;
    pos = Pos.fromFen(pzCur!.fen);
    hist = [];
    arrows = [];
    selected = -1;
    view = -1;
    state = 'user';
    result = null;
    moveSerial++;
    final lines = ['Đỏ đi trước, chiếu bí trong ${pzCur!.n} nước. Máy sẽ chống đỡ bằng nước tốt nhất.'];
    if (pzCur!.theme != null) lines.add('Đòn: ${pzCur!.theme}. ${themeInfo[pzCur!.theme] ?? ''}');
    if (pzCol!.source != null) lines.add('Nguồn: ${pzCol!.title} · ${pzCol!.source}');
    final n0 = _noteAt(0);
    if (n0.isNotEmpty) lines.add('Lời bình gốc: $n0');
    coach = Coach('Bài ${i + 1}${pzCur!.name != null ? ' · ${pzCur!.name}' : ''}', lines: lines);
    _render();
  }

  void nextPuzzle() => loadPuzzle(pzIdx + 1 < pzCol!.items.length ? pzIdx + 1 : 0);
  void prevPuzzle() => loadPuzzle(pzIdx - 1);

  String _noteAt(int ply) {
    for (final n in pzCur?.notes ?? const <(int, String)>[]) {
      if (n.$1 == ply) return n.$2;
    }
    return '';
  }

  bool _onSolPath() {
    for (var i = 0; i < hist.length; i++) {
      if (i >= pzCur!.sol.length || hist[i].m != pzCur!.sol[i]) return false;
    }
    return true;
  }

  Future<void> _onPuzzleMove(int m) async {
    final t = tok, before = pos.clone(), name = pos.moveName(m);
    final followed = _onSolPath() && hist.length < pzCur!.sol.length && pzCur!.sol[hist.length] == m;
    final capture = pos.b[m >> 7] != 0;
    pos.make(m);
    _moved(pos, m, capture);
    hist.add(HistEntry(m, name, 'user', before));
    selected = -1;
    arrows = [];
    state = 'ai';
    coach = Coach('Máy đang tìm cách đỡ…', busy: true);
    _render();
    final left = pzCur!.n - _usedMoves();
    if (pos.legalMoves().isEmpty) return _puzzleSolved();
    if (left <= 0) return _puzzleFail(null, 'Đã hết ${pzCur!.n} nước mà chưa chiếu bí được.');
    int reply;
    if (followed && hist.length < pzCur!.sol.length) {
      reply = pzCur!.sol[hist.length]; // đúng lời giải gốc: đối phương đỡ theo sách
    } else {
      final r = await engine.search(pos.clone(), SearchOpts(depth: 2 * left + 2, timeMs: 4000, multipv: 1));
      if (t != tok || r == null || r.multi.isEmpty) return;
      final best = r.multi[0];
      if (best.score > -MATE + 2 * left) return _puzzleFail(best.move, null);
      reply = best.move;
    }
    await Future.delayed(Duration(milliseconds: moveAnimMs(m) + 250));
    if (t != tok) return;
    final b2 = pos.clone(), rn = pos.moveName(reply);
    final cap2 = pos.b[reply >> 7] != 0;
    pos.make(reply);
    _moved(pos, reply, cap2);
    hist.add(HistEntry(reply, rn, 'ai', b2));
    state = 'user';
    pzHintStep = 0;
    final lines = [...explain(before, m, short: true), 'Đối phương đỡ: $rn. Còn $left nước nữa để chiếu bí.'];
    var note = _noteAt(hist.length - 1);
    if (note.isEmpty) note = _noteAt(hist.length);
    if (note.isNotEmpty) lines.add('Lời bình gốc: $note');
    coach = Coach('✓ Đúng rồi: $name', cls: 'good', lines: lines);
    _render();
  }

  void _puzzleFail(int? reply, String? msg) {
    pzFails++;
    final h = hist.last, lines = <String>[];
    if (msg != null) lines.add(msg);
    if (reply != null) {
      lines.add('Đối phương thoát được bằng ${pos.moveName(reply)} (mũi tên cam).');
      arrows = [Arrow(reply, 'bad')];
    }
    lines.add('Bấm "Thử lại" để đi lại nước này, hoặc "Gợi ý" sau khi thử lại.');
    state = 'fail';
    _fx('fail', 350);
    coach = Coach('✗ Chưa đúng: ${h.name}', cls: 'mistake', lines: lines);
    _render();
  }

  void retryPuzzle() {
    var i = hist.length - 1;
    while (i >= 0 && hist[i].by != 'user') {
      i--;
    }
    if (i < 0) return loadPuzzle(pzIdx);
    tok++;
    pos = hist[i].before.clone();
    hist = hist.sublist(0, i);
    moveSerial++;
    arrows = [];
    selected = -1;
    state = 'user';
    coach = Coach(
      'Thử lại',
      lines: ['Còn ${pzCur!.n - _usedMoves()} nước để chiếu bí. Hãy tìm nước chiếu mà đối phương không thoát được.'],
    );
    _render();
  }

  void _puzzleSolved() {
    state = 'done';
    arrows = [];
    pzSolved.add(_pzKey(pzIdx));
    store.set('solved', pzSolved.toList());
    _fx('win', 480);
    final lines = [
      pzFails > 0 ? 'Bạn giải được sau $pzFails lần thử sai.' : 'Giải đúng ngay lần đầu!',
      'Các nước: ${hist.map((h) => h.name).join(' → ')}',
    ];
    if (pzCur!.theme != null) lines.add('Đòn: ${pzCur!.theme}. ${themeInfo[pzCur!.theme] ?? ''}');
    final note = _noteAt(hist.length);
    if (note.isNotEmpty) lines.add('Lời bình gốc: $note');
    coach = Coach('🎉 Chiếu bí! Xong bài ${pzIdx + 1}', cls: 'best', lines: lines);
    _render();
  }

  Future<void> _puzzleHint() async {
    if (state != 'user') return;
    final t = tok, left = pzCur!.n - _usedMoves();
    int m;
    int? score;
    if (_onSolPath() && hist.length < pzCur!.sol.length) {
      m = pzCur!.sol[hist.length];
    } else {
      coach = Coach('Đang tìm…', busy: true);
      _render();
      final r = await engine.search(pos.clone(), SearchOpts(depth: 2 * left + 1, timeMs: 4000, multipv: 1));
      if (t != tok || r == null || r.multi.isEmpty) return;
      m = r.multi[0].move;
      score = r.multi[0].score;
    }
    pzHintStep++;
    if (pzHintStep == 1) {
      selected = m & 127;
      coach = Coach(
        '💡 Gợi ý 1',
        lines: ['Quân cần đi: ${nameOf(pos.b[m & 127])} (đang được chọn sẵn).', 'Bấm Gợi ý lần nữa để xem nước cụ thể.'],
      );
    } else {
      arrows = [Arrow(m, 'best')];
      coach = Coach(
        '💡 Gợi ý 2',
        lines: [
          'Nước đúng: ${pos.moveName(m)}.',
          ...explain(pos, m, score: score, short: true),
        ],
      );
    }
    _render();
  }

  Future<void> showSolution() async {
    final t = ++tok;
    pos = Pos.fromFen(pzCur!.fen);
    hist = [];
    arrows = [];
    selected = -1;
    view = -1;
    state = 'demo';
    moveSerial++;
    coach = Coach('Lời giải bài ${pzIdx + 1}${pzCur!.name != null ? ' · ${pzCur!.name}' : ''}');
    _render();
    for (final m in pzCur!.sol) {
      await Future.delayed(const Duration(milliseconds: 1000));
      if (t != tok) return;
      final b = pos.clone(), nm = pos.moveName(m);
      coach!.lines.add('${b.side == RED ? 'Đỏ: ' : 'Đen: '}$nm');
      final cap = pos.b[m >> 7] != 0;
      pos.make(m);
      _moved(pos, m, cap);
      hist.add(HistEntry(m, nm, b.side == RED ? 'user' : 'ai', b));
      final note = _noteAt(hist.length);
      if (note.isNotEmpty) coach!.lines.add('   ↳ $note');
      _render();
    }
    state = 'done';
    coach!.lines.add('Chiếu bí!${pzCur!.theme != null ? ' ${themeInfo[pzCur!.theme] ?? ''}' : ''}');
    _render();
  }

  // ---------- Ván đại sư: xem lại & luyện đoán nước ----------
  Future<void> _gmEnter() async {
    state = 'gview';
    hist = [];
    arrows = [];
    userSide = gmGuess ? gmSide : RED;
    _render();
    if (gmIndex == null) {
      try {
        gmIndex = await loadGameIndex();
      } catch (_) {
        gmIndex = [];
      }
    }
    if (mode != Mode.games) return;
    if (gmCol == null) {
      await gmOpenCol(store.get<String?>('gmCol', gmIndex!.isNotEmpty ? gmIndex![0].id : null), store.get<int>('gmGame', 0));
    } else {
      gmGoto(gmPly);
    }
  }

  Future<void> gmOpenCol(String? id, [int gi = 0]) async {
    if (id == null) return;
    var col = _gmCache[id];
    if (col == null) {
      try {
        col = await loadGameCollection(id);
        _gmCache[id] = col;
      } catch (_) {
        return;
      }
    }
    gmCol = col;
    store.set('gmCol', id);
    gmFilter = '';
    gmLoad(math.min(gi, col.games.length - 1));
  }

  void gmLoad(int i) {
    tok++;
    final g = gmCol!.games[i];
    gmGi = i;
    gmGame = g;
    store.set('gmGame', i);
    _gmStart = g.fen != null ? Pos.fromFen(g.fen!) : Pos.start();
    gmMoves = g.decodeMoves();
    gmOk = gmNear = gmTot = 0;
    gmSide = g.res == -1 ? BLACK : RED; // mặc định đoán nước bên thắng
    userSide = gmGuess ? gmSide : RED;
    gmGoto(0);
  }

  void gmGoto(int ply) {
    if (gmGame == null) return;
    tok++;
    ply = ply.clamp(0, gmMoves.length);
    final p = _gmStart!.clone();
    hist = [];
    for (var k = 0; k < ply; k++) {
      final m = gmMoves[k];
      if (!p.isLegal(m)) {
        ply = k;
        break;
      }
      final b = p.clone();
      hist.add(HistEntry(m, p.moveName(m), 'ai', b));
      p.make(m);
    }
    final forward = ply == gmPly + 1;
    pos = p;
    gmPly = ply;
    view = -1;
    selected = -1;
    arrows = [];
    if (forward && hist.isNotEmpty) {
      final last = hist.last;
      _moved(p, last.m, last.before.b[last.m >> 7] != 0);
    } else {
      moveSerial++;
    }
    state = gmGuess && ply < gmMoves.length && p.side == gmSide ? 'user' : 'gview';
    _gmShow();
    if (gmGuess && state == 'gview' && ply < gmMoves.length) _gmAutoReply();
  }

  Future<void> _gmAutoReply() async {
    final t = tok;
    await Future.delayed(const Duration(milliseconds: 700));
    if (t != tok || mode != Mode.games) return;
    gmGoto(gmPly + 1);
  }

  List<String> _gmInfoLines() {
    final g = gmGame!, lines = <String>[];
    final who = '${g.r ?? 'Đỏ'} (Đỏ) – ${g.b ?? 'Đen'} (Đen)';
    lines.add(
      who +
          (g.res == 1
              ? ' · Đỏ thắng'
              : g.res == -1
              ? ' · Đen thắng'
              : g.res == 0
              ? ' · Hòa'
              : ''),
    );
    final meta = [g.ev, g.d].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    if (meta.isNotEmpty) lines.add(meta);
    if (g.eco != null) {
      lines.add('Khai cuộc: ${g.eco}');
    } else if (g.t != null) {
      lines.add(g.t!);
    }
    return lines;
  }

  String _gmNote(int ply) {
    for (final n in gmGame?.notes ?? const <(int, String)>[]) {
      if (n.$1 == ply) return n.$2;
    }
    return '';
  }

  void _gmShow() {
    if (gmGame == null) {
      _render();
      return;
    }
    final lines = _gmInfoLines();
    final note = _gmNote(gmPly);
    if (note.isNotEmpty) lines.add('Bình luận: $note');
    if (gmGuess) {
      lines.add(
        'Luyện đoán nước bên ${sideName(gmSide)}: trùng $gmOk/$gmTot'
        '${gmNear > 0 ? ', tương đương $gmNear' : ''}'
        '${gmTot > 0 ? ' (${(100 * (gmOk + gmNear) / gmTot).round()}%)' : ''}',
      );
    }
    final fl = _gmFlash;
    String title;
    String? c;
    if (fl != null && fl.n > 0) {
      title = fl.title;
      c = fl.cls;
      _gmFlash = (title: fl.title, cls: fl.cls, n: fl.n - 1);
    } else {
      title = '${gmCol?.title ?? ''} · Ván ${gmGi + 1}';
    }
    coach = Coach(title, cls: c, lines: lines);
    _render();
  }

  Future<void> _onGuessMove(int m) async {
    final t = tok, before = pos.clone(), master = gmMoves[gmPly];
    final mine = before.moveName(m), mname = before.moveName(master);
    gmTot++;
    if (m == master) {
      gmOk++;
      _gmFlash = (title: '✓ Trùng nước đại sư: $mine', cls: 'best', n: 2);
      gmGoto(gmPly + 1);
      return;
    }
    state = 'ai';
    selected = -1;
    coach = Coach('Đang so sánh với nước đại sư…', busy: true);
    _render();
    final pa = before.clone()..make(m);
    final pb = before.clone()..make(master);
    final ra = await engine.search(pa, const SearchOpts(timeMs: 900, multipv: 1));
    if (t != tok || ra == null) return;
    final rb = await engine.search(pb, const SearchOpts(timeMs: 900, multipv: 1));
    if (t != tok || rb == null) return;
    final sa = ra.multi.isEmpty ? MATE : -ra.multi[0].score, sb = rb.multi.isEmpty ? MATE : -rb.multi[0].score;
    final diff = clampS(sb) - clampS(sa);
    String verdict, c;
    if (diff <= 30) {
      verdict = 'Nước của bạn được máy đánh giá tương đương (chênh ${(diff / 100).toStringAsFixed(1)}).';
      c = 'good';
      gmNear++;
    } else if (diff <= 120) {
      verdict = 'Nước của đại sư tốt hơn khoảng ${(diff / 100).toStringAsFixed(1)} Tốt.';
      c = 'inacc';
    } else {
      verdict = 'Nước của bạn kém hơn rõ rệt (${(diff / 100).toStringAsFixed(1)} Tốt).';
      c = 'mistake';
    }
    state = 'reveal';
    arrows = [Arrow(master, 'best'), Arrow(m, 'bad')];
    final lines = _gmInfoLines();
    lines.add('Bạn đi: $mine (mũi tên cam). Đại sư đi: $mname (mũi tên xanh).');
    lines.add(verdict);
    lines.addAll(explain(before, master, score: sb).map((x) => '• $x'));
    coach = Coach('Đại sư đi $mname', cls: c, lines: lines, gmNext: true);
    _render();
  }

  void gmNext() {
    coach?.gmNext = false;
    gmGoto(gmPly + 1);
  }

  void gmFirst() => gmGoto(0);

  void gmLast() {
    gmGuess = false;
    userSide = RED;
    gmGoto(gmMoves.length);
  }

  void gmToggleGuess() {
    gmGuess = !gmGuess;
    userSide = gmGuess ? gmSide : RED;
    gmOk = gmNear = gmTot = 0;
    gmGoto(gmGuess ? 0 : gmPly);
  }

  void gmToggleSide() {
    gmSide = -gmSide;
    if (gmGuess) {
      userSide = gmSide;
      gmOk = gmNear = gmTot = 0;
      gmGoto(0);
    } else {
      _gmShow();
    }
  }

  void setGmFilter(String f) {
    gmFilter = f;
    _render();
  }
}
