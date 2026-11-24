import '../auth/identity.dart';
import '../http/http_error.dart';
import 'pi_payments.dart';

/// Something the app sells for Pi. `metadata.kind` of a payment says which.
abstract interface class Purchasable {
  String get kind;

  /// Checks what [who] is buying with [payment] (its amount and metadata)
  /// and returns the order to [fulfill]; throws an [HttpError] if it is not
  /// for sale to them like this.
  Object order(Identity who, num amount, Map<String, dynamic> metadata);

  /// Whether the payment with this id has already been fulfilled.
  bool fulfilled(String paymentId);

  /// Delivers [order]; returns what the client should learn about it.
  Future<Map<String, dynamic>> fulfill(Identity who, String paymentId, Object order);
}

/// The Pi user-to-app payment flow for everything the app sells.
///
/// It never trusts the client: before approving, and again before
/// completing, it reads the payment back from Pi and checks who pays, that it
/// goes to the app and is not cancelled, and then lets the matching
/// [Purchasable] check the amount and what is bought.
class PaymentDesk {
  PaymentDesk(this._pi, List<Purchasable> items) : _items = {for (final i in items) i.kind: i};

  final PiPayments? _pi;
  final Map<String, Purchasable> _items;

  bool get enabled => _pi != null;

  /// Step 1 (`onReadyForServerApproval`): check the payment, then approve it.
  Future<void> approve(Identity who, String paymentId) async {
    final pi = _requirePi();
    _check(who, await pi.get(paymentId));
    await pi.approve(paymentId);
  }

  /// Step 2 (`onReadyForServerCompletion`, or an incomplete payment found at
  /// sign-in): check the payment and its transaction, complete it, deliver.
  /// Safe to call twice.
  Future<Map<String, dynamic>> complete(Identity who, String paymentId, String txid) async {
    final pi = _requirePi();
    if (_items.values.any((i) => i.fulfilled(paymentId))) return {};
    final payment = await pi.get(paymentId);
    final (item, order) = _check(who, payment);
    final tx = payment['transaction'];
    if (tx is! Map || tx['txid'] != txid) throw HttpError(409, 'payment has no matching transaction');
    await pi.complete(paymentId, txid);
    return item.fulfill(who, paymentId, order);
  }

  PiPayments _requirePi() => _pi ?? (throw HttpError(503, 'payments are not set up'));

  (Purchasable, Object) _check(Identity who, Map<String, dynamic> p) {
    if (who.guest || !who.uid.startsWith('pi:')) throw HttpError(403, 'sign in with Pi to pay');
    if (p['user_uid'] != who.uid.substring(3)) throw HttpError(403, 'not your payment');
    if (p['direction'] != null && p['direction'] != 'user_to_app') throw HttpError(400, 'not a payment to the app');
    final status = p['status'];
    if (status is Map && (status['cancelled'] == true || status['user_cancelled'] == true)) {
      throw HttpError(409, 'payment was cancelled');
    }
    final amount = p['amount'];
    if (amount is! num) throw HttpError(400, 'wrong amount');
    final meta = p['metadata'];
    final item = meta is Map ? _items[meta['kind']] : null;
    if (item == null) throw HttpError(400, 'not something this app sells');
    return (item, item.order(who, amount, Map<String, dynamic>.from(meta as Map)));
  }
}

/// Whether [amount] is [price], allowing for floating point.
bool samePrice(num amount, num price) => (amount - price).abs() < 1e-9;
