// ignore_for_file: constant_identifier_names, non_constant_identifier_names
// Cờ Tướng engine: luật, sinh nước, đánh giá, tìm kiếm alpha-beta.
// Port 1-1 từ site/js/engine.js. Hash Zobrist phải khớp bản JS từng bit
// vì sách khai cuộc (book.json) dùng hash làm khóa.
import 'dart:typed_data';

const int K = 1, A = 2, B = 3, N = 4, R = 5, C = 6, P = 7;
const int RED = 1, BLACK = -1;
const List<int> VAL = [0, 0, 200, 200, 400, 900, 450, 100];
const int MATE = 30000, INF = 32000, MAXPLY = 96;
const String START_FEN = 'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w';
const List<String> PIECE_NAME = ['', 'Tướng', 'Sĩ', 'Tượng', 'Mã', 'Xe', 'Pháo', 'Tốt'];

const _ORTH = [
  [-1, 0],
  [1, 0],
  [0, -1],
  [0, 1],
];
const _DIAG = [
  [-1, -1],
  [-1, 1],
  [1, -1],
  [1, 1],
];
// Mã: chân mã (lr, lc) và hai đích
const _NLEG = [
  [-1, 0, -2, -1, -2, 1],
  [1, 0, 2, -1, 2, 1],
  [0, -1, -1, -2, 1, -2],
  [0, 1, -1, 2, 1, 2],
];
const _FEN_MAP = {'k': K, 'a': A, 'b': B, 'e': B, 'n': N, 'h': N, 'r': R, 'c': C, 'p': P};
const _FEN_CH = ['', 'k', 'a', 'b', 'n', 'r', 'c', 'p'];

bool _inB(int r, int c) => r >= 0 && r < 10 && c >= 0 && c < 9;
bool _inPalace(int r, int c, int s) => c >= 3 && c <= 5 && (s > 0 ? r >= 7 && r <= 9 : r >= 0 && r <= 2);

int moveFrom(int m) => m & 127;
int moveTo(int m) => m >> 7;
int makeMove(int f, int t) => f | (t << 7);

Int16List _t(List<List<int>> rows) {
  final a = Int16List(90);
  for (var r = 0; r < rows.length; r++) {
    for (var c = 0; c < 9; c++) {
      a[r * 9 + c] = rows[r][c];
    }
  }
  return a;
}

