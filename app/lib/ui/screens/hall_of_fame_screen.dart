import 'package:flutter/material.dart';
import 'package:sisyphus_core/sisyphus_core.dart';

import '../../copy.dart';
import '../../data/models.dart';
import '../../models/leaderboard_model.dart';
import '../../models/presence_model.dart';
import '../theme.dart';
import '../widgets/game_button.dart';
import '../widgets/live_dot.dart';
import '../widgets/panel.dart';

/// The live ranking, the world totals and who is climbing right now.
class HallOfFameScreen extends StatelessWidget {
  const HallOfFameScreen({
    super.key,
    required this.leaderboard,
    required this.presence,
    required this.me,
    required this.onBack,
  });

  final LeaderboardModel leaderboard;
  final PresenceModel presence;
  final String me;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final stats = leaderboard.stats;
    return Panel(maxWidth: 460, children: [
      const Text(Copy.hallOfFame, style: TextStyles.heading),
      const SizedBox(height: 4),
      const Text(Copy.boardSubtitle, textAlign: TextAlign.center, style: TextStyles.small),
      const SizedBox(height: 14),
      Row(children: [
        _StatTile(Copy.count(stats.players), Copy.statPlayers),
        _StatTile(Copy.meters(stats.totalMeters), Copy.statMeters),
        const _StatTile('0', Copy.statSummit),
      ]),
      const SizedBox(height: 10),
      ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.38),
        child: leaderboard.top.isEmpty
            ? const Padding(padding: EdgeInsets.all(16), child: Text(Copy.emptyBoard, style: TextStyles.muted))
            : ListView(
                shrinkWrap: true,
                children: [for (final e in leaderboard.top) _RankRow(e, isMe: e.username == me)],
              ),
      ),
      const SizedBox(height: 16),
      const Row(children: [
        LiveDot(),
        Text(Copy.pushingNow, style: TextStyle(fontSize: 14, color: Palette.muted, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: presence.climbers.isEmpty
            ? const Text(Copy.nobodyPushing, style: TextStyle(fontSize: 12, color: Palette.muted))
            : Wrap(spacing: 6, runSpacing: 6, children: [for (final c in presence.climbers) _ClimberChip(c)]),
      ),
      GameButton(Copy.back, onPressed: onBack),
    ]);
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(this.value, this.label);

  final String value, label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(color: const Color(0x0AFFFFFF), borderRadius: BorderRadius.circular(10)),
          child: Column(children: [
            Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Palette.ink)),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Palette.muted)),
          ]),
        ),
      );
}

class _RankRow extends StatelessWidget {
  const _RankRow(this.entry, {required this.isMe});

  final BoardEntry entry;
  final bool isMe;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
        decoration: BoxDecoration(
          color: isMe ? const Color(0x1FE8A95B) : null,
          borderRadius: BorderRadius.circular(8),
          border: const Border(bottom: BorderSide(color: Palette.hairline)),
        ),
        child: Row(children: [
          SizedBox(
            width: 36,
            child: Text('${entry.rank}',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800, color: entry.rank <= 3 ? Palette.accent : Palette.muted)),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(Copy.playerName(entry.username, isGuest: entry.guest),
                  overflow: TextOverflow.ellipsis, style: TextStyles.body),
              Text('${tierFor(entry.best).name} · ${Copy.timesPushed(entry.runs)}',
                  style: const TextStyle(fontSize: 11, color: Palette.muted)),
            ]),
          ),
          Text('${entry.best}m', style: const TextStyle(fontWeight: FontWeight.w800, color: Palette.ink)),
        ]),
      );
}

class _ClimberChip extends StatelessWidget {
  const _ClimberChip(this.climber);

  final LiveClimber climber;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0x1A7BD88F),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x407BD88F)),
        ),
        child: Text('${climber.name} · ${climber.height}m', style: const TextStyle(fontSize: 12, color: Palette.ink)),
      );
}
