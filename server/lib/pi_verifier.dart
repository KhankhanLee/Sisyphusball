import 'dart:convert';

import 'package:http/http.dart' as http;

/// A verified Pi user.
class PiUser {
  const PiUser(this.uid, this.username);

  final String uid;
  final String username;
}

typedef VerifyPiToken = Future<PiUser> Function(String accessToken);

/// Verifies an access token from `Pi.authenticate` on the client by asking the
/// Pi Platform API who it belongs to. The uid/username a client claims is
/// never trusted; only what `/v2/me` returns is.
VerifyPiToken piVerifier({
  String apiBase = 'https://api.minepi.com',
  http.Client? client,
}) {
  final c = client ?? http.Client();
  return (accessToken) async {
    if (accessToken.length < 10) throw const FormatException('invalid access token');
    final res = await c
        .get(Uri.parse('$apiBase/v2/me'),
            headers: {'Authorization': 'Bearer $accessToken'})
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw StateError('Pi API rejected token (${res.statusCode})');
    }
    final me = jsonDecode(res.body) as Map<String, dynamic>;
    final uid = me['uid'], username = me['username'];
    if (uid is! String || username is! String) {
      throw StateError('Pi API returned no user');
    }
    return PiUser('pi:$uid', username);
  };
}