const _z9 = [0, 0, 0, 0, 0, 0, 0, 0, 0];
final List<Int16List?> _PST = [
  null,
  _t([
    _z9,
    _z9,
    _z9,
    _z9,
    _z9,
    _z9,
    _z9,
    [0, 0, 0, -20, -20, -20, 0, 0, 0],
    [0, 0, 0, -10, -10, -10, 0, 0, 0],
    [0, 0, 0, 0, 4, 0, 0, 0, 0],
  ]),
  _t([
    _z9,
    _z9,
    _z9,
    _z9,
    _z9,
    _z9,
    _z9,
    [0, 0, 0, -2, 0, -2, 0, 0, 0],
    [0, 0, 0, 0, 6, 0, 0, 0, 0],
    _z9,
  ]),
  _t([
    _z9,
    _z9,
    _z9,
    _z9,
    _z9,
    [0, 0, -2, 0, 0, 0, -2, 0, 0],
    _z9,
    [-4, 0, 0, 0, 6, 0, 0, 0, -4],
    _z9,
    _z9,
  ]),
  _t([
    [4, 8, 16, 12, 4, 12, 16, 8, 4],
    [4, 10, 28, 16, 8, 16, 28, 10, 4],
    [12, 14, 16, 20, 18, 20, 16, 14, 12],
    [8, 24, 18, 24, 20, 24, 18, 24, 8],
    [6, 16, 14, 18, 16, 18, 14, 16, 6],
    [4, 12, 16, 14, 12, 14, 16, 12, 4],
    [2, 6, 8, 6, 10, 6, 8, 6, 2],
    [4, 2, 8, 8, 4, 8, 8, 2, 4],
    [0, 2, 4, 4, -2, 4, 4, 2, 0],
    [0, -10, 0, 0, 0, 0, 0, -10, 0],
  ]),
  _t([
    [14, 14, 12, 18, 16, 18, 12, 14, 14],
    [16, 20, 18, 24, 26, 24, 18, 20, 16],
    [12, 12, 12, 18, 18, 18, 12, 12, 12],
    [12, 18, 16, 22, 22, 22, 16, 18, 12],
    [12, 14, 12, 18, 18, 18, 12, 14, 12],
    [12, 16, 14, 20, 20, 20, 14, 16, 12],
    [6, 10, 8, 14, 14, 14, 8, 10, 6],
    [4, 8, 6, 14, 12, 14, 6, 8, 4],
    [8, 4, 8, 16, 8, 16, 8, 4, 8],
    [-6, 6, 4, 12, 0, 12, 4, 6, -6],
  ]),
  _t([
    [6, 4, 0, -10, -12, -10, 0, 4, 6],
    [2, 2, 0, -4, -14, -4, 0, 2, 2],
    [2, 2, 0, -10, -8, -10, 0, 2, 2],
    [0, 0, -2, 4, 10, 4, -2, 0, 0],
    [0, 0, 0, 2, 8, 2, 0, 0, 0],
    [-2, 0, 4, 2, 6, 2, 4, 0, -2],
    [0, 0, 0, 2, 4, 2, 0, 0, 0],
    [4, 0, 4, 6, 16, 6, 4, 0, 4],
    [0, 2, 4, 6, 6, 6, 4, 2, 0],
    [0, 0, 2, 6, 6, 6, 2, 0, 0],
  ]),
  _t([
    [0, 3, 6, 9, 12, 9, 6, 3, 0],
    [18, 36, 56, 80, 120, 80, 56, 36, 18],
    [14, 26, 42, 60, 80, 60, 42, 26, 14],
    [10, 20, 30, 34, 40, 34, 30, 20, 10],
    [6, 12, 18, 18, 20, 18, 18, 12, 6],
    [2, 0, 8, 0, 8, 0, 8, 0, 2],
    [0, 0, -2, 0, 4, 0, -2, 0, 0],
    _z9,
    _z9,
    _z9,
  ]),
];

int _pieceScore(int p, int sq) {
  final t = p > 0 ? p : -p;
  var idx = sq;
  if (p < 0) {
    final r = sq ~/ 9;
    idx = (9 - r) * 9 + (sq - r * 9);
  }
  return VAL[t] + _PST[t]![idx];
}

// ---- Zobrist giống JS (mulberry32, seed cố định), số nguyên 32 bit có dấu ----
const _M32 = 0xFFFFFFFF;
int _i32(int x) {
  x &= _M32;
  return x >= 0x80000000 ? x - 0x100000000 : x;
}

int _imul(int a, int b) => (a * b) & _M32; // Dart native: nhân bọc 64 bit, 32 bit thấp vẫn đúng

int Function() _mulberry32(int seed) {
  var a = seed & _M32;
  return () {
    a = (a + 0x6d2b79f5) & _M32;
    var t = _imul(a ^ (a >> 15), 1 | a);
    t = ((t + _imul(t ^ (t >> 7), 61 | t)) & _M32) ^ t;
    return _i32(t ^ (t >> 14));
  };
}

final _Z = _initZobrist();
final Int32List _Z1 = _Z.$1, _Z2 = _Z.$2;
final int _ZS1 = _Z.$3, _ZS2 = _Z.$4;

(Int32List, Int32List, int, int) _initZobrist() {
  final rnd = _mulberry32(20261108);
  final z1 = Int32List(14 * 90), z2 = Int32List(14 * 90);
  for (var i = 0; i < z1.length; i++) {
    z1[i] = rnd();
    z2[i] = rnd();
  }
  final s1 = rnd(), s2 = rnd();
  return (z1, z2, s1, s2);
}

int _zi(int p) => p > 0 ? p - 1 : 6 - p;

class Pos {
  final Int8List b = Int8List(90);
  int side = RED;
  int h1 = 0, h2 = 0, ev = 0, kR = -1, kB = -1;
  List<int> hs1 = [], hs2 = [];
  final List<int> _und = [];

  Pos();

