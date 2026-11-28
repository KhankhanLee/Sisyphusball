import 'dart:math';
import 'dart:ui';
import 'dart:ui' as ui show Image;

import 'package:sisyphus_core/sisyphus_core.dart';

/// Draws Sisyphus (or Sisyphe) leaning into the stone from below.
///
/// [x] is the stone's centre line, [top] the bottom of the stone (where the
/// hands are) and [s] the figure's size unit in pixels. With a [look] the
/// figure is drawn in that character and skin; without one, as a plain
/// figure in [tint] (the 2P lanes). With a [sprite] (that look's picture),
/// the picture stands under the stone, holding it up.
void paintPusher(Canvas canvas,
    {required double x, required double top, required double s, Look? look, Color? tint, ui.Image? sprite}) {
  if (look != null && sprite != null) {
    _paintSprite(canvas, x: x, top: top, s: s, look: look, sprite: sprite);
    return;
  }
  final headY = top + s * 0.55;
  final head = Offset(x - s * 0.15, headY);
  final shoulder = Offset(x - s * 0.05, headY + s * 0.5);
  final hip = Offset(x + s * 0.05, headY + s * 1.3);
  final handL = Offset(x - s * 0.35, top), handR = Offset(x + s * 0.35, top);
  final footL = Offset(x - s * 0.35, headY + s * 2.1), footR = Offset(x + s * 0.45, headY + s * 2.0);
  Paint limb(Color c, double w) => Paint()
    ..color = c
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round;

  if (look == null) {
    final p = limb(tint ?? const Color(0xFFEFE6D8), max(2, s * 0.16));
    canvas
      ..drawCircle(head, s * 0.28, p)
      ..drawLine(Offset(x - s * 0.1, headY + s * 0.3), hip, p)
      ..drawLine(shoulder, handL, p)
      ..drawLine(shoulder, handR, p)
      ..drawLine(hip, footL, p)
      ..drawLine(hip, footR, p);
    return;
  }

  final skin = look.skin;
  final c = skin.colors;
  final her = skin.characterId == 'her';
  final skinPaint = limb(Color(c.skin), max(2, s * 0.15));
  final trim = Color(c.trim);

  final glow = c.glow;
  if (glow != null) {
    canvas.drawCircle(
      Offset(x, headY + s * 0.9),
      s * 1.5,
      Paint()
        ..color = Color(glow)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.5),
    );
  }

  // Legs, then sandals.
  canvas
    ..drawLine(hip, footL, skinPaint)
    ..drawLine(hip, footR, skinPaint);
  final sandal = Paint()..color = trim;
  for (final f in [footL, footR]) {
    canvas.drawOval(Rect.fromCenter(center: f.translate(0, s * 0.04), width: s * 0.26, height: s * 0.1), sandal);
  }

  // Long hair falls behind her back.
  if (her) {
    final hair = Path()
      ..moveTo(head.dx - s * 0.26, head.dy - s * 0.05)
      ..quadraticBezierTo(head.dx - s * 0.5, head.dy + s * 0.6, head.dx - s * 0.18, head.dy + s * 1.0)
      ..lineTo(head.dx + s * 0.12, head.dy + s * 0.55)
      ..quadraticBezierTo(head.dx + s * 0.2, head.dy + s * 0.1, head.dx + s * 0.22, head.dy - s * 0.05)
      ..close();
    canvas.drawPath(hair, Paint()..color = Color(c.hair));
  }

  // Tunic (him, to mid-thigh) or robe (her, to the knee, flared).
  final hemY = headY + s * (her ? 1.85 : 1.55);
  final hemHalf = s * (her ? 0.42 : 0.3);
  final body = Path()
    ..moveTo(x - s * 0.27, headY + s * 0.34)
    ..lineTo(x + s * 0.2, headY + s * 0.34)
    ..quadraticBezierTo(x + s * 0.24, headY + s * 1.0, x + s * 0.05 + hemHalf, hemY)
    ..lineTo(x + s * 0.05 - hemHalf, hemY)
    ..quadraticBezierTo(x - s * 0.3, headY + s * 1.0, x - s * 0.27, headY + s * 0.34)
    ..close();
  canvas.drawPath(body, Paint()..color = Color(c.cloth));
  final trimLine = Paint()
    ..color = trim
    ..strokeWidth = max(1.5, s * 0.07)
    ..strokeCap = StrokeCap.round;
  canvas
    ..drawLine(Offset(x - s * 0.24, headY + s * 1.0), Offset(x + s * 0.2, headY + s * 1.0), trimLine) // belt
    ..drawLine(Offset(x + s * 0.05 - hemHalf, hemY), Offset(x + s * 0.05 + hemHalf, hemY), trimLine); // hem
  if (!her) {
    canvas.drawLine(Offset(x - s * 0.22, headY + s * 0.36), Offset(x + s * 0.12, headY + s * 0.95), trimLine); // strap
  }

  // Arms reach up to the stone.
  canvas
    ..drawLine(shoulder, handL, skinPaint)
    ..drawLine(shoulder, handR, skinPaint);

  // Head and hair.
  canvas.drawCircle(head, s * 0.27, Paint()..color = Color(c.skin));
  final cap = Path()
    ..addArc(Rect.fromCircle(center: head, radius: s * (her ? 0.31 : 0.29)), pi * 0.95, pi * (her ? 1.25 : 1.1))
    ..close();
  canvas.drawPath(cap, Paint()..color = Color(c.hair));
  if (her) {
    canvas.drawCircle(head.translate(-s * 0.08, -s * 0.34), s * 0.12, Paint()..color = Color(c.hair)); // bun
  }
}

void _paintSprite(Canvas canvas,
    {required double x, required double top, required double s, required Look look, required ui.Image sprite}) {
  final height = s * 4.0;
  final width = height * sprite.width / sprite.height;
  final dst = Rect.fromLTWH(x - width / 2, top - height * 0.02, width, height);
  final glow = look.skin.colors.glow;
  if (glow != null) {
    canvas.drawOval(
      dst.inflate(width * 0.3),
      Paint()
        ..color = Color(glow)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.6),
    );
  }
  canvas.drawImageRect(
    sprite,
    Rect.fromLTWH(0, 0, sprite.width.toDouble(), sprite.height.toDouble()),
    dst,
    Paint()..filterQuality = FilterQuality.medium,
  );
}
