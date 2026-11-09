// Đọc thế cờ (FEN) và biên bản nước đi người dùng dán vào (port từ site/js/notation.js).
// Hỗ trợ: tiếng Việt đầy đủ ("Pháo 2 bình 5"), ký hiệu Việt ngắn (P2-5, M8.7, X1/1),
// WXF (C2.5 / C2=5, H8+7, R1-1, +C.5) và chữ Hán (炮二平五, 馬８進７, 前炮平五).
import '../engine/engine.dart';

class ImportResult {
  final String? fen, err, warn, notation;
  final List<int> moves;
  const ImportResult({this.fen, this.moves = const [], this.err, this.warn, this.notation});
}

const _pc = {'Tướng': 'K', 'Sĩ': 'A', 'Tượng': 'B', 'Mã': 'N', 'Xe': 'R', 'Pháo': 'C', 'Tốt': 'P'};

/// Khóa chuẩn của một nước: quân · cột (hoặc +/- cho trước/sau) · hướng (+ tiến, - thoái, = bình) · số
String moveKey(Pos pos, int m) {
  final p = pos.moveName(m).split(' ');
  final id = p[1] == 'trước' ? '+' : (p[1] == 'sau' ? '-' : p[1]);
  final op = p[2] == 'tiến' ? '+' : (p[2] == 'thoái' ? '-' : '=');
  return '${_pc[p[0]]}$id$op${p[3]}';
}

final _vnFull = RegExp(
  r'(tướng|tuong|sĩ|si|tượng|mã|ma|xe|pháo|phao|tốt|tot|binh)\s*(\d|trước|truoc|sau)\s*(tiến|tien|thoái|thoai|bình|binh)\s*(\d)',
  caseSensitive: false,
);
const _vnPc = {
  'tướng': 'K', 'tuong': 'K', 'sĩ': 'A', 'si': 'A', 'tượng': 'B', 'mã': 'N', 'ma': 'N', //
  'xe': 'R', 'pháo': 'C', 'phao': 'C', 'tốt': 'P', 'tot': 'P', 'binh': 'P',
};
const _vnOp = {'tiến': '+', 'tien': '+', 'thoái': '-', 'thoai': '-', 'bình': '=', 'binh': '='};

List<List<String>> _vnFullToks(String text) => [
  for (final x in _vnFull.allMatches(text))
    () {
      final id = x[2]!.toLowerCase();
      final i = id.startsWith('tr') ? '+' : (id == 'sau' ? '-' : id);
      return ['${_vnPc[x[1]!.toLowerCase()]}$i${_vnOp[x[3]!.toLowerCase()]}${x[4]}'];
    }(),
];

final _short = RegExp(r'([+\-]?)(tg|[a-z])([1-9+\-]?)([.\-+=/])([1-9])', caseSensitive: false);
const _vnS = {'x': 'R', 'm': 'N', 't': 'B', 's': 'A', 'p': 'C', 'b': 'P', 'tg': 'K', 'k': 'K'};
const _wxfS = {'r': 'R', 'h': 'N', 'n': 'N', 'e': 'B', 'b': 'B', 'a': 'A', 'k': 'K', 'c': 'C', 'p': 'P'};
const _vnSOp = {'.': '+', '/': '-', '-': '=', '+': '+', '=': '='};
const _wxfOp = {'+': '+', '-': '-', '.': '=', '=': '=', '/': '-'};

List<List<String>> _shortToks(String text, bool vn) => [
  for (final x in _short.allMatches(text))
    () {
      final pc = (vn ? _vnS : _wxfS)[x[2]!.toLowerCase()];
      final id = x[3]!.isNotEmpty ? x[3]! : x[1]!;
      if (pc == null || id.isEmpty) return <String>[];
      return ['$pc$id${(vn ? _vnSOp : _wxfOp)[x[4]]}${x[5]}'];
    }(),
];

const _zhPc = {
  '车': 'R', '車': 'R', '俥': 'R', '马': 'N', '馬': 'N', '傌': 'N', '炮': 'C', '砲': 'C', '包': 'C', //
  '兵': 'P', '卒': 'P', '相': 'B', '象': 'B', '仕': 'A', '士': 'A', '帅': 'K', '帥': 'K', '将': 'K', '將': 'K',
};
const _zhN = {
  '一': 1, '二': 2, '三': 3, '四': 4, '五': 5, '六': 6, '七': 7, '八': 8, '九': 9, //
  '１': 1, '２': 2, '３': 3, '４': 4, '５': 5, '６': 6, '７': 7, '８': 8, '９': 9,
};
int _zn(String c) => _zhN[c] ?? int.parse(c);
const _zhOp = {'进': '+', '進': '+', '退': '-', '平': '='};
final _zh = RegExp(
  r'([前后後])?([车車俥马馬傌炮砲包兵卒相象仕士帅帥将將])([一二三四五六七八九1-9１-９前后後])?([进進退平])([一二三四五六七八九1-9１-９])',
);

