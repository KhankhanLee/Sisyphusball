import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf_io.dart' as io;
import 'package:sisyphus_server/sisyphus_server.dart';
import 'package:sisyphus_server/src/http/client_log.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  late Directory web;
  late HttpServer server;
  late SisyphusServer app;
  late Uri base;
  final logged = StringBuffer();

  setUp(() async {
    web = await Directory.systemTemp.createTemp('sisyphus-web');
    File('${web.path}/index.html').writeAsStringSync('<html></html>');
    final sink = StreamController<List<int>>();
    sink.stream.listen((b) => logged.write(utf8.decode(b)));
    app = SisyphusServer(
      config: ServerConfig(webDir: web.path),
      repository: InMemoryScoreRepository(),
      verifyPiToken: (_) async => throw StateError('unused'),
      log: IOSink(sink.sink),
    );
    server = await io.serve(app.handler, InternetAddress.loopbackIPv4, 0);
    base = Uri.parse('http://127.0.0.1:${server.port}');
  });

  tearDown(() async {
    app.close();
    await server.close(force: true);
    await web.delete(recursive: true);
    logged.clear();
  });

  test('client reports land in the server log, one line each', () async {
    final res = await http.post(base.resolve('/api/client-log'),
        body: jsonEncode({'event': 'boot', 'detail': 'webgl=yes\nsecond line', 'ua': 'PiBrowser/1.0'}));
    expect(res.statusCode, 204);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(logged.toString(), contains('[client] boot: webgl=yes second line | ua=PiBrowser/1.0'));
  });

  test('client reports are rate-limited and truncated', () async {
    final lines = StringBuffer();
    final sink = StreamController<List<int>>()..stream.listen((b) => lines.write(utf8.decode(b)));
    final log = ClientLog(IOSink(sink.sink), 2);
    final statuses = <int>[];
    for (var i = 0; i < 3; i++) {
      final req = await _request(base, {'event': 'x', 'detail': 'y' * 3000});
      statuses.add((await log.handle(req)).statusCode);
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(statuses, [204, 204, 429]);
    expect(lines.toString().split('\n').first.length, lessThan(1100), reason: 'detail is cut at 800 chars');
  });

  test('static files are revalidated, so updates reach WebViews', () async {
    final res = await http.get(base.resolve('/'));
    expect(res.statusCode, 200);
    expect(res.headers['cache-control'], 'no-cache');
  });
}

Future<Request> _request(Uri base, Map<String, Object> body) async {
  // shelf Request built directly, as the router would pass it.
  return Request('POST', base.resolve('/api/client-log'), body: jsonEncode(body));
}
