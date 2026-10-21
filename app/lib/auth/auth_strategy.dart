import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';
import '../pi/pi_sdk.dart';

/// Strategy pattern: one way of proving who the player is. A strategy only
/// produces the credentials for `POST /api/auth`, or null when it cannot be
/// used here; [AuthService] tries them in order.
abstract interface class AuthStrategy {
  Future<Map<String, dynamic>?> credentials(ServerSettings settings);
}

/// Signs in with the Pi SDK. Only works inside the Pi Browser (or sandbox).
class PiAuthStrategy implements AuthStrategy {
  const PiAuthStrategy({this.timeout = const Duration(seconds: 10)});

  /// Outside the Pi Browser `Pi.authenticate` never settles.
  final Duration timeout;

  @override
  Future<Map<String, dynamic>?> credentials(ServerSettings settings) async {
    if (!piSdkLoaded) return null;
    try {
      final token = await piAuthenticate(sandbox: settings.sandbox).timeout(timeout);
      return {'accessToken': token};
    } catch (_) {
      return null;
    }
  }
}

/// Plays as a guest under a chosen name, when the server allows it.
class GuestAuthStrategy implements AuthStrategy {
  GuestAuthStrategy(this._askName);

  final Future<String?> Function() _askName;
  static const _prefsKey = 'guestName';

  @override
  Future<Map<String, dynamic>?> credentials(ServerSettings settings) async {
    if (!settings.allowGuests) return null;
    final prefs = await SharedPreferences.getInstance();
    var name = prefs.getString(_prefsKey) ?? '';
    if (name.isEmpty) {
      name = (await _askName())?.trim() ?? '';
      await prefs.setString(_prefsKey, name);
    }
    return {'guest': true, 'name': name};
  }
}
