import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sisyphus_core/sisyphus_core.dart';

import '../data/models.dart';
import '../events.dart';
import '../game/scene.dart';

enum Screen { title, solo, versus, soloResult, versusResult, hallOfFame }

/// Which screen is showing. Navigation follows the game by itself:
/// observes GameController (a run starts or ends) and RunReporter (the
/// server's verdict on the climb that just ended).
class ScreenModel extends ChangeNotifier implements Observer<AppEvent> {
  ScreenModel({Random? random}) : _random = random ?? Random();

  final Random _random;
  Screen screen = Screen.title;
  Screen _beforeHallOfFame = Screen.title;

  List<int> lastScores = const [0];
  String refrain = refrains.first;

  /// The recorded result of the last solo climb; null while it is recorded.
  RunResult? lastResult;

  @override
  void onEvent(AppEvent event) {
    switch (event) {
      case RunStarted(:final mode):
        lastResult = null;
        screen = mode == GameMode.versus ? Screen.versus : Screen.solo;
      case RunEnded(:final mode, :final scores):
        lastScores = scores;
        refrain = refrains[_random.nextInt(refrains.length)];
        screen = mode == GameMode.versus ? Screen.versusResult : Screen.soloResult;
      case RunRecorded(:final result):
        lastResult = result;
      default:
        return;
    }
    notifyListeners();
  }

  void showTitle() => _go(Screen.title);

  void openHallOfFame() {
    _beforeHallOfFame = screen;
    _go(Screen.hallOfFame);
  }

  void closeHallOfFame() => _go(_beforeHallOfFame);

  void _go(Screen next) {
    screen = next;
    notifyListeners();
  }
}
