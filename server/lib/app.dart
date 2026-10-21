import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:sisyphus_core/sisyphus_core.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'pi_verifier.dart';
import 'store.dart';

class ServerConfig {
  const ServerConfig({
    this.sandbox = true,
    this.allowGuest = true,
    this.seed = defaultSeed,
    this.validationKey = '',
    this.leaderboardSize = 50,
    this.webDir,
  });

  final bool sandbox;

  /// Guests can play outside the Pi Browser. Keep this off in production so
  /// the ranking only holds verified Pioneers.
  final bool allowGuest;
  final int seed;

  /// Served at /validation-key.txt for Pi Developer Portal domain checks.
  final String validationKey;
  final int leaderboardSize;

  /// The Flutter web build (`app/build/web`) to serve, if any.
  final String? webDir;
}

class HttpError implements Exception {
  HttpError(this.status, this.message);

  final int status;
  final String message;
}

class _Session {
  _Session(this.uid, this.username, this.guest, this.expires);

  final String uid;
  final String username;
  final bool guest;
  final DateTime expires;
}

class _Run {
  _Run(this.session, this.startedAt) : lastProgress = startedAt;

  final _Session session;
  final DateTime startedAt;
  DateTime lastProgress;
  int height = 0;
}

const _sessionTtl = Duration(hours: 12);
const _runTtl = Duration(hours: 1);
const _liveStale = Duration(seconds: 5);
const _maxBody = 4096;

/// HTTP API + WebSocket live feed.
///
/// REST: /api/config, /api/auth, /api/me, /api/leaderboard,
///       /api/runs, /api/runs/{id}/progress, /api/runs/{id}/finish
/// WS:   /ws pushes {"type":"board"} after every finished climb and
///       {"type":"live"} (who is climbing, how high) once a second.
class SisyphusServer {
  SisyphusServer({
    required this.store,
    required this.config,
    required this.verifyPiToken,
  }) {
    _liveTimer = Timer.periodic(const Duration(seconds: 1), (_) => _pushLive());
  }

  final Store store;
  final ServerConfig config;
  final VerifyPiToken verifyPiToken;

  final _sessions = <String, _Session>{};
  final _runs = <String, _Run>{};
  final _sockets = <WebSocketChannel>{};
  final _random = Random.secure();
  late final Timer _liveTimer;
  String _lastLive = '';

  void close() {
    _liveTimer.cancel();
    final open = _sockets.toList();
    _sockets.clear();
    for (final s in open) {
      s.sink.close();
    }
  }

  Handler get handler {
    final api = Router()
      ..get('/api/config', _config)
      ..post('/api/auth', _auth)
      ..get('/api/me', _me)
      ..get('/api/leaderboard', (Request _) => _json(_boardPayload()))
      ..post('/api/runs', _startRun)
      ..post('/api/runs/<id>/progress', _progress)
      ..post('/api/runs/<id>/finish', _finish)
      ..get('/ws', webSocketHandler(_onSocket))
      ..get('/validation-key.txt', _validationKey)
      ..all('/api/<rest|.*>', (Request _) => throw HttpError(404, 'not found'));

    var cascade = Cascade().add(api.call);
    final webDir = config.webDir;
    if (webDir != null && Directory(webDir).existsSync()) {
      cascade = cascade.add(createStaticHandler(webDir, defaultDocument: 'index.html'));
    }
    return const Pipeline()
        .addMiddleware(_cors)
        .addMiddleware(_errors)
        .addHandler(cascade.handler);
  }

  // ---------- routes ----------

  Response _config(Request _) => _json({
        'sandbox': config.sandbox,
        'allowGuest': config.allowGuest,
        'seed': config.seed,
      });

  Future<Response> _auth(Request req) async {
    final body = await _readJson(req);
    final _Session session;
    final accessToken = body['accessToken'];
    if (accessToken is String && accessToken.isNotEmpty) {
      final PiUser user;
      try {
        user = await verifyPiToken(accessToken);
      } catch (e) {
        throw HttpError(401, 'Pi authentication failed');
      }
      session = _Session(user.uid, user.username, false, DateTime.now().add(_sessionTtl));
    } else if (body['guest'] == true && config.allowGuest) {
      session = _Session('guest:${_token(12)}', _sanitizeName(body['name']), true,
          DateTime.now().add(_sessionTtl));
    } else {
      throw HttpError(400, 'accessToken required');
    }
    final token = _token(24);
    _sessions[token] = session;
    return _json({
      'token': token,
      'user': {'username': session.username, 'guest': session.guest},
      'standing': _standing(session.uid),
    });
  }

  Response _me(Request req) {
    final s = _requireSession(req);
    return _json({
      'user': {'username': s.username, 'guest': s.guest},
      'standing': _standing(s.uid),
    });
  }

  Response _startRun(Request req) {
    final s = _requireSession(req);
    _runs.removeWhere((_, r) => r.session.uid == s.uid); // one live run each
    final id = _token(16);
    _runs[id] = _Run(s, DateTime.now());
    return _json({'runId': id, 'seed': config.seed});
  }

  Future<Response> _progress(Request req, String id) async {
    final (run, ceiling) = _ownedRun(req, id);
    final h = (await _readJson(req))['height'];
    if (h is num && h.isFinite && h >= 0) run.height = min(h.floor(), ceiling);
    run.lastProgress = DateTime.now();
    return _json({'ok': true});
  }

