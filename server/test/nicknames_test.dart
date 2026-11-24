import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf_io.dart' as io;
import 'package:sisyphus_server/sisyphus_server.dart';
import 'package:test/test.dart';

void main() {
  group('cleanNickname', () {
    test('accepts letters of any script, digits, spaces, _ and -', () {
      expect(cleanNickname('  Rock   Pusher '), 'Rock Pusher');
      expect(cleanNickname('돌굴리기_01'), '돌굴리기_01');
      expect(cleanNickname('ab'), 'ab');
      expect(cleanNickname('x' * 16), 'x' * 16);
    });
    test('rejects too short, too long, links, symbols and control characters', () {
      for (final bad in ['a', '', 'x' * 17, 'spam.com', 'a<b>', 'hi!', 'tab\there\u202E', 42]) {
        expect(cleanNickname(bad), isNull, reason: '$bad');
      }
    });
  });

  group('HTTP', () {
    late HttpServer server;
    late SisyphusServer app;
    late Uri base;

    Future<void> start({required bool nicknames}) async {
      app = SisyphusServer(
        config: ServerConfig(nicknames: nicknames),
        repository: InMemoryScoreRepository(),
        verifyPiToken: (t) async => Identity(uid: 'pi:$t', username: 'pi_$t'),
        log: IOSink(StreamController<List<int>>().sink),
      );
      server = await io.serve(app.handler, InternetAddress.loopbackIPv4, 0);
      base = Uri.parse('http://127.0.0.1:${server.port}');
    }

    tearDown(() async {
      app.close();
      await server.close(force: true);
    });

    Future<Map<String, dynamic>> call(String method, String path, {Object? body, String? token}) async {
      final req = http.Request(method, base.resolve(path))..headers['Content-Type'] = 'application/json';
      if (token != null) req.headers['Authorization'] = 'Bearer $token';
      if (body != null) req.body = jsonEncode(body);
      final res = await http.Response.fromStream(await req.send());
      return {'status': res.statusCode, ...jsonDecode(res.body) as Map<String, dynamic>};
    }

    Future<Map<String, dynamic>> signIn(String who) => call('POST', '/api/auth', body: {'accessToken': who});

    test('off by default: Pi username shown, no prompt, no route', () async {
      await start(nicknames: false);
      final me = await signIn('alice');
      expect(me['user'], {'username': 'pi_alice', 'guest': false});
      expect((await call('GET', '/api/config')).containsKey('nicknames'), isFalse);
      expect((await call('POST', '/api/me/nickname', body: {'nickname': 'Rock'}, token: me['token']))['status'], 404);
    });

    test('a Pi player is asked once, then shown by nickname everywhere', () async {
      await start(nicknames: true);
      expect((await call('GET', '/api/config'))['nicknames'], true);
      final first = await signIn('alice');
      expect(first['user']['needsNickname'], true);
      final token = first['token'] as String;

      // a record made before choosing a nickname is renamed on the board too
      app.scores.record(const Identity(uid: 'pi:alice', username: 'pi_alice'), 12);

      final set = await call('POST', '/api/me/nickname', body: {'nickname': '  Rock   Pusher '}, token: token);
      expect(set['status'], 200);
      expect(set['user'], {'username': 'Rock Pusher', 'guest': false});
      expect((await call('GET', '/api/me', token: token))['user']['username'], 'Rock Pusher');
      expect(((await call('GET', '/api/leaderboard'))['top'] as List).single['username'], 'Rock Pusher');

      // the next sign-in uses it straight away
      final again = await signIn('alice');
      expect(again['user'], {'username': 'Rock Pusher', 'guest': false});
    });

    test('names are unique (any case) and validated', () async {
      await start(nicknames: true);
      final alice = (await signIn('alice'))['token'];
      final bob = (await signIn('bob'))['token'];
      expect((await call('POST', '/api/me/nickname', body: {'nickname': 'Rock'}, token: alice))['status'], 200);
      expect((await call('POST', '/api/me/nickname', body: {'nickname': 'rOCK'}, token: bob))['status'], 409);
      expect((await call('POST', '/api/me/nickname', body: {'nickname': 'x'}, token: bob))['status'], 400);
      // someone else's Pi username already on the board is taken as well
      app.scores.record(const Identity(uid: 'pi:carol', username: 'carol_pi'), 3);
      expect((await call('POST', '/api/me/nickname', body: {'nickname': 'CAROL_PI'}, token: bob))['status'], 409);
      // changing your own nickname, even to a different case, is fine
      expect((await call('POST', '/api/me/nickname', body: {'nickname': 'ROCK'}, token: alice))['status'], 200);
      expect((await call('POST', '/api/me/nickname', body: {'nickname': 'Rock'}))['status'], 401);
    });

    test('NicknameStore survives a restart', () async {
      await start(nicknames: false);
      final dir = await Directory.systemTemp.createTemp('nick');
      await NicknameStore(path: '${dir.path}/n.json').set('pi:a', 'Rock');
      final again = NicknameStore(path: '${dir.path}/n.json');
      await again.load();
      expect(again.of('pi:a'), 'Rock');
      await dir.delete(recursive: true);
    });
  });
}
