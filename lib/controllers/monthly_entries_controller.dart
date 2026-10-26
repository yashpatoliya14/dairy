import 'package:get/get.dart';
import 'dart:developer' as developer;

import '../services/api_service.dart';

/// Snapshot of a previous entry value used for undo operations.
class UndoSnapshot {
  UndoSnapshot({
    required this.customerId,
    required this.entryDate,
    required this.wasNew,
    this.previousLiters,
    this.previousPrice,
    this.previousTotal,
    this.entryId,
  });

  final String customerId;
  final String entryDate;
  final bool wasNew;
  final double? previousLiters;
  final double? previousPrice;
  final double? previousTotal;
  String? entryId;

  @override
  String toString() =>
      'UndoSnapshot(date=$entryDate, wasNew=$wasNew, prev=$previousLiters)';
}

class MonthlyEntriesController extends GetxController {
  MonthlyEntriesController(this.api);

  final ApiService api;

  // Customer state
  final customer = Rxn<Map<String, dynamic>>();
  String get customerId => '${customer.value?['id'] ?? ''}'.trim();
  String get customerName =>
      '${customer.value?['name'] ?? customer.value?['fullName'] ?? ''}';
  String get customerNumber =>
      '${customer.value?['uniqueNumber'] ?? customer.value?['customerNumber'] ?? '—'}';
  String get customerPhone =>
      '${customer.value?['phoneNumber'] ?? customer.value?['phone'] ?? ''}'.trim();
  double get customerDefaultLiters =>
      _asDouble(customer.value?['liters'], 1.0);
  double get customerDefaultPrice =>
      _asDouble(customer.value?['price'], 0.0);

  // Dairy & Distributor profile
  final dairyName = 'Dairy Desk'.obs;
  final distributorName = 'Haresh Sambad'.obs;
  final distributorPhone = '+91 9104152524'.obs;

  // Month state
  final selectedYear = DateTime.now().year.obs;
  final selectedMonth = DateTime.now().month.obs;

  // Data state
  final loading = false.obs;
  final error = ''.obs;
  final entries = <Map<String, dynamic>>[].obs;
  final daysInMonth = 30.obs;
  final totalLiters = 0.0.obs;
  final totalAmount = 0.0.obs;
  final entriesCount = 0.obs;

  // Delivery statistics for professional bill
  int get activeDeliveryDays =>
      entries.where((e) => _asDouble(e['liters'], 0) > 0).length;

  int get zeroDeliveryDays =>
      entries.where((e) => _asDouble(e['liters'], -1) == 0).length;

  double get effectiveRate {
    if (totalLiters.value > 0 && totalAmount.value > 0) {
      return totalAmount.value / totalLiters.value;
    }
    return customerDefaultPrice;
  }

  double get averageDailyLiters {
    final active = activeDeliveryDays;
    return active > 0 ? (totalLiters.value / active) : 0.0;
  }

  // Saving state
  final saving = false.obs;

  // Undo stack (most recent first)
  final undoStack = <UndoSnapshot>[].obs;
  static const int maxUndoHistory = 10;

  // Quantity increment
  final increment = 0.5;

  /// Set the customer and load the current month's data.
  void setCustomer(Map<String, dynamic> c) {
    customer.value = c;
    selectedYear.value = DateTime.now().year;
    selectedMonth.value = DateTime.now().month;
    loadProfile();
    loadMonth();
  }

  /// Load distributor / dairy profile if session is present.
  Future<void> loadProfile() async {
    if (!api.hasSession) return;
    try {
      final p = await api.getProfile();
      if (p['dairyName'] != null && '${p['dairyName']}'.trim().isNotEmpty) {
        dairyName.value = '${p['dairyName']}';
      }
      if (p['name'] != null && '${p['name']}'.trim().isNotEmpty) {
        distributorName.value = '${p['name']}';
      }
      if (p['phoneNumber'] != null && '${p['phoneNumber']}'.trim().isNotEmpty) {
        distributorPhone.value = '${p['phoneNumber']}';
      }
    } catch (_) {
      // Graceful fallback to default values
    }
  }

  /// Navigate to the previous month.
  void previousMonth() {
    if (selectedMonth.value == 1) {
      selectedMonth.value = 12;
      selectedYear.value -= 1;
    } else {
      selectedMonth.value -= 1;
    }
    loadMonth();
  }

  /// Navigate to the next month.
  void nextMonth() {
    if (selectedMonth.value == 12) {
      selectedMonth.value = 1;
      selectedYear.value += 1;
    } else {
      selectedMonth.value += 1;
    }
    loadMonth();
  }

  /// Set month/year directly.
  void setMonthYear(int year, int month) {
    selectedYear.value = year;
    selectedMonth.value = month;
    loadMonth();
  }

