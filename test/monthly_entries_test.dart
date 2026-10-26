import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:dairy/controllers/monthly_entries_controller.dart';
import 'package:dairy/services/api_service.dart';
import 'package:dairy/services/app_language.dart';
import 'package:dairy/widgets/monthly_entries_screen.dart';

class MockApiService extends ApiService {
  MockApiService() : super(baseUrl: 'http://localhost:3000');

  final Map<String, Map<String, dynamic>> mockMonthData = {};
  final List<Map<String, dynamic>> addedEntries = [];
  final List<String> deletedEntryIds = [];

  @override
  bool get hasSession => true;

  @override
  Future<Map<String, dynamic>> getProfile() async {
    return {
      'dairyName': 'Gokul Dairy',
      'name': 'Haresh Sambad',
      'phone': '+91 9104152524',
    };
  }

  @override
  Future<Map<String, dynamic>> getMilkEntriesForMonth(
    String customerId, {
    required int year,
    required int month,
  }) async {
    final key = '$customerId-$year-$month';
    if (mockMonthData.containsKey(key)) {
      return mockMonthData[key]!;
    }
    final daysInMonth = DateTime(year, month + 1, 0).day;
    return {
      'year': year,
      'month': month,
      'daysInMonth': daysInMonth,
      'entriesCount': 0,
      'totalLiters': 0.0,
      'totalAmount': 0.0,
      'entries': [],
    };
  }

  @override
  Future<Map<String, dynamic>> addMilkEntry(
    String customerId, {
    required DateTime date,
    required double liters,
    required double price,
  }) async {
    final entry = {
      'id': 'entry_${addedEntries.length + 1}',
      'customerId': customerId,
      'entryDate':
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'liters': liters,
      'price': price,
      'total': liters * price,
    };
    addedEntries.add(entry);
    return entry;
  }

  @override
  Future<void> deleteMilkEntry(String customerId, String entryId) async {
    deletedEntryIds.add(entryId);
  }
}

