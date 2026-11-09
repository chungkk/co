// Dựng giao diện ở nhiều cỡ màn hình (iPhone, iPad dọc/ngang) cho cả 3 chế độ:
// test thất bại nếu có widget bị tràn. Đặt SHOT_DIR=... để lưu ảnh PNG.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:co_tuong/engine/engine.dart';
import 'package:co_tuong/game/controller.dart';
import 'package:co_tuong/ui/home.dart';
import 'package:co_tuong/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const sizes = {
  'iphone': Size(402, 874),
  'iphone-ngang': Size(874, 402),
  'ipad-mini': Size(744, 1133),
  'ipad11': Size(834, 1194),
  'ipad11-ngang': Size(1194, 834),
  'ipad13-ngang': Size(1376, 1032),
};

Future<void> loadFonts() async {
  Future<void> fam(String name, List<String> files) async {
    final l = FontLoader(name);
    for (final f in files) {
      l.addFont(rootBundle.load('assets/fonts/$f'));
    }
    await l.load();
  }

  await fam(kFont, ['BeVietnamPro-Regular.ttf', 'BeVietnamPro-Medium.ttf', 'BeVietnamPro-SemiBold.ttf', 'BeVietnamPro-Bold.ttf']);
  await fam(kHanFont, ['NotoSerifSC-Bold.ttf']);
  await fam('MaterialIcons', []);
}

void main() {
  final shotDir = Platform.environment['SHOT_DIR'];

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadFonts();
    // Icon Material thật để ảnh dễ nhìn
    final icons = File('${Platform.environment['FLUTTER_ROOT'] ?? ''}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) {
      final l = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
      await l.load();
    }
  });

  for (final mode in Mode.values) {
    for (final e in sizes.entries) {
      testWidgets('${mode.name} @ ${e.key}', (tester) async {
        tester.view.physicalSize = e.value * 3;
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        SharedPreferences.setMockInitialValues({});
        late GameController g;
        await tester.runAsync(() async {
          g = GameController(Store(await SharedPreferences.getInstance()));
          await g.init();
          await g.setMode(mode);
          final end = DateTime.now().add(const Duration(seconds: 15));
          while ((g.pro == null || (mode == Mode.games && g.gmGame == null)) && DateTime.now().isBefore(end)) {
            await Future.delayed(const Duration(milliseconds: 50));
          }
          if (mode == Mode.games) {
            for (var i = 0; i < 12; i++) {
              g.primaryAction();
            }
          }
        });
        await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, theme: buildTheme(Brightness.light), home: HomePage(g: g)));
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);
        if (shotDir != null) {
          await tester.runAsync(() async {
            final ro = tester.renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
            final img = await ro.toImage(pixelRatio: 1.5);
            final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
            File('$shotDir/${mode.name}-${e.key}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
          });
        }
        await tester.runAsync(() async => g.dispose());
      });
    }
  }

  testWidgets('hiệu ứng đi quân và ăn quân chạy trọn vẹn', (tester) async {
    tester.view.physicalSize = const Size(402, 874) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    late GameController g;
    await tester.runAsync(() async {
      g = GameController(Store(await SharedPreferences.getInstance()));
      await g.init();
      await g.setMode(Mode.puzzle);
    });
    await tester.pumpWidget(MaterialApp(theme: buildTheme(Brightness.light), home: HomePage(g: g)));
    await tester.pump();
    // tìm một bài có nước giải là nước ăn quân để thử cả hiệu ứng quân bị ăn
    var idx = 0;
    for (var i = 0; i < g.pzCol!.items.length; i++) {
      final p = g.pzCol!.items[i];
      final pos = Pos.fromFen(p.fen);
      if (pos.b[p.sol[0] >> 7] != 0) {
        idx = i;
        break;
      }
    }
    g.loadPuzzle(idx);
    await tester.pump();
    final m = g.pzCur!.sol[0];
    final serial = g.moveSerial;
    g.tapSquare(m & 127);
    await tester.pump();
    g.tapSquare(m >> 7);
    expect(g.animSerial, g.moveSerial);
    expect(g.moveSerial, serial + 1);
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
    }
    // đi lại: không chạy hiệu ứng
    g.retryPuzzle();
    expect(g.animSerial == g.moveSerial, isFalse);
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async => g.dispose());
  });
}
