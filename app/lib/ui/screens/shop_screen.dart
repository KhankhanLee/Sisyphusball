import 'package:flutter/material.dart';
import 'package:sisyphus_core/sisyphus_core.dart';

import '../../copy.dart';
import '../../models/look_model.dart';
import '../theme.dart';
import '../widgets/game_button.dart';
import '../widgets/panel.dart';
import '../widgets/portrait.dart';
import '../widgets/pusher_preview.dart';

/// Choose who pushes the stone, and in what. Looks never change the score.
class ShopScreen extends StatefulWidget {
  const ShopScreen({
    super.key,
    required this.looks,
    required this.signedIn,
    required this.onWear,
    required this.onBuy,
    required this.onBack,
  });

  final LookModel looks;
  final bool signedIn;
  final void Function(Skin skin) onWear, onBuy;
  final VoidCallback onBack;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  late String _character = widget.looks.look.characterId;

  /// The skin shown in the portrait: tapped last, else worn, else free.
  String? _preview;

  String get _previewSkin {
    final tapped = _preview;
    if (tapped != null && skinById(tapped)?.characterId == _character) return tapped;
    final worn = widget.looks.look;
    return worn.characterId == _character ? worn.skinId : defaultSkinOf(_character).id;
  }

  @override
  Widget build(BuildContext context) {
    final looks = widget.looks;
    return Panel(maxWidth: 440, children: [
      const Text(Copy.shopTitle, style: TextStyles.heading),
      const SizedBox(height: 4),
      const Text(Copy.shopSubtitle, textAlign: TextAlign.center, style: TextStyles.small),
      const SizedBox(height: 14),
      if (hasPortrait(_previewSkin)) ...[
        Portrait(_previewSkin),
        const SizedBox(height: 6),
        Text(skinById(_previewSkin)!.name, style: const TextStyle(color: Palette.muted, fontSize: 12)),
        const SizedBox(height: 10),
      ],
      Row(children: [
        for (final c in characters)
          Expanded(
            child: _CharacterCard(
              character: c,
              look: looks.look.characterId == c.id ? looks.look : Look(c.id, defaultSkinOf(c.id).id),
              selected: _character == c.id,
              onTap: () => setState(() {
                _character = c.id;
                _preview = null;
              }),
            ),
          ),
      ]),
      const SizedBox(height: 10),
      for (final skin in skinsOf(_character))
        _SkinRow(
          skin: skin,
          looks: looks,
          signedIn: widget.signedIn,
          onWear: () => widget.onWear(skin),
          onBuy: () => widget.onBuy(skin),
          onPreview: () => setState(() => _preview = skin.id),
        ),
      if (!looks.shopOpen) ...[
        const SizedBox(height: 8),
        const Text(Copy.shopClosed, textAlign: TextAlign.center, style: TextStyles.small),
      ],
      GameButton(Copy.back, onPressed: widget.onBack),
    ]);
  }
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({required this.character, required this.look, required this.selected, required this.onTap});

  final Character character;
  final Look look;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: selected ? const Color(0x1FE8A95B) : const Color(0x0AFFFFFF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? Palette.accent : Palette.hairline, width: selected ? 1.5 : 1),
            ),
            child: Column(children: [
              PusherPreview(look),
              const SizedBox(height: 6),
              Text(character.name, style: const TextStyle(fontWeight: FontWeight.w800, color: Palette.ink)),
              Text(Copy.free, style: TextStyles.small),
            ]),
          ),
        ),
      );
}

class _SkinRow extends StatelessWidget {
  const _SkinRow({
    required this.skin,
    required this.looks,
    required this.signedIn,
    required this.onWear,
    required this.onBuy,
    required this.onPreview,
  });

  final Skin skin;
  final LookModel looks;
  final bool signedIn;
  final VoidCallback onWear, onBuy, onPreview;

  @override
  Widget build(BuildContext context) {
    final wearing = looks.wears(skin);
    final owned = looks.owns(skin);
    final buying = looks.buying == skin.id;
    final Widget action;
    if (wearing) {
      action = const Text(Copy.wearing, style: TextStyle(color: Palette.accent, fontWeight: FontWeight.w700));
    } else if (owned) {
      action = OutlinedButton(onPressed: signedIn ? onWear : null, child: const Text(Copy.wear));
    } else if (buying) {
      action = const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2));
    } else {
      action = FilledButton(
        onPressed: signedIn && looks.shopOpen && looks.buying == null ? onBuy : null,
        child: Text(Copy.buyFor(skin.price)),
      );
    }
    return InkWell(
      onTap: onPreview,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0x0AFFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: wearing ? Palette.accent : Palette.hairline),
        ),
        child: Row(children: [
          PusherPreview(Look(skin.characterId, skin.id), size: const Size(52, 66)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(skin.name, style: const TextStyle(fontWeight: FontWeight.w800, color: Palette.ink)),
              Text(skin.blurb, style: TextStyles.small),
            ]),
          ),
          action,
        ]),
      ),
    );
  }
}
