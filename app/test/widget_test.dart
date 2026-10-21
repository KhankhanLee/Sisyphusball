import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sisyphus_core/sisyphus_core.dart';
import 'package:sisyphusball/app_state.dart';
import 'package:sisyphusball/game/game_controller.dart';
import 'package:sisyphusball/main.dart';

void main() {
  testWidgets('title screen offers solo, 2P and the leaderboard', (tester) async {
    final game = GameController();
    await tester.pumpWidget(MaterialApp(home: GameShell(app: AppState(game))));
    expect(find.textContaining('Sisyphus', findRichText: true), findsOneWidget);
    expect(find.textContaining('둘이서 밀기', findRichText: true), findsOneWidget);
    expect(find.textContaining('명예의 전당', findRichText: true), findsOneWidget);
  });

  testWidgets('2P: holding each half of the screen pushes that stone', (tester) async {
    final game = GameController();
    await tester.pumpWidget(MaterialApp(home: GameShell(app: AppState(game))));
    await tester.tap(find.textContaining('둘이서 밀기', findRichText: true));
    await tester.pump();
    expect(game.mode, GameMode.versus);
    expect(game.lanes, hasLength(2));

    final size = tester.getSize(find.byType(GameShell));
    final p1 = await tester.startGesture(Offset(size.width * 0.25, size.height / 2));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await p1.up();
    expect(game.lanes[0].climber.y, greaterThan(0));
    expect(game.lanes[1].climber.y, 0, reason: 'player 2 did not push');
  });

  test('controller reports when every stone is back at the bottom', () {
    final game = GameController()..start(GameMode.versus, defaultSeed);
    List<int>? result;
    game.onAllOver = (s) => result = s;
    for (final l in game.lanes) {
      l.climber
        ..y = 5
        ..state = ClimbState.falling;
    }
    for (var i = 0; i < 200 && result == null; i++) {
      game.tick(1 / 60);
    }
    expect(result, isNotNull);
    expect(game.mode, GameMode.idle);
  });
}
