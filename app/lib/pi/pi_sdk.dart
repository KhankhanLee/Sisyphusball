/// Pi Network SDK bridge. The real implementation talks to `window.Pi`
/// (loaded by web/index.html); other platforms get a stub that reports the
/// SDK as unavailable so the app falls back to guest play.
library;

export 'pi_sdk_stub.dart' if (dart.library.js_interop) 'pi_sdk_web.dart';
