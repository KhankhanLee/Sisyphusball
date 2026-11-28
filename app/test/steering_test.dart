import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sisyphus_core/sisyphus_core.dart';
import 'package:sisyphusball/game/game_controller.dart';
import 'package:sisyphusball/game/game_view.dart';
import 'package:sisyphusball/game/scene.dart';

class _NoOverlay implements SceneOverlay {
  @override
  List<Ghost> get ghosts => const [];
  @override
  List<Marker> get markers => const [];
  @override
  List<Engraving> get engravings => const [];
  @override
  Look get look => Look.standard;
  @override
  get sprite => null;
}

void main() {
  test('steering only works during a run, and moves at most maxSide', () {
    final game = GameController();
    game.steerBy(0, -0.3);
    expect(game.lanes.first.climber.targetX, 0.5, reason: 'idle title screen');

    game.start(GameMode.solo);
    game.steerBy(0, -0.3);
    game.tick(0.05);
    final c = game.lanes.first.climber;
    expect(c.targetX, closeTo(0.2, 1e-9));
    expect(0.5 - c.x, closeTo(Phys.maxSide / laneWidth * 0.05, 1e-9));
  });

  Future<GameController> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(400, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = GameController()..start(GameMode.solo);
    await tester.pumpWidget(MaterialApp(home: GameView(game: game, overlay: _NoOverlay())));
    return game;
  }

  testWidgets('hold and slide left: the stone climbs and steers left', (tester) async {
    final game = await pump(tester);
    final gesture = await tester.startGesture(const Offset(200, 500));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(-120, 0));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final c = game.lanes.first.climber;
    expect(c.y, greaterThan(0), reason: 'still pushing up');
    expect(c.targetX, lessThan(0.5));
    expect(c.x, lessThan(0.5));
    await gesture.up();
  });

  testWidgets('arrow keys steer while held', (tester) async {
    final game = await pump(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final c = game.lanes.first.climber;
    expect(c.x, greaterThan(0.5));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.lanes.first.steering, 0);
  });
}
