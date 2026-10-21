import 'package:sisyphus_core/sisyphus_core.dart';
import 'package:sisyphus_server/sisyphus_server.dart';
import 'package:test/test.dart';

void main() {
  const alice = Identity(uid: 'a', username: 'alice');

  test('ScoreService announces the board, and personal bests only when beaten', () {
    final scores = ScoreService(InMemoryScoreRepository());
    final events = <ServerEvent>[];
    scores.attach(CallbackObserver(events.add));

    scores.record(alice, 5);
    scores.record(alice, 3);

    expect(events.whereType<LeaderboardChanged>(), hasLength(2));
    expect(events.whereType<PersonalBest>().single.score, 5);
  });

  test('one observer can watch both subjects (n:m)', () async {
    final scores = ScoreService(InMemoryScoreRepository());
    final runs = RunRegistry(tick: const Duration(milliseconds: 10));
    final seen = <Type>{};
    final observer = CallbackObserver<ServerEvent>((e) => seen.add(e.runtimeType));
    scores.attach(observer);
    runs.attach(observer);

    final id = runs.start(alice);
    runs.progress(id, alice, 1);
    scores.record(alice, runs.finish(id, alice, 0));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(seen, containsAll([LeaderboardChanged, PresenceChanged]));
    runs.dispose();
  });

  test('maxReachableScore follows the stone\'s top speed', () {
    expect(maxReachableScore(Duration.zero), 3);
    expect(maxReachableScore(const Duration(seconds: 10)), (10 * maxPointsPerSecond * 1.15 + 3).floor());
  });
}
