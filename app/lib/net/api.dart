import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

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

class Api {
  Api({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? token;

  Future<Map<String, dynamic>> get(String path) => _send('GET', path);

  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) =>
      _send('POST', path, body);

  Future<Map<String, dynamic>> _send(String method, String path, [Map<String, dynamic>? body]) async {
    final req = http.Request(method, serverBase.resolve(path))
      ..headers['Content-Type'] = 'application/json';
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
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

/// The server's WebSocket feed: leaderboard updates and who is climbing now.
/// Reconnects on its own when the connection drops.
class LiveFeed {
  LiveFeed({required this.onBoard, required this.onLive});

  final void Function(Map<String, dynamic>) onBoard;
  final void Function(Map<String, dynamic>) onLive;

  WebSocketChannel? _ws;
  StreamSubscription<dynamic>? _sub;
  Timer? _retry;
  bool _closed = false;

  void connect() {
    if (_closed) return;
    final base = serverBase;
    final uri = base.replace(scheme: base.scheme == 'https' ? 'wss' : 'ws', path: '/ws');
    final WebSocketChannel ws;
    try {
      ws = WebSocketChannel.connect(uri);
    } catch (_) {
      _scheduleRetry();
      return;
    }
    _ws = ws;
    ws.ready.ignore(); // failures also surface on the stream, handled below
    _sub = ws.stream.listen(
      (raw) {
        final msg = jsonDecode(raw as String) as Map<String, dynamic>;
        switch (msg['type']) {
          case 'board':
            onBoard(msg);
          case 'live':
            onLive(msg);
        }
      },
      onDone: _scheduleRetry,
      onError: (_) => _scheduleRetry(),
      cancelOnError: true,
    );
  }

  void _scheduleRetry() {
    if (_closed) return;
    _retry?.cancel();
    _retry = Timer(const Duration(seconds: 3), connect);
  }

  void close() {
    _closed = true;
    _retry?.cancel();
    _sub?.cancel();
    _ws?.sink.close();
  }
}
