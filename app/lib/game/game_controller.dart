import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sisyphus_core/sisyphus_core.dart';

enum GameMode { idle, solo, versus }

class Popup {
  Popup(this.y);

  final double y;
  double age = 0;
}

/// One stone on one path (two of them side by side in 2P mode).
class Lane {
  Lane(Mountain mountain) : climber = Climber(mountain);

  final Climber climber;
  double camY = 0;
  bool pushing = false;
  final popups = <Popup>[];
}

/// Another player climbing right now, reported by the live feed.
class Ghost {
  const Ghost(this.name, this.height);

  final String name;
  final double height;
}

/// A horizontal dashed line: a goal that moves nothing.
class Marker {
  const Marker(this.y, this.label, this.color);

  final double y;
  final String label;
  final int color;
}

/// Owns the simulation. [GameView] drives [tick] from a Ticker and the
/// painter repaints whenever this notifies.
class GameController extends ChangeNotifier {
  GameController() {
    _setup(GameMode.idle, defaultSeed);
  }

  GameMode mode = GameMode.idle;
  late Mountain mountain;
  List<Lane> lanes = [];
  List<Ghost> ghosts = const [];
  List<Marker> markers = const [];

  void Function(int lane)? onCrash;
  void Function(List<int> scores)? onAllOver;

  void start(GameMode m, int seed) {
    _setup(m, seed);
    notifyListeners();
  }

  void _setup(GameMode m, int seed) {
    mode = m;
    mountain = Mountain(seed);
    lanes = [for (var i = 0; i < (m == GameMode.versus ? 2 : 1); i++) Lane(mountain)];
  }

  void setPushing(int lane, bool value) {
    if (lane < lanes.length) lanes[lane].pushing = value;
  }

  void tick(double dt) {
    dt = min(dt, 0.05); // a backgrounded tab must not teleport the stone
    var allOver = mode != GameMode.idle;
    for (final (i, lane) in lanes.indexed) {
      final c = lane.climber;
      final ev = c.step(dt, pushing: mode != GameMode.idle && lane.pushing);
      for (var k = 0; k < ev.gained; k++) {
        lane.popups.add(Popup(c.score.toDouble()));
      }
      if (ev.crashed) onCrash?.call(i);
      allOver &= c.state == ClimbState.over;

      // the camera follows, faster while the stone tumbles down
      final follow = c.state == ClimbState.falling ? 10.0 : 5.0;
      lane.camY += (c.y - lane.camY) * min(1, dt * follow);
      for (final p in lane.popups) {
        p.age += dt;
      }
      lane.popups.removeWhere((p) => p.age >= 1);
    }
    if (allOver) {
      final scores = [for (final l in lanes) l.climber.score];
      mode = GameMode.idle;
      onAllOver?.call(scores);
    }
    notifyListeners();
  }
}
