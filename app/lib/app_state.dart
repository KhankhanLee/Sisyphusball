import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sisyphus_core/sisyphus_core.dart';

import 'game/game_controller.dart';
import 'net/api.dart';
import 'pi/pi_sdk.dart';

class BoardEntry {
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

class RunResult {
  const RunResult({required this.score, this.isBest = false, this.error});

  final int score;
  final bool isBest;
  final String? error; // set when the score could not be recorded
}

enum AuthStatus { pending, signedIn, failed }

/// Everything that talks to the outside world: Pi sign-in, the server API,
/// and the live feed of other players.
class AppState extends ChangeNotifier {
  AppState(this.game, {Api? api}) : api = api ?? Api();

  final GameController game;
  final Api api;
  LiveFeed? _feed;

  AuthStatus auth = AuthStatus.pending;
  String? authError;
  String username = '';
  bool guest = false;
  bool sandbox = true;
  bool allowGuest = false;
  int seed = defaultSeed;

  Standing standing = const Standing();
  List<BoardEntry> board = const [];
  int players = 0, totalRuns = 0, totalMeters = 0;
  List<Map<String, dynamic>> liveClimbers = const [];
  int liveCount = 0;

  String? _runId;
  Timer? _progressTimer;
  RunResult? lastResult;

  Tier get tier => tierFor(standing.best);

  /// [askGuestName] is used outside the Pi Browser, when the server allows it.
  Future<void> init(Future<String?> Function() askGuestName) async {
    _feed = LiveFeed(onBoard: _onBoard, onLive: _onLive)..connect();
    try {
      final cfg = await api.get('/api/config');
      sandbox = cfg['sandbox'] as bool? ?? true;
      allowGuest = cfg['allowGuest'] as bool? ?? false;
      seed = cfg['seed'] as int? ?? defaultSeed;
      await _signIn(askGuestName);
      auth = AuthStatus.signedIn;
    } catch (e) {
      auth = AuthStatus.failed;
      authError = e.toString();
    }
    _updateMarkers();
    notifyListeners();
  }

  Future<void> _signIn(Future<String?> Function() askGuestName) async {
    if (piSdkLoaded) {
      try {
        // Outside the Pi Browser authenticate() never settles.
        final token = await piAuthenticate(sandbox: sandbox).timeout(const Duration(seconds: 10));
        _applyAuth(await api.post('/api/auth', {'accessToken': token}));
        return;
      } catch (e) {
        debugPrint('Pi sign-in unavailable: $e');
      }
    }
    if (!allowGuest) throw StateError('Pi Browser에서 열어 주세요.');
    final prefs = await SharedPreferences.getInstance();
    var name = prefs.getString('guestName');
    if (name == null || name.isEmpty) {
      name = (await askGuestName())?.trim() ?? '';
      await prefs.setString('guestName', name);
    }
    _applyAuth(await api.post('/api/auth', {'guest': true, 'name': name}));
  }

  void _applyAuth(Map<String, dynamic> res) {
    api.token = res['token'] as String;
    final user = res['user'] as Map<String, dynamic>;
    username = user['username'] as String;
    guest = user['guest'] as bool? ?? false;
    standing = Standing.fromJson(res['standing'] as Map<String, dynamic>);
  }

  // ---------- solo climb ----------

  Future<void> startSolo() async {
    lastResult = null;
    _runId = null;
    game.start(GameMode.solo, seed);
    _updateMarkers();
    try {
      final res = await api.post('/api/runs');
      _runId = res['runId'] as String;
    } catch (e) {
      debugPrint('could not start a ranked run: $e');
    }
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final id = _runId;
      if (id == null || game.lanes.isEmpty) return;
      api.post('/api/runs/$id/progress', {'height': game.lanes.first.climber.y}).ignore();
    });
  }

  Future<RunResult> finishSolo(int score) async {
    _progressTimer?.cancel();
    final id = _runId;
    _runId = null;
    RunResult result;
    if (id == null) {
      result = RunResult(score: score, error: '서버에 연결되지 않아 기록되지 않았다.');
    } else {
      try {
        final res = await api.post('/api/runs/$id/finish', {'score': score});
        standing = Standing.fromJson(res['standing'] as Map<String, dynamic>);
        _applyStats(res['stats'] as Map<String, dynamic>);
        result = RunResult(score: score, isBest: res['isBest'] as bool? ?? false);
      } catch (e) {
        result = RunResult(score: score, error: '기록 실패: $e');
      }
    }
    lastResult = result;
    _updateMarkers();
    notifyListeners();
    return result;
  }

  // ---------- live feed ----------

  void _onBoard(Map<String, dynamic> msg) {
    board = [for (final e in msg['top'] as List) BoardEntry.fromJson(e as Map<String, dynamic>)];
    _applyStats(msg['stats'] as Map<String, dynamic>);
    _updateMarkers();
    notifyListeners();
  }

  void _onLive(Map<String, dynamic> msg) {
    liveCount = msg['count'] as int? ?? 0;
    liveClimbers = [for (final c in msg['climbers'] as List) c as Map<String, dynamic>];
    final mine = _runId?.substring(0, 8);
    game.ghosts = [
      for (final c in liveClimbers)
        if (c['id'] != mine) Ghost(c['name'] as String, (c['height'] as num).toDouble()),
    ];
    notifyListeners();
  }

  void _applyStats(Map<String, dynamic> s) {
    players = s['players'] as int? ?? players;
    totalRuns = s['totalRuns'] as int? ?? totalRuns;
    totalMeters = s['totalMeters'] as int? ?? totalMeters;
  }

  void _updateMarkers() {
    game.markers = [
      if (standing.best > 0) Marker(standing.best.toDouble(), '나의 최고 ${standing.best}m', 0xFFE8A95B),
      if (board.isNotEmpty && board.first.username != username)
        Marker(board.first.best.toDouble(), '1위 ${board.first.username}', 0xFF7BD88F),
    ];
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _feed?.close();
    super.dispose();
  }
}
