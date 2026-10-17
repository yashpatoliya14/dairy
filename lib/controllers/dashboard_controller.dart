import 'package:get/get.dart';

import '../services/api_service.dart';

class DashboardController extends GetxController {
  DashboardController(this.api);

  final ApiService api;
  final customers = <Map<String, dynamic>>[].obs;
  final defaultLiters = 1.0.obs;
  final defaultPrice = 0.0.obs;
  final loading = true.obs;
  final error = ''.obs;
  final searchQuery = ''.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    loading.value = true;
    error.value = '';
    await Future.wait([loadCustomers(), loadSettings()]);
    loading.value = false;
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
