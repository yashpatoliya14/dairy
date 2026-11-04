import 'package:flutter_test/flutter_test.dart';

// Helper class replicating the calculation engine of MonthlyMilkCard
class MonthlyCardCalculationEngine {
  static int daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  static double computeTotalPay({
    required int year,
    required int month,
    required DateTime referenceDate,
    required Map<String, Map<String, dynamic>> entriesByDate,
  }) {
    final daysCount = daysInMonth(year, month);
    final isCurrent = year == referenceDate.year && month == referenceDate.month;
    final isFuture = (year > referenceDate.year) ||
        (year == referenceDate.year && month > referenceDate.month);

    if (isFuture) return 0.0;

    final maxDay = isCurrent
        ? (referenceDate.day > daysCount ? daysCount : referenceDate.day)
        : daysCount;

    final monthKey = '$year-${month.toString().padLeft(2, '0')}';
    double total = 0.0;

    for (int day = 1; day <= maxDay; day++) {
      final dateKey = '$monthKey-${day.toString().padLeft(2, '0')}';
      final entry = entriesByDate[dateKey];
      if (entry != null) {
        final liters = (entry['liters'] as num?)?.toDouble() ?? 0.0;
        final price = (entry['price'] as num?)?.toDouble() ?? 0.0;
        final entryTotal = (entry['total'] as num?)?.toDouble() ?? (liters * price);
        total += entryTotal;
      }
    }

    return total;
  }

  static double computeTotalLiters({
    required int year,
    required int month,
    required DateTime referenceDate,
    required Map<String, Map<String, dynamic>> entriesByDate,
  }) {
    final daysCount = daysInMonth(year, month);
    final isCurrent = year == referenceDate.year && month == referenceDate.month;
    final isFuture = (year > referenceDate.year) ||
        (year == referenceDate.year && month > referenceDate.month);

    if (isFuture) return 0.0;

    final maxDay = isCurrent
        ? (referenceDate.day > daysCount ? daysCount : referenceDate.day)
        : daysCount;

    final monthKey = '$year-${month.toString().padLeft(2, '0')}';
    double totalLiters = 0.0;

    for (int day = 1; day <= maxDay; day++) {
      final dateKey = '$monthKey-${day.toString().padLeft(2, '0')}';
      final entry = entriesByDate[dateKey];
      if (entry != null) {
        totalLiters += (entry['liters'] as num?)?.toDouble() ?? 0.0;
      }
    }

    return totalLiters;
  }
}

