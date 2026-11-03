import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../http/http_error.dart';
import 'identity.dart';

/// Strategy pattern: each way of signing in is one strategy. [AuthService]
/// asks them in order and uses the first that can handle the request.
abstract interface class AuthStrategy {
  bool canHandle(Map<String, dynamic> request);

  Future<Identity> authenticate(Map<String, dynamic> request);
}

/// Looks up who a Pi access token belongs to.
typedef PiTokenVerifier = Future<Identity> Function(String accessToken);

/// `{"accessToken": "..."}` from `Pi.authenticate` on the client.
///
/// The token is checked with the Pi Platform API; the uid and username a
/// client claims are never trusted.
class PiAuthStrategy implements AuthStrategy {
  PiAuthStrategy(this._verify);

  /// Verifies tokens against `GET {apiBase}/v2/me`.
  factory PiAuthStrategy.platformApi({required String apiBase, http.Client? client}) {
    final c = client ?? http.Client();
    return PiAuthStrategy((token) async {
      final res = await c
          .get(Uri.parse('$apiBase/v2/me'), headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) throw StateError('Pi API rejected token (${res.statusCode})');
      final me = jsonDecode(res.body) as Map<String, dynamic>;
      final uid = me['uid'], username = me['username'];
      if (uid is! String || username is! String) throw StateError('Pi API returned no user');
      return Identity(uid: 'pi:$uid', username: username);
    });
  }

  final PiTokenVerifier _verify;

  @override
  bool canHandle(Map<String, dynamic> request) {
    final token = request['accessToken'];
    return token is String && token.isNotEmpty;
  }

  @override
  Future<Identity> authenticate(Map<String, dynamic> request) async {
    try {
      return await _verify(request['accessToken'] as String);
    } catch (_) {
      throw HttpError(401, 'Pi authentication failed');
    }
  }
}

/// `{"guest": true, "name": "..."}` — for playing outside the Pi Browser.
class GuestAuthStrategy implements AuthStrategy {
  GuestAuthStrategy({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  @override
  bool canHandle(Map<String, dynamic> request) => request['guest'] == true;

  @override
  Future<Identity> authenticate(Map<String, dynamic> request) async => Identity(
        uid: 'guest:${List.generate(12, (_) => _random.nextInt(36).toRadixString(36)).join()}',
        username: _sanitize(request['name']),
        guest: true,
      );

  String _sanitize(Object? name) {
    final clean = (name is String ? name : '')
        .replaceAll(RegExp(r'[^\p{L}\p{N}_\- ]', unicode: true), '')
        .trim();
    final short = String.fromCharCodes(clean.runes.take(16));
    return short.isNotEmpty ? short : 'Guest${_random.nextInt(9000) + 1000}';
  }
}
