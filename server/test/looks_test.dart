import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf_io.dart' as io;
import 'package:sisyphus_server/sisyphus_server.dart';
import 'package:test/test.dart';

/// Pi's payments API as a map of payment id -> payment.
class FakePi implements PiPayments {
  final payments = <String, Map<String, dynamic>>{};
  final completed = <String>[];

  void add(String id, {String uid = 'alice', num amount = 1, String skin = 'her-ember', String? txid}) =>
      payments[id] = {
        'identifier': id,
        'user_uid': uid,
        'amount': amount,
        'direction': 'user_to_app',
        'metadata': {'kind': 'skin', 'skin': skin},
        'status': {'cancelled': false},
        'transaction': txid == null ? null : {'txid': txid},
      };

  @override
  Future<Map<String, dynamic>> get(String id) async => payments[id]!;

  @override
  Future<void> approve(String id) async {}

  @override
  Future<void> complete(String id, String txid) async => completed.add(id);
}

void main() {
  const alice = Identity(uid: 'pi:alice', username: 'alice');
  late FakePi pi;
  late LookService looks;
  late PaymentDesk desk;

  setUp(() {
    pi = FakePi();
    looks = LookService(LookStore());
    desk = PaymentDesk(pi, [looks]);
  });

  Future<int> statusOf(Future<Object?> f) => f.then((_) => 200, onError: (Object e) => (e as HttpError).status);

  test('everyone starts as Sisyphus in Exile and can switch to any free look', () async {
    expect(looks.stateOf('pi:alice'), {
      'look': {'character': 'him', 'skin': 'him-exile'},
      'owned': <String>[],
    });
    final state = await looks.equip(alice, 'her', 'her-exile');
    expect(state['look'], {'character': 'her', 'skin': 'her-exile'});
    expect(await statusOf(looks.equip(alice, 'him', 'her-exile')), 400, reason: 'skin of another character');
    expect(await statusOf(looks.equip(alice, 'her', 'nope')), 400);
  });

  test('a paid skin must be bought before it can be worn', () async {
    expect(await statusOf(looks.equip(alice, 'her', 'her-ember')), 402);

    pi.add('p1');
    await desk.approve(alice, 'p1');
    pi.add('p1', txid: 't1');
    final state = await desk.complete(alice, 'p1', 't1');
    expect(state, {
      'look': {'character': 'her', 'skin': 'her-ember'},
      'owned': ['her-ember'],
    });
    expect(pi.completed, ['p1']);

    // delivered once only; buying it again is refused
    await desk.complete(alice, 'p1', 't1');
    expect(pi.completed, ['p1']);
    pi.add('p2');
    expect(await statusOf(desk.approve(alice, 'p2')), 409);

    // and it can be taken off and put back on
    await looks.equip(alice, 'him', 'him-exile');
    expect((await looks.equip(alice, 'her', 'her-ember'))['look'], {'character': 'her', 'skin': 'her-ember'});
  });

  test('refuses wrong prices, free skins and unknown skins', () async {
    pi
      ..add('cheap', amount: 0.5)
      ..add('free', amount: 0, skin: 'him-exile')
      ..add('ghost', skin: 'nope');
    for (final id in ['cheap', 'free', 'ghost']) {
      expect(await statusOf(desk.approve(alice, id)), 400, reason: id);
    }
  });

  test('LookStore survives a restart', () async {
    final dir = await Directory.systemTemp.createTemp('looks');
    final path = '${dir.path}/looks.json';
    final store = LookStore(path: path);
    final service = LookService(store);
    final pi = FakePi()..add('p', txid: 't');
    await PaymentDesk(pi, [service]).complete(alice, 'p', 't');

    final again = LookStore(path: path);
    await again.load();
    expect(again.of('pi:alice').owned, {'her-ember'});
    expect(again.delivered('p'), isTrue);
    expect(LookService(again).lookOf('pi:alice').skinId, 'her-ember');
    await dir.delete(recursive: true);
  });

  test('HTTP: /api/me/look reads and changes the look; /api/config says when the shop sells', () async {
    final app = SisyphusServer(
      config: const ServerConfig(piApiKey: 'k'),
      repository: InMemoryScoreRepository(),
      verifyPiToken: (t) async => alice,
      payments: FakePi(),
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
      expect((await call('GET', '/api/config'))['shop'], true);
      final token = (await call('POST', '/api/auth', body: {'accessToken': 'x'}))['token'] as String;
      expect((await call('GET', '/api/me/look', token: token))['look'], {'character': 'him', 'skin': 'him-exile'});
      final set = await call('POST', '/api/me/look', body: {'character': 'her', 'skin': 'her-exile'}, token: token);
      expect(set['look'], {'character': 'her', 'skin': 'her-exile'});
      expect((await call('POST', '/api/me/look', body: {'character': 'her', 'skin': 'her-marble'}, token: token))['status'],
          402);
      expect((await call('GET', '/api/me/look'))['status'], 401);
    } finally {
      app.close();
      await server.close(force: true);
    }
  });
}
