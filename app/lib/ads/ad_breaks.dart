import 'dart:async';

import 'package:sisyphus_core/sisyphus_core.dart';

import '../events.dart';
import '../game/scene.dart' show GameMode;

/// Shows one ad.
typedef ShowAd = Future<String> Function();

/// Observes GameController and, after every [every]th solo climb, shows an
/// interstitial a moment after the result screen appears, so the score is
/// seen first. 2P games never show ads, and nothing is shown once the next
/// run has started. When no ad is available the game simply carries on.
class AdBreaks implements Observer<AppEvent> {
  AdBreaks(
    this._show, {
    this.every = 3,
    this.delay = const Duration(milliseconds: 1500),
    this.onResult,
  });

  final ShowAd _show;
  final int every;
  final Duration delay;

  /// Told what the SDK answered (for diagnostics).
  final void Function(String result)? onResult;

  int _soloRuns = 0;
  Timer? _pending;

  @override
  void onEvent(AppEvent event) {
    switch (event) {
      case RunStarted():
        _pending?.cancel();
      case RunEnded(mode: GameMode.solo):
        if (++_soloRuns % every != 0) return;
        _pending?.cancel();
        _pending = Timer(delay, () async {
          final result = await _show();
          onResult?.call(result);
        });
      default:
        break;
    }
  }

  void dispose() => _pending?.cancel();
}