  factory Pos.fromFen(String fen) {
    final p = Pos();
    final parts = fen.trim().split(RegExp(r'\s+'));
    final bd = parts[0];
    final s = parts.length > 1 ? parts[1] : 'w';
    var r = 0, c = 0;
    for (final ch in bd.split('')) {
      if (ch == '/') {
        r++;
        c = 0;
      } else if (ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57) {
        c += int.parse(ch);
      } else {
        final t = _FEN_MAP[ch.toLowerCase()]!;
        p.b[r * 9 + c] = ch == ch.toLowerCase() ? -t : t;
        c++;
      }
    }
    p.side = s == 'b' ? BLACK : RED;
    p.recompute();
    return p;
  }

  factory Pos.start() => Pos.fromFen(START_FEN);

  void recompute() {
    h1 = 0;
    h2 = 0;
    ev = 0;
    for (var sq = 0; sq < 90; sq++) {
      final p = b[sq];
      if (p == 0) continue;
      h1 ^= _Z1[_zi(p) * 90 + sq];
      h2 ^= _Z2[_zi(p) * 90 + sq];
      ev += (p > 0 ? 1 : -1) * _pieceScore(p, sq);
      if (p == K) {
        kR = sq;
      } else if (p == -K) {
        kB = sq;
      }
    }
    if (side == BLACK) {
      h1 ^= _ZS1;
      h2 ^= _ZS2;
    }
    hs1 = [h1];
    hs2 = [h2];
    _und.clear();
  }

  Pos clone() {
    final p = Pos();
    p.b.setAll(0, b);
    p.side = side;
    p.h1 = h1;
    p.h2 = h2;
    p.ev = ev;
    p.kR = kR;
    p.kB = kB;
    p.hs1 = List.of(hs1);
    p.hs2 = List.of(hs2);
    return p;
  }

  /// lịch sử các thế cờ trước (để nhận biết lặp)
  List<List<int>> historyPairs() => [
    for (var i = 0; i < hs1.length - 1; i++) [hs1[i], hs2[i]],
  ];

  void setHistory(List<List<int>> pairs) {
    hs1 = [for (final x in pairs) x[0], h1];
    hs2 = [for (final x in pairs) x[1], h2];
  }

  String toFen() {
    final sb = StringBuffer();
    for (var r = 0; r < 10; r++) {
      var e = 0;
      for (var c = 0; c < 9; c++) {
        final p = b[r * 9 + c];
        if (p == 0) {
          e++;
          continue;
        }
        if (e > 0) {
          sb.write(e);
          e = 0;
        }
        final ch = _FEN_CH[p > 0 ? p : -p];
        sb.write(p > 0 ? ch.toUpperCase() : ch);
      }
      if (e > 0) sb.write(e);
      if (r < 9) sb.write('/');
    }
    sb.write(side == RED ? ' w' : ' b');
    return sb.toString();
  }

  void make(int m) {
    final f = m & 127, t = m >> 7, p = b[f], q = b[t];
    _und
      ..add(m)
      ..add(q)
      ..add(h1)
      ..add(h2)
      ..add(ev);
    final zp = _zi(p) * 90;
    h1 ^= _Z1[zp + f] ^ _Z1[zp + t];
    h2 ^= _Z2[zp + f] ^ _Z2[zp + t];
    ev += (p > 0 ? 1 : -1) * (_pieceScore(p, t) - _pieceScore(p, f));
    if (q != 0) {
      final zq = _zi(q) * 90 + t;
      h1 ^= _Z1[zq];
      h2 ^= _Z2[zq];
      ev -= (q > 0 ? 1 : -1) * _pieceScore(q, t);
    }
    b[t] = p;
    b[f] = 0;
    if (p == K) {
      kR = t;
    } else if (p == -K) {
      kB = t;
    }
    side = -side;
    h1 ^= _ZS1;
    h2 ^= _ZS2;
    hs1.add(h1);
    hs2.add(h2);
  }

