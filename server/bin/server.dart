import 'dart:io';

import 'package:shelf/shelf_io.dart' as io;
import 'package:sisyphus_core/sisyphus_core.dart';
import 'package:sisyphus_server/app.dart';
import 'package:sisyphus_server/pi_verifier.dart';
import 'package:sisyphus_server/store.dart';

Future<void> main() async {
  final env = Platform.environment;
  bool flag(String key, bool fallback) {
    final v = env[key];
    return v == null ? fallback : RegExp(r'^(1|true|yes)$', caseSensitive: false).hasMatch(v);
  }

  final production = env['APP_ENV'] == 'production';
  final config = ServerConfig(
    sandbox: flag('PI_SANDBOX', !production),
    allowGuest: flag('ALLOW_GUEST', !production),
    seed: int.tryParse(env['MOUNTAIN_SEED'] ?? '') ?? defaultSeed,
    validationKey: env['PI_VALIDATION_KEY'] ?? '',
    webDir: env['WEB_DIR'] ?? '../app/build/web',
  );

  final store = Store(env['DATA_FILE'] ?? 'data/scores.json');
  await store.load();

  final app = SisyphusServer(
    store: store,
    config: config,
    verifyPiToken: piVerifier(apiBase: env['PI_API_BASE'] ?? 'https://api.minepi.com'),
  );

  final port = int.tryParse(env['PORT'] ?? '') ?? 8080;
  final server = await io.serve(app.handler, InternetAddress.anyIPv4, port);
  stdout.writeln('Sisyphusball on http://localhost:${server.port} '
      '(sandbox=${config.sandbox}, guests=${config.allowGuest})');

  Future<void> shutdown(ProcessSignal _) async {
    app.close();
    await server.close(force: true);
    await store.flush();
    exit(0);
  }

  ProcessSignal.sigint.watch().listen(shutdown);
  if (!Platform.isWindows) ProcessSignal.sigterm.watch().listen(shutdown);
}