List<List<String>> _zhToks(String text) => [
  for (final x in _zh.allMatches(text))
    () {
      final id = x[1] ?? x[3];
      if (id == null) return <String>[];
      final i = id == '前' ? '+' : (id == '后' || id == '後' ? '-' : '${_zn(id)}');
      return ['${_zhPc[x[2]]}$i${_zhOp[x[4]]}${_zn(x[5]!)}'];
    }(),
];

({List<int> moves, int? bad}) _replay(Pos start, List<List<String>> toks) {
  final p = start.clone(), moves = <int>[];
  for (final cands in toks) {
    int? m;
    for (final x in p.legalMoves()) {
      if (cands.contains(moveKey(p, x))) {
        m = x;
        break;
      }
    }
    if (m == null) return (moves: moves, bad: moves.length);
    moves.add(m);
    p.make(m);
  }
  return (moves: moves, bad: null);
}

final _fenRe = RegExp(r'([rnbakcpheRNBAKCPHE1-9]{1,9}/){9}[rnbakcpheRNBAKCPHE1-9]{1,9}(\s+[wbr])?');

/// Kiểm tra FEN; trả về lời báo lỗi hoặc null nếu hợp lệ
String? checkFen(String fen) {
  final parts = fen.trim().split(RegExp(r'\s+'));
  final rows = parts[0].split('/');
  if (rows.length != 10) return 'FEN phải có 10 hàng.';
  var kr = 0, kb = 0;
  for (final r in rows) {
    var n = 0;
    for (final ch in r.split('')) {
      final d = int.tryParse(ch);
      n += d ?? 1;
      if (ch == 'K') kr++;
      if (ch == 'k') kb++;
    }
    if (n != 9) return 'Mỗi hàng của FEN phải có đúng 9 ô.';
  }
  if (kr != 1 || kb != 1) return 'Thế cờ phải có đúng một Tướng mỗi bên.';
  final s = parts.length > 1 && parts[1] == 'b' ? 'b' : 'w';
  final p = Pos.fromFen('${parts[0]} $s');
  if (p.inCheck(-p.side)) return 'Bên vừa đi đang bị chiếu: thế cờ không hợp lệ.';
  return null;
}

/// Đọc văn bản: FEN (tùy chọn) và/hoặc biên bản nước đi
ImportResult parseImport(String text) {
  text = text.replaceAll('\r', '');
  String? fen;
  var rest = text;
  final fm = _fenRe.firstMatch(text);
  if (fm != null) {
    fen = fm[0]!.trim().replaceFirst(RegExp(r'\s+r$'), ' w');
    if (!RegExp(r'\s[wb]$').hasMatch(fen)) fen += ' w';
    final err = checkFen(fen);
    if (err != null) return ImportResult(err: err);
    rest = '${text.substring(0, fm.start)} ${text.substring(fm.end)}';
  }
  final start = fen != null ? Pos.fromFen(fen) : Pos.start();
  // bỏ số thứ tự nước ("1.", "12)") để không lẫn với ký hiệu
  final clean = rest.replaceAllMapped(RegExp(r'(^|\s)\d+\s*[.)]\s'), (_) => ' ');
  final noFull = clean.replaceAll(_vnFull, ' ');
  final tries = [
    ('vn-full', _vnFullToks(clean)),
    ('zh', _zhToks(clean)),
    ('vn', _shortToks(noFull, true)),
    ('wxf', _shortToks(noFull, false)),
  ];
  ({String name, List<List<String>> toks, List<int> moves, int? bad, double score})? best;
  for (final (name, toks) in tries) {
    if (toks.isEmpty) continue;
    final r = _replay(start, toks);
    final double score = r.moves.length - (r.bad != null ? 0.5 : 0.0);
    if (best == null || score > best.score) best = (name: name, toks: toks, moves: r.moves, bad: r.bad, score: score);
  }
  if (best == null) {
    if (fen != null) return ImportResult(fen: fen);
    return const ImportResult(
      err:
          'Không đọc được thế cờ hay nước đi nào. Hãy dán FEN hoặc biên bản như "Pháo 2 bình 5, Mã 8 tiến 7…", '
          '"C2.5 H8+7…" hoặc "炮二平五 馬8進7…".',
    );
  }
  return ImportResult(
    fen: fen,
    moves: best.moves,
    notation: best.name,
    warn: best.bad != null
        ? 'Chỉ đọc được ${best.moves.length}/${best.toks.length} nước: nước thứ ${best.bad! + 1} không hợp lệ ở thế cờ đó.'
        : null,
  );
}
