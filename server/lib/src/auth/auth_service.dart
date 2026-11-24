import 'dart:convert';
import 'dart:math';

import '../http/http_error.dart';
import 'auth_strategy.dart';
import 'identity.dart';

/// Signs players in through the configured [AuthStrategy]s and keeps their
/// sessions. Sessions are bearer tokens (never cookies).
class AuthService {
  AuthService(this._strategies,
      {this.sessionTtl = const Duration(hours: 12), Random? random, Identity Function(Identity)? personalize})
      : _random = random ?? Random.secure(),
        _personalize = personalize ?? _same;

  static Identity _same(Identity who) => who;

  final List<AuthStrategy> _strategies;
  final Duration sessionTtl;
  final Random _random;

  /// Turns the proven identity into the one shown to others (nickname).
  final Identity Function(Identity) _personalize;
  final _sessions = <String, ({Identity identity, DateTime expires})>{};

  /// Returns a new session token for whoever [request] proves to be.
  Future<(String token, Identity identity)> signIn(Map<String, dynamic> request) async {
    final strategy = _strategies.where((s) => s.canHandle(request)).firstOrNull;
    if (strategy == null) throw HttpError(400, 'accessToken required');
    final identity = _personalize(await strategy.authenticate(request));
    final token = base64Url.encode(List.generate(24, (_) => _random.nextInt(256))).replaceAll('=', '');
    _sessions[token] = (identity: identity, expires: DateTime.now().add(sessionTtl));
    return (token, identity);
  }

  /// Shows [uid] as [username] in every live session from now on.
  void rename(String uid, String username) {
    for (final e in _sessions.entries.toList()) {
      final id = e.value.identity;
      if (id.uid == uid) {
        _sessions[e.key] = (identity: Identity(uid: uid, username: username, guest: id.guest), expires: e.value.expires);
      }
    }
  }

  /// The identity behind an `Authorization: Bearer <token>` header.
  Identity requireSession(String? authorizationHeader) {
    final header = authorizationHeader ?? '';
    final token = header.startsWith('Bearer ') ? header.substring(7) : '';
    final session = _sessions[token];
    if (session == null || session.expires.isBefore(DateTime.now())) {
      _sessions.remove(token);
      throw HttpError(401, 'not signed in');
    }
    return session.identity;
  }
}
