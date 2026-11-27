import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sisyphus_core/sisyphus_core.dart';
import 'package:sisyphusball/data/api_client.dart';
import 'package:sisyphusball/models/look_model.dart';
import 'package:sisyphusball/payments/payment.dart';
import 'package:sisyphusball/shop/shop_service.dart';
import 'package:sisyphusball/ui/screens/shop_screen.dart';
import 'package:sisyphusball/ui/widgets/portrait.dart';

void main() {
  final ember = skinById('her-lilac')!;

  test('buying a skin pays its price, lets the server deliver it, and wears it', () async {
    final calls = <String>[];
    final api = ApiClient(
      client: MockClient((req) async {
        calls.add('${req.method} ${req.url.path}');
        if (req.url.path == '/api/payments/complete') {
          return http.Response(
              jsonEncode({
                'look': {'character': 'her', 'skin': 'her-lilac'},
                'owned': ['her-lilac'],
              }),
              200);
        }
        return http.Response('{}', 200);
      }),
    );
    PaymentRequest? asked;
    final model = LookModel();
    final shop = ShopService(api, (request, {required approve, required complete}) async {
      asked = request;
      expect(model.buying, 'her-lilac', reason: 'shown as in progress while paying');
      await approve('p1');
      await complete('p1', 't1');
      return PaymentOutcome.completed;
    }, model);

    expect(await shop.buy(ember), PaymentOutcome.completed);
    expect(asked!.amount, 1);
    expect(asked!.metadata, {'kind': 'skin', 'skin': 'her-lilac'});
    expect(calls, ['POST /api/payments/approve', 'POST /api/payments/complete']);
    expect(model.look.skinId, 'her-lilac');
    expect(model.owns(ember), isTrue);
    expect(model.buying, isNull);
  });

  test('a cancelled purchase reloads the wardrobe and changes nothing', () async {
    final api = ApiClient(client: MockClient((req) async => http.Response(jsonEncode({'look': null, 'owned': []}), 200)));
    final model = LookModel();
    final shop = ShopService(api, (r, {required approve, required complete}) async => PaymentOutcome.cancelled, model);
    expect(await shop.buy(ember), PaymentOutcome.cancelled);
    expect(model.look.skinId, Look.standard.skinId);
    expect(model.owns(ember), isFalse);
  });

  Widget screen(LookModel looks, {void Function(Skin)? onBuy, void Function(Skin)? onWear}) => MaterialApp(
        home: Scaffold(
          body: ShopScreen(
            looks: looks,
            signedIn: true,
            onWear: onWear ?? (_) {},
            onBuy: onBuy ?? (_) {},
            onBack: () {},
          ),
        ),
      );

  testWidgets('shows both characters; buying is offered only when the shop is open', (tester) async {
    tester.view
      ..physicalSize = const Size(900, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final looks = LookModel();
    await tester.pumpWidget(screen(looks));
    expect(find.text('Sisyphus'), findsOneWidget);
    expect(find.text('Sisyphe'), findsOneWidget);
    expect(find.text('Wearing'), findsOneWidget); // Exile, free
    final buy = find.widgetWithText(FilledButton, '1π').first;
    expect(tester.widget<FilledButton>(buy).onPressed, isNull, reason: 'shop closed');

    final bought = <String>[];
    looks.setShopOpen(true);
    await tester.pumpWidget(screen(looks, onBuy: (s) => bought.add(s.id)));
    await tester.ensureVisible(find.widgetWithText(FilledButton, '1π').first);
    await tester.tap(find.widgetWithText(FilledButton, '1π').first);
    expect(bought, ['him-marble']);
  });

  testWidgets('owned skins can be worn; switching character shows its skins', (tester) async {
    tester.view
      ..physicalSize = const Size(900, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final looks = LookModel()
      ..apply({
        'look': {'character': 'him', 'skin': 'him-exile'},
        'owned': ['her-lilac'],
      });
    final worn = <String>[];
    await tester.pumpWidget(screen(looks, onWear: (s) => worn.add(s.id)));
    await tester.tap(find.text('Sisyphe'));
    await tester.pump();
    expect(find.text('A short reprieve. It never lasts.'), findsOneWidget);
    await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Wear').last);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Wear').last);
    expect(worn, ['her-lilac']);
  });

  testWidgets('Sisyphe has a portrait that follows the tapped skin', (tester) async {
    tester.view
      ..physicalSize = const Size(900, 2000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(screen(LookModel()));
    expect(find.byType(Portrait), findsNothing, reason: 'Sisyphus has no portrait yet');
    await tester.tap(find.text('Sisyphe'));
    await tester.pump();
    expect(tester.widget<Portrait>(find.byType(Portrait)).skinId, 'her-exile');
    await tester.tap(find.text('A short reprieve. It never lasts.'));
    await tester.pump();
    expect(tester.widget<Portrait>(find.byType(Portrait)).skinId, 'her-lilac');
  });
}
