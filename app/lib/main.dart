import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game/controller.dart';
import 'ui/home.dart';
import 'ui/sfx.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sp = await SharedPreferences.getInstance();
  final g = GameController(Store(sp));
  final sfx = Sfx();
  g.onFx = sfx.play;
  runApp(CoTuongApp(g: g));
  g.init();
}

class CoTuongApp extends StatelessWidget {
  final GameController g;
  const CoTuongApp({super.key, required this.g});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cờ Tướng',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: HomePage(g: g),
    );
  }
}