  void unmake() {
    final u = _und;
    final evv = u.removeLast(), hh2 = u.removeLast(), hh1 = u.removeLast(), q = u.removeLast(), m = u.removeLast();
    final f = m & 127, t = m >> 7, p = b[t];
    b[f] = p;
    b[t] = q;
    if (p == K) {
      kR = f;
    } else if (p == -K) {
      kB = f;
    }
    side = -side;
    h1 = hh1;
    h2 = hh2;
    ev = evv;
    hs1.removeLast();
    hs2.removeLast();
  }

  void makeNull() {
    _und
      ..add(0)
      ..add(0)
      ..add(h1)
      ..add(h2)
      ..add(ev);
    side = -side;
    h1 ^= _ZS1;
    h2 ^= _ZS2;
    hs1.add(h1);
    hs2.add(h2);
  }

  void unmakeNull() {
    final u = _und;
    ev = u.removeLast();
    h2 = u.removeLast();
    h1 = u.removeLast();
    u.removeLast();
    u.removeLast();
    side = -side;
    hs1.removeLast();
    hs2.removeLast();
  }

  /// Sinh nước giả hợp lệ (chưa kiểm tra tự để Tướng bị chiếu)
  List<int> gen(bool capOnly, [int? sideArg]) {
    final s = sideArg ?? side;
    final out = <int>[];
    void add(int f, int t) {
      final q = b[t];
      if (q == 0) {
        if (!capOnly) out.add(f | (t << 7));
      } else if ((q > 0) != (s > 0)) {
        out.add(f | (t << 7));
      }
    }

    for (var sq = 0; sq < 90; sq++) {
      final p = b[sq];
      if (p == 0 || (p > 0) != (s > 0)) continue;
      final t = p > 0 ? p : -p, r = sq ~/ 9, c = sq - (sq ~/ 9) * 9;
      switch (t) {
        case K:
          for (final d in _ORTH) {
            final nr = r + d[0], nc = c + d[1];
            if (_inPalace(nr, nc, s)) add(sq, nr * 9 + nc);
          }
          break;
        case A:
          for (final d in _DIAG) {
            final nr = r + d[0], nc = c + d[1];
            if (_inPalace(nr, nc, s)) add(sq, nr * 9 + nc);
          }
          break;
        case B:
          for (final d in _DIAG) {
            final nr = r + 2 * d[0], nc = c + 2 * d[1];
            if (!_inB(nr, nc) || (s > 0 ? nr < 5 : nr > 4)) continue;
            if (b[(r + d[0]) * 9 + c + d[1]] == 0) add(sq, nr * 9 + nc);
          }
          break;
        case N:
          for (final l in _NLEG) {
            final ar = r + l[0], ac = c + l[1];
            if (!_inB(ar, ac) || b[ar * 9 + ac] != 0) continue;
            for (var k = 2; k < 6; k += 2) {
              final nr = r + l[k], nc = c + l[k + 1];
              if (_inB(nr, nc)) add(sq, nr * 9 + nc);
            }
          }
          break;
        case R:
          for (final d in _ORTH) {
            var nr = r + d[0], nc = c + d[1];
            while (_inB(nr, nc)) {
              final q = b[nr * 9 + nc];
              if (q == 0) {
                if (!capOnly) out.add(sq | ((nr * 9 + nc) << 7));
              } else {
                if ((q > 0) != (s > 0)) out.add(sq | ((nr * 9 + nc) << 7));
                break;
              }
              nr += d[0];
              nc += d[1];
            }
          }
          break;
        case C:
          for (final d in _ORTH) {
            var nr = r + d[0], nc = c + d[1];
            var screen = false;
            while (_inB(nr, nc)) {
              final q = b[nr * 9 + nc];
              if (!screen) {
                if (q == 0) {
                  if (!capOnly) out.add(sq | ((nr * 9 + nc) << 7));
                } else {
                  screen = true;
                }
              } else if (q != 0) {
                if ((q > 0) != (s > 0)) out.add(sq | ((nr * 9 + nc) << 7));
                break;
              }
              nr += d[0];
              nc += d[1];
            }
          }
          break;
        case P:
          final fw = s > 0 ? -1 : 1;
          if (_inB(r + fw, c)) add(sq, (r + fw) * 9 + c);
          if (s > 0 ? r <= 4 : r >= 5) {
            if (c > 0) add(sq, sq - 1);
            if (c < 8) add(sq, sq + 1);
          }
          break;
      }
    }
    return out;
  }

