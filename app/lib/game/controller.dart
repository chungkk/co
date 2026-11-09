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
import 'notation.dart';

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

  /// null = thế ban đầu; khác: ván bắt đầu từ thế cờ này (tàn cục, ván nhập vào)
  String? startFen;
  String? gameTitle;
  Coach? _pendingCoach;
  Pos _startPos() => startFen != null ? Pos.fromFen(startFen!) : Pos.start();

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

  /// Thế cờ đã giải (theo FEN): cùng thế cờ ở nhiều bộ chỉ cần giải một lần
  late Set<String> pzSolvedFen;
  bool pzHinted = false, _pzRecorded = false;

  /// Sổ lỗi sai: thế cờ người chơi từng đi Sai lầm/Nước hỏng
  late List<ReviewCard> reviews;

  /// Thống kê theo chủ đề: [giải đúng ngay lần đầu, số lần thử]
  late Map<String, List<int>> themeStat;

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
    pzSolvedFen = store.get<List<dynamic>>('solvedFen', []).cast<String>().toSet();
    reviews = [
      for (final x in store.get<List<dynamic>>('review', []))
        if (x is Map<String, dynamic>) ReviewCard.fromJson(x),
    ];
    themeStat = {
      for (final e in store.get<Map<String, dynamic>>('themeStat', {}).entries)
        e.key: [for (final v in e.value as List) (v as num).toInt()],
    };
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
          _updateReviewCount();
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
    if (pro != null || startFen != null) return [];
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
    if (startFen != null) return null;
    final e = _ecoOf();
    final old = _oldOpening(names);
    if (e != null) return OpeningInfo(e.name, old?.tip);
    return old == null ? null : OpeningInfo(old.name, old.tip);
  }

  // ---------- Luyện khai cuộc theo cây nước đại sư ----------
  /// Các khai cuộc có thể chọn để luyện: "tự do" + mỗi tên trong [openings] một lần
  static final drillOps = <Opening>[
    const Opening([], 'Tự do (theo đại sư)', null),
    for (var i = 0; i < openings.length; i++)
      if (openings.indexWhere((x) => x.name == openings[i].name) == i) openings[i],
  ];
  static const drillMin = 20; // thế cờ có ít hơn số ván này coi như đã ra khỏi sách

  /// Đang luyện khai cuộc (null = ván thường)
  ({String name, int ok, int tot, int fails})? drill;

  /// Khai cuộc đang chọn để luyện (chỉ số trong [drillOps])
  int drillOp = 0;
  void setDrillOp(int k) {
    drillOp = k;
    _render();
  }

  int _bookTot(List<BookMove>? pm) => pm == null ? 0 : pm.fold<int>(0, (s, x) => s + x.n);

  /// Nước chấp nhận được: ≥10% số ván, hoặc nằm trong top 3 và ≥3%
  ({BookMove x, int rank, BookMove top})? _drillAccept(List<BookMove> pm, int m) {
    final sorted = [...pm]..sort((a, b) => b.n.compareTo(a.n));
    final rank = sorted.indexWhere((y) => y.m == m);
    if (rank < 0) return null;
    final x = sorted[rank];
    return x.share >= 0.1 || (rank < 3 && x.share >= 0.03) ? (x: x, rank: rank, top: sorted[0]) : null;
  }

  void startDrill(int k) {
    if (pro == null) return;
    final op = drillOps[k.clamp(0, drillOps.length - 1)];
    tok++;
    engine.reset();
    startFen = null;
    gameTitle = null;
    pos = Pos.start();
    hist = [];
    selected = -1;
    arrows = [];
    view = -1;
    result = null;
    hintsUsed = 0;
    lastScore = 0;
    moveSerial++;
    for (final nm in op.seq) {
      final m = pos.legalMoves().where((x) => pos.moveName(x) == nm).firstOrNull;
      if (m == null) break;
      final before = pos.clone();
      pos.make(m);
      hist.add(HistEntry(m, nm, 'ai', before)); // nước dựng sẵn của khai cuộc, không tính là nước của người chơi
    }
    drill = (name: op.name, ok: 0, tot: 0, fails: 0);
    coach = Coach(
      '📖 Luyện khai cuộc: ${op.name}',
      lines: [
        'Bạn cầm ${sideName(userSide)}. Máy đi theo các nước đại sư hay chơi; bạn hãy đáp bằng nước phổ biến (≥10% số ván, hoặc nằm trong top 3).',
        'Đi nước hiếm hoặc ngoài sách sẽ được đi lại. Bấm "Gợi ý" để xem đại sư thường đi gì.',
        if (op.tip != null) '${op.name}: ${op.tip}',
      ],
    );
    _save();
    _drillNext();
  }

  void stopDrill() {
    tok++;
    drill = null;
    arrows = [];
    coach = Coach('Đã dừng luyện khai cuộc', lines: ['Ván tiếp tục như đấu thường: máy đánh theo cấp độ đã chọn, thầy chấm từng nước.']);
    _continueGame();
  }

  void _continueGame() {
    if (_checkOver()) return;
    if (pos.side == userSide) {
      _startUserTurn();
    } else {
      _aiTurn();
    }
  }

  void _drillNext() {
    final pm = proMoves(pos);
    if (_bookTot(pm) < drillMin) return _drillEnd();
    if (pos.side == userSide) {
      state = 'user';
      selected = -1;
      drill = (name: drill!.name, ok: drill!.ok, tot: drill!.tot, fails: 0);
      _render();
    } else {
      _drillReply(pm!);
    }
  }

  Future<void> _drillReply(List<BookMove> pm) async {
    final t = tok;
    state = 'ai';
    _render();
    await Future.delayed(const Duration(milliseconds: 450));
    if (t != tok || drill == null) return;
    // chọn theo tần suất đại sư, bỏ các nước quá hiếm
    final pool = pm.where((x) => x.n >= 3 && x.share >= 0.03).toList();
    final ws = pool.isNotEmpty ? pool : pm;
    var r0 = _rnd.nextDouble() * ws.fold<int>(0, (s, x) => s + x.n);
    var pick = ws.last;
    for (final x in ws) {
      r0 -= x.n;
      if (r0 <= 0) {
        pick = x;
        break;
      }
    }
    final before = pos.clone(), name = pos.moveName(pick.m), capture = pos.b[pick.m >> 7] != 0;
    pos.make(pick.m);
    _moved(pos, pick.m, capture);
    hist.add(HistEntry(pick.m, name, 'ai', before));
    if (coach != null && !coach!.busy) coach!.lines.add('Máy đáp: $name (${pct(pick.share)} số ván đại sư).');
    _save();
    _drillNext();
  }

  void _onDrillMove(int m) {
    final pm = proMoves(pos) ?? const <BookMove>[], name = pos.moveName(m), d = drill!;
    final ok = _drillAccept(pm, m);
    if (ok == null) {
      drill = (name: d.name, ok: d.ok, tot: d.tot, fails: d.fails + 1);
      final y = pm.where((z) => z.m == m).firstOrNull;
      final lines = [
        y != null
            ? '$name chỉ có ${fmtInt(y.n)} ván (${pct(y.share)}): đại sư ít chọn nước này.'
            : '$name không có trong ván đại sư nào ở thế cờ này.',
      ];
      if (drill!.fails >= 2) {
        lines.add('Đại sư thường đi: ${proLine(pm, 3)}. Mũi tên xanh là nước chính.');
        arrows = [for (var i = 0; i < pm.length && i < 3; i++) Arrow(pm[i].m, i == 0 ? 'best' : 'alt')];
      } else {
        lines.add('Hãy thử lại. Bấm "Gợi ý" nếu chưa nhớ.');
        arrows = [Arrow(m, 'bad')];
      }
      _fx('fail');
      coach = Coach('✗ $name: ${y != null ? 'nước hiếm' : 'ngoài sách'}', cls: 'mistake', lines: lines);
      selected = -1;
      _render();
      return;
    }
    drill = (name: d.name, ok: d.ok + (d.fails == 0 ? 1 : 0), tot: d.tot + 1, fails: d.fails);
    final x = ok.x, rank = ok.rank;
    final before = pos.clone(), capture = pos.b[m >> 7] != 0;
    pos.make(m);
    _moved(pos, m, capture);
    final lines = [
      '${rank == 0 ? 'Nước chính' : 'Nước phổ biến'}: ${fmtInt(x.n)} ván đại sư (${pct(x.share)}), bên đi thắng ${pct(x.w / x.n)}, hòa ${pct(x.d / x.n)}.',
      if (rank > 0) 'Nước chính ở thế này: ${ok.top.name} (${pct(ok.top.share)}).',
      if (d.fails > 0) '(Đúng sau ${d.fails} lần thử.)',
    ];
    final c = rank == 0 ? 'best' : 'book';
    final co = Coach('${rank == 0 ? '★' : '📖'} $name: nước của đại sư', cls: c, lines: lines);
    hist.add(
      HistEntry(m, name, 'user', before, cls: d.fails > 0 ? 'inacc' : c, coach: SavedCoach(co.title, co.cls, lines, null)),
    );
    coach = co;
    arrows = [];
    _save();
    _render();
    _drillNext();
  }

  void _drillHint() {
    final pm = proMoves(pos) ?? const <BookMove>[];
    hintsUsed++;
    final d = drill!;
    drill = (name: d.name, ok: d.ok, tot: d.tot, fails: math.max(d.fails, 1));
    arrows = [for (var i = 0; i < pm.length && i < 3; i++) Arrow(pm[i].m, i == 0 ? 'best' : 'alt')];
    coach = Coach(
      '💡 Đại sư thường đi',
      lines: ['${proLine(pm, 3)}.', 'Mũi tên xanh là nước chính, mũi tên vàng là các nước phổ biến khác.'],
    );
    _render();
  }

  void _drillEnd() {
    final d = drill!;
    drill = null;
    final e = _ecoOf();
    coach = Coach(
      '🏁 Hết sách khai cuộc: ${d.name}',
      lines: [
        'Thế cờ đã ra khỏi sách (ít hơn $drillMin ván đại sư).',
        if (d.tot > 0) 'Bạn đi đúng ngay lần đầu ${d.ok}/${d.tot} nước (${pct(d.ok / d.tot)}).',
        if (e != null) 'Thế trận: ${e.name}.',
        'Ván tiếp tục: từ đây máy đánh theo cấp độ đã chọn và thầy chấm từng nước như bình thường. Bấm "Luyện khai cuộc" để luyện lại.',
      ],
    );
    _continueGame();
  }

  // ---------- Ván từ thế cờ bất kỳ: tàn cục đại sư, ván/thế cờ nhập vào ----------
  /// Ghi ván vào bộ nhớ rồi chuyển sang chế độ đấu: _restore() dựng lại và cho máy/người đi tiếp.
  /// [mine]: các nước có sẵn là của người chơi (ván nhập vào) hay của người khác (ván đại sư).
  Future<void> playFrom({
    String? fen,
    required List<int> moves,
    required int side,
    String? title,
    required List<String> lines,
    bool mine = false,
  }) async {
    final p = fen != null ? Pos.fromFen(fen) : Pos.start();
    final ms = <Map<String, dynamic>>[];
    for (final m in moves) {
      ms.add({'m': m, 'by': mine && p.side == side ? 'user' : 'ai'});
      p.make(m);
    }
    store.set('game', {'side': side, 'fen': fen, 'title': title, 'moves': ms, 'hints': 0});
    _pendingCoach = Coach(title ?? 'Ván mới từ thế cờ', lines: lines);
    if (mode == Mode.play) {
      tok++;
      engine.reset();
      if (!_restore()) newGame();
    } else {
      await setMode(Mode.play);
    }
  }

  /// Nhập FEN/biên bản; trả về lời báo lỗi hoặc null. [side]: RED, BLACK hoặc 0 = bên tới lượt.
  String? importGame(String text, int side) {
    final r = parseImport(text);
    if (r.err != null) return r.err;
    final end = r.fen != null ? Pos.fromFen(r.fen!) : Pos.start();
    for (final m in r.moves) {
      end.make(m);
    }
    final s = side == 0 ? end.side : side;
    playFrom(
      fen: r.fen,
      moves: r.moves,
      side: s,
      title: 'Ván nhập vào',
      mine: true,
      lines: [
        r.moves.isNotEmpty
            ? 'Đã nhập ${r.moves.length} nửa nước${r.fen != null ? ' từ thế cờ FEN' : ''}. Bạn cầm ${sideName(s)}.'
            : 'Đã nhập thế cờ. Bạn cầm ${sideName(s)}.',
        if (r.warn != null) '⚠️ ${r.warn}',
        r.moves.isNotEmpty
            ? 'Bấm "Phân tích ván" để thầy chấm từng nước của bạn; các nước sai sẽ vào sổ "Ôn lỗi sai". Hoặc cứ đánh tiếp với máy.'
            : 'Đánh tiếp với máy từ thế này. Thầy chấm từng nước như bình thường.',
      ],
    );
    return null;
  }

  /// FEN của thế cờ đang hiển thị
  String get currentFen => shownPos.toFen();

  /// Có nước của người chơi chưa được chấm (ván nhập vào)
  bool get canAnalyze => mode == Mode.play && view < 0 && state == 'user' && hist.any((h) => h.by == 'user' && h.cls == null);

  String _classify(int loss, bool isBest, bool isBook, int userScore, int bestScore) {
    String c;
    if (isBest) {
      c = 'best';
    } else if (isBook && loss <= 120) {
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
    if (clampS(userScore) > 1500 && c != 'blunder' && !(bestScore > MATE - 500 && userScore < MATE - 500)) {
      c = c == 'best' ? 'best' : 'good';
    }
    if (bestScore > MATE - 500 && userScore < MATE - 500 && c != 'blunder') c = 'mistake';
    return c;
  }

  /// Chấm lại từng nước của người chơi trong ván (ván nhập vào chưa có điểm)
  Future<void> analyzeGame() async {
    final todo = hist.where((h) => h.by == 'user' && h.cls == null).toList();
    if (todo.isEmpty) return;
    final t = ++tok;
    engine.reset();
    state = 'analyze';
    view = -1;
    arrows = [];
    var saved = 0;
    for (var k = 0; k < todo.length; k++) {
      final h = todo[k];
      coach = Coach(
        'Đang phân tích ván… ${k + 1}/${todo.length}',
        busy: true,
        lines: ['Máy chấm từng nước của bạn (khoảng 1 giây mỗi nước). Có thể chạm vào các nước đã chấm để xem.'],
      );
      _render();
      final before = h.before, after = before.clone()..make(h.m);
      final rb = await engine.analyse(before.clone(), const SearchOpts(timeMs: 700, multipv: 1));
      if (t != tok || rb == null || rb.multi.isEmpty) return;
      final best = rb.multi[0];
      var userScore = best.score;
      int? reply;
      if (h.m != best.move) {
        if (after.legalMoves().isEmpty) {
          userScore = MATE - 1;
        } else {
          final ra = await engine.analyse(after.clone(), const SearchOpts(timeMs: 500, multipv: 1));
          if (t != tok || ra == null) return;
          userScore = ra.multi.isNotEmpty ? -ra.multi[0].score : 0;
          reply = ra.multi.isNotEmpty ? ra.multi[0].move : null;
        }
      }
      final loss = math.max(0, clampS(best.score) - clampS(userScore));
      final pm = proMoves(before);
      final bx = pm?.where((y) => y.m == h.m).firstOrNull;
      final c = _classify(loss, h.m == best.move, bx != null && bx.share >= 0.05 && bx.n >= 10, userScore, best.score);
      h.cls = c;
      h.loss = loss;
      h.acc = (100 * math.exp(-loss / 280)).round();
      h.best = best.move;
      h.bestName = before.moveName(best.move);
      final lines = <String>[];
      if (c == 'best' || c == 'book' || c == 'good') {
        if (bx != null) lines.add('Nước của đại sư: ${fmtInt(bx.n)} ván (${pct(bx.share)}).');
        lines.addAll(explain(before, h.m, score: userScore).map((x) => '• $x'));
        if (c == 'good' && h.m != best.move) lines.add('Máy thích ${h.bestName} hơn một chút.');
      } else {
        lines.add('Bạn mất khoảng ${(loss / 100).toStringAsFixed(1)} Tốt lợi thế.');
        if (reply != null && after.isLegal(reply)) {
          lines.add('Vì đối phương có thể đáp ${after.moveName(reply)}: ${lc(explain(after, reply, short: true).join(' '))}');
        }
        lines.add('Nước tốt hơn: ${h.bestName}.');
        if (pm != null && pm.isNotEmpty) lines.add('Đại sư thường đi: ${proLine(pm, 3)}.');
        lines.addAll(explain(before, best.move, score: best.score).map((x) => '• $x'));
        if ((c == 'mistake' || c == 'blunder') && addReview(before, h.m, best.move, loss)) saved++;
      }
      h.coach = SavedCoach('${cls[c]!.icon} ${h.name}: ${cls[c]!.label}', c, lines, null);
      _save();
    }
    final mine = hist.where((h) => h.by == 'user' && h.cls != null).toList();
    final cnt = <String, int>{};
    var acc = 0;
    for (final h in mine) {
      cnt[h.cls!] = (cnt[h.cls!] ?? 0) + 1;
      acc += h.acc ?? accOf[h.cls!]!;
    }
    final lines = [
      'Độ chính xác của bạn: ${(acc / mine.length).round()}%',
      cls.keys.where((k) => cnt[k] != null).map((k) => '${cls[k]!.icon} ${cls[k]!.short}: ${cnt[k]}').join(' · '),
      'Chạm vào các nước đánh dấu ? hoặc ?? trong danh sách nước đi để xem nên đi thế nào.',
      if (saved > 0) '📌 $saved thế cờ đi sai đã được lưu vào "Ôn lỗi sai của bạn" (tab Bài tập).',
    ];
    coach = Coach('Phân tích xong', lines: lines);
    if (_checkOver()) {
      coach = Coach('Phân tích xong', lines: [result!.text, ...lines]);
      _render();
    } else if (pos.side == userSide) {
      _startUserTurn();
    } else {
      _aiTurn();
    }
  }

  // ---------- Luồng ván cờ ----------
  void _save() {
    if (mode != Mode.play) return;
    store.set('game', {
      'side': userSide,
      'fen': startFen,
      'title': gameTitle,
      'moves': [
        for (final h in hist) {'m': h.m, 'by': h.by, 'cls': h.cls, 'coach': h.coach?.toJson()},
      ],
      'hints': hintsUsed,
    });
  }

  void newGame({bool keepSide = false}) {
    tok++;
    engine.reset();
    drill = null;
    startFen = null;
    gameTitle = null;
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
    drill = null;
    if (g == null || g['moves'] == null || ((g['moves'] as List).isEmpty && g['fen'] == null)) return false;
    try {
      userSide = g['side'] as int;
      startFen = g['fen'] as String?;
      gameTitle = g['title'] as String?;
      final p = _startPos();
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
      coach =
          _pendingCoach ??
          Coach('Tiếp tục ván cũ', lines: ['Ván cờ trước đã được khôi phục.${gameTitle != null ? ' ($gameTitle)' : ''}']);
      _pendingCoach = null;
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
      startFen = null;
      gameTitle = null;
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
      final bad = hist.where((h) => h.by == 'user' && (h.cls == 'mistake' || h.cls == 'blunder')).length;
      if (bad > 0) {
        lines.add(
          'Bấm vào các nước đánh dấu ? hoặc ?? trong danh sách nước đi để xem lại nên đi thế nào. '
          '$bad thế cờ đi sai đã được lưu vào "Ôn lỗi sai của bạn" ở tab Bài tập.',
        );
      }
    }
    if (hintsUsed > 0) lines.add('Số lần dùng gợi ý: $hintsUsed');
    return Coach('Kết thúc ván', lines: lines);
  }

  void _startUserTurn() {
    state = 'user';
    selected = -1;
    final p = pos.clone(), t = tok;
    final f = engine.analyse(p, const SearchOpts(timeMs: coachMs, multipv: 3));
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
      final r = await engine.analyse(pos.clone(), SearchOpts(timeMs: (coachMs * 0.8).round(), multipv: 1));
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
    final saved = (c == 'mistake' || c == 'blunder') && addReview(before, m, best.move, loss);

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
      if (saved) lines.add('📌 Đã lưu thế cờ này vào "Ôn lỗi sai của bạn" (tab Bài tập) để luyện lại.');
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
    if (drill != null) {
      _render();
      return _drillNext();
    }
    _startUserTurn();
  }

  void _rebuildPos() {
    final p = _startPos();
    for (final h in hist) {
      h.before = p.clone();
      p.make(h.m);
    }
    pos = p;
  }

  bool get canUndo {
    if (mode == Mode.puzzle) return state != 'ai' && pzCur != null;
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
    } else if (drill != null) {
      _drillHint();
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
      if (pzCol?.review ?? false) {
        if (state == 'user') return 'Thẻ ${pzIdx + 1}: tìm nước tốt nhất';
        if (state == 'done') return 'Đã tìm ra nước đúng';
        if (state == 'ai') return 'Thầy đang chấm…';
      }
      return switch (state) {
        'empty' => 'Chưa có thẻ nào',
        'user' => 'Bài ${pzIdx + 1}: chiếu bí trong $left nước',
        'ai' => 'Máy đang tìm cách đỡ…',
        'fail' => 'Chưa đúng, thử lại nhé',
        'done' => 'Đã chiếu bí!',
        'demo' => 'Đang xem lời giải…',
        _ => '',
      };
    }
    if (view >= 0) return 'Đang xem lại nước ${view + 1}';
    if (state == 'analyze') return 'Đang phân tích ván…';
    if (state == 'over') return result?.text ?? '';
    if (drill != null && state == 'ai') return 'Máy đi theo đại sư…';
    if (state == 'ai') return coach != null && coach!.busy ? 'Thầy đang chấm nước của bạn…' : 'Máy đang nghĩ…';
    if (state == 'confirm') return 'Bạn có chắc muốn đi nước này?';
    if (drill != null) return 'Luyện khai cuộc: nước ${hist.length ~/ 2 + 1}, đến lượt bạn';
    return pos.inCheck(pos.side) ? 'Bạn đang bị chiếu!' : 'Đến lượt bạn (${sideName(userSide)})';
  }

  bool get statusThinking => state == 'ai' || state == 'demo' || state == 'analyze';
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
        } else if (drill != null) {
          _onDrillMove(m);
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
  String _pzKey(int i) => '${pzCol!.id}:${pzCol!.items[i].k ?? i}';
  bool isSolved(int i) {
    final col = pzCol;
    if (col == null) return false;
    if (col.review) return col.items[i].rv!.due > _now();
    return pzSolved.contains(_pzKey(i)) || pzSolvedFen.contains(col.items[i].fen);
  }

  // ---------- Sổ lỗi sai: ôn lại thế cờ mình từng đi sai (lặp lại ngắt quãng) ----------
  static const _day = 86400000, _revMax = 300;

  /// Đồng hồ (ms); test có thể thay để giả lập thời gian trôi
  int Function() clock = () => DateTime.now().millisecondsSinceEpoch;
  int _now() => clock();

  void _saveReview() => store.set('review', [for (final c in reviews) c.toJson()]);

  bool addReview(Pos before, int played, int best, int loss) {
    if (played == best) return false;
    final fen = before.toFen();
    var c = reviews.where((x) => x.fen == fen).firstOrNull;
    if (c == null) {
      c = ReviewCard(
        fen: fen,
        added: _now(),
        best: best,
        played: played,
        bestName: '',
        playedName: '',
        loss: loss,
        due: _now(),
      );
      reviews.add(c);
    }
    c
      ..best = best
      ..played = played
      ..bestName = before.moveName(best)
      ..playedName = before.moveName(played)
      ..loss = loss
      ..iv = 0
      ..due = _now();
    if (reviews.length > _revMax) reviews.removeRange(0, reviews.length - _revMax);
    _saveReview();
    _updateReviewCount();
    return true;
  }

  int get reviewDue => reviews.where((c) => c.due <= _now()).length;

  void _updateReviewCount() {
    for (final c in pzCols) {
      if (c.id != reviewColId) continue;
      c.count = reviews.length;
      c.title = 'Ôn lỗi sai của bạn${reviewDue > 0 ? ' · $reviewDue đến hạn' : ''}';
    }
  }

  PuzzleCollection _reviewCollection() {
    // thẻ đến hạn lên trước, rồi tới thẻ sắp đến hạn
    final cards = [...reviews]..sort((a, b) => a.due.compareTo(b.due));
    return PuzzleCollection(reviewColId, 'Ôn lỗi sai của bạn', null, [
      for (final c in cards) Puzzle(c.fen, 1, [c.best], null, null, const [], null, const [], c),
    ], review: true);
  }

  void _gradeReview(ReviewCard c, bool ok) {
    c.reps++;
    if (ok) {
      c.iv = c.iv > 0 ? math.min(120, (c.iv * 2.5).round()) : 1;
    } else {
      c.iv = 0;
      c.lapses++;
    }
    c.due = _now() + (ok ? c.iv * _day : 0);
    _saveReview();
    _updateReviewCount();
  }

  String fmtDue(ReviewCard c) {
    final d = ((c.due - _now()) / _day).ceil();
    return d <= 0 ? 'đến hạn ôn' : 'ôn lại sau $d ngày';
  }

  Future<void> _onReviewMove(int m) async {
    final t = tok, before = pos.clone(), name = pos.moveName(m), c = pzCur!.rv!;
    final capture = pos.b[m >> 7] != 0;
    pos.make(m);
    _moved(pos, m, capture);
    hist.add(HistEntry(m, name, 'user', before));
    selected = -1;
    arrows = [];
    state = 'ai';
    coach = Coach('Thầy đang chấm…', busy: true);
    _render();
    var ok = m == c.best;
    var loss = 0;
    if (!ok && m != c.played) {
      // chấp nhận nước khác nếu máy đánh giá ngang nước tốt nhất
      final rb = await engine.analyse(before.clone(), const SearchOpts(timeMs: 900, multipv: 1));
      if (t != tok || rb == null) return;
      SearchResult? ra;
      if (pos.legalMoves().isNotEmpty) {
        ra = await engine.analyse(pos.clone(), const SearchOpts(timeMs: 900, multipv: 1));
        if (t != tok) return;
      }
      final sb = rb.multi.isNotEmpty ? rb.multi[0].score : 0;
      final sa = ra != null && ra.multi.isNotEmpty ? -ra.multi[0].score : MATE;
      loss = math.max(0, clampS(sb) - clampS(sa));
      ok = loss <= 40;
    }
    if (pzFails == 0 && !pzHinted) _gradeReview(c, ok);
    if (ok) {
      state = 'done';
      _fx('win', 300);
      coach = Coach(
        '✓ $name: chính xác!',
        cls: 'best',
        lines: [
          m == c.best ? 'Đúng nước tốt nhất.' : 'Nước này cũng tốt ngang nước máy chọn (${c.bestName}).',
          ...explain(before, m).map((x) => '• $x'),
          'Lúc trước bạn đã đi ${c.playedName} và mất ${(c.loss / 100).toStringAsFixed(1)} Tốt lợi thế.',
          pzFails > 0 || pzHinted ? 'Thẻ này sẽ được ôn lại sớm vì bạn chưa làm đúng ngay lần đầu.' : 'Thẻ này: ${fmtDue(c)}.',
        ],
      );
    } else {
      pzFails++;
      state = 'fail';
      _fx('fail', 350);
      arrows = [Arrow(m, 'bad')];
      coach = Coach(
        '✗ Chưa đúng: $name',
        cls: 'mistake',
        lines: [
          m == c.played
              ? 'Đây chính là nước bạn đã đi sai lần trước.'
              : 'Nước này kém nước tốt nhất khoảng ${(loss / 100).toStringAsFixed(1)} Tốt.',
          'Bấm "Thử lại" để tìm nước khác, hoặc "Gợi ý" sau khi thử lại.',
        ],
      );
    }
    _render();
  }

  void deleteReview() {
    final c = pzCur?.rv;
    if (c == null) return;
    reviews.remove(c);
    _saveReview();
    _updateReviewCount();
    pzCol = _reviewCollection();
    loadPuzzle(math.min(pzIdx, math.max(0, pzCol!.items.length - 1)));
  }

  // ---------- Thống kê theo chủ đề: tỷ lệ giải đúng ngay lần đầu ----------
  void _recordTheme(bool ok) {
    if (_pzRecorded || pzCur == null || pzCol!.review) return;
    _pzRecorded = true;
    for (final t in pzCur!.allThemes) {
      final x = themeStat.putIfAbsent(t, () => [0, 0]);
      x[1]++;
      if (ok) x[0]++;
    }
    store.set('themeStat', themeStat);
  }

  /// Tối đa 3 chủ đề có tỷ lệ đúng dưới 70% (đã thử ít nhất 3 bài)
  List<({String t, int ok, int tot})> get weakThemes {
    final out = [
      for (final e in themeStat.entries)
        if (e.value[1] >= 3 && e.value[0] / e.value[1] < 0.7) (t: e.key, ok: e.value[0], tot: e.value[1]),
    ];
    double r(({String t, int ok, int tot}) x) => (x.ok + 1) / (x.tot + 2);
    out.sort((a, b) => r(a).compareTo(r(b)));
    return out.take(3).toList();
  }

  void practiceTheme(String t) {
    final items = pzCol!.items;
    bool has(Puzzle p) => p.allThemes.contains(t);
    for (final unsolvedOnly in [true, false]) {
      for (var k = 1; k <= items.length; k++) {
        final i = (pzIdx + k) % items.length;
        if (has(items[i]) && (!unsolvedOnly || !isSolved(i))) return loadPuzzle(i);
      }
    }
    coach = Coach('Không có bài "$t" trong bộ này', lines: ['Hãy chọn bộ khác, ví dụ Vu sư ma đề hoặc Sát trước đại toàn.']);
    _render();
  }
  int get solvedCount => pzCol == null
      ? 0
      : [
          for (var i = 0; i < pzCol!.items.length; i++)
            if (isSolved(i)) i,
        ].length;

  Future<void> openCollection(String id, [int idx = 0]) async {
    if (id == reviewColId) {
      pzCol = _reviewCollection();
      store.set('pzCol', reviewColId);
      return loadPuzzle(0);
    }
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
    final n0 = pzSolvedFen.length;
    for (var i = 0; i < col.items.length; i++) {
      if (pzSolved.contains(_pzKey(i))) pzSolvedFen.add(col.items[i].fen);
    }
    if (pzSolvedFen.length != n0) store.set('solvedFen', pzSolvedFen.toList());
    loadPuzzle(idx);
  }

  void loadPuzzle(int i) {
    final items = pzCol?.items;
    if (items == null) return;
    if (items.isEmpty) {
      tok++;
      pzCur = null;
      pos = Pos.start();
      hist = [];
      arrows = [];
      selected = -1;
      view = -1;
      state = 'empty';
      userSide = RED;
      moveSerial++;
      coach = pzCol!.review
          ? Coach(
              'Chưa có lỗi nào để ôn',
              lines: [
                'Khi đấu với máy, mỗi nước Sai lầm (?) hoặc Nước hỏng (??) của bạn sẽ được lưu vào đây.',
                'Ôn lại đúng những thế cờ mình từng đi sai là cách tiến bộ nhanh nhất. Thẻ làm đúng sẽ được giãn lịch ôn '
                    '(1, 3, 7, 18… ngày), làm sai sẽ quay lại ngay.',
              ],
            )
          : Coach('Bộ bài trống');
      _render();
      return;
    }
    tok++;
    i = i.clamp(0, items.length - 1);
    pzIdx = i;
    pzCur = items[i];
    store.set('pzIdx', i);
    pzHintStep = 0;
    pzFails = 0;
    pzHinted = false;
    _pzRecorded = false;
    pos = Pos.fromFen(pzCur!.fen);
    userSide = pzCol!.review ? pos.side : RED;
    hist = [];
    arrows = [];
    selected = -1;
    view = -1;
    state = 'user';
    result = null;
    moveSerial++;
    final rv = pzCur!.rv;
    if (rv != null) {
      final d = DateTime.fromMillisecondsSinceEpoch(rv.added);
      coach = Coach(
        'Ôn lỗi · thẻ ${i + 1}/${items.length}',
        lines: [
          'Thế cờ từ ván của bạn (${d.day}/${d.month}/${d.year}). Bạn cầm ${sideName(pos.side)}.',
          'Lần đó bạn đi ${rv.playedName} và mất ${(rv.loss / 100).toStringAsFixed(1)} Tốt lợi thế. Hãy tìm nước tốt hơn.',
          'Đã ôn ${rv.reps} lần · ${fmtDue(rv)}.',
        ],
      );
      _render();
      return;
    }
    final lines = ['Đỏ đi trước, chiếu bí trong ${pzCur!.n} nước. Máy sẽ chống đỡ bằng nước tốt nhất.'];
    if (pzCur!.theme != null) lines.add('Đòn: ${pzCur!.theme}. ${themeInfo[pzCur!.theme] ?? ''}');
    if (pzCol!.source != null) lines.add('Nguồn: ${pzCol!.title} · ${pzCol!.source}');
    final n0 = _noteAt(0);
    if (n0.isNotEmpty) lines.add('Lời bình gốc: $n0');
    coach = Coach('Bài ${i + 1}${pzCur!.name != null ? ' · ${pzCur!.name}' : ''}', lines: lines);
    _render();
  }

  void nextPuzzle() {
    if (pzCol!.review) {
      final cur = pzCur?.rv;
      pzCol = _reviewCollection();
      final items = pzCol!.items;
      final due = items.indexWhere((p) => p.rv!.due <= _now());
      return loadPuzzle(due >= 0 ? due : math.max(0, items.indexWhere((p) => p.rv == cur)));
    }
    loadPuzzle(pzIdx + 1 < pzCol!.items.length ? pzIdx + 1 : 0);
  }
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
    if (pzCol!.review) return _onReviewMove(m);
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
    _recordTheme(false);
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
      lines: [
        pzCol!.review
            ? 'Tìm nước tốt nhất cho ${sideName(pos.side)}. Bấm "Gợi ý" nếu cần.'
            : 'Còn ${pzCur!.n - _usedMoves()} nước để chiếu bí. Hãy tìm nước chiếu mà đối phương không thoát được.',
      ],
    );
    _render();
  }

  void _puzzleSolved() {
    _recordTheme(pzFails == 0 && !pzHinted);
    state = 'done';
    arrows = [];
    pzSolved.add(_pzKey(pzIdx));
    store.set('solved', pzSolved.toList());
    pzSolvedFen.add(pzCur!.fen);
    store.set('solvedFen', pzSolvedFen.toList());
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
    pzHinted = true;
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
    if (pzCur == null) return;
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
    final rv = pzCur!.rv;
    if (rv != null) {
      pzHinted = true;
      if (rv.iv > 0 || rv.due > _now()) _gradeReview(rv, false);
      state = 'done';
      coach!.lines.add('Nước tốt nhất. Lúc trước bạn đi ${rv.playedName}.');
      coach!.lines.addAll(explain(Pos.fromFen(pzCur!.fen), pzCur!.sol[0]).map((x) => '• $x'));
      _render();
      return;
    }
    _recordTheme(false);
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
    final ra = await engine.analyse(pa, const SearchOpts(timeMs: 900, multipv: 1));
    if (t != tok || ra == null) return;
    final rb = await engine.analyse(pb, const SearchOpts(timeMs: 900, multipv: 1));
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

  /// Chơi tiếp với máy từ thế cờ đang xem của ván đại sư (cầm bên thắng trong ván gốc)
  Future<void> gmPlay() async {
    final g = gmGame;
    if (g == null || _gmStart == null) return;
    final p = _gmStart!.clone();
    for (var k = 0; k < gmPly; k++) {
      p.make(gmMoves[k]);
    }
    if (p.legalMoves().isEmpty) {
      coach = Coach('Ván đã kết thúc ở thế này', lines: ['Hãy lùi về một thế cờ trước đó rồi bấm "Đánh tiếp với máy".']);
      _render();
      return;
    }
    final side = g.res == 1 ? RED : (g.res == -1 ? BLACK : p.side);
    final res = switch (g.res) {
      1 => 'Đỏ thắng',
      -1 => 'Đen thắng',
      0 => 'hòa',
      _ => '',
    };
    final won = g.res == (side == RED ? 1 : -1);
    await playFrom(
      fen: _gmStart!.toFen(),
      moves: gmMoves.sublist(0, gmPly),
      side: side,
      title: '${gmCol?.title ?? 'Ván đại sư'} · ván ${gmGi + 1}',
      lines: [
        'Bạn cầm ${sideName(side)}${gmPly > 0 ? ' từ nước $gmPly' : ' từ thế xuất phát'} của ván'
            '${g.r != null ? ' ${g.r} – ${g.b}' : ''}${res.isNotEmpty ? ' (kết quả gốc: $res)' : ''}.',
        won
            ? 'Đại sư đã thắng từ thế này. Hãy thắng máy (cấp $level) để chứng tỏ bạn nắm được cách thắng.'
            : 'Hãy đánh tiếp và giữ thế cờ trước máy.',
        'Mẹo: chọn cấp 4–5 trong "Đấu với máy" để máy chống trả mạnh nhất.',
      ],
    );
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
