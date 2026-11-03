import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'game_controller.dart';
import 'game_painter.dart';
import 'scene.dart';

/// Full-screen game surface. Hold to push the stone up; let go and it rolls
/// back down. In 2P mode the left half of the screen (or W) is player 1 and
/// the right half (or ↑) is player 2.
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

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    final key = e.logicalKey;
    final versus = game.mode == GameMode.versus;
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
