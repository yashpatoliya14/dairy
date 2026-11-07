import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/app_language.dart';
import '../services/app_update_service.dart';

class AppUpdateDialog extends StatelessWidget {
  const AppUpdateDialog({
    super.key,
    required this.info,
    required this.currentVersion,
    required this.onUpdateTap,
    required this.onDismiss,
  });

  final AppVersionInfo info;
  final String currentVersion;
  final VoidCallback onUpdateTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final isForced = info.mustForceUpdate;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 16,
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Hero Banner
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xff075e54), Color(0xff128c7e)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 2,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        LucideIcons.rocket,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    T.t('New Version Available!'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'v$currentVersion',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            LucideIcons.arrowRight,
                            size: 13,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'v${info.latestVersion}',
                          style: const TextStyle(
                            color: Color(0xff86efac),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Mandatory vs Recommended Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isForced
                            ? const Color(0xfffef2f2)
                            : const Color(0xfff0fdf4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isForced
                              ? const Color(0xfffecaca)
                              : const Color(0xffbbf7d0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isForced
                                ? LucideIcons.triangleAlert
                                : LucideIcons.sparkles,
                            size: 16,
                            color: isForced
                                ? const Color(0xffdc2626)
                                : const Color(0xff16a34a),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isForced
                                  ? T.t('Mandatory Update: You must update to continue using the application.')
                                  : T.t('Recommended Update: New features and improvements ready.'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isForced
                                    ? const Color(0xff991b1b)
                                    : const Color(0xff166534),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Changelog title
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.sparkles,
                          size: 15,
                          color: Color(0xff075e54),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          T.t('What’s New in this Update:'),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xff1e293b),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xffe2e8f0),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            info.apkSize,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xff475569),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Changelog box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xfff8fafc),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xffe2e8f0)),
                      ),
                      child: Text(
                        info.releaseNotes,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: Color(0xff334155),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Copy Link helper row
                    InkWell(
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(text: info.downloadUrl),
                        );
                        Get.snackbar(
                          T.t('Link Copied!'),
                          T.t('Direct APK download link copied to clipboard'),
                          snackPosition: SnackPosition.BOTTOM,
                          duration: const Duration(seconds: 2),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              LucideIcons.copy,
                              size: 13,
                              color: Color(0xff075e54),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              T.t('Copy APK Download Link'),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xff075e54),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Action Buttons
            Container(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onUpdateTap,
                      icon: const Icon(LucideIcons.downloadCloud, size: 18),
                      label: Text(
                        T.t('Update Now 🚀'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xff075e54),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  if (!isForced) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: onDismiss,
                      child: Text(
                        T.t('Remind Me Later'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
