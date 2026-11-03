import 'package:flutter/material.dart';

import '../../copy.dart';
import '../../models/leaderboard_model.dart';
import '../../models/player_model.dart';
import '../theme.dart';
import '../widgets/game_button.dart';
import '../widgets/panel.dart';

class TitleScreen extends StatelessWidget {
  const TitleScreen({
    super.key,
    required this.player,
    required this.leaderboard,
    required this.onSolo,
    required this.onVersus,
    required this.onHallOfFame,
    required this.onOpenPage,
  });

  final PlayerModel player;
  final LeaderboardModel leaderboard;
  final VoidCallback onSolo, onVersus, onHallOfFame;

  /// Opens a server page such as `privacy` or `terms`.
  final void Function(String path) onOpenPage;

  String get _whoAmI => switch (player.status) {
        SignInStatus.pending => Copy.checkingAccount,
        SignInStatus.failed => player.failure ?? Copy.signInFailed,
        SignInStatus.signedIn =>
          Copy.playerLine(player.username, player.player!.guest, player.tier.name, player.standing.best),
      };

  @override
  Widget build(BuildContext context) {
    final stats = leaderboard.stats;
    return Panel(children: [
      const Text.rich(TextSpan(text: 'Sisyphus', style: TextStyles.display, children: [
        TextSpan(text: 'ball', style: TextStyle(fontWeight: FontWeight.w300, color: Palette.stone)),
      ])),
      const SizedBox(height: 6),
      const Text(Copy.tagline, style: TextStyles.muted),
      const SizedBox(height: 16),
      Text(_whoAmI, textAlign: TextAlign.center, style: TextStyles.body),
      const SizedBox(height: 8),
      GameButton(Copy.playSolo, hint: Copy.playSoloHint, primary: true, onPressed: player.signedIn ? onSolo : null),
      GameButton(Copy.playVersus, hint: Copy.playVersusHint, onPressed: onVersus),
      GameButton(Copy.hallOfFame, onPressed: onHallOfFame),
      const SizedBox(height: 18),
      const Text(Copy.howTo, textAlign: TextAlign.center, style: TextStyles.small),
      if (stats.totalRuns > 0) ...[
        const SizedBox(height: 8),
        Text(
          Copy.worldLine(stats.players, stats.totalRuns, stats.totalMeters),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Palette.accent, height: 1.5),
        ),
      ],
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _FooterLink(Copy.privacy, () => onOpenPage('privacy')),
        const Text('·', style: TextStyles.small),
        _FooterLink(Copy.terms, () => onOpenPage('terms')),
      ]),
    ]);
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(foregroundColor: Palette.muted, textStyle: const TextStyle(fontSize: 12)),
        child: Text(label),
      );
}
