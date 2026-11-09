// Chuyển kết quả Pikafish (UCI) từ máy chủ sang nước đi/điểm của app.
import 'package:co_tuong/engine/engine.dart';
import 'package:co_tuong/engine/engine_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nước UCI → nước của app, điểm nhân hệ số', () {
    final p = Pos.start();
    final r = fromRemote(p, {
      'multi': [
        {'move': 'h2e2', 'pv': ['h2e2', 'h9g7', 'h0g2'], 'cp': 30},
        {'move': 'b2e2', 'pv': ['b2e2', 'x9x9'], 'cp': -10}, // nước rác sau nước đầu bị bỏ
      ],
      'depth': 18,
    })!;
    expect(r.depth, 18);
    expect(r.multi.length, 2);
    expect(p.moveName(r.multi[0].move), 'Pháo 2 bình 5');
    expect(r.multi[0].pv.length, 3);
    expect(r.multi[0].score, 36);
    expect(p.moveName(r.multi[1].move), 'Pháo 8 bình 5');
    expect(r.multi[1].pv.length, 1);
    expect(r.all.map((x) => x.move), [r.multi[0].move, r.multi[1].move]);
  });

  test('chiếu bí và nước không hợp lệ', () {
    final p = Pos.fromFen('3k5/9/9/9/9/9/9/9/4R4/4K4 w');
    final r = fromRemote(p, {
      'multi': [
        {'move': 'e1d1', 'pv': ['e1d1'], 'mate': 1},
      ],
    })!;
    expect(p.moveName(r.multi[0].move), 'Xe 5 bình 6');
    expect(r.multi[0].score, MATE - 1);
    expect(fromRemote(p, {'multi': [{'pv': ['a0a9']}]}), isNull); // nước không hợp lệ
    expect(fromRemote(p, {'multi': []}), isNull);
    final m = fromRemote(Pos.start(), {'multi': [{'pv': ['h2e2'], 'mate': -2}]})!;
    expect(m.multi[0].score, -(MATE - 4));
  });
}
