import 'ads/ad_breaks.dart';
import 'auth/auth_service.dart';
import 'auth/auth_strategy.dart';
import 'copy.dart';
import 'data/api_client.dart';
import 'data/diagnostics.dart';
import 'data/live_feed.dart';
import 'data/models.dart';
import 'data/run_reporter.dart';
import 'game/game_controller.dart';
import 'models/leaderboard_model.dart';
import 'models/player_model.dart';
import 'models/presence_model.dart';
import 'models/scene_overlay_model.dart';
import 'models/screen_model.dart';
import 'pi/pi_sdk.dart';

/// Composition root: creates every service and model once and wires the
/// observers to their subjects. This table is the whole event flow:
///
///   subject           →  observers
///   ──────────────       ───────────────────────────────────────────
///   GameController    →  RunReporter, ScreenModel, AdBreaks
///   RunReporter       →  ScreenModel, PlayerModel, LeaderboardModel, PresenceModel
///   AuthService       →  PlayerModel, Diagnostics (when given)
///   LiveFeed          →  LeaderboardModel, PresenceModel
///
/// Four subjects, six observers, and most observers listen to more than
/// one subject: n:m.
class AppServices {
  AppServices({
    required Future<String?> Function() askGuestName,
    List<AuthStrategy>? authStrategies,
    ApiClient? api,
    Diagnostics? diagnostics,
    ShowAd? showAd,
  }) : api = api ?? ApiClient() {
    game = GameController();
    feed = LiveFeed();
    auth = AuthService(this.api, authStrategies ?? [const PiAuthStrategy(), GuestAuthStrategy(askGuestName)]);
    reporter = RunReporter(this.api, currentHeight: () => game.height);
    overlay = SceneOverlayModel(player: player, leaderboard: leaderboard, presence: presence);
    ads = AdBreaks(showAd ?? piShowInterstitial, onResult: (r) => diagnostics?.report('ad', r));

    game
      ..attach(reporter)
      ..attach(screens)
      ..attach(ads);
    reporter
      ..attach(screens)
      ..attach(player)
      ..attach(leaderboard)
      ..attach(presence);
    auth.attach(player);
    if (diagnostics != null) auth.attach(diagnostics);
    feed
      ..attach(leaderboard)
      ..attach(presence);
  }

  final ApiClient api;

  // subjects
  late final GameController game;
  late final LiveFeed feed;
  late final AuthService auth;
  late final RunReporter reporter;

  late final AdBreaks ads;

  // observers (UI state)
  final screens = ScreenModel();
  final player = PlayerModel();
  final leaderboard = LeaderboardModel();
  final presence = PresenceModel();
  late final SceneOverlayModel overlay;

  /// Connects to the live feed, loads the server settings and signs in.
  Future<void> start() async {
    feed.connect();
    final ServerSettings settings;
    try {
      settings = ServerSettings.fromJson(await api.get('/api/config'));
    } catch (e) {
      auth.fail('${Copy.signInFailed} $e');
      return;
    }
    game.seed = settings.seed;
    await auth.signIn(settings);
  }

  void dispose() {
    feed.close();
    reporter.dispose();
    ads.dispose();
    auth.detachAll();
    game
      ..detachAll()
      ..dispose();
    for (final model in [screens, player, leaderboard, presence]) {
      model.dispose();
    }
  }
}
