import 'package:sisyphus_core/sisyphus_core.dart';

/// One player's lifetime record.
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

/// Totals across every player and every climb.
class WorldTotals {
  WorldTotals({this.players = 0, this.runs = 0, this.meters = 0});

  int players;
  int runs;
  int meters;

  Map<String, dynamic> toJson() => {
        'players': players,
        'totalRuns': runs,
        'totalMeters': meters,
        // Every stone that was ever pushed is back at the bottom.
        'stonesAtSummit': 0,
      };
}

/// A player's place in the world, as shown to that player.
class Standing {
  const Standing({this.best = 0, this.rank, this.runs = 0, this.totalMeters = 0});

  final int best;
  final int? rank;
  final int runs;
  final int totalMeters;

  Map<String, dynamic> toJson() => {
        'best': best,
        'rank': rank,
        'runs': runs,
        'totalMeters': totalMeters,
        'tier': tierFor(best).name,
      };
}

/// The public scoreboard.
class Leaderboard {
  const Leaderboard(this.top, this.totals);

  final List<PlayerRecord> top; // already ranked, best first
  final WorldTotals totals;

  Map<String, dynamic> toJson() => {
        'top': [
          for (final (i, p) in top.indexed)
            {'rank': i + 1, 'username': p.username, 'guest': p.guest, 'best': p.best, 'runs': p.runs},
        ],
        'stats': totals.toJson(),
      };
}
