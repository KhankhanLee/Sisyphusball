import 'dart:typed_data';

import 'package:shelf/shelf.dart';

import 'http_error.dart';

/// A screenshot the app takes of its own rendering, for diagnosing WebViews
/// we cannot look into (the Pi Browser). Only when enabled (`DEBUG_SHOTS`);
/// keeps the latest PNG in memory, nothing on disk.
///
///   POST /api/debug/shot       raw PNG body from the app
///   GET  /api/debug/shot.png   the latest one
class DebugShots {
  DebugShots({required this.enabled, this.maxBytes = 3 * 1024 * 1024});

  final bool enabled;
  final int maxBytes;
  Uint8List? _latest;
  DateTime? _takenAt;

  static const _pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

  Future<Response> upload(Request req) async {
    if (!enabled) throw HttpError(404, 'not found');
    final len = req.contentLength;
    if (len != null && len > maxBytes) throw HttpError(413, 'too large');
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in req.read()) {
      bytes.add(chunk);
      if (bytes.length > maxBytes) throw HttpError(413, 'too large');
    }
    final png = bytes.takeBytes();
    if (png.length <= _pngSignature.length || !_startsWithSignature(png)) throw HttpError(400, 'not a PNG');
    _latest = png;
    _takenAt = DateTime.now().toUtc();
    return Response(204);
  }

  Response latest(Request _) {
    final png = _latest;
    if (!enabled || png == null) throw HttpError(404, 'not found');
    return Response.ok(png, headers: {
      'content-type': 'image/png',
      'cache-control': 'no-store',
      'x-taken-at': _takenAt!.toIso8601String(),
    });
  }

  static bool _startsWithSignature(Uint8List bytes) {
    for (var i = 0; i < _pngSignature.length; i++) {
      if (bytes[i] != _pngSignature[i]) return false;
    }
    return true;
  }
}
