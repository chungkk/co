// Chạy thử luồng của cả 3 chế độ với engine thật (isolate) và dữ liệu đóng gói.
import 'package:co_tuong/engine/engine.dart';
import 'package:co_tuong/game/controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> waitFor(bool Function() cond, {int seconds = 20}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (!cond()) {
    if (DateTime.now().isAfter(end)) throw StateError('timeout');
    await Future.delayed(const Duration(milliseconds: 50));
  }
}

int moveNamed(Pos p, String name) => p.legalMoves().firstWhere((m) => p.moveName(m) == name);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameController g;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    g = GameController(Store(await SharedPreferences.getInstance()));
    await g.init();
    await waitFor(() => g.pro != null);
  });
  tearDown(() => g.dispose());

  test('đấu với máy: đi nước, thầy chấm, máy đáp, đi lại', () async {
    expect(g.mode, Mode.play);
    expect(g.state, 'user');
    final m = moveNamed(g.pos, 'Pháo 2 bình 5');
    g.tapSquare(m & 127);
    expect(g.selected, m & 127);
    expect(g.selectedDests, contains(m >> 7));
    g.tapSquare(m >> 7);
    expect(g.hist.length, 1);
    await waitFor(() => g.hist.length == 2 && g.state == 'user');
    expect(g.hist[0].cls, isIn(['best', 'book', 'good']));
    expect(g.coach!.title, contains('Pháo 2 bình 5'));
    // gợi ý
    g.primaryAction();
    await waitFor(() => g.coach!.title == '💡 Gợi ý');
    expect(g.coach!.lines.any((l) => l.startsWith('Nên đi:')), isTrue);
    expect(g.arrows, isNotEmpty);
    // đi lại
    g.secondaryAction();
    expect(g.hist, isEmpty);
    expect(g.pos.toFen(), START_FEN);
  });

  test('ván được lưu và khôi phục', () async {
    final m = moveNamed(g.pos, 'Mã 2 tiến 3');
    g.tapSquare(m & 127);
    g.tapSquare(m >> 7);
    await waitFor(() => g.hist.length == 2 && g.state == 'user');
    final fen = g.pos.toFen();
    final g2 = GameController(g.store);
    await g2.init();
    expect(g2.pos.toFen(), fen);
    expect(g2.hist.first.cls, isNotNull);
    g2.dispose();
  });

  test('bài tập sát cục: giải đúng bài 1', () async {
    await g.setMode(Mode.puzzle);
    expect(g.pzCur, isNotNull);
    final sol = g.pzCur!.sol;
    expect(g.pzCur!.n, 1);
    g.tapSquare(sol[0] & 127);
    g.tapSquare(sol[0] >> 7);
    await waitFor(() => g.state == 'done');
    expect(g.isSolved(0), isTrue);
    g.nextPuzzle();
    expect(g.pzIdx, 1);
    // gợi ý 2 bước
    g.primaryAction();
    await waitFor(() => g.coach!.title == '💡 Gợi ý 1');
    expect(g.selected, g.pzCur!.sol[0] & 127);
  });

  test('mọi bộ bài tập và ván đại sư đều nạp được, nước đi hợp lệ', () async {
    await g.setMode(Mode.puzzle);
    for (final c in g.pzCols) {
      await g.openCollection(c.id);
      expect(g.pzCol!.id, c.id);
      for (final p in g.pzCol!.items) {
        final pos = Pos.fromFen(p.fen);
        for (final m in p.sol) {
          expect(pos.isLegal(m), isTrue, reason: '${c.id} ${p.fen}');
          pos.make(m);
        }
        expect(pos.legalMoves(), isEmpty, reason: 'lời giải phải chiếu bí: ${c.id} ${p.fen}');
      }
    }
    await g.setMode(Mode.games);
    await waitFor(() => g.gmGame != null);
    var games = 0;
    for (final c in g.gmIndex!) {
      await g.gmOpenCol(c.id);
      expect(g.gmCol!.games.length, c.count);
      games += c.count;
    }
    expect(games, greaterThan(8000));
  });

  test('ván đại sư: tiến/lùi, luyện đoán nước', () async {
    await g.setMode(Mode.games);
    await waitFor(() => g.gmGame != null);
    g.primaryAction();
    expect(g.gmPly, 1);
    g.secondaryAction();
    expect(g.gmPly, 0);
    g.gmToggleGuess();
    await waitFor(() => g.state == 'user');
    final master = g.gmMoves[g.gmPly];
    g.tapSquare(master & 127);
    g.tapSquare(master >> 7);
    expect(g.gmOk, 1);
  });
}
