import 'package:flutter/material.dart';
import 'package:sisyphus_core/sisyphus_core.dart';

import '../../copy.dart';
import '../../game/game_controller.dart';
import '../../models/player_model.dart';
import '../../models/presence_model.dart';
import '../theme.dart';
import '../widgets/live_dot.dart';

/// Score while climbing alone. Rebuilds with the game, every frame.
class SoloHud extends StatelessWidget {
  const SoloHud({super.key, required this.game, required this.player, required this.presence});

  final GameController game;
  final PlayerModel player;
  final PresenceModel presence;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Align(
            alignment: Alignment.topCenter,
            child: ListenableBuilder(
              listenable: game,
              builder: (context, child) {
                final score = game.lanes.first.climber.score;
                return Column(mainAxisSize: MainAxisSize.min, children: [
                  Text.rich(TextSpan(
                    text: '$score',
                    style: const TextStyle(
                        fontSize: 56, fontWeight: FontWeight.w800, color: Palette.ink, height: 1, shadows: TextStyles.shadow),
                    children: const [TextSpan(text: 'm', style: TextStyle(fontSize: 20, color: Palette.muted))],
                  )),
                  const SizedBox(height: 6),
                  Text(Copy.hudLine(tierFor(score).name, player.standing.best),
                      style: const TextStyle(fontSize: 13, color: Palette.muted, shadows: TextStyles.shadow)),
                  const SizedBox(height: 4),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const LiveDot(),
                    Text(Copy.liveCount(presence.count),
                        style: const TextStyle(fontSize: 12, color: Palette.muted, shadows: TextStyles.shadow)),
                  ]),
                ]);
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Both scores side by side in 2P mode.
class VersusHud extends StatelessWidget {
  const VersusHud({super.key, required this.game});

  final GameController game;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ListenableBuilder(
            listenable: game,
            builder: (context, child) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final (i, lane) in game.lanes.indexed)
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: 'P${i + 1}  ', style: const TextStyle(fontSize: 14, color: Palette.accent)),
                      TextSpan(text: '${lane.climber.score}m'),
                    ]),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w800, color: Palette.ink, shadows: TextStyles.shadow),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
