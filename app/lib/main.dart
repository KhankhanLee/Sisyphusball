import 'package:flutter/material.dart';
import 'package:sisyphus_core/sisyphus_core.dart' show Skin;
import 'package:url_launcher/url_launcher.dart';

import 'app_services.dart';
import 'copy.dart';
import 'data/api_client.dart';
import 'data/diagnostics.dart';
import 'game/game_controller.dart';
import 'game/game_view.dart';
import 'models/screen_model.dart';
import 'payments/payment.dart';
import 'ui/screens/carve_dialog.dart';
import 'ui/screens/guest_name_dialog.dart';
import 'ui/screens/hall_of_fame_screen.dart';
import 'ui/screens/nickname_dialog.dart';
import 'ui/screens/shop_screen.dart';
import 'ui/screens/huds.dart';
import 'ui/screens/solo_result_screen.dart';
import 'ui/screens/title_screen.dart';
import 'ui/screens/versus_result_screen.dart';
import 'ui/theme.dart';

final diagnostics = Diagnostics();

void main() {
  diagnostics
    ..install()
    ..report('dart-start');
  runApp(const SisyphusApp());
  diagnostics
    ..reportFirstFrame()
    ..reportFrameCount()
    ..reportLayout();
}

class SisyphusApp extends StatelessWidget {
  const SisyphusApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: Copy.appName,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        builder: (context, child) => RepaintBoundary(
          key: diagnostics.captureKey,
          child: safeTypography(context, child),
        ),
        home: const GameShell(),
      );
}

/// The game surface is always on screen; the current screen floats above it.
class GameShell extends StatefulWidget {
  const GameShell({super.key, this.services});

  /// Injected in tests; otherwise created and started here.
  final AppServices? services;

  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> {
  late final AppServices s = widget.services ?? AppServices(askGuestName: () => showGuestNameDialog(context), diagnostics: diagnostics);

  bool _askingNickname = false;

  @override
  void initState() {
    super.initState();
    s.player.addListener(_askNicknameIfNeeded);
    if (widget.services == null) WidgetsBinding.instance.addPostFrameCallback((_) => s.start());
  }

  @override
  void dispose() {
    s.player.removeListener(_askNicknameIfNeeded);
    if (widget.services == null) s.dispose();
    super.dispose();
  }

  /// A Pi player without a nickname picks one before playing.
  void _askNicknameIfNeeded() {
    if (_askingNickname || !s.player.needsNickname) return;
    _askingNickname = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) await _editNickname(required: true);
      _askingNickname = false;
    });
  }

  Future<void> _editNickname({bool required = false}) => showNicknameDialog(
        context,
        required: required,
        initial: required ? '' : s.player.username,
        save: (name) async {
          try {
            await s.auth.setNickname(name);
            return null;
          } on ApiException catch (e) {
            return e.message;
          } catch (_) {
            return Copy.signInFailed;
          }
        },
      );

  void _play(GameMode mode) => s.game.start(mode);

  void _openPage(String path) => launchUrl(serverBase.resolve(path)).ignore();

  Future<void> _carve() async {
    final price = s.carvings.price;
    final height = s.screens.lastScores.first;
    if (price == null) return;
    final text = await showCarveDialog(context, height: height, price: price);
    if (text == null || !mounted) return;
    s.screens.setCarving(carving: true);
    final outcome = await s.carve.carve(text: text, height: height, price: price);
    s.screens.setCarving(carving: false, carved: outcome == PaymentOutcome.completed);
    diagnostics.report('carve', outcome.name);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(switch (outcome) {
        PaymentOutcome.completed => Copy.carved,
        PaymentOutcome.cancelled => Copy.carveCancelled,
        PaymentOutcome.failed => Copy.carveFailed,
      }),
    ));
  }

  Future<void> _wear(Skin skin) async {
    try {
      await s.shop.wear(skin);
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _buy(Skin skin) async {
    final outcome = await s.shop.buy(skin);
    diagnostics.report('buy-skin', '${skin.id} ${outcome.name}');
    _toast(switch (outcome) {
      PaymentOutcome.completed => Copy.bought,
      PaymentOutcome.cancelled => Copy.buyCancelled,
      PaymentOutcome.failed => Copy.buyFailed,
    });
  }

  void _toast(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _home() {
    s.game.start(GameMode.idle);
    s.screens.showTitle();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(fit: StackFit.expand, children: [
        GameView(game: s.game, overlay: s.overlay),
        ListenableBuilder(
          listenable: Listenable.merge([s.screens, s.player, s.leaderboard, s.presence, s.carvings, s.looks]),
          builder: (context, _) => _screen(),
        ),
      ]),
    );
  }

  Widget _screen() => switch (s.screens.screen) {
        Screen.title => TitleScreen(
            player: s.player,
            leaderboard: s.leaderboard,
            onSolo: () => _play(GameMode.solo),
            onVersus: () => _play(GameMode.versus),
            onHallOfFame: s.screens.openHallOfFame,
            onOpenPage: _openPage,
            onChangeNickname: _editNickname,
            onShop: s.screens.openShop,
          ),
        Screen.solo => SoloHud(game: s.game, player: s.player, presence: s.presence),
        Screen.versus => VersusHud(game: s.game),
        Screen.soloResult => SoloResultScreen(
            score: s.screens.lastScores.first,
            result: s.screens.lastResult,
            standing: s.player.standing,
            players: s.leaderboard.stats.players,
            refrain: s.screens.refrain,
            onAgain: () => _play(GameMode.solo),
            onHallOfFame: s.screens.openHallOfFame,
            onHome: _home,
            carvePrice: s.player.player?.guest == false ? s.carvings.price : null,
            carving: s.screens.carving,
            carved: s.screens.carved,
            onCarve: _carve,
          ),
        Screen.versusResult => VersusResultScreen(
            scores: s.screens.lastScores,
            onAgain: () => _play(GameMode.versus),
            onHome: _home,
          ),
        Screen.shop => ShopScreen(
            looks: s.looks,
            signedIn: s.player.signedIn,
            onWear: _wear,
            onBuy: _buy,
            onBack: s.screens.showTitle,
          ),
        Screen.hallOfFame => HallOfFameScreen(
            leaderboard: s.leaderboard,
            presence: s.presence,
            me: s.player.username,
            onBack: s.screens.closeHallOfFame,
          ),
      };
}
