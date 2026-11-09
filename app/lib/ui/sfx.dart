// Âm thanh quân cờ gỗ + rung nhẹ. File âm sinh bởi tool/gen_sfx.py.
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class Sfx {
  // Mỗi loại có thể có nhiều biến thể, chọn ngẫu nhiên để đỡ nhàm tai.
  static const _files = {
    'move': ['sfx/move1.wav', 'sfx/move2.wav', 'sfx/move3.wav'],
    'capture': ['sfx/capture1.wav', 'sfx/capture2.wav'],
    'check': ['sfx/check.wav'],
    'select': ['sfx/select.wav'],
    'win': ['sfx/win.wav'],
    'end': ['sfx/end.wav'],
    'fail': ['sfx/fail.wav'],
  };
  final Map<String, List<AudioPlayer>> _players = {};
  final _rnd = Random();
  int _last = -1;

  Sfx() {
    try {
      // ambient: tôn trọng nút gạt im lặng, tự trộn với nhạc của app khác
      AudioPlayer.global.setAudioContext(AudioContext(iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient)));
      for (final e in _files.entries) {
        _players[e.key] = [
          for (final f in e.value)
            AudioPlayer()
              ..setReleaseMode(ReleaseMode.stop)
              ..setSource(AssetSource(f)).catchError((_) {}),
        ];
      }
    } catch (_) {
      // không có âm thanh vẫn chơi được
    }
  }

  void play(String kind) {
    switch (kind) {
      case 'capture':
      case 'check':
        HapticFeedback.mediumImpact();
      case 'win':
      case 'fail':
        HapticFeedback.heavyImpact();
      case 'select':
        HapticFeedback.selectionClick();
      default:
        HapticFeedback.lightImpact();
    }
    final ps = _players[kind];
    if (ps == null || ps.isEmpty) return;
    var i = _rnd.nextInt(ps.length);
    if (ps.length > 1 && i == _last) i = (i + 1) % ps.length; // không lặp biến thể liền nhau
    _last = i;
    final p = ps[i];
    p.stop().then((_) => p.resume()).catchError((_) {});
  }
}
