import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/dairy_milk_loader.dart';

class ApiService {
  ApiService({String? baseUrl})
    : baseUrl = _normalizeBaseUrl(
        baseUrl ??
            const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'http://10.248.67.9:3000',
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

  static const _tokenKey = 'dairy_jwt';
  static const _expiryKey = 'dairy_jwt_expiry';
  static const Duration sessionLifetime = Duration(days: 30);

  DateTime? _expiry;

  /// Callback fired when the session expires (either client-side or on 401).
  void Function({String? reason})? onSessionExpired;

  DateTime? get tokenExpiry => _expiry;
  String? get currentToken => _token;

  /// Extracts the expiration date from a JWT token's `exp` claim.
  static DateTime? extractJwtExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final normalized = base64Url.normalize(parts[1]);
      final payloadJson = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(payloadJson);
      if (payload is Map && payload['exp'] is num) {
        final expSeconds = (payload['exp'] as num).toInt();
        return DateTime.fromMillisecondsSinceEpoch(expSeconds * 1000);
      }
    } catch (_) {}
    return null;
  }

  /// Whether the current stored JWT token is expired.
  bool get isTokenExpired {
    if (_token == null) return true;
    if (_expiry != null && DateTime.now().isAfter(_expiry!)) {
      return true;
    }
    final jwtExp = extractJwtExpiry(_token!);
    if (jwtExp != null && DateTime.now().isAfter(jwtExp)) {
      return true;
    }
    return false;
  }

  Future<void> loadSession() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(_tokenKey);
    final expiry = preferences.getInt(_expiryKey);
    if (token != null) {
      final jwtExp = extractJwtExpiry(token);
      final storedExpiry =
          expiry != null ? DateTime.fromMillisecondsSinceEpoch(expiry) : null;
      final effectiveExpiry = jwtExp ?? storedExpiry;

      if (effectiveExpiry != null && DateTime.now().isBefore(effectiveExpiry)) {
        _token = token;
        _expiry = effectiveExpiry;
        return;
      }
    }

    _token = null;
    _expiry = null;
    await preferences.remove(_tokenKey);
    await preferences.remove(_expiryKey);
  }

  bool get hasSession => _token != null && !isTokenExpired;

  Future<Map<String, dynamic>> login(String email, String password) async {
    return _authenticate(
      '/auth/login',
      {'email': email, 'password': password},
      loaderMessage: 'Logging in...',
    );
  }

  Future<Map<String, dynamic>> signup(
    String firstName,
    String lastName,
    String email,
    String password,
    String dairyName,
  ) async {
    return _authenticate(
      '/auth/signup',
      {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'password': password,
        'dairyName': dairyName,
      },
      loaderMessage: 'Creating dairy account...',
    );
  }

  Future<Map<String, dynamic>> verifyEmail(String email, String code) async {
    return _postAuth(
      '/auth/verify-email',
      {'email': email, 'code': code},
      loaderMessage: 'Verifying code...',
    );
  }

  Future<void> resendVerification(String email) async {
    await _postAuth(
      '/auth/resend-verification',
      {'email': email},
      loaderMessage: 'Sending verification code...',
    );
  }

  Future<void> requestPasswordReset(String email) async {
    await _postAuth(
      '/auth/forgot-password',
      {'email': email},
      loaderMessage: 'Sending reset code...',
    );
  }

  Future<void> resetPassword(
    String email,
    String code,
    String newPassword,
  ) async {
    await _postAuth(
      '/auth/reset-password',
      {
        'email': email,
        'code': code,
        'newPassword': newPassword,
      },
      loaderMessage: 'Resetting password...',
    );
  }

  Future<Map<String, dynamic>> _postAuth(
    String path,
    Map<String, dynamic> body, {
    String? loaderMessage,
  }) async {
    final response = await _send(
      'POST',
      path,
      body: body,
      includeAuth: false,
      loaderMessage: loaderMessage,
    );
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

  Future<Map<String, dynamic>> getMilkEntriesForMonth(
    String customerId, {
    required int year,
    required int month,
  }) async {
    final response = await _send(
      'GET',
      '/customers/$customerId/entries?year=$year&month=$month',
    );
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<void> deleteMilkEntry(String customerId, String entryId) async {
    await _send('DELETE', '/customers/$customerId/entries/$entryId');
  }

  Future<Map<String, dynamic>> sendWhatsAppBill(
    Map<String, dynamic> payload,
  ) async {
    final response = await _send(
      'POST',
      '/whatsapp/send-bill',
      body: payload,
      timeout: const Duration(seconds: 45),
    );
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<Map<String, dynamic>> sendWhatsAppText({
    required String to,
    required String message,
  }) async {
    final response = await _send(
      'POST',
      '/whatsapp/send-text',
      body: {'to': to, 'message': message},
      timeout: const Duration(seconds: 45),
    );
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<Map<String, dynamic>> sendDailyWhatsAppEntry({
    required String customerId,
    required String date,
    String? message,
  }) async {
    final body = <String, dynamic>{
      'customerId': customerId,
      'date': date,
    };
    if (message != null && message.trim().isNotEmpty) {
      body['message'] = message.trim();
    }
    final response = await _send(
      'POST',
      '/whatsapp/send-daily-entry',
      body: body,
      timeout: const Duration(seconds: 45),
    );
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<Map<String, dynamic>> sendBulkDailyWhatsAppEntries({
    required List<String> customerIds,
    required String date,
  }) async {
    final response = await _send(
      'POST',
      '/whatsapp/send-daily-entry-bulk',
      body: {
        'customerIds': customerIds,
        'date': date,
      },
      timeout: const Duration(seconds: 45),
    );
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<Map<String, dynamic>> getBulkJobStatus(
    String jobId, {
    bool showLoader = false,
  }) async {
    final response = await _send(
      'GET',
      '/whatsapp/bulk-job/$jobId',
      showLoader: showLoader,
    );
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<Map<String, dynamic>> getDailySummary({
    String? date,
    bool showLoader = true,
  }) async {
    final query = date != null ? '?date=$date' : '';
    final response = await _send(
      'GET',
      '/whatsapp/daily-summary$query',
      showLoader: showLoader,
      loaderMessage: 'Loading daily summary...',
    );
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<Map<String, dynamic>> updateDailyMessageStatus({
    required String customerId,
    required String date,
    required String status,
    String? messageContent,
    String? errorMessage,
  }) async {
    final body = <String, dynamic>{
      'customerId': customerId,
      'date': date,
      'status': status,
    };
    if (messageContent != null) body['messageContent'] = messageContent;
    if (errorMessage != null) body['errorMessage'] = errorMessage;

    final response = await _send(
      'POST',
      '/whatsapp/daily-message-status',
      body: body,
    );
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<List<Map<String, dynamic>>> getCustomerMessageHistory(
    String customerId,
  ) async {
    final response = await _send(
      'GET',
      '/whatsapp/customers/$customerId/history',
    );
    final data = jsonDecode(response.body);
    final list = data is List ? data : <dynamic>[];
    return list
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> updateProfile({
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? dairyName,
  }) async {
    final body = <String, dynamic>{};
    if (firstName != null) body['firstName'] = firstName;
    if (lastName != null) body['lastName'] = lastName;
    if (phoneNumber != null) body['phoneNumber'] = phoneNumber;
    if (dairyName != null) body['dairyName'] = dairyName;

    final response = await _send('PATCH', '/auth/profile', body: body);
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<void> logout() async {
    _token = null;
    _expiry = null;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tokenKey);
    await preferences.remove(_expiryKey);
  }

  Future<Map<String, dynamic>> _authenticate(
    String path,
    Map<String, dynamic> body, {
    String? loaderMessage,
  }) async {
    final response = await _send(
      'POST',
      path,
      body: body,
      includeAuth: false,
      loaderMessage: loaderMessage,
    );
    final data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    final token = data['token'] ?? data['accessToken'];
    if (token is String) {
      _token = token;
      final jwtExp = extractJwtExpiry(token);
      DateTime expiryDate;
      if (jwtExp != null) {
        expiryDate = jwtExp;
      } else if (data['expiresIn'] is num) {
        expiryDate = DateTime.now().add(
          Duration(seconds: (data['expiresIn'] as num).toInt()),
        );
      } else {
        expiryDate = DateTime.now().add(sessionLifetime);
      }
      _expiry = expiryDate;

      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_tokenKey, token);
      await preferences.setInt(_expiryKey, expiryDate.millisecondsSinceEpoch);
    }
    return data;
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
    bool showLoader = true,
    String? loaderMessage,
    Duration timeout = const Duration(seconds: 35),
  }) async {
    if (includeAuth) {
      if (_token == null || isTokenExpired) {
        developer.log(
          'Token missing or expired before $method $path. Triggering session expiry.',
          name: 'ApiService',
        );
        onSessionExpired?.call(reason: 'Session expired. Please log in again.');
        throw const ApiException(401, 'Session expired. Please log in again.');
      }
    }

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
    if (showLoader) {
      DairyMilkLoadingService.show(message: loaderMessage);
    }
    late final http.Response response;
    try {
      response = switch (method) {
        'GET' =>
          await http
              .get(uri, headers: headers)
              .timeout(timeout),
        'POST' =>
          await http
              .post(uri, headers: headers, body: jsonEncode(body))
              .timeout(timeout),
        'PATCH' =>
          await http
              .patch(uri, headers: headers, body: jsonEncode(body))
              .timeout(timeout),
        'DELETE' =>
          await http
              .delete(uri, headers: headers)
              .timeout(timeout),
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
    } finally {
      if (showLoader) {
        DairyMilkLoadingService.hide();
      }
    }
    developer.log(
      '$method $path -> ${response.statusCode} ${response.body}',
      name: 'ApiService',
    );
    if (includeAuth && response.statusCode == 401) {
      developer.log(
        'Received 401 Unauthorized for $method $path. Triggering session expiry.',
        name: 'ApiService',
      );
      onSessionExpired?.call(
        reason: _message(response.statusCode, response.body),
      );
    }
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