  Future<Response> _finish(Request req, String id) async {
    final (run, ceiling) = _ownedRun(req, id);
    final score = (await _readJson(req))['score'];
    _runs.remove(id);
    if (score is! int || score < 0) throw HttpError(400, 'invalid score');
    if (score > ceiling) throw HttpError(422, 'score is faster than the stone can roll');
    final s = run.session;
    final result = store.recordRun(uid: s.uid, username: s.username, guest: s.guest, score: score);
    _broadcast({'type': 'board', ..._boardPayload()});
    return _json({
      'score': score,
      'isBest': result.isBest,
      'standing': _standing(s.uid),
      'stats': store.stats(),
    });
  }

  Response _validationKey(Request _) {
    if (config.validationKey.isEmpty) throw HttpError(404, 'not found');
    return Response.ok(config.validationKey, headers: {'Content-Type': 'text/plain'});
  }

  // ---------- live feed ----------

  void _onSocket(WebSocketChannel ws, String? _) {
    _sockets.add(ws);
    ws.sink.add(jsonEncode({'type': 'board', ..._boardPayload()}));
    ws.sink.add(jsonEncode({'type': 'live', ..._liveSnapshot()}));
    // Clients only listen; incoming messages are ignored.
    ws.stream.listen((_) {}, onDone: () => _sockets.remove(ws), onError: (_) => _sockets.remove(ws));
  }

  Map<String, dynamic> _liveSnapshot() {
    final now = DateTime.now();
    _runs.removeWhere((_, r) => now.difference(r.startedAt) > _runTtl);
    final climbers = [
      for (final MapEntry(:key, :value) in _runs.entries)
        if (now.difference(value.lastProgress) < _liveStale)
          {'id': key.substring(0, 8), 'name': value.session.username, 'height': value.height}
    ]..sort((a, b) => (b['height'] as int).compareTo(a['height'] as int));
    return {'count': climbers.length, 'climbers': climbers.take(30).toList()};
  }

  void _pushLive() {
    if (_sockets.isEmpty) return;
    final msg = jsonEncode({'type': 'live', ..._liveSnapshot()});
    if (msg == _lastLive) return;
    _lastLive = msg;
    for (final s in _sockets.toList()) {
      s.sink.add(msg);
    }
  }

  void _broadcast(Map<String, dynamic> data) {
    final msg = jsonEncode(data);
    for (final s in _sockets.toList()) {
      s.sink.add(msg);
    }
  }

  Map<String, dynamic> _boardPayload() =>
      {'top': store.leaderboard(config.leaderboardSize), 'stats': store.stats()};

  // ---------- helpers ----------

  Map<String, dynamic> _standing(String uid) {
    final p = store.player(uid);
    final best = p?.best ?? 0;
    return {
      'best': best,
      'rank': store.rankOf(uid),
      'runs': p?.runs ?? 0,
      'totalMeters': p?.totalMeters ?? 0,
      'tier': tierFor(best).name,
    };
  }

  _Session _requireSession(Request req) {
    final header = req.headers['authorization'] ?? '';
    final token = header.startsWith('Bearer ') ? header.substring(7) : '';
    final s = _sessions[token];
    if (s == null || s.expires.isBefore(DateTime.now())) {
      _sessions.remove(token);
      throw HttpError(401, 'not signed in');
    }
    return s;
  }

  /// The run [id] if it belongs to the caller, plus the highest score that
  /// is physically reachable since it started.
  (_Run, int) _ownedRun(Request req, String id) {
    final s = _requireSession(req);
    final run = _runs[id];
    if (run == null || run.session.uid != s.uid) throw HttpError(404, 'run not found');
    final elapsed = DateTime.now().difference(run.startedAt).inMilliseconds / 1000;
    // Generous slack for latency, but nobody climbs faster than the physics.
    return (run, (elapsed * maxPointsPerSecond * 1.15 + 3).floor());
  }

  String _token(int bytes) =>
      base64Url.encode(List.generate(bytes, (_) => _random.nextInt(256))).replaceAll('=', '');

  String _sanitizeName(Object? name) {
    final clean = (name is String ? name : '')
        .replaceAll(RegExp(r'[^\p{L}\p{N}_\- ]', unicode: true), '')
        .trim();
    final short = String.fromCharCodes(clean.runes.take(16));
    return short.isNotEmpty ? short : '나그네${_random.nextInt(9000) + 1000}';
  }

  static Future<Map<String, dynamic>> _readJson(Request req) async {
    final len = req.contentLength;
    if (len != null && len > _maxBody) throw HttpError(413, 'body too large');
    final bytes = <int>[];
    await for (final chunk in req.read()) {
      bytes.addAll(chunk);
      if (bytes.length > _maxBody) throw HttpError(413, 'body too large');
    }
    if (bytes.isEmpty) return {};
    try {
      final data = jsonDecode(utf8.decode(bytes));
      if (data is Map<String, dynamic>) return data;
    } on FormatException {
      // fall through
    }
    throw HttpError(400, 'invalid JSON');
  }

  static Response _json(Object body, [int status = 200]) => Response(status,
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store'});

  static Handler _errors(Handler inner) => (req) async {
        try {
          return await inner(req);
        } on HttpError catch (e) {
          return _json({'error': e.message}, e.status);
        }
      };

  // Auth uses a Bearer header, never cookies, so allowing any origin is safe
  // and lets `flutter run -d chrome` talk to a local server on another port.
  static Handler _cors(Handler inner) {
    const headers = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'Authorization, Content-Type',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    };
    return (req) async {
      if (req.method == 'OPTIONS') return Response.ok(null, headers: headers);
      return (await inner(req)).change(headers: headers);
    };
  }
}
