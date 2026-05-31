import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import 'supabase_service.dart';

class ApiException implements Exception {
  const ApiException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  final SupabaseClient _supabase = SupabaseService.client;
  final http.Client _http = http.Client();

  Future<dynamic> get(String path) async {
    final response = await _http.get(
      _uri(path),
      headers: await _headers(),
    );

    return _decode(response);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final response = await _http.post(
      _uri(path),
      headers: await _headers(),
      body: jsonEncode(body),
    );

    return _decode(response);
  }

  Uri _uri(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('${AppConfig.apiBaseUrl}$normalizedPath');
  }

  Future<Map<String, String>> _headers() async {
    final token = _supabase.auth.currentSession?.accessToken;
    if (token == null) {
      throw const AuthException('Sesi login berakhir. Silakan login ulang.');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  dynamic _decode(http.Response response) {
    final body = response.body.isEmpty ? null : jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    if (body is Map<String, dynamic>) {
      final message = body['message'];
      if (message is String) {
        throw ApiException(message, response.statusCode);
      }
      if (message is List) {
        throw ApiException(message.join(', '), response.statusCode);
      }
    }

    throw ApiException('Request backend gagal.', response.statusCode);
  }
}
