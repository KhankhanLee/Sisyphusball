import 'package:flutter/material.dart';

import '../theme.dart';

/// Dimmed backdrop with a centered card; every menu screen is one of these.
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
                  border: Border.all(color: Palette.hairline),
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
