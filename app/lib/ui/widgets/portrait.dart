import 'package:flutter/material.dart';

import '../theme.dart';

/// Skins that have a drawn portrait (`assets/portraits/{skin id}.jpg`). Art
/// can be replaced by dropping in a new file with the same name.
const _portraits = {'her-exile', 'her-starlight', 'her-lilac', 'her-herald', 'her-envoy'};

bool hasPortrait(String skinId) => _portraits.contains(skinId);

/// The large full-body picture (2:3) of a character in a skin, shown in the shop.
class Portrait extends StatelessWidget {
  const Portrait(this.skinId, {super.key, this.height = 330});

  final String skinId;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        width: height * 2 / 3,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Palette.hairline),
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 10))],
        ),
        clipBehavior: Clip.antiAlias,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Image.asset(
            'assets/portraits/$skinId.jpg',
            key: ValueKey(skinId),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            height: height,
            width: height * 2 / 3,
          ),
        ),
      );
}
