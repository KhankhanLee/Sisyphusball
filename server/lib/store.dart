import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// One player's record.
class PlayerRecord {
  PlayerRecord({
    required this.uid,
    required this.username,
    this.guest = false,
    this.best = 0,
    this.bestAt = 0,
    this.totalMeters = 0,
    this.runs = 0,
    this.lastAt = 0,
  });

  factory PlayerRecord.fromJson(Map<String, dynamic> j) => PlayerRecord(
        uid: j['uid'] as String,
        username: j['username'] as String,
        guest: j['guest'] as bool? ?? false,
        best: j['best'] as int? ?? 0,
        bestAt: j['bestAt'] as int? ?? 0,
        totalMeters: j['totalMeters'] as int? ?? 0,
        runs: j['runs'] as int? ?? 0,
        lastAt: j['lastAt'] as int? ?? 0,
      );

  final String uid;
  String username;
  bool guest;
  int best;
  int bestAt;
  int totalMeters;
  int runs;
  int lastAt;

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'username': username,
        'guest': guest,
        'best': best,
        'bestAt': bestAt,
        'totalMeters': totalMeters,
        'runs': runs,
        'lastAt': lastAt,
      };
}

class RunResult {
  RunResult(this.player, this.isBest, this.rank);

  final PlayerRecord player;
  final bool isBest;
  final int? rank;
}

/// Scoreboard state.
///
/// Dart runs request handlers on a single isolate and every mutation here is
/// synchronous, so concurrent requests never interleave mid-update. Writes to
/// disk are debounced and chained so overlapping saves cannot clobber each
/// other; each save goes to a temp file that is then renamed into place.
class Store {
  Store(this.file, {this.saveDelay = const Duration(milliseconds: 300)});

  final String? file;
  final Duration saveDelay;

  final Map<String, PlayerRecord> _players = {};
  int totalMeters = 0;
  int totalRuns = 0;
  List<PlayerRecord>? _sorted;
  Timer? _saveTimer;
  Future<void> _saving = Future.value();

  Future<void> load() async {
    final path = file;
    if (path == null) return;
    final f = File(path);
    if (!await f.exists()) return;
    final data = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    for (final j in (data['players'] as List? ?? const [])) {
      final p = PlayerRecord.fromJson(j as Map<String, dynamic>);
      _players[p.uid] = p;
    }
    totalMeters = data['totalMeters'] as int? ?? 0;
    totalRuns = data['totalRuns'] as int? ?? 0;
  }

  /// Records a finished climb and returns the player's updated standing.
  RunResult recordRun({
    required String uid,
    required String username,
    bool guest = false,
    required int score,
    int? at,
  }) {
    final now = at ?? DateTime.now().millisecondsSinceEpoch;
    final p = _players.putIfAbsent(
        uid, () => PlayerRecord(uid: uid, username: username, guest: guest));
    p
      ..username = username
      ..runs += 1
      ..totalMeters += score
      ..lastAt = now;
    final isBest = score > p.best;
    if (isBest) {
      p
        ..best = score
        ..bestAt = now;
    }
    // Names can change, so always rebuild the ranking.
    _sorted = null;
    totalMeters += score;
    totalRuns += 1;
    _scheduleSave();
    return RunResult(p, isBest, rankOf(uid));
  }

  List<PlayerRecord> get _ranking => _sorted ??= (_players.values
          .where((p) => p.best > 0)
          .toList()
        ..sort((a, b) {
          final byBest = b.best.compareTo(a.best);
          return byBest != 0 ? byBest : a.bestAt.compareTo(b.bestAt);
        }));

  int? rankOf(String uid) {
    final i = _ranking.indexWhere((p) => p.uid == uid);
    return i == -1 ? null : i + 1;
  }

  PlayerRecord? player(String uid) => _players[uid];

  List<Map<String, dynamic>> leaderboard([int limit = 50]) => [
        for (final (i, p) in _ranking.take(limit).indexed)
          {
            'rank': i + 1,
            'username': p.username,
            'guest': p.guest,
            'best': p.best,
            'runs': p.runs,
          }
      ];

  Map<String, dynamic> stats() => {
        'players': _players.length,
        'totalRuns': totalRuns,
        'totalMeters': totalMeters,
        // Every stone that was ever pushed is back at the bottom.
        'stonesAtSummit': 0,
      };

  void _scheduleSave() {
    if (file == null || _saveTimer != null) return;
    _saveTimer = Timer(saveDelay, () {
      _saveTimer = null;
      _saving = _saving.then((_) => _write()).catchError((Object e) {
        stderr.writeln('[store] save failed: $e');
      });
    });
  }

  Future<void> flush() async {
    if (_saveTimer != null) {
      _saveTimer!.cancel();
      _saveTimer = null;
      _saving = _saving.then((_) => _write());
    }
    await _saving;
  }

  Future<void> _write() async {
    final f = File(file!);
    await f.parent.create(recursive: true);
    final tmp = File('${f.path}.$pid.tmp');
    await tmp.writeAsString(jsonEncode({
      'players': [for (final p in _players.values) p.toJson()],
      'totalMeters': totalMeters,
      'totalRuns': totalRuns,
    }));
    await tmp.rename(f.path);
  }
}
