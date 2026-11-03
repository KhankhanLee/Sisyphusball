import 'dart:async';

import 'package:sisyphus_core/sisyphus_core.dart';

import '../copy.dart';
import '../events.dart';
import '../game/scene.dart';
import 'api_client.dart';
import 'models.dart';

/// Reports ranked (solo) climbs to the server.
///
/// Both sides of the pattern at once:
///  * an [Observer] of the game — [RunStarted] opens a run on the server and
///    starts sending the height every [interval]; [RunEnded] submits the score;
///  * a [Subject] for the rest of the app — announces [RunRegistered] and
///    [RunRecorded].
class RunReporter with Subject<AppEvent> implements Observer<AppEvent> {
  RunReporter(this._api, {required this.currentHeight, this.interval = const Duration(seconds: 1)});

  final ApiClient _api;
  final double Function() currentHeight;
  final Duration interval;

  Future<String?>? _registration;
  Timer? _heartbeat;

  @override
  void onEvent(AppEvent event) {
    switch (event) {
      case RunStarted(mode: GameMode.solo):
        _begin();
      case RunEnded(mode: GameMode.solo, :final scores):
        _finish(scores.first);
      default:
        break;
    }
  }

  void _begin() {
    _heartbeat?.cancel();
    final registration = _register();
    _registration = registration;
    _heartbeat = Timer.periodic(interval, (_) async {
      final id = await registration;
      if (id != null) _api.post('/api/runs/$id/progress', {'height': currentHeight()}).ignore();
    });
  }

  Future<String?> _register() async {
    try {
      final id = (await _api.post('/api/runs'))['runId'] as String;
      notify(RunRegistered(id));
      return id;
    } catch (_) {
      return null; // played offline: the climb still counts for the player
    }
  }

  Future<void> _finish(int score) async {
    _heartbeat?.cancel();
    // A stone can crash before the server has even answered; wait for it.
    final id = await _registration;
    _registration = null;
    notify(RunRecorded(id == null ? RunResult(score: score, error: Copy.notRecorded) : await _submit(id, score)));
  }

  Future<RunResult> _submit(String id, int score) async {
    try {
      final res = await _api.post('/api/runs/$id/finish', {'score': score});
      return RunResult(
        score: score,
        isBest: res['isBest'] as bool? ?? false,
        standing: Standing.fromJson(res['standing'] as Map<String, dynamic>),
        stats: WorldStats.fromJson(res['stats'] as Map<String, dynamic>),
      );
    } catch (e) {
      return RunResult(score: score, error: Copy.recordFailed(e));
    }
  }

  void dispose() {
    _heartbeat?.cancel();
    detachAll();
  }
}
