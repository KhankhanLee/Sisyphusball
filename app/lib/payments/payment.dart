/// A Pi payment the player is asked to make, as passed to `Pi.createPayment`.
class PaymentRequest {
  const PaymentRequest({required this.amount, required this.memo, required this.metadata});

  final double amount;
  final String memo;
  final Map<String, Object?> metadata;
}

/// A payment the Pi SDK reported as left unfinished (seen at sign-in).
class PendingPayment {
  const PendingPayment(this.id, this.txid);

  final String id;
  final String? txid;
}

/// How a payment flow ended.
enum PaymentOutcome { completed, cancelled, failed }

/// Runs the Pi payment flow: shows the Pi wallet, calls [approve] when Pi is
/// ready for the server's approval and [complete] once the transaction is on
/// the blockchain. Completes when the flow ends.
typedef PayWithPi = Future<PaymentOutcome> Function(
  PaymentRequest request, {
  required Future<void> Function(String paymentId) approve,
  required Future<void> Function(String paymentId, String txid) complete,
});
