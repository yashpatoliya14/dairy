import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../services/api_service.dart';
import '../services/app_language.dart';
import '../widgets/dairy_milk_loader.dart';
import 'dashboard_controller.dart';

class AppController extends GetxController with WidgetsBindingObserver {
  AppController(this.api, {this.authPageBuilder});

  final ApiService api;
  final Widget Function(ApiService api)? authPageBuilder;
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
      _sessionCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        checkSessionValidity();
      });
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionCheckTimer?.cancel();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      checkSessionValidity();
    }
  }

  void checkSessionValidity() {
    if (ready.value && api.hasSession && api.isTokenExpired) {
      handleSessionExpired(reason: 'Session expired. Please log in again.');
    }
  }

  Future<void> handleSessionExpired({String? reason}) async {
    if (_isRedirecting) return;
    _isRedirecting = true;

    try {
      DairyMilkLoadingService.reset();
      await api.logout();
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

        Get.snackbar(
          T.t('Session Expired'),
          T.t(reason ?? 'Your session has expired. Please log in again.'),
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
        );
      });
    } finally {
      Future.delayed(const Duration(seconds: 2), () {
        _isRedirecting = false;
      });
    }
  }

  Future<void> _restoreSession() async {
    try {
      await api.loadSession();
    } finally {
      ready.value = true;
    }
  }
}
