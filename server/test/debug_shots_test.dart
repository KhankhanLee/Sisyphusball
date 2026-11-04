import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf_io.dart' as io;
import 'package:sisyphus_server/sisyphus_server.dart';
import 'package:test/test.dart';

void main() {
  Future<(HttpServer, SisyphusServer)> start({required bool shots}) async {
    final app = SisyphusServer(
      config: ServerConfig(debugShots: shots),
      repository: InMemoryScoreRepository(),
      verifyPiToken: (_) async => throw StateError('unused'),
      log: IOSink(StreamController<List<int>>().sink),
    );
    return (await io.serve(app.handler, InternetAddress.loopbackIPv4, 0), app);
  }

  final png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3];

  test('off by default: upload and download are 404', () async {
    final (server, app) = await start(shots: false);
    final base = 'http://127.0.0.1:${server.port}';
    expect((await http.post(Uri.parse('$base/api/debug/shot'), body: png)).statusCode, 404);
    expect((await http.get(Uri.parse('$base/api/debug/shot.png'))).statusCode, 404);
    app.close();
    await server.close(force: true);
  });

  test('when enabled, the latest PNG is served back; non-PNGs are refused', () async {
    final (server, app) = await start(shots: true);
    final base = 'http://127.0.0.1:${server.port}';
    expect((await http.post(Uri.parse('$base/api/debug/shot'), body: [1, 2, 3, 4, 5, 6, 7, 8, 9])).statusCode, 400);
    expect((await http.post(Uri.parse('$base/api/debug/shot'), body: png)).statusCode, 204);
    final res = await http.get(Uri.parse('$base/api/debug/shot.png'));
    expect(res.statusCode, 200);
    expect(res.headers['content-type'], 'image/png');
    expect(res.bodyBytes, png);
    expect((await http.get(Uri.parse('$base/api/config'))).body, contains('"debugShots":true'));
    app.close();
    await server.close(force: true);
  });
}
