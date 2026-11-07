import 'package:flutter_test/flutter_test.dart';
import 'package:dairy/main.dart';
import 'package:dairy/services/app_language.dart';

bool isValidEmailForTest(String email) {
  final trimmed = email.trim().toLowerCase();
  final emailRegex = RegExp(
    r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$',
  );
  if (!emailRegex.hasMatch(trimmed)) return false;

  final parts = trimmed.split('@');
  if (parts.length != 2) return false;
  final domain = parts[1];
  final domainParts = domain.split('.');
  if (domainParts.length < 2) return false;
  final tld = domainParts.last;
  if (tld.length < 2) return false;

  // Typo guard: reject malformed domain typos like 426gmail.com
  final malformedTypoDomainRegex = RegExp(r'^[0-9]+(gmail|yahoo|outlook|hotmail|icloud)\.[a-z]{2,}$');
  if (malformedTypoDomainRegex.hasMatch(domain)) return false;

  return true;
}

bool isPhoneNumberForTest(String input) {
  final cleaned = input.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
  if (RegExp(r'^\d{10}$').hasMatch(cleaned)) return true;
  if (RegExp(r'^91\d{10}$').hasMatch(cleaned)) return true;
  return false;
}

void main() {
  group('Email and Mobile Identification Tests', () {
    test('Rejects malformed email HArEshSambad@426gmail.com', () {
      expect(isValidEmailForTest('HArEshSambad@426gmail.com'), isFalse);
    });

    test('Accepts valid email hareshsambad426@gmail.com', () {
      expect(isValidEmailForTest('hareshsambad426@gmail.com'), isTrue);
    });

    test('Rejects invalid email formats', () {
      expect(isValidEmailForTest('invalid'), isFalse);
      expect(isValidEmailForTest('user@.com'), isFalse);
      expect(isValidEmailForTest('user@domain.c'), isFalse);
      expect(isValidEmailForTest('@domain.com'), isFalse);
    });

    test('Accepts 10-digit Indian phone numbers', () {
      expect(isPhoneNumberForTest('7043333359'), isTrue);
      expect(isPhoneNumberForTest('+917043333359'), isTrue);
      expect(isPhoneNumberForTest('917043333359'), isTrue);
      expect(isPhoneNumberForTest('+91 70433 33359'), isTrue);
    });

    test('Rejects invalid phone numbers', () {
      expect(isPhoneNumberForTest('12345'), isFalse);
      expect(isPhoneNumberForTest('7043333359999'), isFalse);
      expect(isPhoneNumberForTest('abcdefghij'), isFalse);
    });

    test('Customer Phone Number Validation - 10-digit and country-wise format (non-specific to India)', () {
      // Standard 10-digit numbers from any country (Indian starting with 6-9 and US/Canada starting with 2-5)
      expect(isValidCustomerPhoneNumber('9876543210'), isTrue);
      expect(isValidCustomerPhoneNumber('7043333359'), isTrue);
      expect(isValidCustomerPhoneNumber('2025550123'), isTrue);
      expect(isValidCustomerPhoneNumber('4155552671'), isTrue);
      expect(isValidCustomerPhoneNumber('98765 43210'), isTrue);
      expect(isValidCustomerPhoneNumber('(202) 555-0123'), isTrue);

      // Country-wise international format with country codes
      expect(isValidCustomerPhoneNumber('+91 98765 43210'), isTrue);
      expect(isValidCustomerPhoneNumber('+1 202 555 0123'), isTrue);
      expect(isValidCustomerPhoneNumber('+44 7911 123456'), isTrue);
      expect(isValidCustomerPhoneNumber('+971 50 123 4567'), isTrue);
      expect(isValidCustomerPhoneNumber('+61 412 345 678'), isTrue);
      expect(isValidCustomerPhoneNumber('+966 50 123 4567'), isTrue);

      // Strictly rejects numbers < 10 digits
      expect(isValidCustomerPhoneNumber('12345'), isFalse);
      expect(isValidCustomerPhoneNumber('1234567'), isFalse);
      expect(isValidCustomerPhoneNumber('12345678'), isFalse);
      expect(isValidCustomerPhoneNumber('123456789'), isFalse);

      // Rejects numbers > 15 digits or invalid characters
      expect(isValidCustomerPhoneNumber('1234567890123456'), isFalse);
      expect(isValidCustomerPhoneNumber('abc9876543210'), isFalse);
      expect(isValidCustomerPhoneNumber(''), isFalse);
      expect(isValidCustomerPhoneNumber(null), isFalse);
    });

    test('buildCustomerPhoneNumber and parseCustomerPhone work across countries', () {
      // India
      expect(buildCustomerPhoneNumber('9876543210', '+91'), '+919876543210');
      // US
      expect(buildCustomerPhoneNumber('2025550123', '+1'), '+12025550123');
      // Direct
      expect(buildCustomerPhoneNumber('9876543210', ''), '9876543210');
      // Already typed with +
      expect(buildCustomerPhoneNumber('+44 7911 123456', '+91'), '+447911123456');

      // Parsing
      final parsedIndia = parseCustomerPhone('+919876543210');
      expect(parsedIndia.$1, '+91');
      expect(parsedIndia.$2, '9876543210');

      final parsedUS = parseCustomerPhone('+12025550123');
      expect(parsedUS.$1, '+1');
      expect(parsedUS.$2, '2025550123');
    });
  });

  group('Gujarati Translation Tests', () {
    test('Translates core dairy terminology accurately into Gujarati', () {
      expect(T.t('Today\'s Entries Done', language: 'gu'), 'આજની એન્ટ્રીઓ પૂર્ણ થઈ');
      expect(T.t('Send Today\'s Milk Summary', language: 'gu'), 'આજનો દૂધ સારાંશ મોકલો');
      expect(T.t('WhatsApp Messages', language: 'gu'), 'વોટ્સએપ સંદેશાઓ');
      expect(T.t('Pending', language: 'gu'), 'બાકી');
      expect(T.t('Opened in WhatsApp', language: 'gu'), 'વોટ્સએપમાં ખોલ્યું');
      expect(T.t('Customer details', language: 'gu'), 'ગ્રાહકની વિગતો');
      expect(T.t('Morning', language: 'gu'), 'સવાર');
      expect(T.t('Evening', language: 'gu'), 'સાંજ');
      expect(T.t('Total Liters', language: 'gu'), 'કુલ લીટર');
      expect(T.t('Total Amount', language: 'gu'), 'કુલ રકમ');
      expect(T.t('Message Preview', language: 'gu'), 'મેસેજ પૂર્વાવલોકન');
      expect(T.t('Copy Message', language: 'gu'), 'મેસેજ કોપી કરો');
      expect(T.t('Change password', language: 'gu'), 'પાસવર્ડ બદલો');
      expect(T.t('Contact support', language: 'gu'), 'સપોર્ટનો સંપર્ક કરો');
      expect(T.t('Send feedback', language: 'gu'), 'પ્રતિસાદ મોકલો');
      expect(T.t('Change password', language: 'hi'), 'पासवर्ड बदलें');
      expect(T.t('Contact support', language: 'hi'), 'सपोर्ट से संपर्क करें');
      expect(T.t('Send feedback', language: 'hi'), 'प्रतिक्रिया भेजें');
    });

    test('Falls back gracefully to English when language is en', () {
      expect(T.t('Today\'s Entries Done', language: 'en'), 'Today\'s Entries Done');
      expect(T.t('Opened in WhatsApp', language: 'en'), 'Opened in WhatsApp');
    });
  });
}
