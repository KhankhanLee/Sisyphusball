import 'package:flutter/widgets.dart';
import 'package:sisyphus_core/sisyphus_core.dart';

import '../../game/pusher_painter.dart';

/// A small picture of a look: the figure pushing a stone up a slope.
class PusherPreview extends StatelessWidget {
  const PusherPreview(this.look, {super.key, this.size = const Size(84, 108)});

  final Look look;
  final Size size;

  @override
  Widget build(BuildContext context) => CustomPaint(size: size, painter: _PreviewPainter(look));
}

class _PreviewPainter extends CustomPainter {
  _PreviewPainter(this.look);

  final Look look;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final s = h * 0.24;
    final r = s * 0.62;
    final stone = Offset(w / 2, h * 0.24);
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
    paintPusher(canvas, x: stone.dx, top: stone.dy + r, s: s, look: look);
  }

  @override
  bool shouldRepaint(covariant _PreviewPainter old) => old.look.skinId != look.skinId;
}
