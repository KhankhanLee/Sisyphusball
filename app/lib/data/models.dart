/// Plain data received from the server.
library;

class ServerSettings {
  const ServerSettings({required this.sandbox, required this.allowGuests, required this.seed});

  ServerSettings.fromJson(Map<String, dynamic> j)
      : sandbox = j['sandbox'] as bool? ?? true,
        allowGuests = j['allowGuest'] as bool? ?? false,
        seed = j['seed'] as int;

  final bool sandbox;
  final bool allowGuests;
  final int seed;
}

class Player {
  const Player({required this.username, this.guest = false});

  Player.fromJson(Map<String, dynamic> j)
      : username = j['username'] as String,
        guest = j['guest'] as bool? ?? false;

  final String username;
  final bool guest;
}

class Standing {
  const Standing({this.best = 0, this.rank, this.runs = 0, this.totalMeters = 0});

  Standing.fromJson(Map<String, dynamic> j)
      : best = j['best'] as int? ?? 0,
        rank = j['rank'] as int?,
        runs = j['runs'] as int? ?? 0,
        totalMeters = j['totalMeters'] as int? ?? 0;

  final int best;
  final int? rank;
  final int runs;
  final int totalMeters;
}

class WorldStats {
  const WorldStats({this.players = 0, this.totalRuns = 0, this.totalMeters = 0});

  WorldStats.fromJson(Map<String, dynamic> j)
      : players = j['players'] as int? ?? 0,
        totalRuns = j['totalRuns'] as int? ?? 0,
        totalMeters = j['totalMeters'] as int? ?? 0;

  final int players;
  final int totalRuns;
  final int totalMeters;
}

class BoardEntry {
  const BoardEntry({required this.rank, required this.username, this.guest = false, required this.best, this.runs = 0});

  BoardEntry.fromJson(Map<String, dynamic> j)
      : rank = j['rank'] as int,
        username = j['username'] as String,
        guest = j['guest'] as bool? ?? false,
        best = j['best'] as int,
        runs = j['runs'] as int? ?? 0;

  final int rank;
  final String username;
  final bool guest;
  final int best;
  final int runs;
}

class LiveClimber {
  const LiveClimber({required this.id, required this.name, required this.height});

  LiveClimber.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        name = j['name'] as String,
        height = j['height'] as int;

  /// Short prefix of the run id; lets a client recognise its own run.
  final String id;
  final String name;
  final int height;
}

/// What became of one finished solo climb.
class RunResult {
  const RunResult({required this.score, this.isBest = false, this.standing, this.stats, this.error});

  final int score;
  final bool isBest;
  final Standing? standing;
  final WorldStats? stats;

  /// Set when the climb could not be recorded.
  final String? error;
}
