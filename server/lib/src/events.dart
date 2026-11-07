import 'carvings/carving.dart';
import 'scores/score_models.dart';
import 'runs/presence.dart';

/// Everything the server's subjects announce. Subjects ([ScoreService],
/// [RunRegistry]) and observers ([LiveClient], [ActivityLog]) all speak this
/// one sealed family, which is what lets them be wired n:m.
sealed class ServerEvent {
  const ServerEvent();
}

/// The ranking or the world totals changed.
final class LeaderboardChanged extends ServerEvent {
  const LeaderboardChanged(this.leaderboard);

  final Leaderboard leaderboard;
}

/// Who is climbing right now, and how high, changed.
final class PresenceChanged extends ServerEvent {
  const PresenceChanged(this.presence);

  final Presence presence;
}

/// A player beat their own best.
final class PersonalBest extends ServerEvent {
  const PersonalBest(this.username, this.score, this.rank);

  final String username;
  final int score;
  final int? rank;
}

/// Someone carved words into the mountain.
final class CarvingsChanged extends ServerEvent {
  const CarvingsChanged(this.carvings);

  final List<Carving> carvings;
}
