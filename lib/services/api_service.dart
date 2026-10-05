import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  ApiService({String? baseUrl})
    : baseUrl = baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'http://10.0.2.2:3000',
          );

  final String baseUrl;
  String? _token;

  Future<void> loadSession() async {
    final preferences = await SharedPreferences.getInstance();
    _token = preferences.getString('dairy_jwt');
  }

  bool get hasSession => _token != null;

  Future<Map<String, dynamic>> login(String email, String password) async {
    return _authenticate('/auth/login', {'email': email, 'password': password});
  }

  Future<Map<String, dynamic>> signup(
    String email,
    String password,
    String dairyName,
  ) async {
    return _authenticate('/auth/signup', {
      'email': email,
      'password': password,
      'dairyName': dairyName,
    });
  }

  Future<List<Map<String, dynamic>>> getCustomers() async {
    final response = await _send('GET', '/customers');
    final data = jsonDecode(response.body);
    final list = data is List
        ? data
        : data is Map
        ? (data['customers'] as List? ?? [])
        : <dynamic>[];
    return list
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> createCustomer(
    Map<String, dynamic> customer,
  ) async {
    final response = await _send('POST', '/customers', body: customer);
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<void> logout() async {
    _token = null;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('dairy_jwt');
  }

  Future<Map<String, dynamic>> _authenticate(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _send('POST', path, body: body, includeAuth: false);
    final data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    final token = data['token'] ?? data['accessToken'];
    if (token is String) {
      _token = token;
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('dairy_jwt', token);
    }
    return data;
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (includeAuth && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    final uri = Uri.parse('$baseUrl$path');
    final response = switch (method) {
      'GET' => await http.get(uri, headers: headers),
      'POST' => await http.post(uri, headers: headers, body: jsonEncode(body)),
      _ => throw UnsupportedError('Unsupported HTTP method: $method'),
    };
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, _message(response.body));
    }
    return response;
  }

  String _message(String body) {
    try {
      final data = jsonDecode(body);
      return data['message']?.toString() ?? 'Something went wrong';
    } catch (_) {
      return 'Something went wrong';
    }
  }
}

class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  @override
  String toString() => message;
}
