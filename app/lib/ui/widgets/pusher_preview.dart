import 'dart:ui' as ui show Image;

import 'package:flutter/widgets.dart';
import 'package:sisyphus_core/sisyphus_core.dart';

import '../../game/pusher_painter.dart';

/// A small picture of a look: the figure pushing a stone up a slope.
class PusherPreview extends StatelessWidget {
  const PusherPreview(this.look, {super.key, this.size = const Size(84, 108), this.sprite});

  final Look look;
  final Size size;

  /// The look's picture, if it has one.
  final ui.Image? sprite;

  @override
  Widget build(BuildContext context) => CustomPaint(size: size, painter: _PreviewPainter(look, sprite));
}

class _PreviewPainter extends CustomPainter {
  _PreviewPainter(this.look, this.sprite);

  final Look look;
  final ui.Image? sprite;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // A picture is taller than the coded figure: draw it smaller.
    final s = sprite == null ? h * 0.24 : h * 0.19;
    final r = s * 0.62;
    final stone = Offset(w / 2, sprite == null ? h * 0.24 : h * 0.14);
    final frame = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10));
    canvas.clipRRect(frame);
    canvas.drawRRect(
      frame,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2B2340), Color(0xFF4A3B4F)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawCircle(
      stone,
      r,
      Paint()
        ..shader = const RadialGradient(center: Alignment(-0.35, -0.35), colors: [Color(0xFFE2D3BB), Color(0xFF8F7F69)])
            .createShader(Rect.fromCircle(center: stone, radius: r)),
    );
    paintPusher(canvas, x: stone.dx, top: stone.dy + r, s: s, look: look, sprite: sprite);
  }

  @override
  bool shouldRepaint(covariant _PreviewPainter old) => old.look.skinId != look.skinId || old.sprite != sprite;
}
