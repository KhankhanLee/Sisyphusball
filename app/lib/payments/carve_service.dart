import '../data/api_client.dart';
import 'payment.dart';

/// The longest carving the server accepts.
const maxCarvingLength = 40;

/// "Carve the Mountain": pays for a carving through Pi and lets the server
/// approve and complete it. The server checks everything again; this class
/// only drives the flow.
class CarveService {
  CarveService(this._api, this._pay);

  final ApiClient _api;
  final PayWithPi _pay;

  Future<PaymentOutcome> carve({required String text, required int height, required double price}) => _pay(
        PaymentRequest(
          amount: price,
          memo: 'Carve the Mountain at ${height}m',
          metadata: {'kind': 'carve', 'text': text.trim(), 'height': height},
        ),
        approve: (id) => _api.post('/api/payments/approve', {'paymentId': id}),
        complete: (id, txid) => _api.post('/api/payments/complete', {'paymentId': id, 'txid': txid}),
      );

  /// Finishes a payment Pi reported as unfinished at sign-in, if it already
  /// reached the blockchain. Never throws.
  Future<void> settle(PendingPayment? pending) async {
    final txid = pending?.txid;
    if (pending == null || txid == null) return;
    try {
      await _api.post('/api/payments/complete', {'paymentId': pending.id, 'txid': txid});
    } catch (_) {
      // the server will see it again at the next sign-in
    }
  }
}
