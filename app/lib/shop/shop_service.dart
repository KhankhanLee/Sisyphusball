import 'package:sisyphus_core/sisyphus_core.dart';

import '../data/api_client.dart';
import '../models/look_model.dart';
import '../payments/payment.dart';

/// The shop: puts looks on and buys skins with Pi. The server checks every
/// payment again before a skin is delivered.
class ShopService {
  ShopService(this._api, this._pay, this.model);

  final ApiClient _api;
  final PayWithPi _pay;
  final LookModel model;

  /// Loads what the signed-in player wears and owns. Never throws.
  Future<void> load() async {
    try {
      model.apply(await _api.get('/api/me/look'));
    } catch (_) {
      // keeps the standard look
    }
  }

  /// Puts on [skin] (free or owned). Throws an [ApiException] otherwise.
  Future<void> wear(Skin skin) async =>
      model.apply(await _api.post('/api/me/look', {'character': skin.characterId, 'skin': skin.id}));

  /// Buys [skin] for its price in Pi; it is worn once bought.
  Future<PaymentOutcome> buy(Skin skin) async {
    model.setBuying(skin.id);
    try {
      final outcome = await _pay(
        PaymentRequest(amount: skin.price, memo: 'Skin: ${skin.name}', metadata: {'kind': 'skin', 'skin': skin.id}),
        approve: (id) => _api.post('/api/payments/approve', {'paymentId': id}),
        complete: (id, txid) async =>
            model.apply(await _api.post('/api/payments/complete', {'paymentId': id, 'txid': txid})),
      );
      if (outcome != PaymentOutcome.completed) await load();
      return outcome;
    } finally {
      model.setBuying(null);
    }
  }
}