void main() {
  group('MonthlyEntriesController Tests', () {
    late MockApiService mockApi;
    late MonthlyEntriesController controller;

    setUp(() {
      mockApi = MockApiService();
      controller = MonthlyEntriesController(mockApi);
    });

    test('Month navigation and year rollover', () {
      controller.selectedYear.value = 2026;
      controller.selectedMonth.value = 1;

      controller.previousMonth();
      expect(controller.selectedYear.value, 2025);
      expect(controller.selectedMonth.value, 12);

      controller.nextMonth();
      expect(controller.selectedYear.value, 2026);
      expect(controller.selectedMonth.value, 1);
    });

    test('Load month data and populate statistics', () async {
      mockApi.mockMonthData['c1-2026-11'] = {
        'year': 2026,
        'month': 11,
        'daysInMonth': 30,
        'entriesCount': 2,
        'totalLiters': 3.5,
        'totalAmount': 210.0,
        'entries': [
          {
            'id': 'e1',
            'entryDate': '2026-11-01',
            'liters': 2.0,
            'price': 60.0,
            'total': 120.0,
          },
          {
            'id': 'e2',
            'entryDate': '2026-11-02',
            'liters': 1.5,
            'price': 60.0,
            'total': 90.0,
          },
        ],
      };

      controller.customer.value = {'id': 'c1', 'name': 'Haresh Bhai'};
      controller.setMonthYear(2026, 11);
      await controller.loadMonth();

      expect(controller.daysInMonth.value, 30);
      expect(controller.entriesCount.value, 2);
      expect(controller.missingDays, 28);
      expect(controller.totalLiters.value, 3.5);
      expect(controller.totalAmount.value, 210.0);

      // Verify specific day lookup
      final day1 = controller.entryForDay(1);
      expect(day1, isNotNull);
      expect(day1!['liters'], 2.0);

      final day3 = controller.entryForDay(3);
      expect(day3, isNull);
    });

    test('Zero quantity explicitly recorded vs missing entry', () async {
      mockApi.mockMonthData['c1-2026-11'] = {
        'year': 2026,
        'month': 11,
        'daysInMonth': 30,
        'entriesCount': 1,
        'totalLiters': 0.0,
        'totalAmount': 0.0,
        'entries': [
          {
            'id': 'e0',
            'entryDate': '2026-11-03',
            'liters': 0.0,
            'price': 60.0,
            'total': 0.0,
          },
        ],
      };

      controller.customer.value = {'id': 'c1', 'name': 'Haresh Bhai'};
      controller.setMonthYear(2026, 11);
      await controller.loadMonth();

      // Day 3 has entry with liters == 0 (explicit zero)
      final day3 = controller.entryForDay(3);
      expect(day3, isNotNull);
      expect(day3!['liters'], 0.0);

      // Day 4 has no entry recorded (missing)
      final day4 = controller.entryForDay(4);
      expect(day4, isNull);
    });

    test('Undo behavior: newly created entry is deleted', () async {
      controller.customer.value = {
        'id': 'c1',
        'name': 'Haresh Bhai',
        'price': 60.0,
      };
      controller.setMonthYear(2026, 11);

      // Save a new entry for day 5
      final saved = await controller.saveEntry(day: 5, liters: 2.5, price: 60.0);
      expect(saved, isTrue);
      expect(controller.undoStack.length, 1);
      expect(controller.undoStack.first.wasNew, isTrue);
      expect(mockApi.addedEntries.length, 1);

      // Undo the entry
      final undone = await controller.undo();
      expect(undone, isTrue);
      expect(controller.undoStack.isEmpty, isTrue);
      expect(mockApi.deletedEntryIds.length, 1);
    });

    test('Undo behavior: edited entry restores previous values', () async {
      mockApi.mockMonthData['c1-2026-11'] = {
        'year': 2026,
        'month': 11,
        'daysInMonth': 30,
        'entriesCount': 1,
        'totalLiters': 2.0,
        'totalAmount': 120.0,
        'entries': [
          {
            'id': 'e1',
            'entryDate': '2026-11-01',
            'liters': 2.0,
            'price': 60.0,
            'total': 120.0,
          },
        ],
      };

      controller.customer.value = {'id': 'c1', 'name': 'Haresh Bhai'};
      controller.setMonthYear(2026, 11);
      await controller.loadMonth();

      // Edit day 1 from 2.0 to 3.0 liters
      final saved = await controller.saveEntry(day: 1, liters: 3.0, price: 60.0);
      expect(saved, isTrue);
      expect(controller.undoStack.first.wasNew, isFalse);
      expect(controller.undoStack.first.previousLiters, 2.0);

      // Undo the edit
      final undone = await controller.undo();
      expect(undone, isTrue);
      // Verify mockApi was called to restore day 1 with 2.0 liters
      expect(mockApi.addedEntries.last['liters'], 2.0);
    });

    test('Delivery metrics: active days, off days, rate, average', () async {
      mockApi.mockMonthData['c1-2026-11'] = {
        'year': 2026,
        'month': 11,
        'daysInMonth': 30,
        'entriesCount': 3,
        'totalLiters': 5.0,
        'totalAmount': 300.0,
        'entries': [
          {'id': 'e1', 'entryDate': '2026-11-01', 'liters': 2.5, 'price': 60.0, 'total': 150.0},
          {'id': 'e2', 'entryDate': '2026-11-02', 'liters': 2.5, 'price': 60.0, 'total': 150.0},
          {'id': 'e3', 'entryDate': '2026-11-03', 'liters': 0.0, 'price': 60.0, 'total': 0.0},
        ],
      };

      controller.customer.value = {
        'id': 'c1',
        'customerNumber': '101',
        'name': 'Haresh Bhai',
        'defaultLiters': 2.0,
        'defaultPrice': 60.0,
      };
      controller.setMonthYear(2026, 11);
      await controller.loadMonth();

      expect(controller.activeDeliveryDays, 2);
      expect(controller.zeroDeliveryDays, 1);
      expect(controller.effectiveRate, 60.0);
      expect(controller.averageDailyLiters, 2.5);
    });

    testWidgets('MonthlyEntriesScreen displays small professional bill FIRST, then milk table', (tester) async {
      final now = DateTime.now();
      final monthData = {
        'year': now.year,
        'month': now.month,
        'daysInMonth': DateTime(now.year, now.month + 1, 0).day,
        'entriesCount': 2,
        'totalLiters': 4.0,
        'totalAmount': 240.0,
        'entries': [
          {
            'id': 'e1',
            'entryDate': '${now.year}-${now.month.toString().padLeft(2, '0')}-01',
            'liters': 2.0,
            'price': 60.0,
            'total': 120.0,
          },
          {
            'id': 'e2',
            'entryDate': '${now.year}-${now.month.toString().padLeft(2, '0')}-02',
            'liters': 2.0,
            'price': 60.0,
            'total': 120.0,
          },
        ],
      };
      mockApi.mockMonthData['c1-${now.year}-${now.month}'] = monthData;
      mockApi.mockMonthData['c1-2026-11'] = monthData;

      await tester.pumpWidget(MaterialApp(
        home: MonthlyEntriesScreen(
          api: mockApi,
          customer: {
            'id': 'c1',
            'customerNumber': '101',
            'name': 'Haresh Bhai',
            'defaultLiters': 2.0,
            'defaultPrice': 60.0,
          },
        ),
      ));
      await tester.pumpAndSettle();

      // 1. FIRST: Small Professional Bill Card
      expect(find.text('Gokul Dairy'), findsOneWidget);
      expect(find.text('Send WhatsApp Bill'), findsOneWidget);
      expect(find.text('Copy Bill'), findsOneWidget);
      expect(find.text('Total Liters'), findsOneWidget);
      expect(find.text('4.0 L'), findsOneWidget);
      expect(find.text('Rate per Liter'), findsOneWidget);
      expect(find.text('Delivery Days'), findsOneWidget);
      expect(find.text('Total Amount'), findsOneWidget);

      // 2. THEN: Table Column Headers
      expect(find.text('DATE / DAY'), findsOneWidget);
      expect(find.text('LITERS (L)'), findsOneWidget);
      expect(find.text('RATE (₹)'), findsOneWidget);
      expect(find.text('TOTAL (₹)'), findsOneWidget);

      // Clean up Get instance tag created by screen
      Get.reset();
    });
  });

  group('Monthly Entry Translations Tests', () {
    test('Translates month names and table headers into Gujarati', () {
      expect(T.t('Monthly Milk Entry Table', language: 'gu'), 'માસિક દૂધ એન્ટ્રી ટેબલ');
      expect(T.t('January', language: 'gu'), 'જાન્યુઆરી');
      expect(T.t('November', language: 'gu'), 'નવેમ્બર');
      expect(T.t('December', language: 'gu'), 'ડિસેમ્બર');
      expect(T.t('Undo', language: 'gu'), 'પૂર્વવત્ કરો');
      expect(T.t('Select month', language: 'gu'), 'મહિનો પસંદ કરો');
      expect(T.t('Previous month', language: 'gu'), 'પાછલો મહિનો');
      expect(T.t('Next month', language: 'gu'), 'આગલો મહિનો');
      expect(T.t('Total Milk', language: 'gu'), 'કુલ દૂધ');
      expect(T.t('Entries', language: 'gu'), 'એન્ટ્રીઓ');
      expect(T.t('Missing', language: 'gu'), 'બાકી દિવસો');
      expect(T.t('Days', language: 'gu'), 'દિવસો');
    });

    test('Translates into Hindi', () {
      expect(T.t('Monthly Milk Entry Table', language: 'hi'), 'मासिक दूध प्रविष्टि तालिका');
      expect(T.t('January', language: 'hi'), 'जनवरी');
      expect(T.t('Undo', language: 'hi'), 'पूर्ववत करें');
      expect(T.t('Previous month', language: 'hi'), 'पिछला महीना');
      expect(T.t('Next month', language: 'hi'), 'अगला महीना');
    });
  });
}
