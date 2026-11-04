/// Scoreboard, ranking and live-feed server for Sisyphusball.
library;

import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_static/shelf_static.dart';

import 'src/auth/auth_service.dart';
import 'src/auth/auth_strategy.dart';
import 'src/config.dart';
import 'src/http/api_routes.dart';
import 'src/http/middleware.dart';
import 'src/live/observers.dart';
import 'src/runs/run_registry.dart';
import 'src/scores/score_repository.dart';
import 'src/scores/score_service.dart';

export 'src/auth/auth_strategy.dart' show PiTokenVerifier;
export 'src/auth/identity.dart';
export 'src/config.dart';
export 'src/events.dart';
export 'src/runs/presence.dart';
export 'src/runs/run_registry.dart' show RunRegistry, maxReachableScore;
export 'src/scores/score_models.dart';
export 'src/scores/score_repository.dart';
export 'src/scores/score_service.dart';

/// Composition root: builds every service once and wires the observers.
///
///   subjects            observers
///   ─────────────       ──────────────────────────────
///   ScoreService   ──┬─▶ LiveClient (one per socket) ×N
///   RunRegistry    ──┘   ActivityLog (ScoreService only)
class SisyphusServer {
  SisyphusServer({
    required this.config,
    required ScoreRepository repository,
    PiTokenVerifier? verifyPiToken,
    IOSink? log,
  })  : scores = ScoreService(repository, boardSize: config.leaderboardSize),
        runs = RunRegistry(),
        auth = AuthService([
          verifyPiToken != null
              ? PiAuthStrategy(verifyPiToken)
              : PiAuthStrategy.platformApi(apiBase: config.piApiBase),
          if (config.allowGuests) GuestAuthStrategy(),
        ]) {
    scores.attach(ActivityLog(log));
  }

  final ServerConfig config;
  final ScoreService scores;
  final RunRegistry runs;
  final AuthService auth;

  Handler get handler {
    final api = ApiRoutes(config: config, auth: auth, scores: scores, runs: runs);
    var cascade = Cascade().add(api.router.call);
    final webDir = config.webDir;
    if (webDir != null && Directory(webDir).existsSync()) {
      cascade = cascade.add(createStaticHandler(webDir, defaultDocument: 'index.html'));
    }
    return const Pipeline()
        .addMiddleware(allowAnyOrigin())
        .addMiddleware(errorsAsJson())
        .addHandler(cascade.handler);
  }

  void close() {
    runs.dispose();
    scores.detachAll();
  }
}

/// `dart:io` adds `X-Frame-Options: SAMEORIGIN` to every response. The Pi
/// Browser shows apps inside its own frame, so that header makes it refuse to
/// load the game (`net::ERR_BLOCKED_BY_RESPONSE`). Call this on the server
/// returned by `shelf_io.serve`.
void allowEmbeddingInPiBrowser(HttpServer server) =>
    server.defaultResponseHeaders.removeAll('x-frame-options');
