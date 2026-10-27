import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models.dart';

class Api {
  Api(this.url, [this.token = '']);
  final String url, token;
  static String normalize(String value, {bool allowHttp = false}) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        (uri.scheme != 'https' && !(uri.scheme == 'http' && allowHttp))) {
      throw ApiException(
        'Use an HTTPS origin such as https://monitor.example.com',
        400,
      );
    }
    return uri.origin;
  }

  Future<dynamic> request(
    String path, {
    String method = 'GET',
    Json? body,
  }) async {
    final client = http.Client();
    try {
      final request = http.Request(method, Uri.parse('$url/api/v1$path'))
        ..followRedirects = false
        ..headers['Content-Type'] = 'application/json'
        ..headers['User-Agent'] = 'Probelune Mobile/0.1.0';
      if (token.isNotEmpty) request.headers['Authorization'] = 'Bearer $token';
      if (body != null) request.body = jsonEncode(body);
      final response = await http.Response.fromStream(
        await client.send(request).timeout(const Duration(seconds: 15)),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode >= 300) {
        String message = 'HTTP ${response.statusCode}';
        try {
          message =
              object(jsonDecode(response.body))['error'] as String? ?? message;
        } catch (_) {}
        throw ApiException(message, response.statusCode);
      }
      return response.body.isEmpty ? null : jsonDecode(response.body);
    } finally {
      client.close();
    }
  }
}
