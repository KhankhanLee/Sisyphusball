import 'package:flutter/material.dart';

import '../../copy.dart';
import '../theme.dart';
import '../widgets/game_button.dart';
import '../widgets/panel.dart';

class VersusResultScreen extends StatelessWidget {
  const VersusResultScreen({super.key, required this.scores, required this.onAgain, required this.onHome});

  final List<int> scores;
  final VoidCallback onAgain, onHome;

  @override
  Widget build(BuildContext context) {
    final [p1, p2] = scores;
    final verdict = p1 == p2 ? Copy.versusDraw : Copy.versusWinner(p1 > p2 ? 1 : 2);
    return Panel(children: [
      const Text(Copy.versusRefrain, textAlign: TextAlign.center, style: TextStyles.refrain),
      const SizedBox(height: 12),
      Text(verdict, textAlign: TextAlign.center, style: TextStyles.heading),
      const SizedBox(height: 6),
      Text(Copy.versusScores(p1, p2), style: TextStyles.muted),
      const SizedBox(height: 6),
      const Text(Copy.versusCoda, style: TextStyles.small),
      GameButton(Copy.pushTogetherAgain, primary: true, onPressed: onAgain),
      GameButton(Copy.home, onPressed: onHome),
    ]);
  }
}
