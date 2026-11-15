import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_controller.dart';
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

  static const _cacheDairyNameKey = 'dash_cache_dairy_name';
  static const _cacheOwnerNameKey = 'dash_cache_owner_name';
  static const _cacheDefaultLitersKey = 'dash_cache_default_liters';
  static const _cacheDefaultPriceKey = 'dash_cache_default_price';
  static const _cacheCustomersKey = 'dash_cache_customers';
  static const _cacheTodaySummaryKey = 'dash_cache_today_summary';

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
    _prehydrateFromCache();
    load();
  }

  Future<void> _prehydrateFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dName = prefs.getString(_cacheDairyNameKey);
      final oName = prefs.getString(_cacheOwnerNameKey);
      final dLiters = prefs.getDouble(_cacheDefaultLitersKey);
      final dPrice = prefs.getDouble(_cacheDefaultPriceKey);
      final custRaw = prefs.getString(_cacheCustomersKey);
      final sumRaw = prefs.getString(_cacheTodaySummaryKey);

      if (dName != null && dName.isNotEmpty) dairyName.value = dName;
      if (oName != null && oName.isNotEmpty) ownerName.value = oName;
      if (dLiters != null) defaultLiters.value = dLiters;
      if (dPrice != null) defaultPrice.value = dPrice;

      if (custRaw != null && custRaw.isNotEmpty) {
        final decoded = jsonDecode(custRaw);
        if (decoded is List) {
          customers.assignAll(
            decoded
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList(),
          );
        }
      }

      if (sumRaw != null && sumRaw.isNotEmpty) {
        final decoded = jsonDecode(sumRaw);
        if (decoded is Map) {
          _applySummaryData(Map<String, dynamic>.from(decoded));
        }
      }
    } catch (_) {}
  }

  Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (dairyName.value.isNotEmpty) {
        await prefs.setString(_cacheDairyNameKey, dairyName.value);
      }
      if (ownerName.value.isNotEmpty) {
        await prefs.setString(_cacheOwnerNameKey, ownerName.value);
      }
      await prefs.setDouble(_cacheDefaultLitersKey, defaultLiters.value);
      await prefs.setDouble(_cacheDefaultPriceKey, defaultPrice.value);
      if (customers.isNotEmpty) {
        await prefs.setString(_cacheCustomersKey, jsonEncode(customers));
      }
      if (todaySummary.isNotEmpty) {
        await prefs.setString(_cacheTodaySummaryKey, jsonEncode(todaySummary));
      }
    } catch (_) {}
  }

  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheDairyNameKey);
      await prefs.remove(_cacheOwnerNameKey);
      await prefs.remove(_cacheDefaultLitersKey);
      await prefs.remove(_cacheDefaultPriceKey);
      await prefs.remove(_cacheCustomersKey);
      await prefs.remove(_cacheTodaySummaryKey);
    } catch (_) {}
  }

  Future<void>? _inFlightLoad;

  Future<void> load() {
    if (_inFlightLoad != null) return _inFlightLoad!;
    _inFlightLoad = _performLoad().whenComplete(() {
      _inFlightLoad = null;
    });
    return _inFlightLoad!;
  }

  Future<void> _performLoad() async {
    if (customers.isEmpty) {
      loading.value = true;
    }
    error.value = '';

    // Check for updates
    if (Get.isRegistered<AppController>()) {
      final appCtrl = Get.find<AppController>();
      final updateInfo =
          await appCtrl.updateService.checkForUpdate(silent: true);
      if (updateInfo != null && updateInfo.isUpdateAvailable) {
        loading.value = false;
        appCtrl.updateService.navigateToUpdateScreen(updateInfo);
        return;
      }
    }

    if (_isUpdatePending) {
      loading.value = false;
      return;
    }

    try {
      // 1. Instant single-roundtrip bootstrap (profile, settings, customers, todaySummary)
      final bootstrap = await api.getBootstrapData(date: formattedSelectedDate);
      _applyBootstrap(bootstrap);
    } catch (_) {
      // 2. Parallel graceful fallback
      await Future.wait([
        loadCustomers(),
        loadSettings(),
        loadProfile(),
        loadTodaySummary(),
      ]);
    } finally {
      loading.value = false;
      _saveCache();
    }
  }

  void _applyBootstrap(Map<String, dynamic> data) {
    if (data['profile'] is Map) {
      final profile = Map<String, dynamic>.from(data['profile'] as Map);
      dairyName.value = '${profile['dairyName'] ?? ''}'.trim();
      ownerName.value =
          '${profile['name'] ?? profile['fullName'] ?? ''}'.trim();
    }
    if (data['settings'] is Map) {
      final settings = Map<String, dynamic>.from(data['settings'] as Map);
      defaultLiters.value = _asDouble(settings['defaultLiters'], 1.0);
      defaultPrice.value = _asDouble(settings['defaultPrice'], 0.0);
    }
    if (data['customers'] is List) {
      final rawList = (data['customers'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      rawList.sort((a, b) {
        final aNum = int.tryParse(
                '${a['uniqueNumber'] ?? a['customerNumber'] ?? ''}') ??
            999999;
        final bNum = int.tryParse(
                '${b['uniqueNumber'] ?? b['customerNumber'] ?? ''}') ??
            999999;
        return aNum.compareTo(bNum);
      });
      customers.assignAll(rawList);
    }
    if (data['todaySummary'] is Map) {
      _applySummaryData(
        Map<String, dynamic>.from(data['todaySummary'] as Map),
      );
    }
    _saveCache();
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

  void _applySummaryData(Map<String, dynamic> summaryRes) {
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
  }

  Future<void> loadTodaySummary() async {
    if (_isUpdatePending) return;
    try {
      final summaryRes = await api.getDailySummary(date: formattedSelectedDate);
      _applySummaryData(summaryRes);
      if (isSelectedDateToday) {
        _saveCache();
      }
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
      _saveCache();
    } catch (exception) {
      error.value = error.value.isEmpty ? exception.toString() : error.value;
    }
  }

  Future<void> loadCustomers() async {
    if (_isUpdatePending) return;
    try {
      customers.assignAll(await api.getCustomers());
      _saveCache();
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
      _saveCache();
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
