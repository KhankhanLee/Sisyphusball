import 'dart:io';

import 'package:sisyphus_server/sisyphus_server.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('sisyphus-backup'));
  tearDown(() => dir.delete(recursive: true));

  Future<void> saveOnDay(JsonFileScoreRepository repo, int day) async {
    repo.save(PlayerRecord(uid: 'u', username: 'u', best: day));
    await repo.flush();
  }

  test('one backup per day, newest N kept', () async {
    var now = DateTime.utc(2026, 11, 1, 12);
    final repo = JsonFileScoreRepository('${dir.path}/scores.json', backupsToKeep: 3, clock: () => now);

    await saveOnDay(repo, 1);
    await saveOnDay(repo, 1); // same day: no second copy
    for (var day = 2; day <= 5; day++) {
      now = DateTime.utc(2026, 11, day, 12);
      await saveOnDay(repo, day);
    }

    final names = repo.backupDir.listSync().map((e) => e.uri.pathSegments.last).toList()..sort();
    expect(names, ['scores-2026-11-03.json', 'scores-2026-11-04.json', 'scores-2026-11-05.json']);
    final restored = JsonFileScoreRepository('${repo.backupDir.path}/scores-2026-11-03.json');
    await restored.load();
    expect(restored.find('u')!.best, 3, reason: 'a backup is a loadable ranking file');
  });

  test('backups can be turned off', () async {
    final repo = JsonFileScoreRepository('${dir.path}/scores.json', backupsToKeep: 0);
    await saveOnDay(repo, 1);
    expect(repo.backupDir.existsSync(), isFalse);
  });
}
