import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'pi_sandbox.dart';

@JS('Pi')
external _Pi get _pi;

extension type _Pi._(JSObject _) implements JSObject {
  external void init(JSObject options);
  external JSPromise<_AuthResult> authenticate(
      JSArray<JSString> scopes, JSFunction onIncompletePaymentFound);
  @JS('Ads')
  external _Ads? get ads;
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
  // The game never asks players to pay; the SDK still requires the callback.
  void onIncompletePaymentFound(JSAny? payment) {}
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
