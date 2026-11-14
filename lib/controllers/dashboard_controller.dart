import 'app_controller.dart';
import 'package:get/get.dart';

import '../services/api_service.dart';

class DashboardController extends GetxController {
  DashboardController(this.api);

  final ApiService api;
  final customers = <Map<String, dynamic>>[].obs;
  final defaultLiters = 1.0.obs;
  final defaultPrice = 0.0.obs;
  final dairyName = ''.obs;
  final ownerName = ''.obs;
  final loading = true.obs;
  final error = ''.obs;
  final searchQuery = ''.obs;

  // Selected date for dashboard view
  final selectedDate = DateTime.now().obs;

  // Summary observables
  final todaySummary = <String, dynamic>{}.obs;
  final todayLiters = 0.0.obs;
  final todayTotalAmount = 0.0.obs;
  final todayEntriesDone = 0.obs;
  final todayMissingCount = 0.obs;
  final todayTotalCustomers = 0.obs;
  final todaySentCount = 0.obs;
  final todayOpenedCount = 0.obs;
  final todayPendingCount = 0.obs;
  final todayFailedCount = 0.obs;
  final todayNotSentCount = 0.obs;
  final dailyCustomerItems = <Map<String, dynamic>>[].obs;

  // Daily list filter: 'all', 'missing', 'completed' - defaults to 'completed' (milk entry done today)
  final dailyFilter = 'completed'.obs;

  bool get isSelectedDateToday {
    final now = DateTime.now();
    final d = selectedDate.value;
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  String get formattedSelectedDate {
    final d = selectedDate.value;
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  bool get _isUpdatePending {
    if (Get.isRegistered<AppController>()) {
      return Get.find<AppController>().updateService.hasUpdate.value;
    }
    return false;
  }

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    loading.value = true;
    error.value = '';

    // Check for updates on top of dashboard data fetch
    if (Get.isRegistered<AppController>()) {
      final appCtrl = Get.find<AppController>();
      final updateInfo = await appCtrl.updateService.checkForUpdate(silent: true);
      if (updateInfo != null && updateInfo.isUpdateAvailable) {
        loading.value = false;
        appCtrl.updateService.navigateToUpdateScreen(updateInfo);
        return; // Stop loading: dashboard data is not fetched and dashboard is not shown
      }
    }

    if (_isUpdatePending) {
      loading.value = false;
      return;
    }

    await Future.wait([
      loadCustomers(),
      loadSettings(),
      loadProfile(),
      loadTodaySummary(),
    ]);
    loading.value = false;
  }

  void setDailyFilter(String filter) {
    dailyFilter.value = filter;
  }

  Future<void> setSelectedDate(DateTime date) async {
    if (_isUpdatePending) return;
    selectedDate.value = date;
    await loadTodaySummary();
  }

  Future<void> previousDay() async {
    if (_isUpdatePending) return;
    await setSelectedDate(selectedDate.value.subtract(const Duration(days: 1)));
  }

  Future<void> nextDay() async {
    if (_isUpdatePending) return;
    await setSelectedDate(selectedDate.value.add(const Duration(days: 1)));
  }

  Future<void> goToToday() async {
    if (_isUpdatePending) return;
    await setSelectedDate(DateTime.now());
  }

  Future<void> loadTodaySummary() async {
    if (_isUpdatePending) return;
    try {
      final summaryRes = await api.getDailySummary(date: formattedSelectedDate);
      todaySummary.assignAll(summaryRes);
      final summary = summaryRes['summary'] as Map? ?? {};
      todayLiters.value = _asDouble(summary['totalLiters'], 0.0);
      todayTotalAmount.value = _asDouble(summary['totalAmount'], 0.0);
      todayEntriesDone.value =
          int.tryParse('${summary['completedEntriesCount']}') ?? 0;
      todayMissingCount.value =
          int.tryParse('${summary['missingEntriesCount']}') ?? 0;
      todayTotalCustomers.value =
          int.tryParse('${summary['totalCustomers']}') ?? customers.length;
      todaySentCount.value = int.tryParse('${summary['sentCount']}') ?? 0;
      todayOpenedCount.value = int.tryParse('${summary['openedCount']}') ?? 0;
      todayPendingCount.value = int.tryParse('${summary['pendingCount']}') ?? 0;
      todayFailedCount.value = int.tryParse('${summary['failedCount']}') ?? 0;
      todayNotSentCount.value = int.tryParse('${summary['notSentCount']}') ?? 0;

      final rawList = summaryRes['customers'] as List? ?? [];
      dailyCustomerItems.assignAll(
        rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      );
    } catch (_) {
      // Non-blocking fallback
    }
  }

  Future<void> loadProfile() async {
    if (_isUpdatePending) return;
    try {
      final profile = await api.getProfile();
      dairyName.value = '${profile['dairyName'] ?? ''}'.trim();
      ownerName.value = '${profile['name'] ?? profile['fullName'] ?? ''}'
          .trim();
    } catch (exception) {
      error.value = error.value.isEmpty ? exception.toString() : error.value;
    }
  }

  Future<void> loadCustomers() async {
    if (_isUpdatePending) return;
    try {
      customers.assignAll(await api.getCustomers());
    } catch (exception) {
      error.value = exception.toString();
    }
  }

  Future<void> loadSettings() async {
    if (_isUpdatePending) return;
    try {
      final settings = await api.getSettings();
      defaultLiters.value = _asDouble(settings['defaultLiters'], 1);
      defaultPrice.value = _asDouble(settings['defaultPrice'], 0);
    } catch (exception) {
      error.value = exception.toString();
    }
  }

  Future<bool> saveCustomerMilkEntry(
    String customerId,
    double liters,
    double price, {
    DateTime? date,
  }) async {
    try {
      await api.addMilkEntry(
        customerId,
        date: date ?? selectedDate.value,
        liters: liters,
        price: price,
      );
      await Future.wait([
        loadTodaySummary(),
        loadCustomers(),
      ]);
      return true;
    } catch (_) {
      return false;
    }
  }

  void setSearch(String value) =>
      searchQuery.value = value.trim().toLowerCase();

  double _asDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? fallback;
  }
}
