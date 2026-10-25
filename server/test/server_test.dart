import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf_io.dart' as io;
import 'package:sisyphus_server/sisyphus_server.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  late HttpServer server;
  late SisyphusServer app;
  late Uri base;

  Future<Identity> fakeVerify(String token) async {
    if (token == 'good-token-alice') return const Identity(uid: 'pi:alice', username: 'alice');
    if (token == 'good-token-bob00') return const Identity(uid: 'pi:bob', username: 'bob');
    throw StateError('bad token');
  }

  setUp(() async {
    app = SisyphusServer(
      config: const ServerConfig(allowGuests: true),
      repository: InMemoryScoreRepository(),
      verifyPiToken: fakeVerify,
      log: IOSink(StreamController<List<int>>().sink),
    );
    server = await io.serve(app.handler, InternetAddress.loopbackIPv4, 0);
    base = Uri.parse('http://127.0.0.1:${server.port}');
  });

  tearDown(() async {
    app.close();
    await server.close(force: true);
  });

  Future<(int, Map<String, dynamic>)> call(String method, String path,
      {Object? body, String? token}) async {
    final req = http.Request(method, base.resolve(path))
      ..headers['Content-Type'] = 'application/json';
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    if (body != null) req.body = jsonEncode(body);
    final res = await http.Response.fromStream(await req.send());
    return (res.statusCode, jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<String> signIn(String accessToken) async {
    final (status, body) = await call('POST', '/api/auth', body: {'accessToken': accessToken});
    expect(status, 200);
    return body['token'] as String;
  }

  test('Pi tokens are verified server-side', () async {
    final (bad, _) = await call('POST', '/api/auth', body: {'accessToken': 'forged-token-x'});
    expect(bad, 401);
    final (ok, body) = await call('POST', '/api/auth', body: {'accessToken': 'good-token-alice'});
    expect(ok, 200);
    expect(body['user']['username'], 'alice');
    expect(body['standing']['tier'], 'Pebble at the Bottom');
  });

  test('guest names are sanitized', () async {
    final (_, body) = await call('POST', '/api/auth', body: {'guest': true, 'name': '<b>Sisyphus</b>!!'});
    expect(body['user']['username'], 'bSisyphusb');
    expect(body['user']['guest'], true);
    final (_, unnamed) = await call('POST', '/api/auth', body: {'guest': true, 'name': ''});
    expect(unnamed['user']['username'], startsWith('Guest'));
  });

  test('runs require a session', () async {
    final (status, _) = await call('POST', '/api/runs');
    expect(status, 401);
  });

  test('impossible scores are rejected', () async {
    final token = await signIn('good-token-alice');
    final (_, run) = await call('POST', '/api/runs', token: token);
    final (status, _) = await call('POST', '/api/runs/${run['runId']}/finish',
        token: token, body: {'score': 500});
    expect(status, 422);
  });

  test('a run can be finished once, only by its owner', () async {
    final alice = await signIn('good-token-alice');
    final bob = await signIn('good-token-bob00');
    final (_, run) = await call('POST', '/api/runs', token: alice);
    final path = '/api/runs/${run['runId']}/finish';
    expect((await call('POST', path, token: bob, body: {'score': 1})).$1, 404);
    expect((await call('POST', path, token: alice, body: {'score': 2})).$1, 200);
    expect((await call('POST', path, token: alice, body: {'score': 2})).$1, 404);
  });

  test('concurrent players build one ranking and the feed pushes updates', () async {
    final ws = WebSocketChannel.connect(base.replace(scheme: 'ws', path: '/ws'));
    final messages = ws.stream.map((m) => jsonDecode(m as String) as Map<String, dynamic>);
    final boards = messages.where((m) => m['type'] == 'board');

    final alice = await signIn('good-token-alice');
    final bob = await signIn('good-token-bob00');
    final (_, ra) = await call('POST', '/api/runs', token: alice);
    final (_, rb) = await call('POST', '/api/runs', token: bob);

    // Both finish at the same moment.
    final results = await Future.wait([
      call('POST', '/api/runs/${ra['runId']}/finish', token: alice, body: {'score': 3}),
      call('POST', '/api/runs/${rb['runId']}/finish', token: bob, body: {'score': 2}),
    ]);
    expect(results.map((r) => r.$1), everyElement(200));
    expect(results[0].$2['standing']['rank'], 1);

    final (_, board) = await call('GET', '/api/leaderboard');
    expect([for (final e in board['top'] as List) e['username']], ['alice', 'bob']);
    expect(board['stats']['totalMeters'], 5);
    expect(board['stats']['stonesAtSummit'], 0);

    // initial snapshot + one per finished run
    final pushed = await boards.take(3).last.timeout(const Duration(seconds: 5));
    expect((pushed['top'] as List).length, 2);
    await ws.sink.close();
  });

  test('progress shows up as a live climber', () async {
    final alice = await signIn('good-token-alice');
    final (_, run) = await call('POST', '/api/runs', token: alice);
    await call('POST', '/api/runs/${run['runId']}/progress', token: alice, body: {'height': 2.7});
    final ws = WebSocketChannel.connect(base.replace(scheme: 'ws', path: '/ws'));
    final live = await ws.stream
        .map((m) => jsonDecode(m as String) as Map<String, dynamic>)
        .firstWhere((m) => m['type'] == 'live')
        .timeout(const Duration(seconds: 5));
    expect(live['count'], 1);
    expect(live['climbers'][0], containsPair('name', 'alice'));
    expect(live['climbers'][0]['height'], 2);
    await ws.sink.close();
  });

  test('legal pages are reachable over HTTP for the Pi Developer Portal', () async {
    for (final path in ['/privacy', '/terms']) {
      final res = await http.get(base.resolve(path));
      expect(res.statusCode, 200, reason: path);
      expect(res.headers['content-type'], startsWith('text/html'));
    }
  });

  test('repository persists across restarts', () async {
    final dir = await Directory.systemTemp.createTemp('sisyphus');
    final path = '${dir.path}/scores.json';
    final first = JsonFileScoreRepository(path);
    final service = ScoreService(first);
    service.record(const Identity(uid: 'u1', username: 'one'), 7);
    await first.flush();

    final second = JsonFileScoreRepository(path);
    await second.load();
    expect(second.find('u1')!.best, 7);
    expect(second.totals.runs, 1);
    await dir.delete(recursive: true);
  });
}
