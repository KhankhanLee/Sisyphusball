import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sisyphus_core/sisyphus_core.dart';

import 'game_controller.dart';
import 'scene.dart';

/// Paints every lane side by side, repainting whenever the game ticks.
class GamePainter extends CustomPainter {
  GamePainter(this.game, this.overlay) : super(repaint: game);

  final GameController game;
  final SceneOverlay overlay;

  static const _laneColors = [Color(0xFFE8A95B), Color(0xFF7FC4E8)];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF0E0C14));
    final lanes = game.lanes;
    if (lanes.length == 1) {
      final w = min(size.width, 480.0);
      _LanePainter(canvas, Rect.fromLTWH((size.width - w) / 2, 0, w, size.height), lanes.first)
          .paint(ghosts: overlay.ghosts, markers: overlay.markers, figure: const Color(0xFFEFE6D8));
      return;
    }
    final w = size.width / lanes.length;
    for (final (i, lane) in lanes.indexed) {
      _LanePainter(canvas, Rect.fromLTWH(i * w, 0, w, size.height), lane).paint(figure: _laneColors[i % 2]);
    }
    canvas.drawRect(Rect.fromLTWH(w - 1, 0, 2, size.height), Paint()..color = const Color(0x55000000));
  }

  @override
  bool shouldRepaint(covariant GamePainter old) => old.game != game || old.overlay != overlay;
}

/// Draws one mountain path. World height `y` (meters) maps to the screen so
/// the stone sits at [_anchor] of the height, following the lane camera.
class _LanePainter {
  _LanePainter(this.canvas, this.rect, this.lane)
      : scale = rect.width / laneWidth,
        anchorY = rect.height * _anchor {
    lo = lane.cameraY - (rect.height - anchorY) / scale - 1;
    hi = lane.cameraY + anchorY / scale + 1;
  }

  static const _anchor = 0.68;

  final Canvas canvas;
  final Rect rect;
  final Lane lane;
  final double scale; // pixels per meter
  final double anchorY;
  late final double lo, hi; // visible height range (m)

  double get w => rect.width;
  double get h => rect.height;
  double get pathLeft => w * 0.04;
  double get pathRight => w * 0.96;
  double get centerX => w / 2;
  double get stoneRadius => ballRadius * scale;
  double get fontSize => max(10.0, scale * 0.32);
  Climber get climber => lane.climber;

  double toScreen(double y) => anchorY - (y - lane.cameraY) * scale;

  void paint({List<Ghost> ghosts = const [], List<Marker> markers = const [], required Color figure}) {
    canvas
      ..save()
      ..clipRect(rect)
      ..translate(rect.left, 0);
    _sky();
    _path();
    _ground();
    _heightTicks();
    _markers(markers);
    _rocks();
    _ghosts(ghosts);
    _figure(figure);
    _stone();
    _popups();
    canvas.restore();
  }

