import 'package:flutter/material.dart';

import '../theme.dart';

class GameButton extends StatelessWidget {
  const GameButton(this.label, {super.key, this.onPressed, this.primary = false, this.hint});

  final String label;
  final String? hint;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? const Color(0xFF23180B) : Palette.ink;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            backgroundColor: primary ? Palette.accent : const Color(0x0FFFFFFF),
            foregroundColor: fg,
            disabledForegroundColor: fg.withValues(alpha: 0.4),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: primary ? BorderSide.none : const BorderSide(color: Palette.hairline),
            ),
          ),
          child: Text.rich(TextSpan(children: [
            TextSpan(text: label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            if (hint != null)
              TextSpan(
                text: '  $hint',
                style: TextStyle(fontSize: 12, color: fg.withValues(alpha: 0.65), fontWeight: FontWeight.w400),
              ),
          ])),
        ),
      ),
    );
  }
}
