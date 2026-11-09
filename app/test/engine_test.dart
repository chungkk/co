// So khớp engine Dart với engine JS gốc (test/engine_ref.json sinh từ site/js/engine.js).
import 'dart:convert';
import 'dart:io';

import 'package:co_tuong/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

int perft(Pos p, int d) {
  if (d == 0) return 1;
  var n = 0;
  for (final m in p.legalMoves()) {
    p.make(m);
    n += perft(p, d - 1);
    p.unmake();
  }
  return n;
}

void main() {
  final ref = jsonDecode(File('test/engine_ref.json').readAsStringSync()) as List;
  for (final r in ref) {
    final fen = r['fen'] as String;
    test('khớp engine JS: $fen', () {
      final p = Pos.fromFen(fen);
      expect(p.key, r['key'], reason: 'hash Zobrist');
      expect(p.toFen(), fen);
      expect(perft(p, 3), r['perft3']);
      expect(p.legalMoves().take(5).map(p.moveName).toList(), (r['names'] as List).cast<String>());
      final res = Search().run(p, const SearchOpts(depth: 5, timeMs: 1000000000, multipv: 3));
      expect([for (final x in res.multi) [x.move, x.score, x.pv.join(',')]], r['multi']);
      expect(res.nodes, r['nodes'], reason: 'số node tìm kiếm');
    });
  }

  test('thế khởi đầu có trong sách khai cuộc', () {
    final book = jsonDecode(File('assets/data/book.json').readAsStringSync()) as Map<String, dynamic>;
    final p = Pos.start();
    expect((book['pos'] as Map).containsKey(p.key), isTrue);
    // đi Pháo 2 bình 5 rồi tra tiếp
    final m = p.legalMoves().firstWhere((m) => p.moveName(m) == 'Pháo 2 bình 5');
    p.make(m);
    expect((book['pos'] as Map).containsKey(p.key), isTrue);
  });
}