  /// The sky darkens as you climb: there is no light at the top either.
  void _sky() {
    final depth = (lane.cameraY / 600).clamp(0.0, 1.0);
    final bounds = Rect.fromLTWH(0, 0, w, h);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(const Color(0xFF2B2340), const Color(0xFF0B0A12), depth)!,
            Color.lerp(const Color(0xFF4A3B4F), const Color(0xFF1A1524), depth)!,
          ],
        ).createShader(bounds),
    );
  }

  void _path() {
    canvas.drawRect(Rect.fromLTRB(pathLeft, 0, pathRight, h), Paint()..color = const Color(0x7314101A));
    final cliff = Paint()..color = const Color(0x59000000);
    canvas
      ..drawRect(Rect.fromLTRB(0, 0, pathLeft, h), cliff)
      ..drawRect(Rect.fromLTRB(pathRight, 0, w, h), cliff);
  }

  void _ground() {
    final groundY = toScreen(0) + stoneRadius;
    if (groundY >= h) return;
    canvas
      ..drawRect(Rect.fromLTRB(0, groundY, w, h), Paint()..color = const Color(0xFF231C2A))
      ..drawRect(Rect.fromLTWH(0, groundY, w, 2), Paint()..color = const Color(0x40EFE6D8));
  }

  /// A tick per meter (one point), a labelled line every 10 m.
  void _heightTicks() {
    final tick = Paint()..color = const Color(0x26EFE6D8);
    final line = Paint()..color = const Color(0x1FEFE6D8);
    for (var m = max(1, lo.ceil()); m <= hi; m++) {
      final sy = toScreen(m.toDouble());
      if (m % 10 == 0) {
        canvas.drawRect(Rect.fromLTRB(pathLeft, sy, pathRight, sy + 1), line);
        _text('$m', Offset(pathLeft + 4, sy - 8), const Color(0x59EFE6D8));
      } else {
        canvas
          ..drawRect(Rect.fromLTWH(pathLeft, sy, 6, 1), tick)
          ..drawRect(Rect.fromLTWH(pathRight - 6, sy, 6, 1), tick);
      }
    }
  }

  void _markers(List<Marker> markers) {
    for (final mk in markers) {
      if (mk.height <= 0 || mk.height < lo || mk.height > hi) continue;
      final sy = toScreen(mk.height);
      final paint = Paint()..color = Color(mk.color);
      for (var x = pathLeft; x < pathRight; x += 12) {
        canvas.drawLine(Offset(x, sy), Offset(min(x + 6, pathRight), sy), paint);
      }
      _text(mk.label, Offset(pathRight - 4, sy - 9), Color(mk.color), align: TextAlign.right);
    }
  }

  void _rocks() {
    final body = Paint()..color = const Color(0xFF6D6273);
    final shine = Paint()..color = const Color(0x14FFFFFF);
    for (final rock in climber.mountain.inRange(lo, hi)) {
      final cx = rock.xAt(climber.t) * w;
      final rw = rock.width * w, rh = rockThickness * scale;
      final sy = toScreen(rock.y);
      canvas
        ..drawRRect(
            RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, sy), width: rw, height: rh), Radius.circular(rh / 2)),
            body)
        ..drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(cx - rw / 2 + 3, sy - rh / 2 + 2, rw - 6, rh * 0.35), Radius.circular(rh / 4)),
            shine);
    }
  }

  /// Everyone else pushing their own stone at this very moment.
  void _ghosts(List<Ghost> ghosts) {
    final paint = Paint()..color = const Color(0x47E8DCC6);
    for (final g in ghosts) {
      if (g.height < lo || g.height > hi) continue;
      final sy = toScreen(g.height);
      canvas.drawCircle(Offset(centerX, sy), stoneRadius, paint);
      _text(g.name, Offset(centerX, sy - stoneRadius - 16), const Color(0x8CEFE6D8), align: TextAlign.center);
    }
  }

  /// Sisyphus, leaning into the stone from below. He stays where the stone
  /// slipped away from him.
  void _figure(Color color) {
    final x = centerX, top = toScreen(climber.figureY) + stoneRadius;
    final s = scale * 0.5;
    final p = Paint()
      ..color = color
      ..strokeWidth = max(2, s * 0.16)
      ..strokeCap = StrokeCap.round;
    final headY = top + s * 0.55;
    final shoulder = Offset(x - s * 0.05, headY + s * 0.5);
    final hip = Offset(x + s * 0.05, headY + s * 1.3);
    canvas
      ..drawCircle(Offset(x - s * 0.15, headY), s * 0.28, p)
      ..drawLine(Offset(x - s * 0.1, headY + s * 0.3), hip, p) // torso
      ..drawLine(shoulder, Offset(x - s * 0.35, top), p) // arms reach up
      ..drawLine(shoulder, Offset(x + s * 0.35, top), p)
      ..drawLine(hip, Offset(x - s * 0.35, headY + s * 2.1), p) // legs braced
      ..drawLine(hip, Offset(x + s * 0.45, headY + s * 2.0), p);
  }

  void _stone() {
    final center = Offset(centerX, toScreen(climber.y));
    final r = stoneRadius;
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.35),
          colors: [Color(0xFFE2D3BB), Color(0xFF8F7F69)],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
    final grain = Paint()
      ..color = const Color(0x733C3024)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1, r * 0.08);
    for (var i = 0; i < 3; i++) {
      final a = climber.rotation + i * pi * 2 / 3;
      canvas.drawCircle(center + Offset(cos(a), sin(a)) * (r * 0.45), r * 0.18, grain);
    }
  }

  void _popups() {
    for (final p in lane.popups) {
      _text(
        '+1',
        Offset(centerX + stoneRadius * 1.8, toScreen(p.height) - p.age * 30 - 10),
        const Color(0xFFE8A95B).withValues(alpha: max(0, 1 - p.age)),
        size: max(14, scale * 0.5),
        bold: true,
      );
    }
  }

  void _text(String text, Offset at, Color color, {TextAlign align = TextAlign.left, double? size, bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: size ?? fontSize, color: color, fontWeight: bold ? FontWeight.bold : null),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = switch (align) {
      TextAlign.right => at.dx - tp.width,
      TextAlign.center => at.dx - tp.width / 2,
      _ => at.dx,
    };
    tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
    tp.dispose();
  }
}
