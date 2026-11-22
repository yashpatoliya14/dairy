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
  String get customerId =>
      '${customer.value?['id'] ?? customer.value?['cid'] ?? ''}'.trim();
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

  /// Effective rate shown for customer reference.
  /// Note: The bill itself is ALWAYS computed by summing daily entry totals,
  /// never by multiplying total liters by an average rate.
  double get effectiveRate {
    if (customerDefaultPrice > 0) {
      return customerDefaultPrice;
    }
    if (entries.isNotEmpty) {
      final firstPrice = _asDouble(entries.first['price'], 0.0);
      if (firstPrice > 0 &&
          entries.every((e) => _asDouble(e['price'], 0.0) == firstPrice)) {
        return firstPrice;
      }
    }
    if (totalLiters.value > 0 && billTotalAmount > 0) {
      return double.parse(
          (billTotalAmount / totalLiters.value).toStringAsFixed(2));
    }
    return customerDefaultPrice;
  }

  /// Total bill amount.
  /// Computed as the exact sum of all entry totals for the billing period.
  /// Never calculated from an average per-liter rate or approximate multiplication.
  double get billTotalAmount {
    if (entries.isNotEmpty) {
      double sum = 0.0;
      for (final e in entries) {
        final total = _asDouble(e['total'], -1.0);
        if (total >= 0) {
          sum += total;
        } else {
          final l = _asDouble(e['liters'], 0.0);
          final p = _asDouble(e['price'], customerDefaultPrice);
          sum += double.parse((l * p).toStringAsFixed(2));
        }
      }
      return double.parse(sum.toStringAsFixed(2));
    }
    return double.parse(totalAmount.value.toStringAsFixed(2));
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
  final increment = 0.25;

  // Payment state
  final paymentReceived = 0.0.obs;
  final paymentNote = ''.obs;
  final paymentDate = Rxn<DateTime>();
  final hasPayment = false.obs;

  // Past months ledger & net settlement state
  final grossPastDue = 0.0.obs;
  final grossPastAdvance = 0.0.obs;
  final pastMonthsDue = 0.0.obs;
  final pastMonthsBreakdown = <String>[].obs;
  final netBalanceDue = 0.0.obs;
  final netAdvance = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    api.addPaymentChangeListener(_handleExternalPaymentChange);
  }

  @override
  void onClose() {
    api.removePaymentChangeListener(_handleExternalPaymentChange);
    super.onClose();
  }

  void _handleExternalPaymentChange(String cid, int y, int m) {
    if (cid == customerId && y == selectedYear.value && m == selectedMonth.value) {
      loadPayment();
      loadBillSummary();
    }
  }

  /// Set the customer and load the current month's data.
  void setCustomer(Map<String, dynamic> c) {
    customer.value = c;
    selectedYear.value = DateTime.now().year;
    selectedMonth.value = DateTime.now().month;
    loadProfile();
    loadMonth();
  }

  /// Load distributor / dairy profile if session is present.
  /// Reload latest customer details (default price/liters) from server.
  Future<void> refreshCustomer() async {
    if (customerId.isEmpty) return;
    try {
      final list = await api.getCustomers();
      for (final c in list) {
        if ('${c['id']}'.trim() == customerId) {
          customer.value = c;
          break;
        }
      }
    } catch (_) {}
  }

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
      // Load payment, past ledger summary, and refresh latest customer profile (e.g. edited default price)
      await loadPayment();
      await loadBillSummary();
      await refreshCustomer();
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
    String? mode,
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
        mode: mode,
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

  // ─── Payment Entry Methods ─────────────────────────────────────────────────

  /// Load the payment entry for the current month.
  Future<void> loadPayment() async {
    if (customerId.isEmpty) return;
    try {
      final data = await api.getPaymentEntry(
        customerId: customerId,
        year: selectedYear.value,
        month: selectedMonth.value,
      );
      if (data != null) {
        paymentReceived.value = _asDouble(data['receivedAmount'], 0.0);
        paymentNote.value = '${data['note'] ?? ''}'.trim();
        final dateStr = data['receivedDate'];
        paymentDate.value = dateStr != null ? DateTime.tryParse('$dateStr') : null;
        hasPayment.value = true;
      } else {
        _resetPayment();
      }
    } catch (e) {
      developer.log('Failed to load payment: $e', name: 'MonthlyEntries');
      _resetPayment();
    }
  }

  /// Load past months overdue ledger breakdown and overall net due from backend.
  Future<void> loadBillSummary() async {
    if (customerId.isEmpty) return;
    try {
      final summary = await api.getCustomerBillSummary(
        customerId: customerId,
        year: selectedYear.value,
        month: selectedMonth.value,
      );
      if (summary.isNotEmpty) {
        grossPastDue.value = _asDouble(summary['grossPastDue'], 0.0);
        grossPastAdvance.value = _asDouble(summary['grossPastAdvance'], 0.0);
        pastMonthsDue.value = _asDouble(summary['pastMonthsDue'], 0.0);
        final rawBreakdown = summary['pastMonthsBreakdown'] as List? ?? [];
        pastMonthsBreakdown.assignAll(rawBreakdown.map((e) => '$e').toList());
        netBalanceDue.value = _asDouble(summary['netBalanceDue'], 0.0);
        netAdvance.value = _asDouble(summary['netAdvance'], 0.0);

        if (summary.containsKey('thisMonthPaid')) {
          final paid = _asDouble(summary['thisMonthPaid'], 0.0);
          paymentReceived.value = paid;
          hasPayment.value = summary['hasPayment'] == true || paid > 0;
          if (summary['paymentNote'] != null) {
            paymentNote.value = '${summary['paymentNote']}';
          }
          if (summary['paymentDate'] != null) {
            paymentDate.value = DateTime.tryParse('${summary['paymentDate']}');
          }
        }
      }
    } catch (e) {
      developer.log('Failed to load bill summary: $e', name: 'MonthlyEntries');
    }
  }

  /// Save a payment entry for the current month.
  Future<bool> savePayment({
    required double receivedAmount,
    String? note,
    DateTime? receivedDate,
  }) async {
    if (customerId.isEmpty) return false;
    try {
      paymentReceived.value = receivedAmount;
      paymentNote.value = (note ?? '').trim();
      paymentDate.value = receivedDate ?? DateTime.now();
      hasPayment.value = true;

      final curDue = billTotalAmount > receivedAmount
          ? double.parse((billTotalAmount - receivedAmount).toStringAsFixed(2))
          : 0.0;
      final excess = receivedAmount > billTotalAmount
          ? double.parse((receivedAmount - billTotalAmount).toStringAsFixed(2))
          : 0.0;
      final totalCredits = grossPastAdvance.value + excess;
      final remPast = grossPastDue.value > totalCredits
          ? double.parse((grossPastDue.value - totalCredits).toStringAsFixed(2))
          : 0.0;
      pastMonthsDue.value = remPast;
      netBalanceDue.value = double.parse((remPast + curDue).toStringAsFixed(2));
      netAdvance.value = totalCredits > grossPastDue.value
          ? double.parse((totalCredits - grossPastDue.value).toStringAsFixed(2))
          : 0.0;

      await api.savePaymentEntry(
        customerId: customerId,
        year: selectedYear.value,
        month: selectedMonth.value,
        billAmount: billTotalAmount,
        receivedAmount: receivedAmount,
        note: note,
        receivedDate: receivedDate,
      );

      await loadBillSummary();
      return true;
    } catch (e) {
      developer.log('Failed to save payment: $e', name: 'MonthlyEntries');
      await loadBillSummary();
      return false;
    }
  }

  /// Delete the payment entry for the current month.
  Future<bool> deletePayment() async {
    if (customerId.isEmpty) return false;
    try {
      _resetPayment();
      final remPast = grossPastDue.value > grossPastAdvance.value
          ? double.parse((grossPastDue.value - grossPastAdvance.value).toStringAsFixed(2))
          : 0.0;
      pastMonthsDue.value = remPast;
      netBalanceDue.value = double.parse((remPast + billTotalAmount).toStringAsFixed(2));

      await api.deletePaymentEntry(
        customerId: customerId,
        year: selectedYear.value,
        month: selectedMonth.value,
      );

      await loadBillSummary();
      return true;
    } catch (e) {
      developer.log('Failed to delete payment: $e', name: 'MonthlyEntries');
      await loadBillSummary();
      return false;
    }
  }

  void _resetPayment() {
    paymentReceived.value = 0.0;
    paymentNote.value = '';
    paymentDate.value = null;
    hasPayment.value = false;
  }

  /// Balance due for the current month only.
  double get currentMonthDue {
    final diff = billTotalAmount - paymentReceived.value;
    return diff > 0 ? double.parse(diff.toStringAsFixed(2)) : 0.0;
  }

  /// Outstanding balance for this month (backward compatible).
  double get balanceDue => currentMonthDue;

  /// Overall net total payable across all periods (past overdue + current month due - credits).
  double get netTotalPayable {
    if (netBalanceDue.value > 0) return netBalanceDue.value;
    final past = pastMonthsDue.value;
    final cur = currentMonthDue;
    final adv = netAdvance.value;
    final net = cur + past - adv;
    return net > 0 ? double.parse(net.toStringAsFixed(2)) : 0.0;
  }

  /// Whether all dues for this customer are fully paid.
  bool get isFullyPaid =>
      hasPayment.value && paymentReceived.value >= billTotalAmount && pastMonthsDue.value == 0;

  /// Whether the bill is partially paid.
  bool get isPartiallyPaid =>
      hasPayment.value && paymentReceived.value > 0 && !isFullyPaid;

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
