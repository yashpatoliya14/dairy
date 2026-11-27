import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:dairy/services/api_service.dart';
import 'package:dairy/services/notification_service.dart';
import 'package:dairy/views/bulk_add_customers_screen.dart';
import 'package:dairy/widgets/reminder_settings_sheet.dart';

class _StubApiService extends ApiService {
  _StubApiService() : super(baseUrl: 'http://localhost:3000');

  @override
  Future<Map<String, dynamic>> getSettings() async => {
        'defaultLiters': 1.5,
        'defaultPrice': 50.0,
      };

  @override
  Future<List<Map<String, dynamic>>> getCustomers() async => [
        {'id': 'c1', 'name': 'Ramesh', 'uniqueNumber': '1'},
        {'id': 'c12', 'name': 'Suresh', 'uniqueNumber': '12'},
      ];
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Get.testMode = true;
  });

  group('Bulk Add Validation & Sequential Numbering', () {
    test('isValidBulkCustomerName accepts Gujarati, Hindi, English and rejects placeholders', () {
      expect(isValidBulkCustomerName('ચીમનભાઈ પટેલ'), isTrue);
      expect(isValidBulkCustomerName('रमेश शर्मा'), isTrue);
      expect(isValidBulkCustomerName('Pooja Parmar'), isTrue);
      expect(isValidBulkCustomerName('Demo 1'), isTrue);

      expect(isValidBulkCustomerName(''), isFalse);
      expect(isValidBulkCustomerName('A'), isFalse);
      expect(isValidBulkCustomerName('Customer #11'), isFalse);
      expect(isValidBulkCustomerName('ગ્રાહક #12'), isFalse);
      expect(isValidBulkCustomerName('ग्राहक #13'), isFalse);
      expect(isValidBulkCustomerName('12345'), isFalse);
    });

    test('normalizeBulkPhoneDigits & validateBulkPhoneInput work properly', () {
      expect(normalizeBulkPhoneDigits('+91 98980 22342'), '9898022342');
      expect(normalizeBulkPhoneDigits('09898022342'), '9898022342');
      expect(validateBulkPhoneInput('9898022342'), isNull);
      expect(validateBulkPhoneInput(''), isNull);
      expect(validateBulkPhoneInput('98980'), isNotNull);
      expect(validateBulkPhoneInput('1234567890'), isNotNull);
    });

    testWidgets('BulkAddCustomersScreen maintains sequential numbers after #12 and dairy defaults',
        (tester) async {
      final api = _StubApiService();
      await tester.pumpWidget(
        GetMaterialApp(
          home: BulkAddCustomersScreen(
            api: api,
            initialDefaultLiters: 1.5,
            initialDefaultPrice: 50.0,
            existingCustomers: const [
              {'id': 'c1', 'uniqueNumber': '1'},
              {'id': 'c12', 'uniqueNumber': '12'},
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Add Row 1 -> must get #13 (after existing #12) with 1.5L and ₹50
      await tester.tap(find.text('Add Row'));
      await tester.pumpAndSettle();
      expect(find.text('#13'), findsOneWidget);
      expect(find.text('1.5'), findsOneWidget);
      expect(find.text('50'), findsOneWidget);

      // Add Row 2 -> must get #14
      await tester.tap(find.text('Add Row'));
      await tester.pumpAndSettle();
      expect(find.text('#14'), findsOneWidget);

      // Delete first draft -> remaining draft re-sequences cleanly to #13
      final trashIcons = find.byTooltip('Delete Row');
      expect(trashIcons, findsNWidgets(2));
      await tester.tap(trashIcons.first);
      await tester.pumpAndSettle();
      expect(find.text('#13'), findsOneWidget);
      expect(find.text('#14'), findsNothing);
    });
  });

  group('NotificationService Timezone & Reminder Limit', () {
    test('configureLocalTimeZone resolves Asia/Kolkata for IST (+05:30), never UTC', () {
      NotificationService.configureLocalTimeZone();
      final istSample = _FakeIstDateTime();
      expect(NotificationService.resolveLocalTimeZoneName(istSample), 'Asia/Kolkata');

      NotificationService.configureLocalTimeZone(istSample);
      expect(tz.local.name, 'Asia/Kolkata');

      final nowIst = tz.TZDateTime(tz.local, 2026, 11, 28, 1, 5);
      final futureToday = NotificationService.computeNextScheduledDate(1, 10, now: nowIst);
      expect(futureToday.day, 28);
      expect(futureToday.hour, 1);
      expect(futureToday.minute, 10);

      final pastToday = NotificationService.computeNextScheduledDate(1, 0, now: nowIst);
      expect(pastToday.day, 29);
      expect(pastToday.hour, 1);
      expect(pastToday.minute, 0);
    });

    test('saveSlots caps reminders at maxReminderSlots (7)', () async {
      final many = List.generate(
        10,
        (i) => ReminderSlot(id: 's$i', hour: 8 + i, minute: 0, type: 'check_ledger'),
      );
      await NotificationService.instance.saveSlots(many);
      final saved = await NotificationService.instance.getSavedSlots();
      expect(saved.length, NotificationService.maxReminderSlots);
      expect(NotificationService.maxReminderSlots, 7);
    });

    testWidgets('ReminderSettingsSheet enforces maximum 7 reminder slots', (tester) async {
      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(
            body: ReminderSettingsSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Default is 2 slots -> 2/7 badge
      expect(find.text('2/7'), findsOneWidget);

      // Add 5 more slots -> reaches 7/7
      for (int i = 0; i < 5; i++) {
        await tester.tap(find.text('Add Another Reminder'));
        await tester.pumpAndSettle();
      }
      expect(find.text('7/7'), findsOneWidget);
      expect(find.text('Maximum 7 reminders limit reached'), findsOneWidget);
    });
  });
}

class _FakeIstDateTime extends DateTime {
  _FakeIstDateTime() : super(2026, 11, 28, 1, 5);

  @override
  String get timeZoneName => 'IST';

  @override
  Duration get timeZoneOffset => const Duration(hours: 5, minutes: 30);
}