  /// Tướng của bên [s] có đang bị chiếu không
  bool inCheck(int s) {
    final k = s > 0 ? kR : kB;
    if (k < 0) return true;
    final r = k ~/ 9, c = k - (k ~/ 9) * 9, e = -s;
    for (final d in _ORTH) {
      var nr = r + d[0], nc = c + d[1];
      var found = false;
      while (_inB(nr, nc)) {
        final q = b[nr * 9 + nc];
        if (q != 0) {
          if (!found) {
            if (q == e * R || (q == e * K && d[1] == 0)) return true;
            found = true;
          } else {
            if (q == e * C) return true;
            break;
          }
        }
        nr += d[0];
        nc += d[1];
      }
    }
    for (final l in _NLEG) {
      for (var j = 2; j < 6; j += 2) {
        final nr = r - l[j], nc = c - l[j + 1];
        if (!_inB(nr, nc) || b[nr * 9 + nc] != e * N) continue;
        if (b[(nr + l[0]) * 9 + nc + l[1]] == 0) return true;
      }
    }
    final pr = r + (s > 0 ? -1 : 1); // tốt đối phương đứng phía trước Tướng
    if (_inB(pr, c) && b[pr * 9 + c] == e * P) return true;
    if (c > 0 && b[k - 1] == e * P) return true;
    if (c < 8 && b[k + 1] == e * P) return true;
    return false;
  }

  List<int> legalMoves() {
    final out = <int>[], me = side;
    for (final m in gen(false)) {
      make(m);
      if (!inCheck(me)) out.add(m);
      unmake();
    }
    return out;
  }

  bool isLegal(int m) => legalMoves().contains(m);

  bool givesCheck(int m) {
    make(m);
    final r = inCheck(side);
    unmake();
    return r;
  }

  bool isRep() {
    final n = hs1.length - 1;
    for (var i = n - 2; i >= 0; i--) {
      if (hs1[i] == h1 && hs2[i] == h2) return true;
    }
    return false;
  }

  int repCount() {
    var n = 0;
    for (var i = 0; i < hs1.length; i++) {
      if (hs1[i] == h1 && hs2[i] == h2) n++;
    }
    return n;
  }

  bool hasBig(int s) {
    for (var i = 0; i < 90; i++) {
      final p = b[i] * s;
      if (p == R || p == N || p == C) return true;
    }
    return false;
  }

  int evalSide() => side * ev + 10;

  /// Khóa tra sách khai cuộc, giống `pkey` bên JS
  String get key => '${(h1 & _M32).toRadixString(36)}.${(h2 & _M32).toRadixString(36)}';

  /// Ký hiệu kiểu Việt Nam: "Pháo 2 bình 5", "Mã 8 tiến 7", "Xe trước tiến 1"
  String moveName(int m) {
    final f = m & 127, t = m >> 7, p = b[f];
    if (p == 0) return '?';
    final s = p > 0 ? 1 : -1, tp = p * s;
    final fr = f ~/ 9, fc = f % 9, tr = t ~/ 9, tc = t % 9;
    int col(int c) => s > 0 ? 9 - c : c + 1;
    var id = '${col(fc)}';
    final same = <int>[];
    for (var r = 0; r < 10; r++) {
      if (b[r * 9 + fc] == p) same.add(r);
    }
    if (same.length == 2 && tp != K) {
      final front = s > 0 ? (same[0] < same[1] ? same[0] : same[1]) : (same[0] > same[1] ? same[0] : same[1]);
      id = fr == front ? 'trước' : 'sau';
    }
    String act;
    if (fr == tr) {
      act = 'bình ${col(tc)}';
    } else {
      final fwd = s > 0 ? fr - tr : tr - fr;
      final num = tp == N || tp == B || tp == A ? col(tc) : (tr - fr).abs();
      act = '${fwd > 0 ? 'tiến ' : 'thoái '}$num';
    }
    return '${PIECE_NAME[tp]} $id $act';
  }
}

// ---------------- Tìm kiếm ----------------
const _EXACT = 0, _LOWER = 1, _UPPER = 2;

