import 'dart:io';

import 'package:shelf/shelf.dart';

import 'middleware.dart';

/// `POST /api/client-log`: browsers report what they see (user agent, boot
/// progress, errors) so problems inside WebViews we cannot inspect, such as
/// the Pi Browser, show up in the server log. Rate-limited, and every value is
/// truncated, so it cannot be used to flood the log.
class ClientLog {
  ClientLog([IOSink? out, this.maxPerMinute = 60]) : _out = out ?? stdout;

  final IOSink _out;
  final int maxPerMinute;
  DateTime _windowStart = DateTime.fromMillisecondsSinceEpoch(0);
  int _inWindow = 0;

  Future<Response> handle(Request req) async {
    final now = DateTime.now();
    if (now.difference(_windowStart) > const Duration(minutes: 1)) {
      _windowStart = now;
      _inWindow = 0;
    }
    if (++_inWindow > maxPerMinute) return Response(429);

    final body = await readJson(req);
    String field(String key, int max) {
      final v = body[key];
      if (v == null) return '-';
      final s = (v is String ? v : '$v').replaceAll(RegExp(r'[\r\n]+'), ' ');
      return s.length > max ? '${s.substring(0, max)}…' : s;
    }

    _out.writeln('[client] ${field('event', 40)}: ${field('detail', 800)} | ua=${field('ua', 200)}');
    return Response(204);
  }
}

/// Static files are revalidated on every load (cheap: the server answers 304
/// when nothing changed). Without this a WebView may keep showing an old
/// page, with old headers, after the server was updated.
Middleware revalidateStaticFiles() => (inner) => (req) async {
      final res = await inner(req);
      if (res.headers.containsKey('cache-control')) return res;
      return res.change(headers: {'cache-control': 'no-cache'});
    };
