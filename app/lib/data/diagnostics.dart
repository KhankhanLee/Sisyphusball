import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
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

  /// Wraps the whole app (MaterialApp.builder) so [reportLayout] can take a
  /// screenshot of what Flutter itself rendered.
  final GlobalKey captureKey = GlobalKey();

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

  /// Counts the frames Flutter actually produced in the first seconds; a
  /// handful means rendering stalled after the first frame.
  void reportFrameCount({Duration after = const Duration(seconds: 6)}) {
    var frames = 0;
    SchedulerBinding.instance.addPersistentFrameCallback((_) => frames++);
    Timer(after, () => report('flutter-frames', '$frames in ${after.inSeconds}s'));
  }

  /// A few seconds in, reports where the visible texts were laid out and the
  /// view's padding/insets, and, when the server enables DEBUG_SHOTS, uploads
  /// a PNG of what Flutter rendered. Compared with what the browser shows,
  /// that tells layout problems apart from display/compositing problems.
  void reportLayout({Duration after = const Duration(seconds: 5)}) {
    Timer(after, () async {
      try {
        final view = PlatformDispatcher.instance.implicitView;
        if (view != null) {
          String insets(ViewPadding p) => '${p.left.round()},${p.top.round()},${p.right.round()},${p.bottom.round()}';
          report('view', 'padding=${insets(view.padding)} viewPadding=${insets(view.viewPadding)} '
              'viewInsets=${insets(view.viewInsets)} physical=${view.physicalSize.width.round()}x${view.physicalSize.height.round()}');
        }

        final texts = <String>[];
        void visit(RenderObject node) {
          if (node is RenderParagraph && node.hasSize && node.attached && texts.length < 8) {
            final rect = node.localToGlobal(Offset.zero) & node.size;
            final color = node.text.style?.color;
            final plain = node.text.toPlainText();
            texts.add('"${plain.length > 18 ? '${plain.substring(0, 18)}…' : plain}"'
                '@${rect.left.round()},${rect.top.round()} ${rect.width.round()}x${rect.height.round()}'
                '${color == null ? '' : ' a=${color.a.toStringAsFixed(2)}'}');
          }
          node.visitChildren(visit);
        }

        final root = WidgetsBinding.instance.rootElement?.renderObject;
        if (root != null) visit(root);
        report('layout', texts.isEmpty ? 'no text laid out' : texts.join(' | '));

        final config = jsonDecode((await _client.get(serverBase.resolve('api/config'))).body);
        if (config is Map && config['debugShots'] == true) await _uploadShot();
      } catch (e) {
        report('layout-error', '$e');
      }
    });
  }

  Future<void> _uploadShot() async {
    final boundary = captureKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return report('shot', 'no capture boundary');
    final image = await boundary.toImage(pixelRatio: 1);
    final png = await image.toByteData(format: ImageByteFormat.png);
    image.dispose();
    if (png == null) return report('shot', 'encoding failed');
    await _client.post(serverBase.resolve('api/debug/shot'), body: png.buffer.asUint8List());
    report('shot', 'uploaded ${png.lengthInBytes} bytes');
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
