import 'package:sisyphus_core/sisyphus_core.dart';

import '../auth/identity.dart';
import '../events.dart';
import '../http/http_error.dart';
import '../payments/payment_desk.dart';
import 'carving.dart';
import 'carving_store.dart';

/// "Carve the Mountain": a player pays [price] π (a Pi user-to-app payment,
/// see [PaymentDesk]) to leave a short text at a height they have reached.
/// A [Subject]: every new carving announces [CarvingsChanged]. Carvings
/// never touch scores.
class CarvingService with Subject<ServerEvent> implements Purchasable {
  CarvingService(this._store, {required this.price, required this.bestOf});

  final CarvingStore _store;
  final double price;

  /// The player's best height; a carving may not sit above it.
  final int Function(String uid) bestOf;

  List<Carving> get carvings => _store.all;

  @override
  String get kind => 'carve';

  @override
  bool fulfilled(String paymentId) => _store.has(paymentId);

  @override
  Object order(Identity who, num amount, Map<String, dynamic> meta) {
    if (!samePrice(amount, price)) throw HttpError(400, 'wrong amount');
    final text = cleanCarvingText(meta['text']);
    if (text == null) throw HttpError(400, 'carvings are 1–$maxCarvingLength characters, without links');
    final height = meta['height'];
    if (height is! int || height < 1 || height > bestOf(who.uid)) throw HttpError(400, 'you have not climbed that high');
    return (height: height, text: text);
  }

  @override
  Future<Map<String, dynamic>> fulfill(Identity who, String paymentId, Object order) async {
    final o = order as ({int height, String text});
    final carving = Carving(
      id: paymentId,
      username: who.username,
      height: o.height,
      text: o.text,
      at: DateTime.now().millisecondsSinceEpoch,
    );
    await _store.add(carving);
    notify(CarvingsChanged(carvings));
    return {'carving': carving.toPublicJson()};
  }
}
