import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sisyphus_core/sisyphus_core.dart';

import '../events.dart';
import 'scene.dart';

export 'scene.dart' show GameMode;

/// A floating "+1" next to the stone.
class Popup {
  Popup(this.height);

  final double height;
  double age = 0;
}

/// One stone on one path (two of them side by side in 2P mode).
class Lane {
  Lane(Mountain mountain) : climber = Climber(mountain);

  final Climber climber;
  double cameraY = 0;
  bool pushing = false;
  final popups = <Popup>[];
}

/// Owns the simulation; [GameView] drives [tick] from a Ticker.
///
/// Two kinds of observers:
///  * as a [Subject] it announces game moments ([RunStarted], [StoneCrashed],
///    [RunEnded]) to the app's services and models;
///  * as a [ChangeNotifier] it tells the painter to redraw every frame.
class GameController extends ChangeNotifier with Subject<AppEvent> {
  GameController({this.seed = defaultSeed}) {
    _setUp(GameMode.idle);
  }

  int seed;
  GameMode mode = GameMode.idle;
  late Mountain mountain;
  List<Lane> lanes = [];

  /// Height of the first stone; what a solo run reports to the server.
  double get height => lanes.first.climber.y;

  void start(GameMode newMode) {
    _setUp(newMode);
    if (newMode != GameMode.idle) notify(RunStarted(newMode));
    notifyListeners();
  }

  void setPushing(int lane, bool pushing) {
    if (lane < lanes.length) lanes[lane].pushing = pushing;
  }

  void tick(double dt) {
    dt = min(dt, 0.05); // a backgrounded tab must not teleport the stone
    final playing = mode != GameMode.idle;
    var allDown = playing;
    for (final (i, lane) in lanes.indexed) {
      final c = lane.climber;
      final ev = c.step(dt, pushing: playing && lane.pushing);
      for (var k = 0; k < ev.gained; k++) {
        lane.popups.add(Popup(c.score.toDouble()));
      }
      if (ev.crashed) notify(StoneCrashed(i, c.score));
      allDown &= c.state == ClimbState.over;
      _followCamera(lane, dt);
      _agePopups(lane, dt);
    }
    if (allDown) {
      final ended = mode;
      mode = GameMode.idle;
      notify(RunEnded(ended, [for (final l in lanes) l.climber.score]));
    }
    notifyListeners();
  }

  void _setUp(GameMode newMode) {
    mode = newMode;
    mountain = Mountain(seed);
    lanes = [for (var i = 0; i < (newMode == GameMode.versus ? 2 : 1); i++) Lane(mountain)];
  }

  // The camera follows the stone, faster while it tumbles down.
  static void _followCamera(Lane lane, double dt) {
    final c = lane.climber;
    final speed = c.state == ClimbState.falling ? 10.0 : 5.0;
    lane.cameraY += (c.y - lane.cameraY) * min(1, dt * speed);
  }

  static void _agePopups(Lane lane, double dt) {
    for (final p in lane.popups) {
      p.age += dt;
    }
    lane.popups.removeWhere((p) => p.age >= 1);
  }
}
