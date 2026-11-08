import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api_service.dart';
import '../views/app_update_screen.dart';

class AppVersionInfo {
  const AppVersionInfo({
    required this.latestVersion,
    required this.buildNumber,
    required this.minSupportedVersion,
    required this.forceUpdate,
    required this.title,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.apkSize,
    required this.publishedAt,
    required this.isUpdateAvailable,
    required this.mustForceUpdate,
  });

  factory AppVersionInfo.fromJson(Map<String, dynamic> json, {
    required String currentVersion,
    required int currentBuild,
  }) {
    final latestVer = '${json['latestVersion'] ?? '1.0.0'}'.trim();
    final buildNum = (json['buildNumber'] as num?)?.toInt() ?? 1;
    final minVer = '${json['minSupportedVersion'] ?? latestVer}'.trim();
    final serverForce = json['forceUpdate'] == true;

    // Compare versions locally as well to be 100% resilient
    final isOutdatedVer = compareVersions(latestVer, currentVersion) > 0;
    final isOutdatedBuild = buildNum > currentBuild;
    final updateAvailable = json['isUpdateAvailable'] == true || isOutdatedVer || isOutdatedBuild;

    final isBelowMinVer = compareVersions(minVer, currentVersion) > 0;
    final force = updateAvailable && (serverForce || json['mustForceUpdate'] == true || isBelowMinVer);

    return AppVersionInfo(
      latestVersion: latestVer,
      buildNumber: buildNum,
      minSupportedVersion: minVer,
      forceUpdate: serverForce,
      title: '${json['title'] ?? 'New Version Available! 🚀'}',
      releaseNotes: '${json['releaseNotes'] ?? 'Bug fixes and performance improvements.'}',
      downloadUrl: '${json['downloadUrl'] ?? '/app/download-latest'}',
      apkSize: '${json['apkSize'] ?? '59.7 MB'}',
      publishedAt: '${json['publishedAt'] ?? ''}',
      isUpdateAvailable: updateAvailable,
      mustForceUpdate: force,
    );
  }

  final String latestVersion;
  final int buildNumber;
  final String minSupportedVersion;
  final bool forceUpdate;
  final String title;
  final String releaseNotes;
  final String downloadUrl;
  final String apkSize;
  final String publishedAt;
  final bool isUpdateAvailable;
  final bool mustForceUpdate;

  static int compareVersions(String v1, String v2) {
    final p1 = v1.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final p2 = v2.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final len = p1.length > p2.length ? p1.length : p2.length;

    for (var i = 0; i < len; i++) {
      final a = i < p1.length ? p1[i] : 0;
      final b = i < p2.length ? p2[i] : 0;
      if (a > b) return 1;
      if (a < b) return -1;
    }
    return 0;
  }
}

class AppUpdateService {
  AppUpdateService({required this.api});

  final ApiService api;

  // The client installed version and build number
  static const String currentVersion = '1.0.4';
  static const int currentBuildNumber = 5;

  Timer? _checkTimer;
  bool _isChecking = false;
  bool _isScreenOpened = false;

  final Rxn<AppVersionInfo> latestInfo = Rxn<AppVersionInfo>();
  final RxBool hasUpdate = false.obs;

  /// Trigger an update check. If update is detected, redirects directly to AppUpdateScreen.
  Future<AppVersionInfo?> checkForUpdate({
    bool silent = true,
  }) async {
    if (_isChecking) return latestInfo.value;
    _isChecking = true;

    try {
      final res = await api.checkAppVersion(
        currentVersion: currentVersion,
        buildNumber: currentBuildNumber,
      );

      final info = AppVersionInfo.fromJson(
        res,
        currentVersion: currentVersion,
        currentBuild: currentBuildNumber,
      );

      latestInfo.value = info;
      hasUpdate.value = info.isUpdateAvailable;

      if (info.isUpdateAvailable) {
        navigateToUpdateScreen(info);
      }

      return info;
    } catch (_) {
      // Fail silently without disrupting user
      return null;
    } finally {
      _isChecking = false;
    }
  }

  /// Start background interval checks (e.g. every 15 minutes)
  void startPeriodicBackgroundChecks({
    Duration interval = const Duration(minutes: 15),
  }) {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(interval, (_) {
      checkForUpdate(silent: true);
    });
  }

  void stopPeriodicChecks() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  /// Replaces the current navigation stack completely with AppUpdateScreen.
  /// The user cannot access the dashboard or any other screen until they update.
  void navigateToUpdateScreen(AppVersionInfo info) {
    if (_isScreenOpened) return;
    _isScreenOpened = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.offAll(() => AppUpdateScreen(
        info: info,
        updateService: this,
      ));
    });
  }

  /// Resolves the download URL against the API baseUrl if relative, and launches via external application
  Future<bool> launchDownloadUrl(String url) async {
    String resolvedUrl = url.trim();
    if (resolvedUrl.startsWith('/')) {
      final base = api.baseUrl.replaceAll(RegExp(r'/+$'), '');
      resolvedUrl = '$base$resolvedUrl';
    }

    final uri = Uri.parse(resolvedUrl);
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        return await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      return false;
    }
  }
}
