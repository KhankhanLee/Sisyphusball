import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../auth/auth_service.dart';
import '../config.dart';
import '../events.dart';
import '../live/observers.dart';
import '../runs/run_registry.dart';
import '../scores/score_service.dart';
import 'client_log.dart';
import 'http_error.dart';
import 'legal_pages.dart';
import 'middleware.dart';

/// Thin HTTP controllers: parse the request, call a service, render JSON.
///
///   GET  /api/config               {sandbox, allowGuest, seed}
///   POST /api/auth                 {accessToken} | {guest, name}
///   GET  /api/me                   (bearer)
///   GET  /api/leaderboard
///   POST /api/runs                 (bearer) → {runId, seed}
///   POST /api/runs/{id}/progress   (bearer) {height}
///   POST /api/runs/{id}/finish     (bearer) {score}
///   GET  /ws                       live feed: {"type":"board"|"live", ...}
///   POST /api/client-log           {event, detail, ua} from browsers, logged
///   GET  /privacy, /terms          legal pages for the Pi Developer Portal
class ApiRoutes {
  ApiRoutes({
    required this.config,
    required this.auth,
    required this.scores,
    required this.runs,
    ClientLog? clientLog,
  })  : legal = LegalPages(directory: config.legalDir, contactEmail: config.contactEmail),
        clientLog = clientLog ?? ClientLog();

  final ServerConfig config;
  final AuthService auth;
  final ScoreService scores;
  final RunRegistry runs;
  final LegalPages legal;
  final ClientLog clientLog;

  Router get router => Router()
    ..get('/api/config', _config)
    ..post('/api/auth', _signIn)
    ..get('/api/me', _me)
    ..get('/api/leaderboard', _leaderboard)
    ..post('/api/runs', _startRun)
    ..post('/api/runs/<id>/progress', _progress)
    ..post('/api/runs/<id>/finish', _finish)
    ..post('/api/client-log', clientLog.handle)
    ..get('/ws', webSocketHandler(_onSocket))
    ..get('/validation-key.txt', _validationKey)
    ..get('/privacy', (Request _) => legal.render('privacy'))
    ..get('/terms', (Request _) => legal.render('terms'))
    ..all('/api/<rest|.*>', (Request _) => throw HttpError(404, 'not found'));

  Response _config(Request _) =>
      jsonResponse({'sandbox': config.sandbox, 'allowGuest': config.allowGuests, 'seed': config.seed});

  Future<Response> _signIn(Request req) async {
    final (token, who) = await auth.signIn(await readJson(req));
    return jsonResponse({'token': token, 'user': who.toJson(), 'standing': scores.standingOf(who.uid).toJson()});
  }

  Response _me(Request req) {
    final who = auth.requireSession(req.headers['authorization']);
    return jsonResponse({'user': who.toJson(), 'standing': scores.standingOf(who.uid).toJson()});
  }

  Response _leaderboard(Request _) => jsonResponse(scores.leaderboard().toJson());

  Response _startRun(Request req) {
    final who = auth.requireSession(req.headers['authorization']);
    return jsonResponse({'runId': runs.start(who), 'seed': config.seed});
  }

  Future<Response> _progress(Request req, String id) async {
    final who = auth.requireSession(req.headers['authorization']);
    final height = (await readJson(req))['height'];
    if (height is num) runs.progress(id, who, height);
    return jsonResponse({'ok': true});
  }

  Future<Response> _finish(Request req, String id) async {
    final who = auth.requireSession(req.headers['authorization']);
    final score = runs.finish(id, who, (await readJson(req))['score']);
    final result = scores.record(who, score);
    return jsonResponse({
      'score': score,
      'isBest': result.isBest,
      'standing': result.standing.toJson(),
      'stats': scores.leaderboard().totals.toJson(),
    });
  }

  Response _validationKey(Request _) {
    if (config.validationKey.isEmpty) throw HttpError(404, 'not found');
    return Response.ok(config.validationKey, headers: {'Content-Type': 'text/plain'});
  }

  /// Each socket becomes one more observer of both subjects.
  void _onSocket(WebSocketChannel socket, String? _) {
    LiveClient.connect(
      socket,
      subjects: [scores, runs],
      initial: [LeaderboardChanged(scores.leaderboard()), PresenceChanged(runs.presence())],
    );
  }
}
