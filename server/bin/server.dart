import 'dart:io';

import 'package:shelf/shelf_io.dart' as io;
import 'package:sisyphus_server/sisyphus_server.dart';

Future<void> main() async {
  final config = ServerConfig.fromEnvironment(Platform.environment);
  final dataFile = config.dataFile;
  final repository = dataFile == null ? InMemoryScoreRepository() : JsonFileScoreRepository(dataFile);
  await repository.load();

  final app = SisyphusServer(config: config, repository: repository);
  final server = await io.serve(app.handler, InternetAddress.anyIPv4, config.port);
  allowEmbeddingInPiBrowser(server);
  stdout.writeln('Sisyphusball on http://localhost:${server.port} '
      '(sandbox=${config.sandbox}, guests=${config.allowGuests})');

  Future<void> shutdown(ProcessSignal _) async {
    app.close();
    await server.close(force: true);
    await repository.flush();
    exit(0);
  }

  ProcessSignal.sigint.watch().listen(shutdown);
  if (!Platform.isWindows) ProcessSignal.sigterm.watch().listen(shutdown);
}
