import 'dart:async';
import 'dart:convert';

import 'package:sisyphus_core/sisyphus_core.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../events.dart';
import 'api_client.dart';
import 'models.dart';

/// The server's WebSocket feed as a [Subject]: announces [BoardUpdated]
/// after every finished climb anywhere, and [PresenceUpdated] as people
/// climb. Reconnects on its own when the connection drops.
class LiveFeed with Subject<AppEvent> {
  LiveFeed({this.retryDelay = const Duration(seconds: 3)});

  final Duration retryDelay;
  WebSocketChannel? _socket;
  StreamSubscription<dynamic>? _subscription;
  Timer? _retry;
  bool _closed = false;

  void connect() {
    if (_closed) return;
    final base = serverBase;
    final uri = base.replace(scheme: base.scheme == 'https' ? 'wss' : 'ws', path: '/ws');
    final WebSocketChannel socket;
    try {
      socket = WebSocketChannel.connect(uri);
    } catch (_) {
      _scheduleRetry();
      return;
    }
    _socket = socket;
    socket.ready.ignore(); // failures also arrive on the stream, handled below
    _subscription = socket.stream.listen(
      (raw) => _dispatch(jsonDecode(raw as String) as Map<String, dynamic>),
      onDone: _scheduleRetry,
      onError: (_) => _scheduleRetry(),
      cancelOnError: true,
    );
  }

  void _dispatch(Map<String, dynamic> msg) {
    switch (msg['type']) {
      case 'board':
        notify(BoardUpdated(
          [for (final e in msg['top'] as List) BoardEntry.fromJson(e as Map<String, dynamic>)],
          WorldStats.fromJson(msg['stats'] as Map<String, dynamic>),
        ));
      case 'live':
        notify(PresenceUpdated(
          [for (final c in msg['climbers'] as List) LiveClimber.fromJson(c as Map<String, dynamic>)],
          msg['count'] as int? ?? 0,
        ));
    }
  }

  void _scheduleRetry() {
    if (_closed) return;
    _retry?.cancel();
    _retry = Timer(retryDelay, connect);
  }

  void close() {
    _closed = true;
    _retry?.cancel();
    _subscription?.cancel();
    _socket?.sink.close();
    detachAll();
  }
}
