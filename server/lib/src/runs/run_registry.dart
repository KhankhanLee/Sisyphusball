import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:sisyphus_core/sisyphus_core.dart';

import '../auth/identity.dart';
import '../events.dart';
import '../http/http_error.dart';
import 'presence.dart';

/// The fastest anyone can honestly score: the stone's top speed, plus slack
/// for network latency.
int maxReachableScore(Duration elapsed) =>
    (elapsed.inMilliseconds / 1000 * maxPointsPerSecond * 1.15 + 3).floor();

class _Run {
  _Run(this.owner, this.startedAt) : lastSeen = startedAt;

  final Identity owner;
  final DateTime startedAt;
  DateTime lastSeen;
  int height = 0;
}

/// Climbs in progress. A [Subject]: announces [PresenceChanged] whenever the
/// set of live climbers (or their heights) changes, checked every [tick].
class RunRegistry with Subject<ServerEvent> {
  RunRegistry({
    this.tick = const Duration(seconds: 1),
    this.staleAfter = const Duration(seconds: 5),
    this.expireAfter = const Duration(hours: 1),
    Random? random,
  }) : _random = random ?? Random.secure() {
    _timer = Timer.periodic(tick, (_) => _publishIfChanged());
  }

  final Duration tick, staleAfter, expireAfter;
  final Random _random;
  final _runs = <String, _Run>{};
  late final Timer _timer;
  String _lastPublished = '';

  /// Starts a run for [who]; any earlier unfinished run of theirs is dropped.
  String start(Identity who) {
    _runs.removeWhere((_, r) => r.owner.uid == who.uid);
    final id = base64Url.encode(List.generate(16, (_) => _random.nextInt(256))).replaceAll('=', '');
    _runs[id] = _Run(who, DateTime.now());
    return id;
  }

  void progress(String runId, Identity who, num height) {
    final run = _owned(runId, who);
    if (height.isFinite && height >= 0) {
      run.height = min(height.floor(), maxReachableScore(DateTime.now().difference(run.startedAt)));
    }
    run.lastSeen = DateTime.now();
  }

  /// Closes the run and returns [score] once it is proven plausible.
  /// A run can be finished only once, and only by its owner.
  int finish(String runId, Identity who, Object? score) {
    final run = _owned(runId, who);
    _runs.remove(runId);
    if (score is! int || score < 0) throw HttpError(400, 'invalid score');
    if (score > maxReachableScore(DateTime.now().difference(run.startedAt))) {
      throw HttpError(422, 'score is faster than the stone can roll');
    }
    return score;
  }

  Presence presence() {
    final now = DateTime.now();
    _runs.removeWhere((_, r) => now.difference(r.startedAt) > expireAfter);
    final live = [
      for (final MapEntry(key: id, value: r) in _runs.entries)
        if (now.difference(r.lastSeen) < staleAfter) LiveClimber(id.substring(0, 8), r.owner.username, r.height),
    ]..sort((a, b) => b.height.compareTo(a.height));
    return Presence(live.take(30).toList(), live.length);
  }

  void dispose() {
    _timer.cancel();
    detachAll();
  }

  _Run _owned(String runId, Identity who) {
    final run = _runs[runId];
    if (run == null || run.owner.uid != who.uid) throw HttpError(404, 'run not found');
    return run;
  }

  void _publishIfChanged() {
    if (observerCount == 0) return;
    final presence = this.presence();
    final fingerprint = jsonEncode(presence.toJson());
    if (fingerprint == _lastPublished) return;
    _lastPublished = fingerprint;
    notify(PresenceChanged(presence));
  }
}
