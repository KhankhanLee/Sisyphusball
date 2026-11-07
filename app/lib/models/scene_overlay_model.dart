import '../copy.dart';
import '../game/scene.dart';
import 'carvings_model.dart';
import 'leaderboard_model.dart';
import 'player_model.dart';
import 'presence_model.dart';

/// Adapts the app's models to what the painter draws over the mountain:
/// other climbers as ghosts, dashed lines at my best and at the #1, and the
/// words people carved into the mountain.
class SceneOverlayModel implements SceneOverlay {
  SceneOverlayModel({required this.player, required this.leaderboard, required this.presence, required this.carvings});

  final PlayerModel player;
  final LeaderboardModel leaderboard;
  final PresenceModel presence;
  final CarvingsModel carvings;

  @override
  List<Engraving> get engravings =>
      [for (final c in carvings.carvings) Engraving(c.height.toDouble(), c.text, c.username)];

  @override
  List<Ghost> get ghosts => [for (final c in presence.others) Ghost(c.name, c.height.toDouble())];

  @override
  List<Marker> get markers {
    final best = player.standing.best;
    final leader = leaderboard.leader;
    return [
      if (best > 0) Marker(best.toDouble(), Copy.myBestMarker(best), 0xFFE8A95B),
      if (leader != null && leader.username != player.username)
        Marker(leader.best.toDouble(), Copy.leaderMarker(leader.username), 0xFF7BD88F),
    ];
  }
}
