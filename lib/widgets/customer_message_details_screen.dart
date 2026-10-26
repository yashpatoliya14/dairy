import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/api_service.dart';
import '../services/app_language.dart';
import 'dairy_milk_loader.dart';

class CustomerMessageDetailsScreen extends StatefulWidget {
  const CustomerMessageDetailsScreen({
    super.key,
    required this.api,
    required this.customerItem,
    required this.date,
    required this.dairyName,
    required this.onStatusUpdated,
  });

  final ApiService api;
  final Map<String, dynamic> customerItem;
  final String date;
  final String dairyName;
  final Future<void> Function() onStatusUpdated;

  @override
  State<CustomerMessageDetailsScreen> createState() =>
      _CustomerMessageDetailsScreenState();
}

class _CustomerMessageDetailsScreenState
    extends State<CustomerMessageDetailsScreen> {
  late final TextEditingController _messageController;
  late final TextEditingController _phoneController;

  bool _isEditing = false;
  bool _saving = false;
  bool _loadingHistory = true;
  List<Map<String, dynamic>> _history = [];

  late Map<String, dynamic> _messageLog;

  @override
  void initState() {
    super.initState();
    _messageLog = Map<String, dynamic>.from(
      widget.customerItem['messageLog'] as Map? ?? {},
    );

    final customer = widget.customerItem['customer'] as Map? ?? {};
    final rawPhone = '${customer['phoneNumber'] ?? ''}'.trim();
    _phoneController = TextEditingController(text: rawPhone);

    final preparedMessage = _generateMessage();
    final savedContent = _messageLog['messageContent'] as String?;
    _messageController = TextEditingController(
      text: savedContent != null && savedContent.trim().isNotEmpty
          ? savedContent
          : preparedMessage,
    );

    _loadHistory();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final customer = widget.customerItem['customer'] as Map? ?? {};
    final cid = '${customer['id'] ?? ''}'.trim();
    if (cid.isEmpty) {
      if (mounted) setState(() => _loadingHistory = false);
      return;
    }

    try {
      final history = await widget.api.getCustomerMessageHistory(cid);
      if (mounted) {
        setState(() {
          _history = history;
          _loadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingHistory = false);
      }
    }
  }

  String _generateMessage() {
    final currentLang = Get.find<AppLanguageController>().language.value;
    final customer = widget.customerItem['customer'] as Map? ?? {};
    final entry = widget.customerItem['entry'] as Map?;

    final name = '${customer['name'] ?? 'Customer'}'.trim();
    final liters = entry != null
        ? '${entry['liters']}'
        : '${customer['defaultLiters'] ?? '0'}';
    final price = entry != null
        ? '${entry['price']}'
        : '${customer['defaultPrice'] ?? '0'}';
    final total = entry != null
        ? '${entry['total']}'
        : (double.tryParse(liters) != null && double.tryParse(price) != null)
            ? (double.parse(liters) * double.parse(price)).toStringAsFixed(2)
            : '0.00';

    final dairy = widget.dairyName.isNotEmpty ? widget.dairyName : 'Dairy Desk';

    if (currentLang == 'gu') {
      return 'નમસ્તે $name,\n\n'
          'આજની દૂધની વિગત (${widget.date}):\n\n'
          'કુલ દૂધ: $liters લીટર\n'
          'દૂધનો દર: ₹$price/લીટર\n'
          'કુલ રકમ: ₹$total\n\n'
          'આભાર!\n'
          '$dairy';
    } else if (currentLang == 'hi') {
      return 'नमस्ते $name,\n\n'
          'आज का दूध विवरण (${widget.date}):\n\n'
          'कुल दूध: $liters लीटर\n'
          'दर: ₹$price/लीटर\n'
          'कुल राशि: ₹$total\n\n'
          'धन्यवाद!\n'
          '$dairy';
    } else {
      return 'Hello $name,\n\n'
          'Today\'s Milk Details (${widget.date}):\n\n'
          'Total Milk: $liters Liters\n'
          'Rate: ₹$price/Liter\n'
          'Total Amount: ₹$total\n\n'
          'Thank you!\n'
          '$dairy';
    }
  }

  Future<void> _copyMessage() async {
    await Clipboard.setData(ClipboardData(text: _messageController.text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(T.t('Message copied to clipboard')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _cleanPhoneNumber(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return '91$digits';
    }
    return digits;
  }

  Future<void> _sendWhatsAppMessage() async {
    final customer = widget.customerItem['customer'] as Map? ?? {};
    final phone = _phoneController.text.trim();
    final cleanPhone = _cleanPhoneNumber(phone);

    if (cleanPhone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(T.t('Please enter a valid phone number')),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    final hasEntry = widget.customerItem['hasEntry'] == true ||
        widget.customerItem['entry'] != null;
    if (!hasEntry) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(T.t('Customer has no milk entry for this date. Please add entry first.')),
          backgroundColor: Colors.amber.shade900,
        ),
      );
      return;
    }

    final message = _messageController.text;
    setState(() => _saving = true);

    try {
      final res = await widget.api.sendDailyWhatsAppEntry(
        customerId: '${customer['id']}',
        date: widget.date,
        message: message,
      );

      if (mounted) {
        setState(() => _saving = false);
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(T.t('WhatsApp message sent successfully via Business API!')),
              backgroundColor: const Color(0xff2d7a55),
            ),
          );
          await widget.onStatusUpdated();
          await _loadHistory();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${T.t('Failed to send WhatsApp message')}: ${res['error'] ?? 'Unknown error'}'),
              backgroundColor: Colors.red.shade700,
            ),
          );
          await widget.onStatusUpdated();
          await _loadHistory();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${T.t('Error sending WhatsApp message')}: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
        await widget.onStatusUpdated();
        await _loadHistory();
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'sent':
        return const Color(0xff2d7a55);
      case 'opened_in_whatsapp':
        return Colors.teal.shade700;
      case 'pending':
        return Colors.blue.shade700;
      case 'failed':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'sent':
        return T.t('Sent');
      case 'opened_in_whatsapp':
        return T.t('Opened in WhatsApp');
      case 'pending':
        return T.t('Pending');
      case 'failed':
        return T.t('Failed');
      default:
        return T.t('Not Sent');
    }
  }

  @override
  Widget build(BuildContext context) {
    final customer = widget.customerItem['customer'] as Map? ?? {};
    final entry = widget.customerItem['entry'] as Map?;
    final hasEntry = widget.customerItem['hasEntry'] == true;

    final name = '${customer['name'] ?? 'Customer'}';
    final number = '${customer['uniqueNumber'] ?? '—'}';
    final liters = entry != null
        ? '${entry['liters']} L'
        : '${customer['defaultLiters'] ?? '—'} L';
    final price = entry != null
        ? '₹${entry['price']}'
        : '₹${customer['defaultPrice'] ?? '—'}';
    final total = entry != null ? '₹${entry['total']}' : '—';

    final status = '${_messageLog['status'] ?? 'not_sent'}';
    final attempts = _messageLog['attemptCount'] ?? 0;
    final lastAttempt = _messageLog['lastAttemptedAt'] != null
        ? '${_messageLog['lastAttemptedAt']}'
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(T.t('Customer Message Details')),
        actions: [
          IconButton(
            tooltip: T.t('Copy Message'),
            icon: const Icon(LucideIcons.copy),
            onPressed: _copyMessage,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Customer Profile Card
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xffe3ebe6)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xffdcefe3),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xff2d7a55),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${T.t('Customer no.')} $number',
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: hasEntry
                              ? const Color(0xffdcefe3)
                              : Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          hasEntry ? T.t('Milk entry saved') : T.t('No Entry'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: hasEntry
                                ? const Color(0xff2d7a55)
                                : Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  // Mobile number input/display
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: T.t('Phone number'),
                      prefixIcon: const Icon(LucideIcons.phone, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Milk Entry Stats Card
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xffe3ebe6)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        T.t('Daily summary'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        widget.date,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatBox(
                          label: T.t('Total Liters'),
                          value: liters,
                          icon: LucideIcons.milk,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatBox(
                          label: T.t('Rate / Liter'),
                          value: price,
                          icon: LucideIcons.indianRupee,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatBox(
                          label: T.t('Total Amount'),
                          value: total,
                          icon: LucideIcons.receipt,
                          highlight: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Status & Accuracy Indicator Card
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xffe3ebe6)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        T.t('Delivery Status'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _getStatusLabel(status),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _getStatusColor(status),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (attempts > 0)
                    Text(
                      lastAttempt != null
                          ? '${T.t('Attempt count')}: $attempts  •  ${T.t('Last attempt')}: ${lastAttempt.substring(0, 16).replaceFirst('T', ' ')}'
                          : '${T.t('Attempt count')}: $attempts',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xfff3f6f4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          LucideIcons.info,
                          size: 16,
                          color: Colors.blueGrey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            T.t(
                              'Note: Messages are sent directly through the WhatsApp Business API to the customer’s phone number without opening the WhatsApp application.',
                            ),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.blueGrey,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Message Preview / Editor Card
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xffe3ebe6)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        T.t('Live Message Preview'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        tooltip: _isEditing ? T.t('Close') : T.t('Edit Message'),
                        icon: Icon(
                          _isEditing ? LucideIcons.check : LucideIcons.penLine,
                          size: 18,
                        ),
                        onPressed: () {
                          setState(() => _isEditing = !_isEditing);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _messageController,
                    maxLines: 10,
                    minLines: 6,
                    readOnly: !_isEditing,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: _isEditing
                          ? Colors.white
                          : const Color(0xfff5f8f6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _isEditing
                              ? const Color(0xff2d7a55)
                              : const Color(0xffe3ebe6),
                        ),
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      fontFamilyFallback: ['Noto Sans Gujarati', 'sans-serif'],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _copyMessage,
                          icon: const Icon(LucideIcons.copy, size: 18),
                          label: Text(T.t('Copy Message')),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _sendWhatsAppMessage,
                          icon: _saving
                              ? DairyMilkLoader.mini(color: Colors.white, size: 20)
                              : const Icon(
                                  LucideIcons.send,
                                  color: Colors.white,
                                  size: 18,
                                ),
                          label: Text(
                            status == 'failed'
                                ? T.t('Retry via Business API')
                                : T.t('Send WhatsApp Message'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xff2d7a55),
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Message History Section
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xffe3ebe6)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    T.t('Message history'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_loadingHistory)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: DairyMilkLoader(
                          size: 46,
                          message: 'Loading message history...',
                        ),
                      ),
                    )
                  else if (_history.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: Text(
                          T.t('No message history yet'),
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  else
                    ..._history.map(
                      (item) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          LucideIcons.messageSquare,
                          size: 18,
                          color: _getStatusColor('${item['status']}'),
                        ),
                        title: Text(
                          '${item['date']}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${_getStatusLabel('${item['status']}')} • ${T.t('Attempt count')}: ${item['attemptCount'] ?? 1}',
                        ),
                        trailing: item['lastAttemptedAt'] != null
                            ? Text(
                                '${item['lastAttemptedAt']}'.substring(11, 16),
                                style: const TextStyle(fontSize: 11),
                              )
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xffdcefe3) : const Color(0xfff3f6f4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 18,
            color: highlight
                ? const Color(0xff2d7a55)
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: highlight ? const Color(0xff2d7a55) : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
