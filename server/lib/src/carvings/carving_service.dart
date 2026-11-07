import 'package:sisyphus_core/sisyphus_core.dart';

import '../auth/identity.dart';
import '../events.dart';
import '../http/http_error.dart';
import '../payments/pi_payments.dart';
import 'carving.dart';
import 'carving_store.dart';

/// "Carve the Mountain": a player pays [price] π (a Pi user-to-app payment)
/// to leave a short text at a height they have reached. A [Subject]: every
/// new carving announces [CarvingsChanged].
///
/// The server never trusts the client: before approving and again before
/// completing, it reads the payment back from Pi and checks who pays, how
/// much, and what it pays for. Carvings never touch scores.
class CarvingService with Subject<ServerEvent> {
  CarvingService(this._store, this._pi, {required this.price, required this.bestOf});

  final CarvingStore _store;
  final PiPayments? _pi;
  final double price;

  /// The player's best height; a carving may not sit above it.
  final int Function(String uid) bestOf;

  bool get enabled => _pi != null;

  List<Carving> get carvings => _store.all;

  /// Step 1 (`onReadyForServerApproval`): check the payment, then approve it.
  Future<void> approve(Identity who, String paymentId) async {
    final pi = _requirePi();
    _order(who, await pi.get(paymentId));
    await pi.approve(paymentId);
  }

  /// Step 2 (`onReadyForServerCompletion`, or an incomplete payment found
  /// at sign-in): check the payment and its transaction, complete it, and
  /// carve. Safe to call twice.
  Future<Carving?> complete(Identity who, String paymentId, String txid) async {
    final pi = _requirePi();
    if (_store.has(paymentId)) return _store.all.lastWhere((c) => c.id == paymentId);
    final payment = await pi.get(paymentId);
    final order = _order(who, payment);
    final tx = payment['transaction'];
    if (tx is! Map || tx['txid'] != txid) throw HttpError(409, 'payment has no matching transaction');
    await pi.complete(paymentId, txid);
    final carving = Carving(
      id: paymentId,
      username: who.username,
      height: order.height,
      text: order.text,
      at: DateTime.now().millisecondsSinceEpoch,
    );
    await _store.add(carving);
    notify(CarvingsChanged(carvings));
    return carving;
  }

  PiPayments _requirePi() => _pi ?? (throw HttpError(503, 'payments are not set up'));

  ({int height, String text}) _order(Identity who, Map<String, dynamic> p) {
    if (who.guest || !who.uid.startsWith('pi:')) throw HttpError(403, 'sign in with Pi to carve');
    if (p['user_uid'] != who.uid.substring(3)) throw HttpError(403, 'not your payment');
    if (p['direction'] != null && p['direction'] != 'user_to_app') throw HttpError(400, 'not a payment to the app');
    final amount = p['amount'];
    if (amount is! num || (amount - price).abs() > 1e-9) throw HttpError(400, 'wrong amount');
    final status = p['status'];
    if (status is Map && (status['cancelled'] == true || status['user_cancelled'] == true)) {
      throw HttpError(409, 'payment was cancelled');
    }
    final meta = p['metadata'];
    if (meta is! Map || meta['kind'] != 'carve') throw HttpError(400, 'not a carving');
    final text = cleanCarvingText(meta['text']);
    if (text == null) throw HttpError(400, 'carvings are 1–$maxCarvingLength characters, without links');
    final height = meta['height'];
    if (height is! int || height < 1 || height > bestOf(who.uid)) throw HttpError(400, 'you have not climbed that high');
    return (height: height, text: text);
  }
}
