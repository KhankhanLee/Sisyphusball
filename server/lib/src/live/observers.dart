import 'dart:convert';
import 'dart:io';

import 'package:sisyphus_core/sisyphus_core.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../events.dart';

/// One connected browser. Observes every subject it is attached to and
/// forwards what the client cares about over its WebSocket.
class LiveClient implements Observer<ServerEvent> {
  LiveClient._(this._socket);

  /// Attaches a new client to all [subjects], sends it [initial] state, and
  /// detaches it again when the socket closes.
  static LiveClient connect(
    WebSocketChannel socket, {
    required List<Subject<ServerEvent>> subjects,
    List<ServerEvent> initial = const [],
  }) {
    final client = LiveClient._(socket);
    initial.forEach(client.onEvent);
    for (final s in subjects) {
      s.attach(client);
    }
    void detach() {
      for (final s in subjects) {
        s.detach(client);
      }
    }

    // Clients only listen; anything they send is ignored.
    socket.stream.listen((_) {}, onDone: detach, onError: (_) => detach());
    return client;
  }

  final WebSocketChannel _socket;

  @override
  void onEvent(ServerEvent event) {
    final message = switch (event) {
      LeaderboardChanged(:final leaderboard) => {'type': 'board', ...leaderboard.toJson()},
      PresenceChanged(:final presence) => {'type': 'live', ...presence.toJson()},
      PersonalBest() => null,
    };
    if (message != null) _socket.sink.add(jsonEncode(message));
  }
}

/// Writes notable moments to the server log.
class ActivityLog implements Observer<ServerEvent> {
  ActivityLog([IOSink? out]) : _out = out ?? stdout;

  final IOSink _out;

  @override
  void onEvent(ServerEvent event) {
    if (event case PersonalBest(:final username, :final score, :final rank)) {
      _out.writeln('[best] $username pushed to ${score}m (rank ${rank ?? '-'}). The stone is back at the bottom.');
    }
  }
}
