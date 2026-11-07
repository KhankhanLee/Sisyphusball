import 'dart:convert';

import 'package:http/http.dart' as http;

/// The parts of the Pi Platform API payments flow the server needs.
abstract interface class PiPayments {
  Future<Map<String, dynamic>> get(String paymentId);

  Future<void> approve(String paymentId);

  Future<void> complete(String paymentId, String txid);
}

/// `{apiBase}/v2/payments/...` with the app's server API key.
class PiPaymentsApi implements PiPayments {
  PiPaymentsApi({required this.apiBase, required this.apiKey, http.Client? client}) : _client = client ?? http.Client();

  final String apiBase;
  final String apiKey;
  final http.Client _client;

  Map<String, String> get _headers => {'Authorization': 'Key $apiKey', 'Content-Type': 'application/json'};

  Future<Map<String, dynamic>> _send(Future<http.Response> request) async {
    final res = await request.timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) throw StateError('Pi payments API ${res.statusCode}: ${res.body}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> get(String id) =>
      _send(_client.get(Uri.parse('$apiBase/v2/payments/${Uri.encodeComponent(id)}'), headers: _headers));

  @override
  Future<void> approve(String id) =>
      _send(_client.post(Uri.parse('$apiBase/v2/payments/${Uri.encodeComponent(id)}/approve'), headers: _headers));

  @override
  Future<void> complete(String id, String txid) => _send(_client.post(
        Uri.parse('$apiBase/v2/payments/${Uri.encodeComponent(id)}/complete'),
        headers: _headers,
        body: jsonEncode({'txid': txid}),
      ));
}
