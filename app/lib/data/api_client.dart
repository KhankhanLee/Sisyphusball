import 'dart:convert';

import 'package:http/http.dart' as http;

/// Server origin. Empty means "same origin as the page", which is how the
/// game is deployed; pass `--dart-define=API_BASE=http://localhost:8080`
/// when running the Flutter dev server separately.
const _apiBase = String.fromEnvironment('API_BASE');

Uri get serverBase {
  if (_apiBase.isNotEmpty) return Uri.parse(_apiBase);
  // Rebuilt from parts: WebSocket URLs must not carry even an empty fragment.
  final page = Uri.base;
  return Uri(scheme: page.scheme, host: page.host, port: page.port, path: '/');
}

class ApiException implements Exception {
  ApiException(this.status, this.message);

  final int status;
  final String message;

  @override
  String toString() => message;
}

/// JSON over HTTP, with the session token attached once signed in.
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? sessionToken;

  Future<Map<String, dynamic>> get(String path) => _send('GET', path);

  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) => _send('POST', path, body);

  Future<Map<String, dynamic>> _send(String method, String path, [Map<String, dynamic>? body]) async {
    final req = http.Request(method, serverBase.resolve(path))..headers['Content-Type'] = 'application/json';
    if (sessionToken != null) req.headers['Authorization'] = 'Bearer $sessionToken';
    if (body != null) req.body = jsonEncode(body);
    final res = await http.Response.fromStream(await _client.send(req));
    Map<String, dynamic> data;
    try {
      data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      data = {};
    }
    if (res.statusCode >= 400) {
      throw ApiException(res.statusCode, data['error'] as String? ?? 'HTTP ${res.statusCode}');
    }
    return data;
  }
}
