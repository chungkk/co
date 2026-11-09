// Đọc biên bản/FEN: cùng một ván ghi theo nhiều kiểu phải ra cùng các nước.
import 'package:co_tuong/engine/engine.dart';
import 'package:co_tuong/game/notation.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> names(ImportResult r) {
  final p = r.fen != null ? Pos.fromFen(r.fen!) : Pos.start();
  return [
    for (final m in r.moves)
      () {
        final n = p.moveName(m);
        p.make(m);
        return n;
      }(),
  ];
}

void main() {
  const want = ['Pháo 2 bình 5', 'Mã 8 tiến 7', 'Mã 2 tiến 3', 'Xe 9 bình 8'];
  for (final (label, text) in [
    ('tiếng Việt', '1. Pháo 2 bình 5  Mã 8 tiến 7\n2. Mã 2 tiến 3  Xe 9 bình 8'),
    ('không dấu', 'phao 2 binh 5, ma 8 tien 7, ma 2 tien 3, xe 9 binh 8'),
    ('Việt ngắn', '1. P2-5 M8.7 2. M2.3 X9-8'),
    ('WXF', '1. C2.5 H8+7 2. H2+3 R9.8'),
    ('WXF =', 'C2=5 h8+7 H2+3 R9=8'),
    ('chữ Hán', '炮二平五 馬８進７ 馬二進三 車９平８'),
    ('giản thể', '炮二平五 马8进7 马二进三 车9平8'),
  ]) {
    test(label, () {
      final r = parseImport(text);
      expect(r.err, isNull);
      expect(r.warn, isNull);
      expect(names(r), want);
    });
  }

  test('FEN kèm nước, trước/sau', () {
    const fen = '3k5/9/9/9/9/2C6/9/2C6/9/4K4 w';
    expect(names(parseImport('$fen Pháo trước bình 5')), ['Pháo trước bình 5']);
    expect(names(parseImport('$fen +C.5')), ['Pháo trước bình 5']);
    expect(names(parseImport('$fen 後炮平五')), ['Pháo sau bình 5']);
  });

  test('báo lỗi và cảnh báo', () {
    expect(parseImport('hello').err, isNotNull);
    expect(parseImport('4k4/9/9/9/9/9/9/9/9/4K4 w').err, contains('chiếu')); // hai Tướng đối mặt
    expect(parseImport('9/9/9/9/9/9/9/9/9/4K4 w').err, contains('Tướng'));
    final r = parseImport('Pháo 2 bình 5, Tướng 5 tiến 3, Mã 8 tiến 7');
    expect(r.moves.length, 1);
    expect(r.warn, contains('nước thứ 2'));
  });
}
