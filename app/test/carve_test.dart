import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sisyphusball/data/api_client.dart';
import 'package:sisyphusball/data/models.dart';
import 'package:sisyphusball/events.dart';
import 'package:sisyphusball/models/carvings_model.dart';
import 'package:sisyphusball/models/leaderboard_model.dart';
import 'package:sisyphusball/models/player_model.dart';
import 'package:sisyphusball/models/presence_model.dart';
import 'package:sisyphusball/models/scene_overlay_model.dart';
import 'package:sisyphusball/payments/carve_service.dart';
import 'package:sisyphusball/payments/payment.dart';
import 'package:sisyphusball/ui/screens/solo_result_screen.dart';

void main() {
  late List<String> calls;
  late ApiClient api;

  setUp(() {
    calls = [];
    api = ApiClient(
      client: MockClient((req) async {
        calls.add('${req.url.path} ${jsonEncode(jsonDecode(req.body))}');
        return http.Response('{"ok":true}', 200);
      }),
    );
  });

  test('carve asks Pi for the payment and lets the server approve and complete it', () async {
    PaymentRequest? asked;
    final service = CarveService(api, (request, {required approve, required complete}) async {
      asked = request;
      await approve('pay-1');
      await complete('pay-1', 'tx-1');
      return PaymentOutcome.completed;
    });

    final outcome = await service.carve(text: '  Still pushing. ', height: 42, price: 1);

    expect(outcome, PaymentOutcome.completed);
    expect(asked!.amount, 1);
    expect(asked!.metadata, {'kind': 'carve', 'text': 'Still pushing.', 'height': 42});
    expect(calls, [
      '/api/payments/approve {"paymentId":"pay-1"}',
      '/api/payments/complete {"paymentId":"pay-1","txid":"tx-1"}',
    ]);
  });

  test('an unfinished payment found at sign-in is completed only once it has a transaction', () async {
    final service = CarveService(api, (r, {required approve, required complete}) async => PaymentOutcome.failed);
    await service.settle(null);
    await service.settle(const PendingPayment('p', null));
    expect(calls, isEmpty);
    await service.settle(const PendingPayment('p', 'tx'));
    expect(calls.single, '/api/payments/complete {"paymentId":"p","txid":"tx"}');
  });

  test('carvings from the live feed are drawn on the mountain', () {
    final carvings = CarvingsModel()
      ..onEvent(const CarvingsUpdated([Carving(username: 'alice', height: 20, text: 'Still pushing.')]));
    final overlay = SceneOverlayModel(
      player: PlayerModel(),
      leaderboard: LeaderboardModel(),
      presence: PresenceModel(),
      carvings: carvings,
    );
    final e = overlay.engravings.single;
    expect((e.height, e.text, e.author), (20.0, 'Still pushing.', 'alice'));
  });

  group('result screen', () {
    Widget screen({double? price, RunResult? result, bool carved = false, int score = 12}) => MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SoloResultScreen(
                score: score,
                result: result,
                standing: const Standing(best: 12, rank: 1, runs: 1, totalMeters: 12),
                players: 1,
                refrain: '',
                onAgain: () {},
                onHallOfFame: () {},
                onHome: () {},
                carvePrice: price,
                carved: carved,
                onCarve: () {},
              ),
            ),
          ),
        );
    const recorded = RunResult(score: 12, isBest: true);

    testWidgets('offers carving once the climb is recorded and payments are on', (tester) async {
      await tester.pumpWidget(screen(price: 1, result: recorded));
      expect(find.textContaining('Carve the Mountain'), findsOneWidget);
    });

    testWidgets('hides it without payments, before recording, or for 0m', (tester) async {
      await tester.pumpWidget(screen(price: null, result: recorded));
      expect(find.textContaining('Carve the Mountain'), findsNothing);
      await tester.pumpWidget(screen(price: 1, result: null));
      expect(find.textContaining('Carve the Mountain'), findsNothing);
      await tester.pumpWidget(screen(price: 1, result: recorded, score: 0));
      expect(find.textContaining('Carve the Mountain'), findsNothing);
    });

    testWidgets('says so once carved', (tester) async {
      await tester.pumpWidget(screen(price: 1, result: recorded, carved: true));
      expect(find.textContaining('Carve the Mountain'), findsNothing);
      expect(find.text('Your words are on the mountain.'), findsOneWidget);
    });
  });
}
