import 'package:sisyphus_core/sisyphus_core.dart';

import '../copy.dart';
import '../data/api_client.dart';
import '../data/models.dart';
import '../events.dart';
import 'auth_strategy.dart';

/// Signs the player in with the first [AuthStrategy] that works here.
/// A [Subject]: announces [SignedIn] or [SignInFailed].
class AuthService with Subject<AppEvent> {
  AuthService(this._api, this._strategies);

  final ApiClient _api;
  final List<AuthStrategy> _strategies;

  Future<void> signIn(ServerSettings settings) async {
    try {
      for (final strategy in _strategies) {
        final credentials = await strategy.credentials(settings);
        if (credentials == null) continue;
        final res = await _api.post('/api/auth', credentials);
        _api.sessionToken = res['token'] as String;
        notify(SignedIn(
          Player.fromJson(res['user'] as Map<String, dynamic>),
          Standing.fromJson(res['standing'] as Map<String, dynamic>),
        ));
        return;
      }
      notify(const SignInFailed(Copy.openInPiBrowser));
    } catch (e) {
      fail('${Copy.signInFailed} $e');
    }
  }

  /// Sign-in could not even be attempted (e.g. the server is unreachable).
  void fail(String reason) => notify(SignInFailed(reason));
}
