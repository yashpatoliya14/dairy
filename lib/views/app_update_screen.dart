import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/app_language.dart';
import '../services/app_update_service.dart';

class AppUpdateScreen extends StatelessWidget {
  const AppUpdateScreen({
    super.key,
    required this.info,
    required this.updateService,
  });

  final AppVersionInfo info;
  final AppUpdateService updateService;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Strictly prevents pressing back to access the app
      child: Scaffold(
        backgroundColor: const Color(0xff09281a),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xff062015),
                Color(0xff0f3d28),
                Color(0xff124a31),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  const Spacer(flex: 1),

                  // Hero Icon Container with layered soft glow
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xff4ade80).withValues(alpha: 0.5),
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xff22c55e).withValues(alpha: 0.25),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        LucideIcons.arrowUpCircle,
                        color: Color(0xff4ade80),
                        size: 48,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Main Heading
                  Text(
                    T.t('Update is Available'),
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 10),

                  // Mandatory Notice
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xfffef2f2).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xffef4444).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.alertTriangle,
                          color: Color(0xfff87171),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            T.t('You must update your application. Without update, you do not have access.'),
                            style: const TextStyle(
                              color: Color(0xfffecaca),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Version Transition Pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'v${AppUpdateService.currentVersion}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(
                            LucideIcons.arrowRight,
                            size: 15,
                            color: Color(0xff4ade80),
                          ),
                        ),
                        Text(
                          'v${info.latestVersion}',
                          style: const TextStyle(
                            color: Color(0xff4ade80),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xff4ade80).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            info.apkSize,
                            style: const TextStyle(
                              color: Color(0xff86efac),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // What's New Box
                  Flexible(
                    flex: 3,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                LucideIcons.sparkles,
                                size: 16,
                                color: Color(0xff4ade80),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                T.t('What’s New in this Release:'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Text(
                                info.releaseNotes,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 13,
                                  height: 1.55,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(flex: 1),

                  // Update Now Button (Primary)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => updateService.launchDownloadUrl(info.downloadUrl),
                      icon: const Icon(LucideIcons.downloadCloud, size: 20),
                      label: Text(
                        T.t('Update Now 🚀'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xff22c55e),
                        foregroundColor: const Color(0xff052e16),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Secondary Action: Copy APK Link
                  InkWell(
                    onTap: () {
                      Clipboard.setData(
                        ClipboardData(text: info.downloadUrl),
                      );
                      Get.snackbar(
                        T.t('Link Copied!'),
                        T.t('Direct APK download link copied to clipboard'),
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: Colors.white,
                        colorText: const Color(0xff0f3d28),
                        duration: const Duration(seconds: 2),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            LucideIcons.copy,
                            size: 13,
                            color: Color(0xff86efac),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            T.t('Copy APK Download Link'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xff86efac),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
