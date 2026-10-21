import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'score_models.dart';

/// Repository pattern: where player records live is hidden behind this
/// interface, so the service never knows about files or databases.
abstract interface class ScoreRepository {
  Iterable<PlayerRecord> get players;

  WorldTotals get totals;

  PlayerRecord? find(String uid);

  /// Stores [player] (new or changed) and the updated [totals].
  void save(PlayerRecord player);

  Future<void> load();

  /// Waits until everything saved so far is durable.
  Future<void> flush();
}

class InMemoryScoreRepository implements ScoreRepository {
  final Map<String, PlayerRecord> _players = {};

  @override
  final WorldTotals totals = WorldTotals();

  @override
  Iterable<PlayerRecord> get players => _players.values;

  @override
  PlayerRecord? find(String uid) => _players[uid];

  @override
  void save(PlayerRecord player) {
    _players[player.uid] = player;
    totals.players = _players.length;
  }

  @override
  Future<void> load() async {}

  @override
  Future<void> flush() async {}
}

/// Keeps everything in memory and mirrors it to one JSON file.
///
/// Writes are debounced and chained one after another, and each goes to a
/// temp file that is then renamed into place — overlapping saves can never
/// leave a half-written file behind.
class JsonFileScoreRepository extends InMemoryScoreRepository {
  JsonFileScoreRepository(this.path, {this.debounce = const Duration(milliseconds: 300)});

  final String path;
  final Duration debounce;
  Timer? _pending;
  Future<void> _writing = Future.value();

  @override
  Future<void> load() async {
    final file = File(path);
    if (!await file.exists()) return;
    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    for (final j in (data['players'] as List? ?? const [])) {
      super.save(PlayerRecord.fromJson(j as Map<String, dynamic>));
    }
    totals
      ..runs = data['totalRuns'] as int? ?? 0
      ..meters = data['totalMeters'] as int? ?? 0;
  }

  @override
  void save(PlayerRecord player) {
    super.save(player);
    _pending ??= Timer(debounce, () {
      _pending = null;
      _enqueueWrite();
    });
  }

  @override
  Future<void> flush() async {
    if (_pending != null) {
      _pending!.cancel();
      _pending = null;
      _enqueueWrite();
    }
    await _writing;
  }

  void _enqueueWrite() {
    _writing = _writing.then((_) => _write()).catchError((Object e) {
      stderr.writeln('[scores] save failed: $e');
    });
  }

  Future<void> _write() async {
    final file = File(path);
    await file.parent.create(recursive: true);
    final tmp = File('$path.$pid.tmp');
    await tmp.writeAsString(jsonEncode({
      'players': [for (final p in players) p.toJson()],
      'totalRuns': totals.runs,
      'totalMeters': totals.meters,
    }));
    await tmp.rename(path);
  }
}
