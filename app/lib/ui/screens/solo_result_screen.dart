import 'package:flutter/material.dart';
import 'package:sisyphus_core/sisyphus_core.dart';

import '../../copy.dart';
import '../../data/models.dart';
import '../theme.dart';
import '../widgets/game_button.dart';
import '../widgets/panel.dart';

/// After a solo climb: the score, the title it earned, and what it means
/// (nothing, and everything).
class SoloResultScreen extends StatelessWidget {
  const SoloResultScreen({
    super.key,
    required this.score,
    required this.result,
    required this.standing,
    required this.players,
    required this.refrain,
    required this.onAgain,
    required this.onHallOfFame,
    required this.onHome,
  });

  final int score;
  final RunResult? result; // null while it is being recorded
  final Standing standing;
  final int players;
  final String refrain;
  final VoidCallback onAgain, onHallOfFame, onHome;

  String get _verdict {
    final r = result;
    if (r == null) return Copy.recording;
    return r.error ?? (r.isBest ? Copy.newBest : Copy.bestSoFar(standing.best));
  }

  @override
  Widget build(BuildContext context) {
    final rank = standing.rank;
    return Panel(children: [
      Text(refrain, textAlign: TextAlign.center, style: TextStyles.refrain),
      const SizedBox(height: 10),
      Text.rich(TextSpan(
        text: '$score',
        style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w800, color: Palette.ink, height: 1),
        children: const [TextSpan(text: 'm', style: TextStyle(fontSize: 24, color: Palette.muted))],
      )),
      const SizedBox(height: 6),
      Text(_verdict,
          textAlign: TextAlign.center,
          style: TextStyle(color: result?.isBest == true ? Palette.accent : Palette.muted)),
      _TierCard(best: standing.best),
      if (rank != null)
        Text(Copy.rank(rank, players),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Palette.ink)),
      const SizedBox(height: 4),
      Text(Copy.lifetime(standing.totalMeters, standing.runs), textAlign: TextAlign.center, style: TextStyles.small),
      GameButton(Copy.pushAgain, primary: true, onPressed: onAgain),
      GameButton(Copy.hallOfFame, onPressed: onHallOfFame),
      GameButton(Copy.home, onPressed: onHome),
    ]);
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({required this.best});

  final int best;

  @override
  Widget build(BuildContext context) {
    final tier = tierFor(best);
    final next = nextTier(best);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x14E8A95B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.hairline),
      ),
      child: Column(children: [
        Text(tier.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Palette.accent)),
        const SizedBox(height: 6),
        Text(tier.motto, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Palette.ink)),
        const SizedBox(height: 8),
        Text(
          next == null ? Copy.noMoreTiers : Copy.nextTier(next.name, next.min - best),
          textAlign: TextAlign.center,
          style: TextStyles.small,
        ),
      ]),
    );
  }
}
