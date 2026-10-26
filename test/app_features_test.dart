import 'package:flutter_test/flutter_test.dart';
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
    });

    test('Falls back gracefully to English when language is en', () {
      expect(T.t('Today\'s Entries Done', language: 'en'), 'Today\'s Entries Done');
      expect(T.t('Opened in WhatsApp', language: 'en'), 'Opened in WhatsApp');
    });
  });
}
