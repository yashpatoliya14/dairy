import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dairy/controllers/monthly_entries_controller.dart';
import 'package:dairy/services/api_service.dart';

class MockApiService extends ApiService {
  MockApiService() : super(baseUrl: 'https://test.local');

  @override
  bool get hasSession => false;

  @override
  Future<Map<String, dynamic>> getMilkEntriesForMonth(
    String customerId, {
    required int year,
    required int month,
  }) async {
    return {
      'daysInMonth': 30,
      'totalLiters': 60.0,
      'totalAmount': 3600.0,
      'entriesCount': 30,
      'entries': <Map<String, dynamic>>[],
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Payment Entry Tests', () {
    late ApiService api;
    late MonthlyEntriesController controller;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      api = MockApiService();
      controller = MonthlyEntriesController(api);
      controller.setCustomer({
        'id': 'cust_123',
        'name': 'Ramesh Kumar',
        'uniqueNumber': '42',
        'liters': 2.0,
        'price': 60.0,
      });
      // Wait for loadMonth to finish
      await controller.loadMonth();
    });

    test('Initial payment state is clean / unpaid', () {
      expect(controller.hasPayment.value, isFalse);
      expect(controller.paymentReceived.value, 0.0);
      expect(controller.balanceDue, 3600.0);
      expect(controller.isFullyPaid, isFalse);
      expect(controller.isPartiallyPaid, isFalse);
    });

    test('Save full payment updates state correctly', () async {
      final success = await controller.savePayment(
        receivedAmount: 3600.0,
        note: 'UPI Payment',
        receivedDate: DateTime(2026, 11, 5),
      );

      expect(success, isTrue);
      expect(controller.hasPayment.value, isTrue);
      expect(controller.paymentReceived.value, 3600.0);
      expect(controller.balanceDue, 0.0);
      expect(controller.isFullyPaid, isTrue);
      expect(controller.isPartiallyPaid, isFalse);
      expect(controller.paymentNote.value, 'UPI Payment');
    });

    test('Save partial payment calculates balance correctly', () async {
      final success = await controller.savePayment(
        receivedAmount: 2000.0,
        note: 'Cash advance',
        receivedDate: DateTime(2026, 11, 2),
      );

      expect(success, isTrue);
      expect(controller.hasPayment.value, isTrue);
      expect(controller.paymentReceived.value, 2000.0);
      expect(controller.balanceDue, 1600.0);
      expect(controller.isFullyPaid, isFalse);
      expect(controller.isPartiallyPaid, isTrue);
    });

    test('Delete payment resets payment state', () async {
      await controller.savePayment(
        receivedAmount: 3600.0,
        note: 'Cash',
      );
      expect(controller.hasPayment.value, isTrue);

      final deleted = await controller.deletePayment();
      expect(deleted, isTrue);
      expect(controller.hasPayment.value, isFalse);
      expect(controller.paymentReceived.value, 0.0);
      expect(controller.balanceDue, 3600.0);
    });

    test('Payment persists and reloads across controller instances', () async {
      await controller.savePayment(
        receivedAmount: 1500.0,
        note: 'GPay Ref #987654',
      );

      // Create a fresh controller with same customer & month
      final newController = MonthlyEntriesController(api);
      newController.customer.value = {'id': 'cust_123'};
      newController.selectedYear.value = controller.selectedYear.value;
      newController.selectedMonth.value = controller.selectedMonth.value;

      await newController.loadPayment();

      expect(newController.hasPayment.value, isTrue);
      expect(newController.paymentReceived.value, 1500.0);
      expect(newController.paymentNote.value, 'GPay Ref #987654');
    });
  });
}
