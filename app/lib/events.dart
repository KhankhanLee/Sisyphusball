import 'data/models.dart';
import 'game/scene.dart' show GameMode;

/// Every event in the app. All subjects emit (their own subtypes of) this one
/// sealed family and all observers accept it, which is what allows the n:m
/// wiring in `AppServices`: an observer attaches to as many subjects as it
/// needs and simply ignores the events it does not care about.
sealed class AppEvent {
  const AppEvent();
}

// ---- from AuthService ----

final class SignedIn extends AppEvent {
  const SignedIn(this.player, this.standing);

  final Player player;
  final Standing standing;
}

final class SignInFailed extends AppEvent {
  const SignInFailed(this.reason);

  final String reason;
}

// ---- from GameController ----

final class RunStarted extends AppEvent {
  const RunStarted(this.mode);

  final GameMode mode;
}

final class StoneCrashed extends AppEvent {
  const StoneCrashed(this.lane, this.score);

  final int lane;
  final int score;
}

/// Every stone of the run is back at the bottom.
final class RunEnded extends AppEvent {
  const RunEnded(this.mode, this.scores);

  final GameMode mode;
  final List<int> scores; // one per lane
}

// ---- from RunReporter ----

/// The server accepted a ranked run and gave it an id.
final class RunRegistered extends AppEvent {
  const RunRegistered(this.runId);

  final String runId;
}

final class RunRecorded extends AppEvent {
  const RunRecorded(this.result);

  final RunResult result;
}

// ---- from LiveFeed ----

final class BoardUpdated extends AppEvent {
  const BoardUpdated(this.top, this.stats);

  final List<BoardEntry> top;
  final WorldStats stats;
}

final class PresenceUpdated extends AppEvent {
  const PresenceUpdated(this.climbers, this.count);

  final List<LiveClimber> climbers;
  final int count;
}

/// The words carved into the mountain changed.
final class CarvingsUpdated extends AppEvent {
  const CarvingsUpdated(this.carvings);

  final List<Carving> carvings;
}