class SearchOpts {
  final int? timeMs;
  final int? depth;
  final int multipv;
  const SearchOpts({this.timeMs, this.depth, this.multipv = 1});
}

class PvLine {
  final int move, score;
  final List<int> pv;
  PvLine(this.move, this.score, this.pv);
}

class RootScore {
  final int move, score;
  final bool exact;
  RootScore(this.move, this.score, this.exact);
}

class SearchResult {
  final List<PvLine> multi;
  final List<RootScore> all;
  final int depth, nodes, ms;
  final bool noMoves;
  SearchResult(this.multi, this.all, this.depth, this.nodes, this.ms, {this.noMoves = false});
}

class _RootEntry {
  int m, s;
  bool exact;
  List<int> pv;
  _RootEntry(this.m, this.s, this.exact, this.pv);
}

class Search {
  static const _size = 1 << 20;
  final int _mask = _size - 1;
  final Int32List _tk = Int32List(_size), _tm = Int32List(_size), _ts = Int32List(_size);
  final Int8List _td = Int8List(_size)..fillRange(0, _size, -1), _tf = Int8List(_size);
  final Int32List _hist = Int32List(1 << 14), _killers = Int32List(MAXPLY * 2);
  final List<Int32List> _pv = List.generate(MAXPLY + 1, (_) => Int32List(MAXPLY + 1));
  final Int32List _pvLen = Int32List(MAXPLY + 1);
  late Pos _pos;
  int _nodes = 0;
  bool _stop = false;
  int _deadline = 0;
  final Stopwatch _clock = Stopwatch()..start();

  void _ttStore(Pos pos, int d, int s, int f, int m, int ply) {
    final i = pos.h1 & _mask;
    if (_tk[i] == pos.h2 && _td[i] > d && f != _EXACT) return;
    if (s > MATE - 500) {
      s += ply;
    } else if (s < -MATE + 500) {
      s -= ply;
    }
    _tk[i] = pos.h2;
    _td[i] = d;
    _ts[i] = s;
    _tf[i] = f;
    _tm[i] = m;
  }

  List<int> _order(Pos pos, List<int> moves, int ttm, int ply) {
    final b = pos.b, sc = List<int>.filled(moves.length, 0);
    final k1 = _killers[ply * 2], k2 = _killers[ply * 2 + 1];
    for (var i = 0; i < moves.length; i++) {
      final m = moves[i], q = b[m >> 7];
      if (m == ttm) {
        sc[i] = 10000000;
      } else if (q != 0) {
        final a = b[m & 127];
        sc[i] = 1000000 + VAL[q > 0 ? q : -q] * 10 - VAL[a > 0 ? a : -a] ~/ 10 + ((q == K || q == -K) ? 100000 : 0);
      } else if (m == k1) {
        sc[i] = 900000;
      } else if (m == k2) {
        sc[i] = 800000;
      } else {
        sc[i] = _hist[m];
      }
    }
    return sc;
  }

  bool _tick() {
    if ((++_nodes & 2047) == 0 && _clock.elapsedMilliseconds > _deadline) _stop = true;
    return _stop;
  }

  void _copyPv(int ply, int m) {
    final dst = _pv[ply], src = _pv[ply + 1];
    dst[ply] = m;
    final n = _pvLen[ply + 1];
    for (var k = ply + 1; k < n; k++) {
      dst[k] = src[k];
    }
    _pvLen[ply] = n > ply + 1 ? n : ply + 1;
  }

  static void _pick(List<int> moves, List<int> sc, int i) {
    var bi = i;
    for (var j = i + 1; j < moves.length; j++) {
      if (sc[j] > sc[bi]) bi = j;
    }
    if (bi != i) {
      var x = moves[i];
      moves[i] = moves[bi];
      moves[bi] = x;
      x = sc[i];
      sc[i] = sc[bi];
      sc[bi] = x;
    }
  }