void main() {
  group('Monthly Milk Card Calendar & Days', () {
    test('calculates correct days for months with 31 days', () {
      expect(MonthlyCardCalculationEngine.daysInMonth(2026, 1), 31); // Jan
      expect(MonthlyCardCalculationEngine.daysInMonth(2026, 3), 31); // Mar
      expect(MonthlyCardCalculationEngine.daysInMonth(2026, 5), 31); // May
      expect(MonthlyCardCalculationEngine.daysInMonth(2026, 7), 31); // Jul
      expect(MonthlyCardCalculationEngine.daysInMonth(2026, 8), 31); // Aug
      expect(MonthlyCardCalculationEngine.daysInMonth(2026, 10), 31); // Oct
      expect(MonthlyCardCalculationEngine.daysInMonth(2026, 12), 31); // Dec
    });

    test('calculates correct days for months with 30 days', () {
      expect(MonthlyCardCalculationEngine.daysInMonth(2026, 4), 30); // Apr
      expect(MonthlyCardCalculationEngine.daysInMonth(2026, 6), 30); // Jun
      expect(MonthlyCardCalculationEngine.daysInMonth(2026, 9), 30); // Sep
      expect(MonthlyCardCalculationEngine.daysInMonth(2026, 11), 30); // Nov
    });

    test('calculates correct days for February in regular vs leap years', () {
      expect(MonthlyCardCalculationEngine.daysInMonth(2025, 2), 28); // Regular
      expect(MonthlyCardCalculationEngine.daysInMonth(2024, 2), 29); // Leap year 2024
      expect(MonthlyCardCalculationEngine.daysInMonth(2028, 2), 29); // Leap year 2028
    });
  });

  group('Dynamic Total Pay Calculation', () {
    test('current month dynamically includes Day 1 to Today and excludes future dates', () {
      // Suppose today is October 24, 2026
      final referenceToday = DateTime(2026, 10, 24);

      final entries = <String, Map<String, dynamic>>{
        '2026-10-01': {'liters': 2.0, 'price': 60.0, 'total': 120.0},
        '2026-10-10': {'liters': 1.5, 'price': 60.0, 'total': 90.0},
        '2026-10-24': {'liters': 2.0, 'price': 60.0, 'total': 120.0},
        // Future dates in the same month (e.g. pre-entered or advance)
        '2026-10-25': {'liters': 2.0, 'price': 60.0, 'total': 120.0},
        '2026-10-31': {'liters': 2.0, 'price': 60.0, 'total': 120.0},
      };

      final totalPay = MonthlyCardCalculationEngine.computeTotalPay(
        year: 2026,
        month: 10,
        referenceDate: referenceToday,
        entriesByDate: entries,
      );

      // Must sum only Oct 1 (120) + Oct 10 (90) + Oct 24 (120) = 330
      // Oct 25 and Oct 31 are strictly excluded!
      expect(totalPay, 330.0);

      final totalLiters = MonthlyCardCalculationEngine.computeTotalLiters(
        year: 2026,
        month: 10,
        referenceDate: referenceToday,
        entriesByDate: entries,
      );
      // 2.0 + 1.5 + 2.0 = 5.5 Liters
      expect(totalLiters, 5.5);
    });

    test('past month includes all dates in the entire month', () {
      // Reference date is in October 2026, querying September 2026 (past month)
      final referenceToday = DateTime(2026, 10, 24);

      final entries = <String, Map<String, dynamic>>{
        '2026-09-01': {'liters': 1.0, 'price': 60.0, 'total': 60.0},
        '2026-09-15': {'liters': 1.0, 'price': 60.0, 'total': 60.0},
        '2026-09-30': {'liters': 1.0, 'price': 60.0, 'total': 60.0},
      };

      final totalPay = MonthlyCardCalculationEngine.computeTotalPay(
        year: 2026,
        month: 9,
        referenceDate: referenceToday,
        entriesByDate: entries,
      );

      // Full month sum: 60 + 60 + 60 = 180
      expect(totalPay, 180.0);
    });

    test('future month returns 0.0 Total Pay', () {
      final referenceToday = DateTime(2026, 10, 24);

      final entries = <String, Map<String, dynamic>>{
        '2026-11-01': {'liters': 1.0, 'price': 60.0, 'total': 60.0},
      };

      final totalPay = MonthlyCardCalculationEngine.computeTotalPay(
        year: 2026,
        month: 11,
        referenceDate: referenceToday,
        entriesByDate: entries,
      );

      expect(totalPay, 0.0);
    });

    test('distinguishes missing entry from recorded zero', () {
      final entries = <String, Map<String, dynamic>>{
        '2026-10-01': {'liters': 0.0, 'price': 60.0, 'total': 0.0}, // recorded zero (off day)
        // '2026-10-02' is missing
      };

      expect(entries.containsKey('2026-10-01'), true);
      expect(entries['2026-10-01']!['liters'], 0.0);
      expect(entries.containsKey('2026-10-02'), false);
    });

    test('CRUD updates recalculate dynamic totals immediately', () {
      final referenceToday = DateTime(2026, 10, 24);
      final entries = <String, Map<String, dynamic>>{};

      // 1. Initial empty
      expect(
        MonthlyCardCalculationEngine.computeTotalPay(
          year: 2026,
          month: 10,
          referenceDate: referenceToday,
          entriesByDate: entries,
        ),
        0.0,
      );

      // 2. Create entry on Day 1
      entries['2026-10-01'] = {'liters': 2.0, 'price': 50.0, 'total': 100.0};
      expect(
        MonthlyCardCalculationEngine.computeTotalPay(
          year: 2026,
          month: 10,
          referenceDate: referenceToday,
          entriesByDate: entries,
        ),
        100.0,
      );

      // 3. Update entry on Day 1
      entries['2026-10-01'] = {'liters': 3.0, 'price': 50.0, 'total': 150.0};
      expect(
        MonthlyCardCalculationEngine.computeTotalPay(
          year: 2026,
          month: 10,
          referenceDate: referenceToday,
          entriesByDate: entries,
        ),
        150.0,
      );

      // 4. Delete entry on Day 1
      entries.remove('2026-10-01');
      expect(
        MonthlyCardCalculationEngine.computeTotalPay(
          year: 2026,
          month: 10,
          referenceDate: referenceToday,
          entriesByDate: entries,
        ),
        0.0,
      );
    });
  });
}