  /// Load entries for the selected month.
  Future<void> loadMonth() async {
    if (customerId.isEmpty) return;
    loading.value = true;
    error.value = '';
    try {
      final data = await api.getMilkEntriesForMonth(
        customerId,
        year: selectedYear.value,
        month: selectedMonth.value,
      );
      daysInMonth.value = data['daysInMonth'] as int? ?? 30;
      totalLiters.value = _asDouble(data['totalLiters'], 0.0);
      totalAmount.value = _asDouble(data['totalAmount'], 0.0);
      entriesCount.value = data['entriesCount'] as int? ?? 0;
      final entryList = data['entries'] as List? ?? [];
      entries.assignAll(
        entryList
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
      );
    } catch (e) {
      error.value = e.toString();
      developer.log('Failed to load month: $e', name: 'MonthlyEntries');
    } finally {
      loading.value = false;
    }
  }

  /// Get the entry for a specific day (1-indexed), or null.
  Map<String, dynamic>? entryForDay(int day) {
    final dateStr = _dateString(selectedYear.value, selectedMonth.value, day);
    for (final entry in entries) {
      if ('${entry['entryDate']}' == dateStr) return entry;
    }
    return null;
  }

  /// Build the date string for a given day.
  String _dateString(int year, int month, int day) {
    final m = month.toString().padLeft(2, '0');
    final d = day.toString().padLeft(2, '0');
    return '$year-$m-$d';
  }

  /// Save or update a milk entry for a specific date.
  Future<bool> saveEntry({
    required int day,
    required double liters,
    required double price,
  }) async {
    if (customerId.isEmpty || saving.value) return false;
    saving.value = true;

    final dateStr = _dateString(selectedYear.value, selectedMonth.value, day);
    final existing = entryForDay(day);

    // Capture undo snapshot before saving
    final snapshot = UndoSnapshot(
      customerId: customerId,
      entryDate: dateStr,
      wasNew: existing == null,
      previousLiters: existing != null ? _asDouble(existing['liters'], 0) : null,
      previousPrice: existing != null ? _asDouble(existing['price'], 0) : null,
      previousTotal: existing != null ? _asDouble(existing['total'], 0) : null,
      entryId: existing?['id']?.toString(),
    );

    try {
      final result = await api.addMilkEntry(
        customerId,
        date: DateTime.utc(
          selectedYear.value,
          selectedMonth.value,
          day,
        ),
        liters: liters,
        price: price,
      );

      // Update the entryId in snapshot (for new entries)
      snapshot.entryId = result['id']?.toString();

      // Push onto undo stack
      _pushUndo(snapshot);

      // Refresh data
      await loadMonth();
      saving.value = false;
      return true;
    } catch (e) {
      developer.log('Failed to save entry: $e', name: 'MonthlyEntries');
      saving.value = false;
      return false;
    }
  }

  /// Execute undo of the most recent save.
  Future<bool> undo() async {
    if (undoStack.isEmpty || saving.value) return false;
    saving.value = true;

    final snapshot = undoStack.first;

    try {
      if (snapshot.wasNew && snapshot.entryId != null) {
        // Entry was newly created — delete it
        await api.deleteMilkEntry(customerId, snapshot.entryId!);
      } else if (!snapshot.wasNew &&
          snapshot.previousLiters != null &&
          snapshot.previousPrice != null) {
        // Entry was edited — restore previous values
        final dateParts = snapshot.entryDate.split('-');
        final year = int.parse(dateParts[0]);
        final month = int.parse(dateParts[1]);
        final day = int.parse(dateParts[2]);
        await api.addMilkEntry(
          customerId,
          date: DateTime.utc(year, month, day),
          liters: snapshot.previousLiters!,
          price: snapshot.previousPrice!,
        );
      }

      undoStack.removeAt(0);
      await loadMonth();
      saving.value = false;
      return true;
    } catch (e) {
      developer.log('Undo failed: $e', name: 'MonthlyEntries');
      saving.value = false;
      return false;
    }
  }

  void _pushUndo(UndoSnapshot snapshot) {
    undoStack.insert(0, snapshot);
    if (undoStack.length > maxUndoHistory) {
      undoStack.removeRange(maxUndoHistory, undoStack.length);
    }
  }

  void clearUndo() => undoStack.clear();

  /// Whether we're viewing a future month (shouldn't allow entries).
  bool get isFutureMonth {
    final now = DateTime.now();
    return selectedYear.value > now.year ||
        (selectedYear.value == now.year && selectedMonth.value > now.month);
  }

  int get missingDays => daysInMonth.value - entriesCount.value;

  static double _asDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? fallback;
  }
}
