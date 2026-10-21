import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sisyphus_core/sisyphus_core.dart';

import 'app_state.dart';
import 'game/game_controller.dart';
import 'game/game_view.dart';
import 'screens/screens.dart';
import 'screens/widgets.dart';

void main() => runApp(const SisyphusApp());

class SisyphusApp extends StatelessWidget {
  const SisyphusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sisyphusball',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF14111C),
        colorScheme: const ColorScheme.dark(primary: accent),
      ),
      home: const GameShell(),
    );
  }
}

enum Screen { title, solo, versus, over, versusOver, board }

/// The game surface is always on screen; menus float above it.
class GameShell extends StatefulWidget {
  const GameShell({super.key, this.app});

  /// Injected in tests.
  final AppState? app;

  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> {
  late final GameController game = widget.app?.game ?? GameController();
  late final AppState app = widget.app ?? AppState(game);
  final _random = Random();

  Screen screen = Screen.title;
  Screen boardReturn = Screen.title;
  String refrain = refrains.first;
  List<int> versusScores = const [0, 0];
  int soloScore = 0;

  @override
  void initState() {
    super.initState();
    game.onAllOver = _onAllOver;
    if (widget.app == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => app.init(_askGuestName));
    }
  }

  @override
  void dispose() {
    app.dispose();
    game.dispose();
    super.dispose();
  }

  void _onAllOver(List<int> scores) {
    if (screen == Screen.solo) {
      app.finishSolo(scores.first);
      setState(() {
        soloScore = scores.first;
        refrain = refrains[_random.nextInt(refrains.length)];
        screen = Screen.over;
      });
    } else if (screen == Screen.versus) {
      setState(() {
        versusScores = scores;
        screen = Screen.versusOver;
      });
    }
  }

  void _solo() {
    app.startSolo();
    setState(() => screen = Screen.solo);
  }

  void _versus() {
    game.start(GameMode.versus, app.seed);
    setState(() => screen = Screen.versus);
  }

  void _home() {
    game.start(GameMode.idle, app.seed);
    setState(() => screen = Screen.title);
  }

  void _board(Screen from) => setState(() {
        boardReturn = from;
        screen = Screen.board;
      });

  Future<String?> _askGuestName() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('손님으로 오르기'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Pi Browser 밖에서는 손님으로 플레이합니다. 이름을 정해 주세요.', style: TextStyle(fontSize: 13)),
          TextField(
            controller: controller,
            autofocus: true,
            maxLength: 16,
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('시작'))],
      ),
    );
    controller.dispose();
    return name;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(fit: StackFit.expand, children: [
        GameView(game: game),
        ListenableBuilder(
          listenable: Listenable.merge([app, game]),
          builder: (context, _) => switch (screen) {
            Screen.title => TitleScreen(app: app, onSolo: _solo, onVersus: _versus, onBoard: () => _board(Screen.title)),
            Screen.solo => SoloHud(app: app, score: game.lanes.first.climber.score),
            Screen.versus => VersusHud(scores: [for (final l in game.lanes) l.climber.score]),
            Screen.over => GameOverScreen(
                app: app,
                score: soloScore,
                result: app.lastResult,
                refrain: refrain,
                onAgain: _solo,
                onBoard: () => _board(Screen.over),
                onHome: _home,
              ),
            Screen.versusOver => VersusOverScreen(scores: versusScores, onAgain: _versus, onHome: _home),
            Screen.board => BoardScreen(app: app, onBack: () => setState(() => screen = boardReturn)),
          },
        ),
      ]),
    );
  }
}
