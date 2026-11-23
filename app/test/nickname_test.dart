import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sisyphusball/auth/auth_service.dart';
import 'package:sisyphusball/data/api_client.dart';
import 'package:sisyphusball/data/models.dart';
import 'package:sisyphusball/events.dart';
import 'package:sisyphusball/models/leaderboard_model.dart';
import 'package:sisyphusball/models/player_model.dart';
import 'package:sisyphusball/ui/screens/nickname_dialog.dart';
import 'package:sisyphusball/ui/screens/title_screen.dart';

void main() {
  test('a Pi player without a nickname is asked; choosing one updates the player', () async {
    final api = ApiClient(
      client: MockClient((req) async {
        expect(req.url.path, '/api/me/nickname');
        final name = (jsonDecode(req.body) as Map)['nickname'];
        if (name == 'taken') return http.Response('{"error":"That name is taken."}', 409);
        return http.Response(jsonEncode({'user': {'username': name, 'guest': false}, 'standing': {}}), 200);
      }),
    );
    final auth = AuthService(api, const []);
    final player = PlayerModel()..onEvent(const SignedIn(Player(username: 'pi_alice', needsNickname: true), Standing()));
    auth.attach(player);
    expect(player.needsNickname, isTrue);

    await expectLater(auth.setNickname('taken'), throwsA(isA<ApiException>()));
    expect(player.username, 'pi_alice');

    await auth.setNickname('Rock Pusher');
    expect(player.username, 'Rock Pusher');
    expect(player.needsNickname, isFalse);
  });

  test('guests are never asked', () {
    final player = PlayerModel()
      ..onEvent(const SignedIn(Player(username: 'g', guest: true, needsNickname: true), Standing()));
    expect(player.needsNickname, isFalse);
  });

  Widget title(PlayerModel player) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TitleScreen(
              player: player,
              leaderboard: LeaderboardModel(),
              onSolo: () {},
              onVersus: () {},
              onHallOfFame: () {},
              onOpenPage: (_) {},
              onChangeNickname: () {},
            ),
          ),
        ),
      );

  testWidgets('"Change name" appears only for Pi players when nicknames are on', (tester) async {
    final player = PlayerModel()..onEvent(const SignedIn(Player(username: 'Rock'), Standing()));
    await tester.pumpWidget(title(player));
    expect(find.text('Change name'), findsNothing);
    player.enableNicknames(true);
    await tester.pumpWidget(title(player));
    expect(find.text('Change name'), findsOneWidget);
  });

  testWidgets('the dialog shows the server\'s reason and stays open until a name is saved', (tester) async {
    late Future<bool> result;
    final tries = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => result = showNicknameDialog(context, required: true, save: (name) async {
            tries.add(name);
            return name == 'taken' ? 'That name is taken.' : null;
          }),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel'), findsNothing, reason: 'required: no way out');

    await tester.enterText(find.byType(TextField), 'taken');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('That name is taken.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), ' Rock ');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(tries, ['taken', 'Rock']);
    expect(await result, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
