import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sisyphus_core/sisyphus_core.dart';

import 'game_controller.dart';

const _anchor = 0.68; // the stone sits at 68% of the screen height

/// Paints every lane of the [GameController] side by side.
class GamePainter extends CustomPainter {
  GamePainter(this.game) : super(repaint: game);

  final GameController game;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF0E0C14));
    final lanes = game.lanes;
    if (lanes.length == 1) {
      final w = min(size.width, 480.0);
      _paintLane(canvas, Rect.fromLTWH((size.width - w) / 2, 0, w, size.height), lanes[0],
          ghosts: game.ghosts, markers: game.markers, figure: const Color(0xFFEFE6D8));
    } else {
      final w = size.width / lanes.length;
      const colors = [Color(0xFFE8A95B), Color(0xFF7FC4E8)];
      for (final (i, lane) in lanes.indexed) {
        _paintLane(canvas, Rect.fromLTWH(i * w, 0, w, size.height), lane, figure: colors[i % 2]);
      }
      canvas.drawRect(Rect.fromLTWH(w - 1, 0, 2, size.height),
          Paint()..color = const Color(0x55000000));
    }
  }

  void _paintLane(
    Canvas canvas,
    Rect r,
    Lane lane, {
    List<Ghost> ghosts = const [],
    List<Marker> markers = const [],
    required Color figure,
  }) {
    final c = lane.climber;
    final w = r.width, h = r.height;
    final scale = w / laneWidth;
    final anchorY = h * _anchor;
    final camY = lane.camY;
    double toScreen(double y) => anchorY - (y - camY) * scale;
    final lo = camY - (h - anchorY) / scale - 1;
    final hi = camY + anchorY / scale + 1;

    canvas.save();
    canvas.clipRect(r);
    canvas.translate(r.left, 0);

    // the sky darkens as you climb: there is no light at the top either
    final depth = (camY / 600).clamp(0.0, 1.0);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(const Color(0xFF2B2340), const Color(0xFF0B0A12), depth)!,
            Color.lerp(const Color(0xFF4A3B4F), const Color(0xFF1A1524), depth)!,
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // the path and its cliffs
    final pathL = w * 0.04, pathR = w * 0.96;
    canvas.drawRect(Rect.fromLTRB(pathL, 0, pathR, h), Paint()..color = const Color(0x7314101A));
    final cliff = Paint()..color = const Color(0x59000000);
    canvas.drawRect(Rect.fromLTRB(0, 0, pathL, h), cliff);
    canvas.drawRect(Rect.fromLTRB(pathR, 0, w, h), cliff);

    // the ground at the foot of the mountain
    final groundY = toScreen(0) + ballRadius * scale;
    if (groundY < h) {
      canvas.drawRect(Rect.fromLTRB(0, groundY, w, h), Paint()..color = const Color(0xFF231C2A));
      canvas.drawRect(Rect.fromLTWH(0, groundY, w, 2), Paint()..color = const Color(0x40EFE6D8));
    }

    // a tick per meter (= one point), a labelled line every 10 m
    final fontSize = max(10.0, scale * 0.32);
    final tick = Paint()..color = const Color(0x26EFE6D8);
    for (var m = max(1, lo.ceil()); m <= hi; m++) {
      final sy = toScreen(m.toDouble());
      if (m % 10 == 0) {
        canvas.drawRect(Rect.fromLTRB(pathL, sy, pathR, sy + 1), Paint()..color = const Color(0x1FEFE6D8));
        _text(canvas, '$m', Offset(pathL + 4, sy - 8), fontSize, const Color(0x59EFE6D8));
      } else {
        canvas.drawRect(Rect.fromLTWH(pathL, sy, 6, 1), tick);
        canvas.drawRect(Rect.fromLTWH(pathR - 6, sy, 6, 1), tick);
      }
    }

    // personal best, the current #1 — goals that move nothing
    for (final mk in markers) {
      if (mk.y <= 0 || mk.y < lo || mk.y > hi) continue;
      final sy = toScreen(mk.y);
      final p = Paint()
        ..color = Color(mk.color)
        ..strokeWidth = 1;
      for (var x = pathL; x < pathR; x += 12) {
        canvas.drawLine(Offset(x, sy), Offset(min(x + 6, pathR), sy), p);
      }
      _text(canvas, mk.label, Offset(pathR - 4, sy - 9), fontSize, Color(mk.color), alignRight: true);
    }

    // rocks sweeping across the path
    final rockPaint = Paint()..color = const Color(0xFF6D6273);
    final shine = Paint()..color = const Color(0x14FFFFFF);
    for (final o in c.mountain.inRange(lo, hi)) {
      final cx = o.xAt(c.t) * w;
      final rw = o.width * w, rh = rockThickness * scale;
      final sy = toScreen(o.y);
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, sy), width: rw, height: rh),
              Radius.circular(rh / 2)),
          rockPaint);
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(cx - rw / 2 + 3, sy - rh / 2 + 2, rw - 6, rh * 0.35),
              Radius.circular(rh / 4)),
          shine);
    }

    // everyone else pushing their own stone at this very moment
    final cx = w / 2;
    final radius = ballRadius * scale;
    for (final g in ghosts) {
      if (g.height < lo || g.height > hi) continue;
      final sy = toScreen(g.height);
      canvas.drawCircle(Offset(cx, sy), radius, Paint()..color = const Color(0x47E8DCC6));
      _text(canvas, g.name, Offset(cx, sy - radius - 16), fontSize, const Color(0x8CEFE6D8), center: true);
    }

    // Sisyphus stays where the stone slipped away from him
    _figure(canvas, cx, toScreen(c.figureY) + radius, scale, figure);

    // the stone
    final by = toScreen(c.y);
    canvas.drawCircle(
      Offset(cx, by),
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.35),
          colors: const [Color(0xFFE2D3BB), Color(0xFF8F7F69)],
        ).createShader(Rect.fromCircle(center: Offset(cx, by), radius: radius)),
    );
    final grain = Paint()
      ..color = const Color(0x733C3024)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1, radius * 0.08);
    for (var i = 0; i < 3; i++) {
      final a = c.rotation + i * pi * 2 / 3;
      canvas.drawCircle(Offset(cx + cos(a) * radius * 0.45, by + sin(a) * radius * 0.45), radius * 0.18, grain);
    }

    // +1, +1, +1 ...
    for (final p in lane.popups) {
      _text(canvas, '+1', Offset(cx + radius * 1.8, toScreen(p.y) - p.age * 30 - 10), max(14, scale * 0.5),
          const Color(0xFFE8A95B).withValues(alpha: max(0, 1 - p.age)),
          bold: true);
    }

    canvas.restore();
  }

  /// A small stick figure leaning into the stone from below.
  void _figure(Canvas canvas, double x, double top, double scale, Color color) {
    final s = scale * 0.5;
    final p = Paint()
      ..color = color
      ..strokeWidth = max(2, s * 0.16)
      ..strokeCap = StrokeCap.round;
    final headY = top + s * 0.55;
    canvas.drawCircle(Offset(x - s * 0.15, headY), s * 0.28, p);
    final hip = Offset(x + s * 0.05, headY + s * 1.3);
    final shoulder = Offset(x - s * 0.05, headY + s * 0.5);
    canvas
      ..drawLine(Offset(x - s * 0.1, headY + s * 0.3), hip, p) // torso
      ..drawLine(shoulder, Offset(x - s * 0.35, top), p) // arms reach up
      ..drawLine(shoulder, Offset(x + s * 0.35, top), p)
      ..drawLine(hip, Offset(x - s * 0.35, headY + s * 2.1), p) // legs braced
      ..drawLine(hip, Offset(x + s * 0.45, headY + s * 2.0), p);
  }

  void _text(Canvas canvas, String text, Offset at, double size, Color color,
      {bool alignRight = false, bool center = false, bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(fontSize: size, color: color, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = alignRight ? at.dx - tp.width : (center ? at.dx - tp.width / 2 : at.dx);
    tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
    tp.dispose();
  }

  @override
  bool shouldRepaint(covariant GamePainter old) => old.game != game;
}
