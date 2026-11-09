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

  test('luyện khai cuộc: từ chối nước ngoài sách, đi theo đại sư tới khi hết sách', () async {
    final k = GameController.drillOps.indexWhere((o) => o.name == 'Thuận pháo');
    g.startDrill(k);
    expect(g.drill, isNotNull);
    expect(g.hist.map((h) => h.name), ['Pháo 2 bình 5', 'Pháo 8 bình 5']);
    expect(g.state, 'user');
    // nước ngoài sách bị từ chối, không đi
    final bad = g.pos.legalMoves().firstWhere((m) => g.pos.moveName(m).startsWith('Tướng'));
    g.tapSquare(bad & 127);
    g.tapSquare(bad >> 7);
    expect(g.hist.length, 2);
    expect(g.coach!.title, contains('ngoài sách'));
    // gợi ý: mũi tên các nước đại sư
    g.primaryAction();
    expect(g.arrows.first.kind, 'best');
    var moves = 0;
    while (g.drill != null && moves < 40) {
      await waitFor(() => g.state == 'user' || g.drill == null);
      if (g.drill == null) break;
      final top = g.proMoves(g.pos)!..sort((a, b) => b.n.compareTo(a.n));
      g.tapSquare(top.first.m & 127);
      g.tapSquare(top.first.m >> 7);
      moves++;
    }
    expect(g.drill, isNull);
    expect(g.coach!.title, startsWith('🏁 Hết sách khai cuộc'));
    expect(g.coach!.lines.join(' '), contains('Bạn đi đúng ngay lần đầu'));
    // ván tiếp tục như đấu thường
    await waitFor(() => g.state == 'user');
    expect(g.hist.length, greaterThan(4));
  });

  test('nhập ván, phân tích, nước sai vào sổ ôn', () async {
    expect(g.importGame('1. C2.5 H8+7 2. R9+2', RED), isNull);
    expect(g.gameTitle, 'Ván nhập vào');
    expect(g.hist.where((h) => h.by == 'user').length, 2);
    // máy đáp nước 2… rồi tới lượt người chơi
    await waitFor(() => g.state == 'user' && g.hist.length == 4);
    expect(g.canAnalyze, isTrue);
    await g.analyzeGame();
    await waitFor(() => g.state == 'user');
    final mine = g.hist.where((h) => h.by == 'user').toList();
    expect(mine.every((h) => h.cls != null), isTrue);
    expect(mine[1].cls, isIn(['mistake', 'blunder'])); // Xe 9 tiến 2 để mất Mã
    expect(g.reviews.map((c) => c.playedName), contains('Xe 9 tiến 2'));
    expect(g.canAnalyze, isFalse);
    expect(g.importGame('hello', RED), isNotNull);
  });

  test('đánh tiếp từ ván tàn cục đại sư, khôi phục khi mở lại', () async {
    await g.setMode(Mode.games);
    await g.gmOpenCol('dac-cap-dai-su-tan-cuc-tap-tuy-duong-dien-tru', 1);
    final fen = g.gmGame!.fen!;
    await g.gmPlay();
    expect(g.mode, Mode.play);
    expect(g.startFen, fen);
    expect(g.userSide, g.gmGame!.res == -1 ? BLACK : RED);
    await waitFor(() => g.state == 'user');
    // mở lại app: ván tàn cục được khôi phục
    final g2 = GameController(g.store);
    await g2.init();
    expect(g2.mode, Mode.play);
    expect(g2.startFen, fen);
    expect(g2.pos.toFen(), g.pos.toFen());
    expect(g2.gameTitle, g.gameTitle);
    g2.dispose();
    // ván mới trở về thế ban đầu
    g.newGame();
    expect(g.startFen, isNull);
    expect(g.pos.toFen(), Pos.start().toFen());
  });

  test('sổ lỗi sai: lưu thẻ, làm sai rồi đúng, giãn lịch ôn', () async {
    var now = DateTime(2026, 1, 1).millisecondsSinceEpoch;
    g.clock = () => now;
    final p = Pos.start();
    p.make(moveNamed(p, 'Pháo 2 bình 5'));
    final played = moveNamed(p, 'Tướng 5 tiến 1'), best = moveNamed(p, 'Mã 8 tiến 7');
    expect(g.addReview(p, played, best, 250), isTrue);
    expect(g.reviewDue, 1);
    await g.setMode(Mode.puzzle);
    await g.openCollection('on-loi');
    expect(g.pzCol!.review, isTrue);
    expect(g.userSide, BLACK); // thế cờ bên Đen đi: bàn cờ lật theo
    expect(g.statusText, contains('tìm nước tốt nhất'));
    // đi lại đúng nước sai cũ
    g.tapSquare(played & 127);
    g.tapSquare(played >> 7);
    await waitFor(() => g.state == 'fail');
    expect(g.reviews.single.lapses, 1);
    expect(g.reviews.single.due, now);
    g.retryPuzzle();
    g.tapSquare(best & 127);
    g.tapSquare(best >> 7);
    await waitFor(() => g.state == 'done');
    // đã sai trong lượt này nên chưa giãn lịch
    expect(g.reviews.single.iv, 0);
    // lượt sau: đúng ngay lần đầu → 1 ngày, rồi 3 ngày
    g.nextPuzzle();
    g.tapSquare(best & 127);
    g.tapSquare(best >> 7);
    await waitFor(() => g.state == 'done');
    expect(g.reviews.single.iv, 1);
    expect(g.isSolved(0), isTrue);
    expect(g.reviewDue, 0);
    now += 2 * 86400000;
    expect(g.reviewDue, 1);
    g.nextPuzzle();
    g.tapSquare(best & 127);
    g.tapSquare(best >> 7);
    await waitFor(() => g.state == 'done');
    expect(g.reviews.single.iv, 3);
    // lưu bền và xoá thẻ
    expect(g.store.get<List<dynamic>>('review', []).length, 1);
    g.deleteReview();
    expect(g.reviews, isEmpty);
    expect(g.state, 'empty');
  });

  test('thống kê chủ đề: đi sai tính vào chủ đề yếu', () async {
    await g.setMode(Mode.puzzle);
    await g.openCollection('co-ban-sat-phap');
    for (var i = 0; i < 3; i++) {
      g.loadPuzzle(i);
      final themes = g.pzCur!.allThemes;
      expect(themes, isNotEmpty);
      // nước sai: nước không chiếu bí (một số bài có nhiều đường chiếu bí)
      final wrong = g.pos.legalMoves().firstWhere((m) => (g.pos.clone()..make(m)).legalMoves().isNotEmpty);
      g.tapSquare(wrong & 127);
      g.tapSquare(wrong >> 7);
      await waitFor(() => g.state == 'fail', seconds: 3).catchError((_) => fail('bài $i: state=${g.state} hist=${g.hist.length} ${g.pzCur!.fen} sai=${Pos.fromFen(g.pzCur!.fen).moveName(wrong)}'));
    }
    expect(g.weakThemes.first.t, 'Bạch diện tướng');
    expect(g.weakThemes.first.ok, 0);
    g.practiceTheme('Bạch diện tướng');
    expect(g.pzCur!.allThemes, contains('Bạch diện tướng'));
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
