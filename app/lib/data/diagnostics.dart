import 'dart:convert';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:sisyphus_core/sisyphus_core.dart';

import '../events.dart';
import 'api_client.dart';

/// Reports what happens on the player's device to the server log
/// (`POST /api/client-log`), so problems inside WebViews we cannot inspect —
/// the Pi Browser in particular — can still be diagnosed. Never sends tokens
/// or personal data; never throws.
///
/// Also an [Observer] of AuthService: sign-in outcomes are reported.
class Diagnostics implements Observer<AppEvent> {
  Diagnostics({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Routes Flutter and uncaught Dart errors to [report] as well.
  void install() {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      report('flutter-error', details.exceptionAsString());
      previous?.call(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      report('dart-error', '$error');
      return false; // keep the default handling (console)
    };
  }

  /// After the first frame, measures a line of text: a width of 0 means the
  /// browser drew the scene but could not shape text.
  void reportFirstFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final probe = TextPainter(
        text: const TextSpan(text: 'Sisyphusball', style: TextStyle(fontSize: 20)),
        textDirection: TextDirection.ltr,
      )..layout();
      final view = PlatformDispatcher.instance.implicitView;
      report(
        'first-frame',
        'textWidth=${probe.width.toStringAsFixed(1)} '
            'platformTextScale=${PlatformDispatcher.instance.textScaleFactor.toStringAsFixed(2)} '
            'view=${view?.physicalSize.width.round()}x${view?.physicalSize.height.round()} '
            'dpr=${view?.devicePixelRatio}',
      );
      probe.dispose();
    });
  }

  @override
  void onEvent(AppEvent event) {
    switch (event) {
      case SignedIn(:final player):
        report('signed-in', player.guest ? 'guest' : 'pi');
      case SignInFailed(:final reason):
        report('sign-in-failed', reason);
      default:
        break;
    }
  }

  void report(String event, [String detail = '']) {
    try {
      _client
          .post(serverBase.resolve('api/client-log'), body: jsonEncode({'event': event, 'detail': detail}))
          .ignore();
    } catch (_) {
      // diagnostics must never break the game
    }
  }
}
