import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sisyphus_core/sisyphus_core.dart';
import 'package:sisyphusball/app_services.dart';
import 'package:sisyphusball/data/api_client.dart';
import 'package:sisyphusball/data/models.dart';
import 'package:sisyphusball/data/run_reporter.dart';
import 'package:sisyphusball/events.dart';
import 'package:sisyphusball/game/game_controller.dart';
import 'package:sisyphusball/models/screen_model.dart';

/// A fake server that accepts one run and records any score.
ApiClient fakeServer() => ApiClient(
      client: MockClient((req) async {
        final path = req.url.path;
        Map<String, dynamic> body = {'ok': true};
        if (path == '/api/runs') body = {'runId': 'abcdef1234567890', 'seed': 1};
        if (path.endsWith('/finish')) {
          body = {
            'isBest': true,
            'standing': {'best': 7, 'rank': 1, 'runs': 1, 'totalMeters': 7},
            'stats': {'players': 1, 'totalRuns': 1, 'totalMeters': 7},
          };
        }
        return http.Response(jsonEncode(body), 200);
      }),
    );

void main() {
  test('GameController announces a run from start to end', () {
    final game = GameController()..start(GameMode.versus);
    final events = <AppEvent>[];
    game.attach(CallbackObserver(events.add));
    for (final lane in game.lanes) {
      lane.climber
        ..y = 5
        ..state = ClimbState.falling;
    }
    for (var i = 0; i < 200 && events.whereType<RunEnded>().isEmpty; i++) {
      game.tick(1 / 60);
    }
    expect(events.whereType<RunEnded>().single.scores, hasLength(2));
    expect(game.mode, GameMode.idle);
  });

  test('RunReporter observes the game and announces registered/recorded runs', () async {
    final reporter = RunReporter(fakeServer(), currentHeight: () => 3);
    final events = <AppEvent>[];
    reporter.attach(CallbackObserver(events.add));

    reporter.onEvent(const RunStarted(GameMode.solo));
    reporter.onEvent(const RunEnded(GameMode.solo, [7]));
    await pumpEventQueue();

    expect(events.whereType<RunRegistered>().single.runId, 'abcdef1234567890');
    final result = events.whereType<RunRecorded>().single.result;
    expect(result.isBest, isTrue);
    expect(result.standing!.best, 7);
    reporter.dispose();
  });

  test('2P runs are never reported', () async {
    final reporter = RunReporter(fakeServer(), currentHeight: () => 0);
    final events = <AppEvent>[];
    reporter.attach(CallbackObserver(events.add));
    reporter.onEvent(const RunStarted(GameMode.versus));
    reporter.onEvent(const RunEnded(GameMode.versus, [1, 2]));
    await pumpEventQueue();
    expect(events, isEmpty);
  });

  test('wired n:m: one solo climb reaches every model that cares', () async {
    final s = AppServices(askGuestName: () async => null, authStrategies: const [], api: fakeServer());

    s.game.start(GameMode.solo);
    expect(s.screens.screen, Screen.solo);

    s.game.lanes.first.climber
      ..y = 7.2
      ..max = 7.2
      ..score = 7
      ..state = ClimbState.falling;
    for (var i = 0; i < 200 && s.screens.screen == Screen.solo; i++) {
      s.game.tick(1 / 60);
    }
    await pumpEventQueue();

    expect(s.screens.screen, Screen.soloResult); // GameController → ScreenModel
    expect(s.screens.lastResult!.score, 7); // RunReporter → ScreenModel
    expect(s.player.standing.rank, 1); // RunReporter → PlayerModel
    expect(s.leaderboard.stats.totalMeters, 7); // RunReporter → LeaderboardModel
    s.presence.onEvent(const PresenceUpdated([LiveClimber(id: 'abcdef12', name: 'me', height: 3)], 1));
    expect(s.presence.others, isEmpty, reason: 'RunReporter → PresenceModel: my own run is not a ghost');

    // LiveFeed → LeaderboardModel and PresenceModel
    s.feed.notify(const BoardUpdated([BoardEntry(rank: 1, username: 'camus', best: 9)], WorldStats(players: 2)));
    expect(s.leaderboard.leader!.username, 'camus');
    expect(s.overlay.markers.map((m) => m.label), contains('#1 camus'));
    s.dispose();
  });
}
