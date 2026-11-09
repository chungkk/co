// Chơi online giữa hai GameController với máy chủ thật (server/engine-server.js).
// Chạy: ONLINE_TEST_URL=http://127.0.0.1:8081/api/online/ flutter test test/online_test.dart
import 'dart:io';

import 'package:co_tuong/engine/engine.dart';
import 'package:co_tuong/engine/engine_service.dart';
import 'package:co_tuong/game/controller.dart';
import 'package:co_tuong/game/online.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> waitFor(bool Function() cond, {int seconds = 10}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (!cond()) {
    if (DateTime.now().isAfter(end)) throw StateError('timeout');
    await Future.delayed(const Duration(milliseconds: 50));
  }
}

int named(Pos p, String n) => p.legalMoves().firstWhere((m) => p.moveName(m) == n);

void main() {
  final url = Platform.environment['ONLINE_TEST_URL'];
  TestWidgetsFlutterBinding.ensureInitialized();

  test('hai người chơi: ghép ngẫu nhiên, đi nước, xin hòa, đầu hàng, ván mới, phân tích', () async {
    HttpOverrides.global = null; // cho phép kết nối mạng thật trong test
    OnlineClient.base = Uri.parse(url!);
    EngineService.remoteUrl = null;
    Future<GameController> make(String name) async {
      SharedPreferences.setMockInitialValues({});
      final g = GameController(Store(await SharedPreferences.getInstance()));
      await g.init();
      await g.setMode(Mode.online);
      g.olName = name;
      g.olTc = '5+3';
      return g;
    }

    final a = await make('An'), b = await make('Bình');
    expect(a.online.token, isNot(b.online.token));
    expect(a.state, 'online-lobby');
    await a.olStart('quick');
    await waitFor(() => a.online.st?['status'] == 'waiting');
    await b.olStart('quick');
    await waitFor(() => a.online.st?['status'] == 'playing' && b.online.st?['status'] == 'playing');
    expect(a.online.room, b.online.room);
    expect(a.olSide, -b.olSide);
    final red = a.olSide == RED ? a : b, black = red == a ? b : a;
    expect(red.state, 'user');
    expect(black.state, 'online-wait');
    expect(black.userSide, BLACK); // bàn cờ lật theo bên mình
    expect(red.canHint, isFalse);

    // Đỏ đi, Đen thấy nước
    final m1 = named(red.pos, 'Pháo 2 bình 5');
    red.tapSquare(m1 & 127);
    red.tapSquare(m1 >> 7);
    await waitFor(() => black.hist.length == 1 && black.state == 'user');
    expect(black.hist.single.name, 'Pháo 2 bình 5');
    final m2 = named(black.pos, 'Xe 1 tiến 2');
    black.tapSquare(m2 & 127);
    black.tapSquare(m2 >> 7);
    await waitFor(() => red.hist.length == 2 && red.state == 'user');

    // xin hòa → từ chối; đầu hàng
    await black.olAct('draw');
    await waitFor(() => red.coach!.lines.contains('Đối thủ đề nghị hòa.'));
    await red.olAct('decline');
    await red.olAct('resign');
    await waitFor(() => black.state == 'online-over' && red.state == 'online-over');
    expect(black.coach!.title, contains('Bạn thắng'));
    expect(red.coach!.title, contains('Bạn thua'));

    // mở lại app giữa chừng: vào lại đúng phòng
    final room = a.online.room;
    final a2 = GameController(a.store);
    await a2.init();
    expect(a2.mode, Mode.online);
    await waitFor(() => a2.online.st != null);
    expect(a2.online.room, room);
    expect(a2.olSide, a.olSide);
    a2.dispose();

    // phân tích: chép ván sang "Đấu với máy", giữ nguyên thế cờ (đang là lượt Đỏ, máy không tự đi)
    await black.olAnalyze();
    expect(black.mode, Mode.play);
    expect(black.hist.length, 2);
    expect(black.state, 'user');
    expect(black.canAnalyze, isTrue);
    await Future.delayed(const Duration(milliseconds: 800));
    expect(black.hist.length, 2);
    // quay lại tab online: vào lại phòng
    await black.setMode(Mode.online);
    await waitFor(() => black.state == 'online-over');

    // ván mới: đổi bên
    final redSide = red.olSide;
    await a.olAct('rematch');
    await b.olAct('rematch');
    await waitFor(() => red.online.st?['status'] == 'playing' && red.hist.isEmpty);
    expect(red.olSide, -redSide);

    // rời phòng
    await black.olLeave();
    expect(black.state, 'online-lobby');
    expect(black.online.room, isNull);
    a.dispose();
    b.dispose();
  }, skip: url == null ? 'Đặt ONLINE_TEST_URL để chạy với máy chủ thật' : false, timeout: const Timeout(Duration(seconds: 60)));
}
