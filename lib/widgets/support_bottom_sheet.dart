import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_language.dart';

class SupportHelper {
  static const String supportNumber = '9104152524';
  static const String formattedNumber = '+91 91041 52524';

  /// Open WhatsApp chat with the support number.
  static Future<void> openWhatsApp({
    String phone = supportNumber,
    String? message,
    BuildContext? context,
  }) async {
    final cleanDigits = phone.replaceAll(RegExp(r'\D'), '');
    final internationalPhone =
        cleanDigits.length == 10 ? '91$cleanDigits' : cleanDigits;

    final query = message != null && message.trim().isNotEmpty
        ? '?text=${Uri.encodeComponent(message.trim())}'
        : '';

    final whatsappUri =
        Uri.parse('https://wa.me/$internationalPhone$query');

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    // Fallback to phone dialer if WhatsApp is unavailable
    final telUri = Uri.parse('tel:+$internationalPhone');
    if (await canLaunchUrl(telUri)) {
      await launchUrl(telUri);
    } else if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${T.t('Contact')}: $formattedNumber',
          ),
        ),
      );
    }
  }

  /// Make a direct phone call to support.
  static Future<void> callSupport({
    String phone = supportNumber,
    BuildContext? context,
  }) async {
    final cleanDigits = phone.replaceAll(RegExp(r'\D'), '');
    final telUri = Uri.parse('tel:+91$cleanDigits');
    if (await canLaunchUrl(telUri)) {
      await launchUrl(telUri);
    } else if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${T.t('Contact')}: $formattedNumber',
          ),
        ),
      );
    }
  }

  /// Show the feedback dialog and send feedback message to 9104152524 on WhatsApp.
  static Future<void> showFeedbackDialog(BuildContext context) async {
    final feedbackController = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xfff3e8ff),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                LucideIcons.messageSquareText,
                size: 18,
                color: Color(0xff9333ea),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                T.t('Send feedback'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              tooltip: T.t('Close'),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => Navigator.pop(dCtx, false),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              T.t('Your feedback will be sent directly to our team via WhatsApp.'),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: feedbackController,
              maxLines: 4,
              autofocus: true,
              decoration: InputDecoration(
                hintText: T.t('Tell us what we can improve'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: Text(T.t('Cancel')),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dCtx, true),
            icon: const Icon(LucideIcons.send, size: 16),
            label: Text(T.t('Send on WhatsApp')),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xff25D366),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    final message = feedbackController.text.trim();
    feedbackController.dispose();

    if (submitted == true && message.isNotEmpty) {
      if (!context.mounted) return;
      await openWhatsApp(
        message: '💬 *Dairy Desk Feedback:*\n$message',
        context: context,
      );
    }
  }

  /// Show the Support bottom sheet with Contact & Feedback options.
  static Future<void> showSupportSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xffecfdf5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      LucideIcons.headphones,
                      color: Color(0xff059669),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          T.t('Contact & Support'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff0f172a),
                          ),
                        ),
                        Text(
                          formattedNumber,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // WhatsApp option
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xffbbf7d0)),
                ),
                tileColor: const Color(0xfff0fdf4),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xff25D366),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(LucideIcons.messageCircle, color: Colors.white, size: 20),
                ),
                title: Text(
                  T.t('Chat on WhatsApp'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: Text(
                  '${T.t('Message support directly at')} $formattedNumber',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: const Icon(LucideIcons.chevronRight, size: 18),
                onTap: () {
                  Navigator.pop(bCtx);
                  openWhatsApp(
                    message: 'Hello Dairy Desk Support, I need assistance with the app.',
                    context: context,
                  );
                },
              ),
              const SizedBox(height: 10),

              // Direct Phone Call option
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xffe2e8f0)),
                ),
                tileColor: const Color(0xfff8fafc),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xff0284c7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(LucideIcons.phoneCall, color: Colors.white, size: 20),
                ),
                title: Text(
                  T.t('Call Support'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: Text(
                  '${T.t('Direct helpline')} $formattedNumber',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: const Icon(LucideIcons.chevronRight, size: 18),
                onTap: () {
                  Navigator.pop(bCtx);
                  callSupport(context: context);
                },
              ),
              const SizedBox(height: 10),

              // Send feedback option
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xffe2e8f0)),
                ),
                tileColor: const Color(0xfff8fafc),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xff9333ea),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(LucideIcons.messageSquareText, color: Colors.white, size: 20),
                ),
                title: Text(
                  T.t('Send feedback'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: Text(
                  T.t('Share suggestions or report an issue directly'),
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: const Icon(LucideIcons.chevronRight, size: 18),
                onTap: () {
                  Navigator.pop(bCtx);
                  showFeedbackDialog(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
