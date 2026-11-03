import 'dart:convert';

import 'package:shelf/shelf.dart';

import 'http_error.dart';

const _maxBody = 4096;

Response jsonResponse(Object body, [int status = 200]) => Response(
      status,
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store'},
    );

Future<Map<String, dynamic>> readJson(Request req) async {
  final len = req.contentLength;
  if (len != null && len > _maxBody) throw HttpError(413, 'body too large');
  final bytes = <int>[];
  await for (final chunk in req.read()) {
    bytes.addAll(chunk);
    if (bytes.length > _maxBody) throw HttpError(413, 'body too large');
  }
  if (bytes.isEmpty) return {};
  try {
    final data = jsonDecode(utf8.decode(bytes));
    if (data is Map<String, dynamic>) return data;
  } on FormatException {
    // reported below
  }
  throw HttpError(400, 'invalid JSON');
}

/// Turns [HttpError]s thrown by handlers into JSON error responses.
Middleware errorsAsJson() => (inner) => (req) async {
      try {
        return await inner(req);
      } on HttpError catch (e) {
        return jsonResponse({'error': e.message}, e.status);
      }
    };

/// Auth uses a bearer header, never cookies, so any origin may call the API;
/// this lets `flutter run -d chrome` talk to a local server on another port.
Middleware allowAnyOrigin() {
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Authorization, Content-Type',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  };
  return (inner) => (req) async {
        if (req.method == 'OPTIONS') return Response.ok(null, headers: headers);
        return (await inner(req)).change(headers: headers);
      };
}
