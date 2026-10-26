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

  // Today's summary observables
  final todaySummary = <String, dynamic>{}.obs;
  final todayLiters = 0.0.obs;
  final todayEntriesDone = 0.obs;
  final todayTotalCustomers = 0.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    loading.value = true;
    error.value = '';
    await Future.wait([
      loadCustomers(),
      loadSettings(),
      loadProfile(),
      loadTodaySummary(),
    ]);
    loading.value = false;
  }

  Future<void> loadTodaySummary() async {
    try {
      final summaryRes = await api.getDailySummary();
      todaySummary.assignAll(summaryRes);
      final summary = summaryRes['summary'] as Map? ?? {};
      todayLiters.value = _asDouble(summary['totalLiters'], 0.0);
      todayEntriesDone.value =
          int.tryParse('${summary['completedEntriesCount']}') ?? 0;
      todayTotalCustomers.value =
          int.tryParse('${summary['totalCustomers']}') ?? customers.length;
    } catch (_) {
      // Non-blocking fallback
    }
  }

  Future<void> loadProfile() async {
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
    try {
      customers.assignAll(await api.getCustomers());
    } catch (exception) {
      error.value = exception.toString();
    }
  }

  Future<void> loadSettings() async {
    try {
      final settings = await api.getSettings();
      defaultLiters.value = _asDouble(settings['defaultLiters'], 1);
      defaultPrice.value = _asDouble(settings['defaultPrice'], 0);
    } catch (exception) {
      error.value = exception.toString();
    }
  }

  void setSearch(String value) =>
      searchQuery.value = value.trim().toLowerCase();

  double _asDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? fallback;
  }
}
