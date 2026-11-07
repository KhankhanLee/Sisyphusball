import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf_io.dart' as io;
import 'package:sisyphus_core/sisyphus_core.dart';
import 'package:sisyphus_server/sisyphus_server.dart';
import 'package:test/test.dart';

/// Pi's payments API as a map of payment id -> payment.
class FakePi implements PiPayments {
  final payments = <String, Map<String, dynamic>>{};
  final approved = <String>[];
  final completed = <String>[];

  void add(String id, {String uid = 'alice', num amount = 1, Object? meta, String? txid}) => payments[id] = {
        'identifier': id,
        'user_uid': uid,
        'amount': amount,
        'direction': 'user_to_app',
        'metadata': meta ?? {'kind': 'carve', 'text': 'Still pushing.', 'height': 20},
        'status': {'cancelled': false, 'user_cancelled': false},
        'transaction': txid == null ? null : {'txid': txid, 'verified': true},
      };

  @override
  Future<Map<String, dynamic>> get(String id) async => payments[id] ?? (throw StateError('no such payment'));

  @override
  Future<void> approve(String id) async => approved.add(id);

  @override
  Future<void> complete(String id, String txid) async => completed.add(id);
}

void main() {
  group('cleanCarvingText', () {
    test('trims and collapses spaces', () => expect(cleanCarvingText('  Still   pushing. '), 'Still pushing.'));
    test('rejects empty, too long, links and control characters', () {
      expect(cleanCarvingText(''), isNull);
      expect(cleanCarvingText('   '), isNull);
      expect(cleanCarvingText('x' * 41), isNull);
      expect(cleanCarvingText('x' * 40), 'x' * 40);
      expect(cleanCarvingText('visit https://spam.example'), isNull);
      expect(cleanCarvingText('go to spam.com now'), isNull);
      expect(cleanCarvingText('www.spam'), isNull);
      expect(cleanCarvingText('abc\u202Edef'), isNull);
      expect(cleanCarvingText(42), isNull);
    });
    test('keeps non-Latin text', () => expect(cleanCarvingText('정상은 없다'), '정상은 없다'));
  });

  group('CarvingService', () {
    late FakePi pi;
    late CarvingService service;
    const alice = Identity(uid: 'pi:alice', username: 'alice');

    setUp(() {
      pi = FakePi();
      service = CarvingService(CarvingStore(), pi, price: 1, bestOf: (uid) => uid == 'pi:alice' ? 30 : 0);
    });

    test('approves, completes and announces a valid carving', () async {
      final events = <ServerEvent>[];
      service.attach(CallbackObserver(events.add));
      pi.add('p1');
      await service.approve(alice, 'p1');
      expect(pi.approved, ['p1']);

      pi.add('p1', txid: 'tx1');
      final carving = await service.complete(alice, 'p1', 'tx1');
      expect(carving!.text, 'Still pushing.');
      expect(carving.height, 20);
      expect(pi.completed, ['p1']);
      expect(events.whereType<CarvingsChanged>().single.carvings.single.username, 'alice');

      // completing again (e.g. an incomplete payment found at sign-in) is a no-op
      await service.complete(alice, 'p1', 'tx1');
      expect(pi.completed, ['p1']);
      expect(service.carvings, hasLength(1));
    });

    Future<int> statusOf(Future<void> f) => f.then((_) => 200, onError: (Object e) => (e as HttpError).status);

    test('refuses what it should not approve', () async {
      pi
        ..add('other', uid: 'bob')
        ..add('cheap', amount: 0.5)
        ..add('high', meta: {'kind': 'carve', 'text': 'too high', 'height': 31})
        ..add('link', meta: {'kind': 'carve', 'text': 'see spam.com', 'height': 5})
        ..add('kind', meta: {'kind': 'skin', 'text': 'x', 'height': 5});
      for (final id in ['other', 'cheap', 'high', 'link', 'kind']) {
        expect(await statusOf(service.approve(alice, id)), greaterThanOrEqualTo(400), reason: id);
      }
      expect(pi.approved, isEmpty);
      expect(await statusOf(service.approve(const Identity(uid: 'guest:1', username: 'g', guest: true), 'other')), 403);
    });

    test('will not complete without the matching transaction', () async {
      pi.add('p2');
      expect(await statusOf(service.complete(alice, 'p2', 'tx-made-up')), 409);
      pi.add('p2', txid: 'tx2');
      expect(await statusOf(service.complete(alice, 'p2', 'tx-other')), 409);
      expect(pi.completed, isEmpty);
      expect(service.carvings, isEmpty);
    });

    test('is off without an API key', () async {
      final off = CarvingService(CarvingStore(), null, price: 1, bestOf: (_) => 99);
      expect(off.enabled, isFalse);
      expect(await statusOf(off.approve(alice, 'p')), 503);
    });
  });

  test('CarvingStore survives a restart', () async {
    final dir = await Directory.systemTemp.createTemp('carvings');
    final path = '${dir.path}/carvings.json';
    await CarvingStore(path: path).add(const Carving(id: 'p', username: 'a', height: 3, text: 'hi', at: 1));
    final again = CarvingStore(path: path);
    await again.load();
    expect(again.all.single.text, 'hi');
    await dir.delete(recursive: true);
  });

  test('HTTP: carve end to end, then it shows in /api/carvings, /api/config and the live feed', () async {
    final pi = FakePi();
    final app = SisyphusServer(
      config: const ServerConfig(piApiKey: 'k'),
      repository: InMemoryScoreRepository(),
      verifyPiToken: (t) async => const Identity(uid: 'pi:alice', username: 'alice'),
      payments: pi,
      log: IOSink(StreamController<List<int>>().sink),
    );
    final server = await io.serve(app.handler, InternetAddress.loopbackIPv4, 0);
    final base = Uri.parse('http://127.0.0.1:${server.port}');
    Future<Map<String, dynamic>> call(String method, String path, {Object? body, String? token}) async {
      final req = http.Request(method, base.resolve(path))..headers['Content-Type'] = 'application/json';
      if (token != null) req.headers['Authorization'] = 'Bearer $token';
      if (body != null) req.body = jsonEncode(body);
      final res = await http.Response.fromStream(await req.send());
      return {'status': res.statusCode, ...jsonDecode(res.body) as Map<String, dynamic>};
    }

    try {
      expect((await call('GET', '/api/config'))['carvePrice'], 1);
      final token = (await call('POST', '/api/auth', body: {'accessToken': 'x'}))['token'] as String;
      app.scores.record(const Identity(uid: 'pi:alice', username: 'alice'), 25);

      pi.add('p9');
      expect((await call('POST', '/api/payments/approve', body: {'paymentId': 'p9'}, token: token))['status'], 200);
      expect((await call('POST', '/api/payments/approve', body: {'paymentId': 'p9'}))['status'], 401);
      pi.add('p9', txid: 't9');
      final done = await call('POST', '/api/payments/complete', body: {'paymentId': 'p9', 'txid': 't9'}, token: token);
      expect(done['status'], 200);
      expect(done['carving']['text'], 'Still pushing.');
      final list = await call('GET', '/api/carvings');
      expect((list['carvings'] as List).single, containsPair('height', 20));
      expect((list['carvings'] as List).single.containsKey('id'), isFalse, reason: 'payment ids stay private');
    } finally {
      app.close();
      await server.close(force: true);
    }
  });
}
