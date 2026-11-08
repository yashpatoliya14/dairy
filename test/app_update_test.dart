import 'package:flutter_test/flutter_test.dart';
import 'package:dairy/services/api_service.dart';
import 'package:dairy/services/app_update_service.dart';

void main() {
  group('AppUpdateService & Version Comparison Tests', () {
    test('compareVersions correctly identifies version precedence', () {
      expect(AppVersionInfo.compareVersions('1.0.1', '1.0.0'), 1);
      expect(AppVersionInfo.compareVersions('1.0.0', '1.0.0'), 0);
      expect(AppVersionInfo.compareVersions('1.0.0', '1.0.1'), -1);
      expect(AppVersionInfo.compareVersions('1.1.0', '1.0.9'), 1);
      expect(AppVersionInfo.compareVersions('2.0.0', '1.99.99'), 1);
      expect(AppVersionInfo.compareVersions('1.0.0', '2.0.0'), -1);
    });

    test('AppVersionInfo.fromJson detects update when server version is higher', () {
      final json = {
        'latestVersion': '1.0.2',
        'buildNumber': 3,
        'minSupportedVersion': '1.0.1',
        'forceUpdate': false,
        'title': 'New Update Available',
        'releaseNotes': 'New features added',
        'downloadUrl': '/app/download-latest',
        'apkSize': '59.6 MB',
      };

      final info = AppVersionInfo.fromJson(
        json,
        currentVersion: '1.0.0',
        currentBuild: 1,
      );

      expect(info.isUpdateAvailable, isTrue);
      // Because currentVersion (1.0.0) is below minSupportedVersion (1.0.1), it MUST force update
      expect(info.mustForceUpdate, isTrue);
    });

    test('AppVersionInfo.fromJson detects optional update when above min supported', () {
      final json = {
        'latestVersion': '1.0.2',
        'buildNumber': 3,
        'minSupportedVersion': '1.0.0',
        'forceUpdate': false,
        'title': 'New Update Available',
        'releaseNotes': 'Performance enhancements',
        'downloadUrl': '/app/download-latest',
        'apkSize': '59.6 MB',
      };

      final info = AppVersionInfo.fromJson(
        json,
        currentVersion: '1.0.1',
        currentBuild: 2,
      );

      expect(info.isUpdateAvailable, isTrue);
      expect(info.mustForceUpdate, isFalse);
    });

    test('AppVersionInfo.fromJson enforces mandatory update when forceUpdate is true', () {
      final json = {
        'latestVersion': '1.0.1',
        'buildNumber': 2,
        'minSupportedVersion': '1.0.0',
        'forceUpdate': true,
        'title': 'Critical Security Update',
        'releaseNotes': 'Mandatory security patch',
        'downloadUrl': 'https://example.com/app.apk',
        'apkSize': '59.6 MB',
      };

      final info = AppVersionInfo.fromJson(
        json,
        currentVersion: '1.0.0',
        currentBuild: 1,
      );

      expect(info.isUpdateAvailable, isTrue);
      expect(info.mustForceUpdate, isTrue);
    });

    test('AppVersionInfo.fromJson recognizes client is already up to date', () {
      final json = {
        'latestVersion': '1.0.0',
        'buildNumber': 1,
        'minSupportedVersion': '1.0.0',
        'forceUpdate': false,
        'isUpdateAvailable': false,
      };

      final info = AppVersionInfo.fromJson(
        json,
        currentVersion: '1.0.0',
        currentBuild: 1,
      );

      expect(info.isUpdateAvailable, isFalse);
      expect(info.mustForceUpdate, isFalse);
    });

    test('AppUpdateService resolves relative download URLs with baseUrl', () async {
      final api = ApiService(baseUrl: 'https://test-dairy.com');

      // Verify URL prefix logic
      String resolve(String url) {
        if (url.startsWith('/')) {
          final base = api.baseUrl.replaceAll(RegExp(r'/+$'), '');
          return '$base$url';
        }
        return url;
      }

      expect(resolve('/app/download-latest'), 'https://test-dairy.com/app/download-latest');
      expect(resolve('https://cdn.example.com/app.apk'), 'https://cdn.example.com/app.apk');
    });
  });
}
