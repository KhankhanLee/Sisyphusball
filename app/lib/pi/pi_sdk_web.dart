import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import '../payments/payment.dart';
import 'pi_sandbox.dart';

export '../payments/payment.dart';

@JS('Pi')
external _Pi get _pi;

extension type _Pi._(JSObject _) implements JSObject {
  external void init(JSObject options);
  external JSPromise<_AuthResult> authenticate(
      JSArray<JSString> scopes, JSFunction onIncompletePaymentFound);
  @JS('Ads')
  external _Ads? get ads;
  external JSAny? createPayment(JSObject paymentData, JSObject callbacks);
}

extension type _Payment._(JSObject _) implements JSObject {
  external String get identifier;
  external _Transaction? get transaction;
}

extension type _Transaction._(JSObject _) implements JSObject {
  external String? get txid;
}

extension type _Ads._(JSObject _) implements JSObject {
  external JSPromise<_AdReady> isAdReady(String type);
  external JSPromise<_AdResult> requestAd(String type);
  external JSPromise<_AdResult> showAd(String type);
}

extension type _AdReady._(JSObject _) implements JSObject {
  external bool get ready;
}

extension type _AdResult._(JSObject _) implements JSObject {
  external String get result;
}

extension type _AuthResult._(JSObject _) implements JSObject {
  external String get accessToken;
}

bool get piSdkLoaded => globalContext.has('Pi');

@JS('document.referrer')
external String get _referrer;

/// True when the app runs inside the Pi Developer Portal's sandbox
/// (`https://sandbox.minepi.com`), which frames the development URL. The SDK
/// must then be initialised with `sandbox: true`, whatever the server says.
bool get piInSandboxFrame => isPiSandboxReferrer(_referrer);

bool _initialized = false;

/// Runs `Pi.authenticate(['username', 'payments'])` and returns the user's
/// access token. `payments` lets the app send A2U payments (Testnet tester
/// thanks, see deploy/azure/pay-testers.sh).
/// The token is sent to our server, which verifies it with the Pi Platform
/// API (`GET /v2/me`); the client never decides who the user is.
///
/// Outside the Pi Browser this promise never settles, so callers must apply
/// a timeout.
Future<String> piAuthenticate({required bool sandbox}) async {
  if (!piSdkLoaded) throw StateError('Pi SDK not loaded');
  if (!_initialized) {
    _pi.init({'version': '2.0', 'sandbox': sandbox}.jsify()! as JSObject);
    _initialized = true;
  }
  // A carving paid for but never completed (e.g. the app was closed): kept so
  // the app can finish it on the server once signed in.
  void onIncompletePaymentFound(_Payment payment) {
    _pending = PendingPayment(payment.identifier, payment.transaction?.txid);
  }
  final auth = await _pi
      .authenticate(['username'.toJS, 'payments'.toJS].toJS, onIncompletePaymentFound.toJS)
      .toDart;
  return auth.accessToken;
}

/// Shows a Pi Ad Network interstitial if one can be had, and returns the
/// SDK's result (`AD_CLOSED`, `AD_NOT_AVAILABLE`, `ADS_NOT_SUPPORTED`, ...).
///
/// Only after [piAuthenticate] has initialised the SDK; never throws.
Future<String> piShowInterstitial() async {
  const type = 'interstitial';
  try {
    final ads = _initialized ? _pi.ads : null;
    if (ads == null) return 'ADS_NOT_SUPPORTED';
    if (!(await ads.isAdReady(type).toDart).ready) {
      final loaded = (await ads.requestAd(type).toDart).result;
      if (loaded != 'AD_LOADED') return loaded;
    }
    return (await ads.showAd(type).toDart).result;
  } catch (e) {
    return 'AD_ERROR $e';
  }
}

PendingPayment? _pending;

/// The unfinished payment Pi reported at sign-in, once; null if none.
PendingPayment? takePendingPayment() {
  final p = _pending;
  _pending = null;
  return p;
}

/// `Pi.createPayment` with its four callbacks; see [PayWithPi].
Future<PaymentOutcome> piPay(
  PaymentRequest request, {
  required Future<void> Function(String paymentId) approve,
  required Future<void> Function(String paymentId, String txid) complete,
}) {
  final done = Completer<PaymentOutcome>();
  void finish(PaymentOutcome outcome) {
    if (!done.isCompleted) done.complete(outcome);
  }

  void onReadyForServerApproval(String paymentId) {
    approve(paymentId).catchError((Object _) => finish(PaymentOutcome.failed));
  }

  void onReadyForServerCompletion(String paymentId, String txid) {
    complete(paymentId, txid).then((_) => finish(PaymentOutcome.completed), onError: (Object _) => finish(PaymentOutcome.failed));
  }

  void onCancel(JSAny? _) => finish(PaymentOutcome.cancelled);
  void onError(JSAny? error, JSAny? payment) => finish(PaymentOutcome.failed);

  try {
    _pi.createPayment(
      {'amount': request.amount, 'memo': request.memo, 'metadata': request.metadata}.jsify()! as JSObject,
      JSObject()
        ..['onReadyForServerApproval'] = onReadyForServerApproval.toJS
        ..['onReadyForServerCompletion'] = onReadyForServerCompletion.toJS
        ..['onCancel'] = onCancel.toJS
        ..['onError'] = onError.toJS,
    );
  } catch (_) {
    finish(PaymentOutcome.failed);
  }
  return done.future;
}
