import 'package:sisyphus_core/sisyphus_core.dart';

import '../auth/identity.dart';
import '../http/http_error.dart';
import '../payments/payment_desk.dart';
import 'look_store.dart';

/// Characters and skins: who wears what, and the shop. Both characters and
/// their first skin are free; other skins are bought for Pi through the
/// [PaymentDesk]. Looks are cosmetic and never touch scores.
class LookService implements Purchasable {
  LookService(this._store);

  final LookStore _store;

  @override
  String get kind => 'skin';

  /// What [uid] wears now.
  Look lookOf(String uid) {
    final w = _store.of(uid);
    final look = Look.fromJson({'character': w.character, 'skin': w.skin});
    return _wearable(uid, look.skin) ? look : Look.standard;
  }

  /// Everything the client needs: what is worn and what is owned.
  Map<String, dynamic> stateOf(String uid) =>
      {'look': lookOf(uid).toJson(), 'owned': _store.of(uid).owned.toList()..sort()};

  /// Puts on [character] in [skin]; the skin must be free or owned.
  Future<Map<String, dynamic>> equip(Identity who, Object? character, Object? skinId) async {
    final skin = skinId is String ? skinById(skinId) : null;
    if (character is! String || skin == null || skin.characterId != character) {
      throw HttpError(400, 'no such look');
    }
    if (!_wearable(who.uid, skin)) throw HttpError(402, 'buy this skin first');
    final w = _store.of(who.uid)
      ..character = character
      ..skin = skin.id;
    await _store.save(who.uid, w);
    return stateOf(who.uid);
  }

  bool _wearable(String uid, Skin skin) => skin.free || _store.of(uid).owned.contains(skin.id);

  @override
  bool fulfilled(String paymentId) => _store.delivered(paymentId);

  @override
  Object order(Identity who, num amount, Map<String, dynamic> meta) {
    final id = meta['skin'];
    final skin = id is String ? skinById(id) : null;
    if (skin == null || skin.free) throw HttpError(400, 'no such skin for sale');
    if (!samePrice(amount, skin.price)) throw HttpError(400, 'wrong amount');
    if (_store.of(who.uid).owned.contains(skin.id)) throw HttpError(409, 'you already own this skin');
    return skin;
  }

  /// Adds the skin to the wardrobe and puts it on.
  @override
  Future<Map<String, dynamic>> fulfill(Identity who, String paymentId, Object order) async {
    final skin = order as Skin;
    final w = _store.of(who.uid)
      ..owned.add(skin.id)
      ..character = skin.characterId
      ..skin = skin.id;
    await _store.save(who.uid, w, paymentId: paymentId);
    return stateOf(who.uid);
  }
}
