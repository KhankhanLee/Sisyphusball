import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('Pi')
external _Pi get _pi;

extension type _Pi._(JSObject _) implements JSObject {
  external void init(JSObject options);
  external JSPromise<_AuthResult> authenticate(
      JSArray<JSString> scopes, JSFunction onIncompletePaymentFound);
}

extension type _AuthResult._(JSObject _) implements JSObject {
  external String get accessToken;
}

bool get piSdkLoaded => globalContext.has('Pi');

bool _initialized = false;

/// Runs `Pi.authenticate(['username'])` and returns the user's access token.
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
  // This game has no payments, but the SDK requires the callback.
  void onIncompletePaymentFound(JSAny? payment) {}
  final auth = await _pi
      .authenticate(['username'.toJS].toJS, onIncompletePaymentFound.toJS)
      .toDart;
  return auth.accessToken;
}
