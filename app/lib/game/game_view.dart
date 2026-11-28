import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'game_controller.dart';
import 'game_painter.dart';
import 'scene.dart';

/// Full-screen game surface. Hold to push the stone up; let go and it rolls
/// back down. While holding, slide the finger left or right to steer.
/// In 2P mode the left half of the screen (or W, A/D) is player 1 and the
/// right half (or ↑, ←/→) is player 2. Solo also steers with ←/→ or A/D.
class GameView extends StatefulWidget {
  const GameView({super.key, required this.game, required this.overlay});

  final GameController game;
  final SceneOverlay overlay;

  @override
  State<GameView> createState() => _GameViewState();
}

class _GameViewState extends State<GameView> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  final _pointers = <int, int>{}; // pointer id -> lane
  final _keys = <int>{}; // lanes held by keyboard
  final _steerKeys = <int, Set<int>>{}; // lane -> held directions (-1, 1)

  /// Fraction of the drag turned into steering: a bit more than 1:1 so a
  /// short thumb movement crosses the path.
  static const _steerGain = 1.3;
  final _focus = FocusNode();

  GameController get game => widget.game;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final dt = (elapsed - _last).inMicroseconds / 1e6;
      _last = elapsed;
      if (dt > 0) game.tick(dt);
    })
      ..start();
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _sync() {
    for (var i = 0; i < game.lanes.length; i++) {
      game.setPushing(i, _keys.contains(i) || _pointers.containsValue(i));
    }
  }

  int _laneAt(Offset pos) {
    if (game.mode != GameMode.versus) return 0;
    return pos.dx < context.size!.width / 2 ? 0 : 1;
  }

  double _laneWidthPx() {
    final w = context.size!.width;
    return game.mode == GameMode.versus ? w / 2 : min(w, 480.0);
  }

  /// Steering keys: (lane, direction) or null.
  (int, int)? _steerKey(LogicalKeyboardKey key, bool versus) {
    if (key == LogicalKeyboardKey.keyA) return (0, -1);
    if (key == LogicalKeyboardKey.keyD) return (0, 1);
    if (key == LogicalKeyboardKey.arrowLeft) return (versus ? 1 : 0, -1);
    if (key == LogicalKeyboardKey.arrowRight) return (versus ? 1 : 0, 1);
    return null;
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    final key = e.logicalKey;
    final versus = game.mode == GameMode.versus;
    final steer = _steerKey(key, versus);
    if (steer != null) {
      final (lane, dir) = steer;
      final held = _steerKeys.putIfAbsent(lane, () => {});
      if (e is KeyDownEvent || e is KeyRepeatEvent) {
        held.add(dir);
      } else if (e is KeyUpEvent) {
        held.remove(dir);
      }
      game.setSteering(lane, held.length == 1 ? held.first : 0);
      return KeyEventResult.handled;
    }
    int? lane;
    if (key == LogicalKeyboardKey.keyW) {
      lane = 0;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      lane = versus ? 1 : 0;
    } else if (key == LogicalKeyboardKey.space && !versus) {
      lane = 0;
    }
    if (lane == null) return KeyEventResult.ignored;
    if (e is KeyDownEvent || e is KeyRepeatEvent) {
      _keys.add(lane);
    } else if (e is KeyUpEvent) {
      _keys.remove(lane);
    }
    _sync();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          _focus.requestFocus();
          _pointers[e.pointer] = _laneAt(e.localPosition);
          _sync();
        },
        onPointerMove: (e) {
          final lane = _pointers[e.pointer];
          if (lane != null) game.steerBy(lane, e.delta.dx / _laneWidthPx() * _steerGain);
        },
        onPointerUp: (e) {
          _pointers.remove(e.pointer);
          _sync();
        },
        onPointerCancel: (e) {
          _pointers.remove(e.pointer);
          _sync();
        },
        child: CustomPaint(painter: GamePainter(game, widget.overlay), size: Size.infinite),
      ),
    );
  }
}
