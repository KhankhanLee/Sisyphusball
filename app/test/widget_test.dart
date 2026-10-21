import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sisyphusball/app_services.dart';
import 'package:sisyphusball/copy.dart';
import 'package:sisyphusball/game/game_controller.dart';
import 'package:sisyphusball/main.dart';
import 'package:sisyphusball/models/screen_model.dart';

AppServices offlineServices() => AppServices(askGuestName: () async => 'tester', authStrategies: const []);

Finder button(String label) => find.textContaining(label, findRichText: true);

void main() {
  testWidgets('title screen is in English and offers every mode', (tester) async {
    await tester.pumpWidget(MaterialApp(home: GameShell(services: offlineServices())));
    expect(find.textContaining('Sisyphus', findRichText: true), findsOneWidget);
    expect(button(Copy.playSolo), findsOneWidget);
    expect(button(Copy.playVersus), findsOneWidget);
    expect(button(Copy.hallOfFame), findsOneWidget);
    expect(find.text(Copy.tagline), findsOneWidget);
  });

  testWidgets('2P: holding the left half pushes only player 1', (tester) async {
    final s = offlineServices();
    await tester.pumpWidget(MaterialApp(home: GameShell(services: s)));
    await tester.tap(button(Copy.playVersus));
    await tester.pump();
    expect(s.game.mode, GameMode.versus);
    expect(s.screens.screen, Screen.versus, reason: 'navigation follows RunStarted');

    final size = tester.getSize(find.byType(GameShell));
    final finger = await tester.startGesture(Offset(size.width * 0.25, size.height / 2));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await finger.up();
    expect(s.game.lanes[0].climber.y, greaterThan(0));
    expect(s.game.lanes[1].climber.y, 0);
  });

  testWidgets('Hall of Fame opens and returns', (tester) async {
    final s = offlineServices();
    await tester.pumpWidget(MaterialApp(home: GameShell(services: s)));
    await tester.tap(button(Copy.hallOfFame));
    await tester.pump();
    expect(find.text(Copy.emptyBoard), findsOneWidget);
    await tester.tap(button(Copy.back));
    await tester.pump();
    expect(s.screens.screen, Screen.title);
  });
}
