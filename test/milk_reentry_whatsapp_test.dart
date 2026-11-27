import 'package:flutter_test/flutter_test.dart';
import 'package:dairy/services/app_update_service.dart';
import 'package:dairy/services/app_language.dart';

void main() {
  group('Milk Re-entry & WhatsApp Tests', () {
    test('App update service reflects version 1.0.44 and build 46', () {
      expect(AppUpdateService.currentVersion, '1.0.44');
      expect(AppUpdateService.currentBuildNumber, 46);
    });

    test('Re-entry accumulation math: adding evening milk onto morning entry', () {
      const double morningLiters = 2.0;
      const double eveningLiters = 1.5;
      const double price = 60.0;

      // In 'add' mode, liters accumulate
      final double totalLiters = morningLiters + eveningLiters;
      final double totalAmount = totalLiters * price;

      expect(totalLiters, 3.5);
      expect(totalAmount, 210.0);
    });

    test('Re-entry replace math: replacing today with new liters', () {
      const double replacementLiters = 4.0;
      const double price = 60.0;

      final double totalAmount = replacementLiters * price;

      expect(replacementLiters, 4.0);
      expect(totalAmount, 240.0);
    });

    test('Translations for re-entry and WhatsApp are available', () {
      expect(T.t('Earlier Today', language: 'hi'), 'आज पहले दर्ज');
      expect(T.t('Earlier Today', language: 'gu'), 'આજે અગાઉ નોંધાયેલ');
      expect(T.t('Add with Last Entry', language: 'hi'), 'अंतिम प्रविष्टि में जोड़ें (+)');
      expect(T.t('Add with Last Entry', language: 'gu'), 'છેલ્લી એન્ટ્રીમાં ઉમેરો (+)');
      expect(T.t('Replace Entry', language: 'hi'), 'प्रविष्टि बदलें');
      expect(T.t('Replace Entry', language: 'gu'), 'એન્ટ્રી બદલો');
      expect(T.t('Final Today', language: 'hi'), 'आज का कुल');
      expect(T.t('Final Today', language: 'gu'), 'આજનો કુલ હિસાબ');
      expect(T.t('Send WhatsApp receipt', language: 'hi'), 'व्हाट्सऐप रसीद भेजें');
      expect(T.t('Send WhatsApp receipt', language: 'gu'), 'વોટ્સએપ રસીદ મોકલો');
      expect(T.t('Open in WhatsApp', language: 'hi'), 'व्हाट्सऐप में खोलें');
      expect(T.t('Open in WhatsApp', language: 'gu'), 'વોટ્સએપમાં ખોલો');
    });

    test('Clean phone helper normalizes 10-digit number with country code', () {
      String cleanPhone(String phone) {
        final digits = phone.replaceAll(RegExp(r'\D'), '');
        if (digits.length == 10) return '91$digits';
        return digits;
      }

      expect(cleanPhone('9876543210'), '919876543210');
      expect(cleanPhone('+91 98765-43210'), '919876543210');
      expect(cleanPhone('919876543210'), '919876543210');
      expect(cleanPhone('123'), '123'); // invalid, stays short
    });
  });
}
