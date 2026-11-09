// Bàn cờ: lưới, quân, mũi tên, hiệu ứng di chuyển. Hệ tọa độ 900×1100 như bản web.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/analysis.dart';
import '../game/constants.dart';
import '../game/controller.dart';
import 'theme.dart';

const double _x0 = 50, _y0 = 100, _cell = 100, _w = 900, _h = 1100;

class BoardView extends StatefulWidget {
  final GameController g;
  const BoardView({super.key, required this.g});

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(vsync: this, value: 1);
  int _played = -1;

  GameController get g => widget.g;

  @override
  void initState() {
    super.initState();
    _played = g.animSerial; // không chạy lại nước cuối khi vừa mở màn hình
  }

  @override
  void didUpdateWidget(BoardView old) {
    super.didUpdateWidget(old);
    final last = g.lastMove;
    if (g.animSerial != _played) {
      _played = g.animSerial;
      if (last != null && g.animSerial == g.moveSerial) {
        _anim.duration = Duration(milliseconds: moveAnimMs(last.m));
        _anim.forward(from: 0);
      }
    } else if (g.moveSerial != g.animSerial && _anim.isAnimating) {
      _anim.value = 1; // đi lại / chuyển bài giữa chừng: dừng hiệu ứng
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Offset _disp(int sq) {
    var r = rowOf(sq), c = colOf(sq);
    if (g.flipped) {
      r = 9 - r;
      c = 8 - c;
    }
    return Offset(_x0 + c * _cell, _y0 + r * _cell);
  }

  int _sqAt(Offset local, double scale) {
    final x = local.dx / scale, y = local.dy / scale;
    var c = ((x - _x0) / _cell).round(), r = ((y - _y0) / _cell).round();
    if (c < 0 || c > 8 || r < 0 || r > 9) return -1;
    if (g.flipped) {
      r = 9 - r;
      c = 8 - c;
    }
    return r * 9 + c;
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return AspectRatio(
      aspectRatio: _w / _h,
      child: LayoutBuilder(
        builder: (context, box) {
          final scale = box.maxWidth / _w;
          final pos = g.shownPos;
          final last = g.lastMove;
          final hang = g.hanging;
          final checkSq = pos.inCheck(pos.side) ? (pos.side > 0 ? pos.kR : pos.kB) : -1;
          final pieceSize = _cell * scale;
          final pieces = <Widget>[];
          Widget? selectedW, moving, captured;
          PieceWidget pw(int p, int sq) => PieceWidget(
            piece: p,
            size: pieceSize,
            hanChars: g.opt.han,
            selected: sq == g.selected && g.view < 0,
            danger: hang.contains(sq),
            check: sq == checkSq,
          );
          final animTo = last != null && g.animSerial == g.moveSerial ? last.m >> 7 : -1;
          for (var sq = 0; sq < 90; sq++) {
            final p = pos.b[sq];
            if (p == 0) continue;
            final o = _disp(sq) * scale;
            if (sq == animTo) {
              final from = _disp(last!.m & 127) * scale;
              moving = _MovingPiece(anim: _anim, from: from, to: o, size: pieceSize, child: pw(p, sq));
              final q = last.before.b[sq];
              if (q != 0) {
                captured = _CapturedPiece(
                  anim: _anim,
                  at: o,
                  size: pieceSize,
                  child: PieceWidget(piece: q, size: pieceSize, hanChars: g.opt.han),
                );
              }
              continue;
            }
            final w = Positioned(left: o.dx - pieceSize / 2, top: o.dy - pieceSize / 2, child: pw(p, sq));
            if (sq == g.selected) {
              selectedW = w; // quân đang chọn vẽ sau cùng để nổi lên trên
            } else {
              pieces.add(w);
            }
          }
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => g.tapSquare(_sqAt(d.localPosition, scale)),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12 * scale + 2),
                gradient: LinearGradient(begin: const Alignment(-0.6, -1), end: const Alignment(0.6, 1), colors: [pal.wood1, pal.wood2]),
                boxShadow: const [
                  BoxShadow(color: Color(0x143C230A), blurRadius: 2, offset: Offset(0, 1)),
                  BoxShadow(color: Color(0x143C230A), blurRadius: 20, offset: Offset(0, 6)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12 * scale + 2),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(painter: _GridPainter(pal.grid, flipped: g.flipped)),
                      ),
                    ),
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _UnderPainter(
                          last: last?.m,
                          dests: [
                            for (final t in g.selectedDests)
                              if (pos.b[t] == 0) _disp(t),
                          ],
                          disp: _disp,
                        ),
                      ),
                    ),
                    ...pieces,
                    ?captured,
                    ?selectedW,
                    ?moving,
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _OverPainter(
                            arrows: g.shownArrows,
                            caps: [
                              for (final t in g.selectedDests)
                                if (pos.b[t] != 0) _disp(t),
                            ],
                            disp: _disp,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Quân đang đi: nhấc lên (to dần, bóng xa dần), trượt theo đường cong mượt rồi đặt xuống.
class _MovingPiece extends StatelessWidget {
  final Animation<double> anim;
  final Offset from, to;
  final double size;
  final Widget child;
  const _MovingPiece({required this.anim, required this.from, required this.to, required this.size, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      child: RepaintBoundary(child: child),
      builder: (context, child) {
        final t = anim.value;
        final pos = Offset.lerp(from, to, Curves.easeInOutCubic.transform(t))!;
        // độ nhấc: lên nhanh, hạ xuống êm, chạm bàn đúng lúc t = 1
        final lift = math.sin(math.pi * Curves.easeOut.transform(t));
        final scale = 1 + 0.11 * lift;
        final rise = size * 0.10 * lift;
        return Positioned(
          left: pos.dx - size / 2,
          top: pos.dy - size / 2,
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (lift > 0.01)
                Positioned.fill(
                  child: Transform.translate(
                    offset: Offset(size * 0.04 * lift, size * 0.06 * lift),
                    child: Center(
                      child: Container(
                        width: size * 0.84,
                        height: size * 0.84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Color.fromRGBO(40, 20, 0, 0.30 * lift), blurRadius: size * (0.08 + 0.18 * lift))],
                        ),
                      ),
                    ),
                  ),
                ),
              Transform.translate(
                offset: Offset(0, -rise),
                child: Transform.scale(scale: scale, child: child),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Quân bị ăn: nằm yên tới khi quân kia sắp đến thì mờ dần và thu nhỏ.
class _CapturedPiece extends StatelessWidget {
  final Animation<double> anim;
  final Offset at;
  final double size;
  final Widget child;
  const _CapturedPiece({required this.anim, required this.at, required this.size, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      child: RepaintBoundary(child: child),
      builder: (context, child) {
        final t = anim.value;
        if (t >= 1) return const SizedBox.shrink();
        final k = Curves.easeIn.transform(((t - 0.55) / 0.45).clamp(0.0, 1.0));
        return Positioned(
          left: at.dx - size / 2,
          top: at.dy - size / 2,
          child: Opacity(
            opacity: 1 - k,
            child: Transform.scale(scale: 1 - 0.18 * k, child: child),
          ),
        );
      },
    );
  }
}

class _GridPainter extends CustomPainter {
  final Color color;
  final bool flipped;
  _GridPainter(this.color, {required this.flipped});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / _w;
    canvas.scale(s);
    // vân gỗ nhẹ
    final grain = Paint()..color = const Color(0x0D784614);
    for (double x = -200; x < _w + 200; x += 11) {
      canvas.drawLine(Offset(x, 0), Offset(x + 40, _h), grain..strokeWidth = 3);
    }
    final glow = Paint()
      ..shader = const RadialGradient(colors: [Color(0x40FFFFFF), Color(0x00FFFFFF)])
          .createShader(Rect.fromCenter(center: const Offset(270, 220), width: 900, height: 700));
    canvas.drawRect(const Rect.fromLTWH(0, 0, _w, _h), glow);

    final pen = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    void l(double x1, double y1, double x2, double y2) => canvas.drawLine(Offset(x1, y1), Offset(x2, y2), pen);
    for (var r = 0; r < 10; r++) {
      l(_x0, _y0 + r * _cell, _x0 + 8 * _cell, _y0 + r * _cell);
    }
    for (var c = 0; c < 9; c++) {
      if (c == 0 || c == 8) {
        l(_x0 + c * _cell, _y0, _x0 + c * _cell, _y0 + 9 * _cell);
      } else {
        l(_x0 + c * _cell, _y0, _x0 + c * _cell, _y0 + 4 * _cell);
        l(_x0 + c * _cell, _y0 + 5 * _cell, _x0 + c * _cell, _y0 + 9 * _cell);
      }
    }
    l(_x0 + 3 * _cell, _y0, _x0 + 5 * _cell, _y0 + 2 * _cell);
    l(_x0 + 5 * _cell, _y0, _x0 + 3 * _cell, _y0 + 2 * _cell);
    l(_x0 + 3 * _cell, _y0 + 7 * _cell, _x0 + 5 * _cell, _y0 + 9 * _cell);
    l(_x0 + 5 * _cell, _y0 + 7 * _cell, _x0 + 3 * _cell, _y0 + 9 * _cell);
    void mark(int r, int c) {
      final x = _x0 + c * _cell, y = _y0 + r * _cell;
      const d = 8.0, ln = 18.0;
      for (final sx in [-1, 1]) {
        if ((c == 0 && sx < 0) || (c == 8 && sx > 0)) continue;
        for (final sy in [-1, 1]) {
          final path = Path()
            ..moveTo(x + sx * (d + ln), y + sy * d)
            ..lineTo(x + sx * d, y + sy * d)
            ..lineTo(x + sx * d, y + sy * (d + ln));
          canvas.drawPath(path, pen);
        }
      }
    }

    for (final rc in [
      [2, 1],
      [2, 7],
      [7, 1],
      [7, 7],
    ]) {
      mark(rc[0], rc[1]);
    }
    for (final r in [3, 6]) {
      for (final c in [0, 2, 4, 6, 8]) {
        mark(r, c);
      }
    }
    canvas.drawRect(
      Rect.fromLTWH(_x0 - 12, _y0 - 12, 8 * _cell + 24, 9 * _cell + 24),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    void text(String t, Offset c, TextStyle st) {
      final tp = TextPainter(
        text: TextSpan(text: t, style: st),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }

    final river = TextStyle(fontFamily: kHanFont, fontSize: 48, color: color.withValues(alpha: 0.55), letterSpacing: 19, height: 1);
    text('楚 河', const Offset(_x0 + 2 * _cell + 10, _y0 + 4.5 * _cell), river);
    text('漢 界', const Offset(_x0 + 6 * _cell + 10, _y0 + 4.5 * _cell), river);
    final num = TextStyle(fontFamily: kFont, fontSize: 26, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.75), height: 1);
    for (var c = 0; c < 9; c++) {
      final x = _x0 + c * _cell;
      text('${c + 1}', Offset(x, 42), num);
      text('${9 - c}', Offset(x, _h - 42), num);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.color != color || old.flipped != flipped;
}

class _UnderPainter extends CustomPainter {
  final int? last;
  final List<Offset> dests;
  final Offset Function(int) disp;
  _UnderPainter({required this.last, required this.dests, required this.disp});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / _w);
    if (last != null) {
      final p = Paint()
        ..color = const Color(0x8C286EC8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4;
      for (final sq in [last! & 127, last! >> 7]) {
        final o = disp(sq);
        _dashedRRect(canvas, RRect.fromRectAndRadius(Rect.fromCenter(center: o, width: 92, height: 92), const Radius.circular(10)), p);
      }
    }
    final dot = Paint()..color = const Color(0xBF1F8A4C);
    for (final o in dests) {
      canvas.drawCircle(o, 13, dot);
    }
  }

  void _dashedRRect(Canvas canvas, RRect rr, Paint p) {
    final path = Path()..addRRect(rr);
    for (final m in path.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, math.min(d + 14, m.length)), p);
        d += 24;
      }
    }
  }

  @override
  bool shouldRepaint(_UnderPainter old) => true;
}

class _OverPainter extends CustomPainter {
  final List<Arrow> arrows;
  final List<Offset> caps;
  final Offset Function(int) disp;
  _OverPainter({required this.arrows, required this.caps, required this.disp});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / _w);
    final ring = Paint()
      ..color = const Color(0xD91F8A4C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    for (final o in caps) {
      canvas.drawCircle(o, 46, ring);
    }
    for (final a in arrows) {
      final color = switch (a.kind) {
        'best' => kArrowBest,
        'alt' => kArrowAlt,
        'bad' => kArrowBad,
        _ => kArrowPlayed,
      };
      final alpha = a.kind == 'alt' ? 0.7 : 0.85;
      final width = a.kind == 'alt' ? 10.0 : 14.0;
      final p1 = disp(a.m & 127), p2 = disp(a.m >> 7);
      final dv = p2 - p1, len = dv.distance;
      if (len == 0) continue;
      final u = dv / len;
      final s = p1 + u * 30;
      final head = width * 2.6;
      final e = p2 - u * 30;
      final shaftEnd = e - u * head * 0.8;
      final paint = Paint()
        ..color = color.withValues(alpha: alpha)
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(s, shaftEnd, paint);
      final nrm = Offset(-u.dy, u.dx);
      final tri = Path()
        ..moveTo(e.dx, e.dy)
        ..lineTo((shaftEnd + nrm * head * 0.62).dx, (shaftEnd + nrm * head * 0.62).dy)
        ..lineTo((shaftEnd - nrm * head * 0.62).dx, (shaftEnd - nrm * head * 0.62).dy)
        ..close();
      canvas.drawPath(tri, Paint()..color = color.withValues(alpha: alpha));
    }
  }

  @override
  bool shouldRepaint(_OverPainter old) => true;
}

class PieceWidget extends StatefulWidget {
  final int piece;
  final double size;
  final bool hanChars, selected, danger, check;
  const PieceWidget({
    super.key,
    required this.piece,
    required this.size,
    this.hanChars = true,
    this.selected = false,
    this.danger = false,
    this.check = false,
  });

  @override
  State<PieceWidget> createState() => _PieceWidgetState();
}

class _PieceWidgetState extends State<PieceWidget> with SingleTickerProviderStateMixin {
  AnimationController? _pulse;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(PieceWidget old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.check && _pulse == null) {
      _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    } else if (!widget.check && _pulse != null) {
      _pulse!.dispose();
      _pulse = null;
    }
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.piece, t = absT(p);
    final color = p > 0 ? kRed : kBlack;
    final label = widget.hanChars ? han[t]![p > 0 ? 0 : 1] : viet[t]!;
    final d = widget.size * 0.88;
    final lift = widget.selected ? -widget.size * 0.04 : 0.0;

    Widget disc(double glow) => Container(
      width: d,
      height: d,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.3, -0.4),
          radius: 0.85,
          colors: [Color(0xFFFFFAF0), kPieceBg, Color(0xFFECD6AA)],
          stops: [0, 0.55, 1],
        ),
        border: Border.all(color: kPieceEdge, width: d * 0.035),
        boxShadow: [
          BoxShadow(color: const Color(0xFFB48A4E), offset: Offset(0, widget.selected ? d * 0.08 : d * 0.035)),
          BoxShadow(color: const Color(0x59281400), offset: Offset(0, d * 0.06), blurRadius: d * 0.1),
          if (widget.selected) BoxShadow(color: const Color(0xBF1F8A4C), spreadRadius: d * 0.05),
          if (widget.danger && !widget.selected) BoxShadow(color: const Color(0xCCD62828), spreadRadius: d * 0.05),
          if (widget.check)
            BoxShadow(color: Color.lerp(const Color(0xE6D62828), const Color(0x40D62828), glow)!, spreadRadius: d * (0.05 + 0.07 * glow)),
        ],
      ),
      child: Container(
        width: d * 0.74,
        height: d * 0.74,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.55), width: math.max(1.2, d * 0.025)),
        ),
        child: Text(
          label,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontFamily: widget.hanChars ? kHanFont : kFont,
            fontWeight: FontWeight.w700,
            fontSize: widget.hanChars ? d * 0.46 : d * 0.36,
            height: 1.0,
            color: color,
          ),
        ),
      ),
    );

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Center(
        child: AnimatedScale(
          scale: widget.selected ? 1.06 : 1,
          duration: const Duration(milliseconds: 120),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: lift),
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            builder: (context, dy, child) => Transform.translate(offset: Offset(0, dy), child: child),
            child: _pulse == null ? disc(0) : AnimatedBuilder(animation: _pulse!, builder: (_, _) => disc(_pulse!.value)),
          ),
        ),
      ),
    );
  }
}
