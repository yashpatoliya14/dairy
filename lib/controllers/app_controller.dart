import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../services/api_service.dart';
import '../services/app_language.dart';
import '../services/app_update_service.dart';
import '../widgets/dairy_milk_loader.dart';
import 'dashboard_controller.dart';

class AppController extends GetxController with WidgetsBindingObserver {
  AppController(
    this.api, {
    this.authPageBuilder,
    AppUpdateService? updateService,
  }) : updateService = updateService ?? AppUpdateService(api: api);

  final ApiService api;
  final Widget Function(ApiService api)? authPageBuilder;
  final AppUpdateService updateService;
  final ready = false.obs;

  Timer? _sessionCheckTimer;
  bool _isRedirecting = false;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    api.onSessionExpired = handleSessionExpired;
    _restoreSession();

    // Periodically verify session validity when running in production
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _sessionCheckTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        checkSessionValidity(remote: true);
      });

      // Periodic background checks for updates (checked every 1 minute for instant OTA)
      updateService.startPeriodicBackgroundChecks(
        interval: const Duration(minutes: 1),
      );
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionCheckTimer?.cancel();
    updateService.stopPeriodicChecks();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      checkSessionValidity(remote: true);
      if (!Platform.environment.containsKey('FLUTTER_TEST')) {
        updateService.checkForUpdate(silent: true);
      }
    }
  }

  Future<void> checkSessionValidity({bool remote = false}) async {
    if (!ready.value || !api.hasSession || _isRedirecting) return;
    if (api.isTokenExpired) {
      handleSessionExpired(reason: 'Session expired. Please log in again.');
      return;
    }
    if (remote && !Platform.environment.containsKey('FLUTTER_TEST')) {
      try {
        await api.getProfile();
      } catch (_) {
        // If 401 Unauthorized, api.onSessionExpired is invoked automatically by ApiService._send.
        // Network/offline failures are safely ignored so offline collection continues smoothly.
      }
    }
  }

  Future<void> checkForUpdatesManual() async {
    await updateService.checkForUpdate(silent: false);
  }

  Future<void> handleSessionExpired({String? reason}) async {
    if (_isRedirecting) return;
    _isRedirecting = true;

    try {
      DairyMilkLoadingService.reset();
      await api.logout();
      await DashboardController.clearCache();
      try {
        if (Get.isRegistered<DashboardController>()) {
          Get.delete<DashboardController>();
        }
      } catch (_) {}

      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Redirect to login screen
        if (authPageBuilder != null) {
          Get.offAll(() => authPageBuilder!(api));
        } else {
          Get.offAllNamed('/auth');
        }

        final isDeactivated =
            reason?.toLowerCase().contains('deactivated') == true;
        final title =
            isDeactivated ? 'Account Deactivated' : 'Session Expired';

        Get.snackbar(
          T.t(title),
          T.t(reason ?? 'Your session has expired. Please log in again.'),
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 5),
        );
      });
    } finally {
      Future.delayed(const Duration(seconds: 2), () {
        _isRedirecting = false;
      });
    }
  }

  Future<void> _restoreSession() async {
    final splashWait = Future.delayed(
      Platform.environment.containsKey('FLUTTER_TEST')
          ? Duration.zero
          : const Duration(milliseconds: 350),
    );
    try {
      await Future.wait([
        api.loadSession(),
        splashWait,
        if (!Platform.environment.containsKey('FLUTTER_TEST'))
          updateService.checkForUpdate(silent: true).timeout(
            const Duration(seconds: 4),
            onTimeout: () => null,
          ),
      ]);

      // If authenticated, keep splash screen active until dashboard details are fetched
      if (api.hasSession && !Platform.environment.containsKey('FLUTTER_TEST')) {
        final hasBlockingUpdate = updateService.hasUpdate.value &&
            (updateService.latestInfo.value?.mustForceUpdate == true ||
                updateService.latestInfo.value?.forceUpdate == true);
        if (!hasBlockingUpdate) {
          final dashCtrl = Get.isRegistered<DashboardController>()
              ? Get.find<DashboardController>()
              : Get.put(DashboardController(api));
          await dashCtrl.load().timeout(
            const Duration(seconds: 8),
            onTimeout: () => null,
          );
        }
      }
    } catch (_) {
      // Graceful fallback so app always loads even if network drops
    } finally {
      ready.value = true;
    }
  }
}