  int _nm(int d, int a, int b, int ply, bool nullOk) {
    final pos = _pos;
    _pvLen[ply] = ply;
    if (_tick()) return 0;
    if (ply > 0 && pos.isRep()) return 0;
    if (ply >= MAXPLY - 1) return pos.evalSide();
    // cắt tỉa theo khoảng cách chiếu bí
    final ma = -MATE + ply, mb = MATE - ply - 1;
    if (a < ma) a = ma;
    if (b > mb) b = mb;
    if (a >= b) return a;
    final inC = pos.inCheck(pos.side);
    if (inC) d++;
    if (d <= 0) return _qs(a, b, ply);
    final ti = pos.h1 & _mask;
    var ttm = 0;
    if (_tk[ti] == pos.h2 && _td[ti] >= 0) {
      ttm = _tm[ti];
      if (_td[ti] >= d && ply > 0) {
        var s = _ts[ti];
        if (s > MATE - 500) {
          s -= ply;
        } else if (s < -MATE + 500) {
          s += ply;
        }
        final f = _tf[ti];
        if (f == _EXACT || (f == _LOWER && s >= b) || (f == _UPPER && s <= a)) return s;
      }
    }
    if (nullOk && !inC && d >= 3 && b < MATE - 500 && b - a == 1 && pos.hasBig(pos.side) && pos.evalSide() >= b) {
      pos.makeNull();
      final s = -_nm(d - 3, -b, -b + 1, ply + 1, false);
      pos.unmakeNull();
      if (_stop) return 0;
      if (s >= b) return b;
    }
    final moves = pos.gen(false), sc = _order(pos, moves, ttm, ply);
    final me = pos.side, a0 = a;
    var best = -INF, bestM = 0, legal = 0;
    for (var i = 0; i < moves.length; i++) {
      _pick(moves, sc, i);
      final m = moves[i], isCap = pos.b[m >> 7] != 0;
      pos.make(m);
      if (pos.inCheck(me)) {
        pos.unmake();
        continue;
      }
      legal++;
      int s;
      if (legal == 1) {
        s = -_nm(d - 1, -b, -a, ply + 1, true);
      } else {
        var red = 0;
        if (d >= 3 && legal > 4 && !isCap && !inC && sc[i] < 800000 && !pos.inCheck(pos.side)) red = legal > 12 && d >= 5 ? 2 : 1;
        s = -_nm(d - 1 - red, -a - 1, -a, ply + 1, true);
        if (s > a && red > 0) s = -_nm(d - 1, -a - 1, -a, ply + 1, true);
        if (s > a && s < b) s = -_nm(d - 1, -b, -a, ply + 1, true);
      }
      pos.unmake();
      if (_stop) return 0;
      if (s > best) {
        best = s;
        bestM = m;
        if (s > a) {
          a = s;
          _copyPv(ply, m);
          if (a >= b) {
            if (!isCap) {
              if (_killers[ply * 2] != m) {
                _killers[ply * 2 + 1] = _killers[ply * 2];
                _killers[ply * 2] = m;
              }
              _hist[m] += d * d;
            }
            break;
          }
        }
      }
    }
    if (legal == 0) return -MATE + ply; // cờ tướng: hết nước đi cũng là thua
    _ttStore(pos, d, best, best <= a0 ? _UPPER : (best >= b ? _LOWER : _EXACT), bestM, ply);
    return best;
  }

  int _qs(int a, int b, int ply) {
    final pos = _pos;
    _pvLen[ply] = ply;
    if (_tick()) return 0;
    if (ply >= MAXPLY - 1) return pos.evalSide();
    final inC = pos.inCheck(pos.side);
    var best = -INF;
    if (!inC) {
      final st = pos.evalSide();
      if (st >= b) return st;
      if (st > a) a = st;
      best = st;
    }
    final moves = pos.gen(!inC), sc = _order(pos, moves, 0, ply), me = pos.side;
    var legal = 0;
    for (var i = 0; i < moves.length; i++) {
      _pick(moves, sc, i);
      final m = moves[i];
      pos.make(m);
      if (pos.inCheck(me)) {
        pos.unmake();
        continue;
      }
      legal++;
      final s = -_qs(-b, -a, ply + 1);
      pos.unmake();
      if (_stop) return 0;
      if (s > best) {
        best = s;
        if (s > a) {
          a = s;
          _copyPv(ply, m);
          if (a >= b) break;
        }
      }
    }
    if (inC && legal == 0) return -MATE + ply;
    return best;
  }

