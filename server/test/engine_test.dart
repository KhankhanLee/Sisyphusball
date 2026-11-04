import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf_io.dart' as io;
import 'package:sisyphus_server/sisyphus_server.dart';
import 'package:test/test.dart';

Future<Map<String, dynamic>> engineFor(String flutterEngine) async {
  final app = SisyphusServer(
    config: ServerConfig(flutterEngine: flutterEngine),
    repository: InMemoryScoreRepository(),
    verifyPiToken: (_) async => throw StateError('unused'),
    log: IOSink(StreamController<List<int>>().sink),
  );
  final server = await io.serve(app.handler, InternetAddress.loopbackIPv4, 0);
  try {
    final res = await http.get(Uri.parse('http://127.0.0.1:${server.port}/api/engine'));
    expect(res.statusCode, 200);
    return jsonDecode(res.body) as Map<String, dynamic>;
  } finally {
    app.close();
    await server.close(force: true);
  }
}

void main() {
  test('no setting means Flutter defaults', () async {
    expect(await engineFor(''), isEmpty);
  });

  test('known loader settings pass through', () async {
    expect(await engineFor('{"renderer":"canvaskit","canvasKitForceCpuOnly":true}'),
        {'renderer': 'canvaskit', 'canvasKitForceCpuOnly': true});
  });

  test('unknown keys are dropped and malformed JSON falls back to defaults', () async {
    expect(await engineFor('{"renderer":"skwasm","entrypointBaseUrl":"https://evil"}'), {'renderer': 'skwasm'});
    expect(await engineFor('not json'), isEmpty);
  });
}
