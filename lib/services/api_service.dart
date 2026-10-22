import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  ApiService({String? baseUrl})
    : baseUrl = _normalizeBaseUrl(
        baseUrl ??
            const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'https://dairy-backend-eemp.onrender.com',
            ),
      );

  final String baseUrl;
  String? _token;

  static String _normalizeBaseUrl(String value) {
    final normalized = value
        .trim()
        .replaceAll('`', '')
        .replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      throw ArgumentError.value(
        value,
        'baseUrl',
        'Expected an HTTP or HTTPS URL',
      );
    }
    return normalized;
  }

  Future<void> loadSession() async {
    final preferences = await SharedPreferences.getInstance();
    _token = preferences.getString('dairy_jwt');
  }

  bool get hasSession => _token != null;

  Future<Map<String, dynamic>> login(String email, String password) async {
    return _authenticate('/auth/login', {'email': email, 'password': password});
  }

  Future<Map<String, dynamic>> signup(
    String firstName,
    String lastName,
    String email,
    String password,
    String dairyName,
  ) async {
    return _authenticate('/auth/signup', {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'password': password,
      'dairyName': dairyName,
    });
  }

  Future<Map<String, dynamic>> verifyEmail(String email, String code) async {
    return _postAuth('/auth/verify-email', {'email': email, 'code': code});
  }

  Future<void> resendVerification(String email) async {
    await _postAuth('/auth/resend-verification', {'email': email});
  }

  Future<void> requestPasswordReset(String email) async {
    await _postAuth('/auth/forgot-password', {'email': email});
  }

  Future<void> resetPassword(
    String email,
    String code,
    String newPassword,
  ) async {
    await _postAuth('/auth/reset-password', {
      'email': email,
      'code': code,
      'newPassword': newPassword,
    });
  }

  Future<Map<String, dynamic>> _postAuth(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _send('POST', path, body: body, includeAuth: false);
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
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

  Future<Map<String, dynamic>> getSettings() async {
    final response = await _send('GET', '/settings');
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<Map<String, dynamic>> getProfile() async {
    final response = await _send('GET', '/auth/profile');
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _send(
      'PATCH',
      '/auth/password',
      body: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }

  Future<Map<String, dynamic>> updateSettings({
    required double defaultLiters,
    required double defaultPrice,
  }) async {
    final response = await _send(
      'PATCH',
      '/settings',
      body: {'defaultLiters': defaultLiters, 'defaultPrice': defaultPrice},
    );
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<Map<String, dynamic>> createCustomer(
    Map<String, dynamic> customer,
  ) async {
    final response = await _send('POST', '/customers', body: customer);
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<Map<String, dynamic>> updateCustomer(
    String customerId,
    Map<String, dynamic> customer,
  ) async {
    final response = await _send(
      'PATCH',
      '/customers/$customerId',
      body: customer,
    );
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<Map<String, dynamic>> addMilkEntry(
    String customerId, {
    required DateTime date,
    required double liters,
    required double price,
  }) async {
    if (customerId.trim().isEmpty) {
      throw const ApiException(0, 'Cannot save entry: customer ID is missing.');
    }
    final response = await _send(
      'POST',
      '/customers/$customerId/entries',
      body: {
        'entryDate': date.toIso8601String().substring(0, 10),
        'liters': liters,
        'price': price,
      },
    );
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<List<Map<String, dynamic>>> getMilkEntries(String customerId) async {
    final response = await _send('GET', '/customers/$customerId/entries');
    final data = jsonDecode(response.body);
    final list = data is List
        ? data
        : data is Map
        ? (data['entries'] as List? ?? [])
        : <dynamic>[];
    return list
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> sendWhatsAppBill(
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _send('POST', '/whatsapp/send-bill', body: payload);
      return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } catch (e) {
      if (payload.containsKey('customMessage') || payload.containsKey('message')) {
        final message = (payload['customMessage'] ?? payload['message']) as String;
        final response = await _send('POST', '/whatsapp/send-text', body: {
          'to': payload['to'],
          'message': message,
        });
        return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> sendWhatsAppText({
    required String to,
    required String message,
  }) async {
    final response = await _send('POST', '/whatsapp/send-text', body: {
      'to': to,
      'message': message,
    });
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
      final token = _token!;
      headers['Authorization'] = 'Bearer $token';
    }
    final uri = Uri.parse('$baseUrl$path');
    developer.log(
      '$method $path${body == null ? '' : ' body=${jsonEncode(body)}'}',
      name: 'ApiService',
    );
    late final http.Response response;
    try {
      response = switch (method) {
        'GET' =>
          await http
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 10)),
        'POST' =>
          await http
              .post(uri, headers: headers, body: jsonEncode(body))
              .timeout(const Duration(seconds: 10)),
        'PATCH' =>
          await http
              .patch(uri, headers: headers, body: jsonEncode(body))
              .timeout(const Duration(seconds: 10)),
        _ => throw UnsupportedError('Unsupported HTTP method: $method'),
      };
    } on SocketException catch (error, stackTrace) {
      developer.log(
        '$method $path socket error: $error',
        name: 'ApiService',
        error: error,
        stackTrace: stackTrace,
      );
      throw const ApiException(
        0,
        'Could not connect to the server. Check the API URL and backend.',
      );
    } on TimeoutException catch (error, stackTrace) {
      developer.log(
        '  timed out: $error',
        name: 'ApiService',
        error: error,
        stackTrace: stackTrace,
      );
      throw const ApiException(
        0,
        'The server took too long to respond. Check the backend and try again.',
      );
    } on http.ClientException catch (error, stackTrace) {
      developer.log(
        '$method $path client error: $error',
        name: 'ApiService',
        error: error,
        stackTrace: stackTrace,
      );
      throw const ApiException(0, 'Network request failed. Try again.');
    }
    developer.log(
      '$method $path -> ${response.statusCode} ${response.body}',
      name: 'ApiService',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        response.statusCode,
        _message(response.statusCode, response.body),
      );
    }
    return response;
  }

  String _message(int statusCode, String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map) {
        final message = data['message'];
        if (message is List) return message.join(', ');
        if (message is String && message.isNotEmpty) {
          if (statusCode == 404 && message.startsWith('Cannot ')) {
            return 'Entry service is not deployed on the server yet.';
          }
          return message;
        }
      }
      return 'Request failed (HTTP $statusCode)';
    } catch (_) {
      return body.trim().isEmpty
          ? 'Request failed (HTTP $statusCode)'
          : body.trim();
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
