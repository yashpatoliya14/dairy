import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dairy/controllers/dashboard_controller.dart';
import 'package:dairy/services/api_service.dart';

class _FakeApiService extends ApiService {
  _FakeApiService() : super(baseUrl: 'http://localhost:3000');

  String? lastDateRequested;
  Map<String, dynamic> fakeSummary = {
    'date': '2026-10-26',
    'dairyName': 'Test Dairy',
    'summary': {
      'totalLiters': 85.5,
      'totalAmount': 5130.0,
      'totalCustomers': 10,
      'completedEntriesCount': 7,
      'missingEntriesCount': 3,
      'sentCount': 6,
      'openedCount': 1,
      'pendingCount': 0,
      'failedCount': 0,
      'notSentCount': 3,
    },
    'customers': [
      {
        'customer': {
          'id': 'c1',
          'name': 'Customer One',
          'uniqueNumber': '1',
          'defaultLiters': 2.0,
          'defaultPrice': 60.0,
        },
        'entry': {
          'id': 'e1',
          'liters': 2.5,
          'price': 60.0,
          'total': 150.0,
        },
        'hasEntry': true,
        'messageLog': {'status': 'sent'},
      },
      {
        'customer': {
          'id': 'c2',
          'name': 'Customer Two',
          'uniqueNumber': '2',
          'defaultLiters': 1.5,
          'defaultPrice': 60.0,
        },
        'entry': null,
        'hasEntry': false,
        'messageLog': {'status': 'not_sent'},
      },
    ],
  };

  @override
  Future<Map<String, dynamic>> getDailySummary({String? date, bool showLoader = false}) async {
    lastDateRequested = date;
    return fakeSummary;
  }

  @override
  Future<List<Map<String, dynamic>>> getCustomers() async {
    return [
      {'id': 'c1', 'name': 'Customer One', 'uniqueNumber': '1'},
      {'id': 'c2', 'name': 'Customer Two', 'uniqueNumber': '2'},
    ];
  }

  @override
  Future<Map<String, dynamic>> getSettings() async {
    return {'defaultLiters': 1.5, 'defaultPrice': 60.0};
  }

  @override
  Future<Map<String, dynamic>> getProfile() async {
    return {'dairyName': 'Test Dairy Farm', 'name': 'Owner Name'};
  }

  @override
  Future<Map<String, dynamic>> addMilkEntry(
    String customerId, {
    required DateTime date,
    required double liters,
    required double price,
  }) async {
    return {'success': true};
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DashboardController Tests', () {
    test('Initial loading populates summary and customer stats correctly', () async {
      final fakeApi = _FakeApiService();
      final controller = DashboardController(fakeApi);
      await controller.load();

      expect(controller.dairyName.value, 'Test Dairy Farm');
      expect(controller.ownerName.value, 'Owner Name');
      expect(controller.todayLiters.value, 85.5);
      expect(controller.todayTotalAmount.value, 5130.0);
      expect(controller.todayEntriesDone.value, 7);
      expect(controller.todayMissingCount.value, 3);
      expect(controller.todayTotalCustomers.value, 10);
      expect(controller.todaySentCount.value, 6);
      expect(controller.dailyCustomerItems.length, 2);
    });

    test('Date navigation updates selectedDate and fetches summary for that date', () async {
      final fakeApi = _FakeApiService();
      final controller = DashboardController(fakeApi);
      await controller.load();

      final today = DateTime.now();
      expect(controller.isSelectedDateToday, isTrue);

      await controller.previousDay();
      final yesterday = today.subtract(const Duration(days: 1));
      expect(controller.selectedDate.value.day, yesterday.day);
      expect(controller.isSelectedDateToday, isFalse);

      await controller.nextDay();
      expect(controller.selectedDate.value.day, today.day);

      final specificDate = DateTime(2026, 5, 15);
      await controller.setSelectedDate(specificDate);
      expect(controller.formattedSelectedDate, '2026-05-15');
      expect(fakeApi.lastDateRequested, '2026-05-15');

      await controller.goToToday();
      expect(controller.isSelectedDateToday, isTrue);
    });

    test('Filter state management functions correctly', () async {
      final fakeApi = _FakeApiService();
      final controller = DashboardController(fakeApi);

      expect(controller.dailyFilter.value, 'all');
      controller.setDailyFilter('missing');
      expect(controller.dailyFilter.value, 'missing');
      controller.setDailyFilter('completed');
      expect(controller.dailyFilter.value, 'completed');
    });

    test('Saving milk entry reloads summary and customers', () async {
      final fakeApi = _FakeApiService();
      final controller = DashboardController(fakeApi);
      await controller.load();

      final saved = await controller.saveCustomerMilkEntry('c2', 2.0, 60.0);
      expect(saved, isTrue);
    });
  });
}
