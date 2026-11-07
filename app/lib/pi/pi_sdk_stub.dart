import '../payments/payment.dart';

export '../payments/payment.dart';

bool get piSdkLoaded => false;

Future<String> piAuthenticate({required bool sandbox}) =>
    Future.error(UnsupportedError('Pi SDK is only available on the web'));

Future<String> piShowInterstitial() async => 'ADS_NOT_SUPPORTED';

bool get piInSandboxFrame => false;

PendingPayment? takePendingPayment() => null;

Future<PaymentOutcome> piPay(
  PaymentRequest request, {
  required Future<void> Function(String paymentId) approve,
  required Future<void> Function(String paymentId, String txid) complete,
}) async =>
    PaymentOutcome.failed;