  SearchResult run(Pos pos, SearchOpts opts) {
    _pos = pos;
    _nodes = 0;
    _stop = false;
    final t0 = _clock.elapsedMilliseconds;
    final time = opts.timeMs ?? 1000;
    final maxD = (opts.depth ?? 60) < MAXPLY - 10 ? (opts.depth ?? 60) : MAXPLY - 10;
    final mpv = opts.multipv;
    _hist.fillRange(0, _hist.length, 0);
    _killers.fillRange(0, _killers.length, 0);
    var root = [
      for (final m in pos.legalMoves()) _RootEntry(m, -INF, false, [m]),
    ];
    if (root.isEmpty) return SearchResult([], [], 0, 0, 0, noMoves: true);
    // sắp xếp ban đầu: ăn quân giá trị cao trước (sort ổn định như JS)
    final sc0 = _order(pos, [for (final e in root) e.m], 0, 0);
    final idx = List.generate(root.length, (i) => i);
    _stableSort(idx, (x, y) => sc0[y] - sc0[x]);
    root = [for (final i in idx) root[i]];
    var depth = 0;
    for (var d = 1; d <= maxD; d++) {
      _deadline = d == 1 ? 1 << 62 : t0 + time;
      final res = <_RootEntry>[];
      final exacts = <int>[];
      for (final e in root) {
        final thr = exacts.length >= mpv ? exacts[mpv - 1] : -INF;
        pos.make(e.m);
        int s;
        if (thr == -INF) {
          s = -_nm(d - 1, -INF, INF, 1, true);
        } else {
          s = -_nm(d - 1, -thr - 1, -thr, 1, true);
          if (s > thr && !_stop) s = -_nm(d - 1, -INF, -thr, 1, true);
        }
        pos.unmake();
        if (_stop) break;
        final exact = s > thr;
        final pv = [e.m];
        for (var k = 1; k < _pvLen[1]; k++) {
          pv.add(_pv[1][k]);
        }
        res.add(_RootEntry(e.m, s, exact, exact ? pv : e.pv));
        if (exact) {
          exacts.add(s);
          exacts.sort((x, y) => y - x);
        }
      }
      if (_stop) break;
      _stableSort(res, (x, y) {
        final ex = (y.exact ? 1 : 0) - (x.exact ? 1 : 0);
        return ex != 0 ? ex : y.s - x.s;
      });
      root = res;
      depth = d;
      final bs = root[0].s;
      if (bs > MATE - 500 && MATE - bs <= d) break;
      if (root.length == 1 && d >= 4) break;
      if (_clock.elapsedMilliseconds - t0 > time * 0.5) break;
    }
    final multi = [for (final e in root.where((e) => e.exact).take(mpv)) PvLine(e.m, e.s, e.pv)];
    return SearchResult(multi, [for (final e in root) RootScore(e.m, e.s, e.exact)], depth, _nodes, _clock.elapsedMilliseconds - t0);
  }
}

/// Sắp xếp ổn định (insertion/merge) để khớp Array.prototype.sort của JS
void _stableSort<T>(List<T> a, int Function(T, T) cmp) {
  if (a.length < 2) return;
  final tmp = List<T>.of(a);
  _mergeSort(a, tmp, 0, a.length, cmp);
}

void _mergeSort<T>(List<T> a, List<T> tmp, int lo, int hi, int Function(T, T) cmp) {
  if (hi - lo < 2) return;
  final mid = (lo + hi) >> 1;
  _mergeSort(a, tmp, lo, mid, cmp);
  _mergeSort(a, tmp, mid, hi, cmp);
  var i = lo, j = mid, k = lo;
  while (i < mid && j < hi) {
    tmp[k++] = cmp(a[j], a[i]) < 0 ? a[j++] : a[i++];
  }
  while (i < mid) {
    tmp[k++] = a[i++];
  }
  while (j < hi) {
    tmp[k++] = a[j++];
  }
  for (var x = lo; x < hi; x++) {
    a[x] = tmp[x];
  }
}
