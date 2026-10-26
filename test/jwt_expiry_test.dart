import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dairy/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String createTestJwt({required int expSeconds}) {
    final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})));
    final payload = base64Url.encode(utf8.encode(jsonEncode({
      'sub': 'user-123',
      'did': 'dist-123',
      'email': 'test@dairy.com',
      'exp': expSeconds,
    })));
    const signature = 'mock-signature';
    return '$header.$payload.$signature';
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('JWT Token Expiry and Session Lifecycle', () {
    test('extractJwtExpiry correctly parses exp claim from JWT token', () {
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final futureExpSec = nowSec + (30 * 24 * 3600); // 30 days (1 month)
      final token = createTestJwt(expSeconds: futureExpSec);

      final expiry = ApiService.extractJwtExpiry(token);
      expect(expiry, isNotNull);
      expect(expiry!.millisecondsSinceEpoch ~/ 1000, equals(futureExpSec));
    });

    test('extractJwtExpiry returns null for invalid token string', () {
      expect(ApiService.extractJwtExpiry('invalid-token'), isNull);
      expect(ApiService.extractJwtExpiry('a.b'), isNull);
      expect(ApiService.extractJwtExpiry(''), isNull);
    });

    test('isTokenExpired returns true when token expiration has passed', () async {
      final pastSec = (DateTime.now().millisecondsSinceEpoch ~/ 1000) - 3600; // 1 hour ago
      final expiredToken = createTestJwt(expSeconds: pastSec);

      final api = ApiService(baseUrl: 'http://localhost:3000');
      SharedPreferences.setMockInitialValues({
        'dairy_jwt': expiredToken,
        'dairy_jwt_expiry': pastSec * 1000,
      });

      await api.loadSession();
      expect(api.hasSession, isFalse);
      expect(api.isTokenExpired, isTrue);
      expect(api.currentToken, isNull);
    });

    test('isTokenExpired returns false when token has 1 month validity', () async {
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final futureSec = nowSec + (30 * 24 * 3600); // 30 days / 1 month
      final validToken = createTestJwt(expSeconds: futureSec);

      final api = ApiService(baseUrl: 'http://localhost:3000');
      SharedPreferences.setMockInitialValues({
        'dairy_jwt': validToken,
        'dairy_jwt_expiry': futureSec * 1000,
      });

      await api.loadSession();
      expect(api.hasSession, isTrue);
      expect(api.isTokenExpired, isFalse);
      expect(api.currentToken, equals(validToken));
    });

    test('session lifetime default is 30 days (1 month)', () {
      expect(ApiService.sessionLifetime.inDays, equals(30));
    });

    test('logout clears in-memory token, expiry, and shared preferences', () async {
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final futureSec = nowSec + (30 * 24 * 3600);
      final validToken = createTestJwt(expSeconds: futureSec);

      final api = ApiService(baseUrl: 'http://localhost:3000');
      SharedPreferences.setMockInitialValues({
        'dairy_jwt': validToken,
        'dairy_jwt_expiry': futureSec * 1000,
      });

      await api.loadSession();
      expect(api.hasSession, isTrue);

      await api.logout();
      expect(api.hasSession, isFalse);
      expect(api.currentToken, isNull);
      expect(api.tokenExpiry, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('dairy_jwt'), isNull);
      expect(prefs.getInt('dairy_jwt_expiry'), isNull);
    });
  });
}
