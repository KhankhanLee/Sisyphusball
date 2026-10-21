import 'package:flutter/material.dart';

const ink = Color(0xFFEFE6D8);
const muted = Color(0xFFA99F92);
const accent = Color(0xFFE8A95B);
const liveGreen = Color(0xFF7BD88F);

/// Dimmed backdrop with a centered card.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.children, this.maxWidth = 400});

  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0x8C0A080E),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xEB181422),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0x1FEFE6D8)),
                  boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 60, offset: Offset(0, 20))],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
                  child: Column(mainAxisSize: MainAxisSize.min, children: children),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GameButton extends StatelessWidget {
  const GameButton(this.label, {super.key, this.onPressed, this.primary = false, this.hint});

  final String label;
  final String? hint;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? const Color(0xFF23180B) : ink;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            backgroundColor: primary ? accent : const Color(0x0FFFFFFF),
            foregroundColor: fg,
            disabledForegroundColor: fg.withValues(alpha: 0.4),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: primary ? BorderSide.none : const BorderSide(color: Color(0x1FEFE6D8)),
            ),
          ),
          child: Text.rich(TextSpan(children: [
            TextSpan(text: label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            if (hint != null)
              TextSpan(
                  text: '  $hint',
                  style: TextStyle(fontSize: 12, color: fg.withValues(alpha: 0.65), fontWeight: FontWeight.w400)),
          ])),
        ),
      ),
    );
  }
}

class LiveDot extends StatefulWidget {
  const LiveDot({super.key});

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: 1.0, end: 0.3).animate(_c),
        child: Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.only(right: 6),
          decoration: const BoxDecoration(color: liveGreen, shape: BoxShape.circle),
        ),
      );
}

String formatMeters(int m) {
  final s = m.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}
