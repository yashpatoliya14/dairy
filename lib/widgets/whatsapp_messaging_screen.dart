import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/dashboard_controller.dart';
import '../services/api_service.dart';
import '../services/app_language.dart';
import 'customer_message_details_screen.dart';
import 'dairy_milk_loader.dart';

class WhatsAppMessagingScreen extends StatefulWidget {
  const WhatsAppMessagingScreen({
    super.key,
    required this.api,
    this.initialDate,
  });

  final ApiService api;
  final DateTime? initialDate;

  @override
  State<WhatsAppMessagingScreen> createState() =>
      WhatsAppMessagingScreenState();
}

class WhatsAppMessagingScreenState extends State<WhatsAppMessagingScreen> {
  late DateTime _selectedDate;
  bool _loading = true;
  String _searchQuery = '';
  String _selectedFilter = 'entry_done'; // 'entry_done', 'all', 'pending', 'sent', 'failed', 'no_entry'

  Map<String, dynamic>? _dailyData;
  String? _errorMessage;

  // Multi-select for bulk workflow
  bool _selectionMode = false;
  final Set<String> _selectedCustomerIds = {};
  String? _sendingCustomerId;
  bool _bulkSending = false;

  // Background bulk job tracking
  Timer? _jobPollTimer;
  int _activeJobTotal = 0;
  int _activeJobSent = 0;
  int _activeJobFailed = 0;
  String? _activeJobStatus;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    widget.api.addEntryChangeListener(_handleExternalEntryChange);
    _loadData();
  }

  void _handleExternalEntryChange() {
    if (mounted) {
      _loadData(silent: true);
    }
  }

  void reload() {
    _loadData();
  }

  @override
  void dispose() {
    widget.api.removeEntryChangeListener(_handleExternalEntryChange);
    _jobPollTimer?.cancel();
    super.dispose();
  }

  String get _formattedDate =>
      _selectedDate.toIso8601String().substring(0, 10);

  String get _formattedDateDisplay {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final weekday = weekdays[_selectedDate.weekday - 1];
    return '$weekday, ${_selectedDate.day} ${months[_selectedDate.month - 1]} ${_selectedDate.year}';
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final res = await widget.api.getDailySummary(
        date: _formattedDate,
        showLoader: !silent,
      );
      if (mounted) {
        setState(() {
          _dailyData = res;
          if (!silent) _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (!silent) {
            _errorMessage = e.toString();
            _loading = false;
          }
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _selectedCustomerIds.clear();
      });
      await _loadData();
    }
  }

  void _previousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
      _selectedCustomerIds.clear();
    });
    _loadData();
  }

  void _nextDay() {
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
      _selectedCustomerIds.clear();
    });
    _loadData();
  }

  void _goToToday() {
    setState(() {
      _selectedDate = DateTime.now();
      _selectedCustomerIds.clear();
    });
    _loadData();
  }

  String _cleanPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '91$digits';
    return digits;
  }

  String _formatDisplayPhone(String? raw) {
    if (raw == null) return '';
    final cleaned = raw.replaceAll(RegExp(r'[^\d+]'), '').trim();
    if (cleaned.isEmpty || cleaned == 'null') return '';
    String digits = cleaned.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    } else if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (digits.length == 10) {
      return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
    }
    return raw;
  }

  bool _hasValidPhone(Map customer) {
    final raw = '${customer['phoneNumber'] ?? customer['phone'] ?? ''}'.trim();
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 10;
  }

  String _buildQuickMessage(Map<String, dynamic> item) {
    final currentLang = Get.find<AppLanguageController>().language.value;
    final customer = item['customer'] as Map? ?? {};
    final entry = item['entry'] as Map?;

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

    final dairy = '${_dailyData?['dairyName'] ?? ''}'.trim();
    final dairyName = dairy.isNotEmpty ? dairy : 'Dairy Desk';

    if (currentLang == 'gu') {
      return 'નમસ્તે $name,\n\n'
          'આજની દૂધની વિગત ($_formattedDate):\n\n'
          'કુલ દૂધ: $liters લીટર\n'
          'દૂધનો દર: ₹$price/લીટર\n'
          'કુલ રકમ: ₹$total\n\n'
          'આભાર!\n'
          '$dairyName';
    } else if (currentLang == 'hi') {
      return 'नमस्ते $name,\n\n'
          'आज का दूध विवरण ($_formattedDate):\n\n'
          'कुल दूध: $liters लीटर\n'
          'दर: ₹$price/लीटर\n'
          'कुल राशि: ₹$total\n\n'
          'धन्यवाद!\n'
          '$dairyName';
    } else {
      return 'Hello $name,\n\n'
          'Today\'s Milk Details ($_formattedDate):\n\n'
          'Total Milk: $liters Liters\n'
          'Rate: ₹$price/Liter\n'
          'Total Amount: ₹$total\n\n'
          'Thank you!\n'
          '$dairyName';
    }
  }

  Future<void> _launchDirectWhatsApp(String cleanPhone, String message) async {
    final encoded = Uri.encodeComponent(message);
    final nativeUri = Uri.parse('whatsapp://send?phone=$cleanPhone&text=$encoded');
    final webUri = Uri.parse('https://wa.me/$cleanPhone?text=$encoded');
    try {
      if (await canLaunchUrl(nativeUri)) {
        await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Future<void> _promptEnterPhone(Map<String, dynamic> item) async {
    final customer = item['customer'] as Map? ?? {};
    final cid = '${customer['id']}';
    final name = '${customer['name'] ?? 'Customer'}'.trim();
    final phoneCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${T.t('Add Phone Number')} - $name'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: T.t('Mobile number'),
              prefixText: '+91 ',
              hintText: '9876543210',
            ),
            validator: (v) {
              final cleaned = (v ?? '').replaceAll(RegExp(r'\D'), '');
              if (cleaned.length < 10) return T.t('Please enter a valid phone number');
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text(T.t('Cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.of(ctx).pop(phoneCtrl.text.replaceAll(RegExp(r'\D'), ''));
              }
            },
            child: Text(T.t('Save')),
          ),
        ],
      ),
    );

    if (saved != null && saved.isNotEmpty) {
      try {
        await widget.api.updateCustomer(cid, {'phoneNumber': saved});
        customer['phoneNumber'] = saved;
        await _loadData();
        if (mounted) {
          _sendSingleWhatsApp(item);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating phone: $e')),
          );
        }
      }
    }
  }

  Future<void> _sendSingleWhatsApp(Map<String, dynamic> item) async {
    final customer = item['customer'] as Map? ?? {};
    final cid = '${customer['id']}';
    final name = '${customer['name'] ?? 'Customer'}'.trim();
    final phone = '${customer['phoneNumber'] ?? ''}'.trim();
    final cleanPhone = _cleanPhone(phone);
    if (cleanPhone.length < 10) {
      await _promptEnterPhone(item);
      return;
    }

    final message = _buildQuickMessage(item);

    setState(() => _sendingCustomerId = cid);

    try {
      final res = await widget.api.sendDailyWhatsAppEntry(
        customerId: cid,
        date: _formattedDate,
        message: message,
      );

      if (mounted) {
        if (res['success'] == true && res['status'] != 'failed') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${T.t('WhatsApp message sent to')} $name via Business API!'),
              backgroundColor: const Color(0xff2d7a55),
            ),
          );
        } else {
          final errStr = res['message'] ?? res['error'] ?? 'WhatsApp API failed to deliver';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${T.t('Failed to send WhatsApp message')}: $errStr',
              ),
              backgroundColor: Colors.amber.shade900,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: T.t('Open in WhatsApp'),
                textColor: Colors.white,
                onPressed: () => _launchDirectWhatsApp(cleanPhone, message),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${T.t('Error sending WhatsApp message')}: $e'),
            backgroundColor: Colors.amber.shade900,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: T.t('Open in WhatsApp'),
              textColor: Colors.white,
              onPressed: () => _launchDirectWhatsApp(cleanPhone, message),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sendingCustomerId = null);
        await _loadData();
      }
    }
  }

  Future<void> _sendBulkToSelected(List<Map<String, dynamic>> eligibleList) async {
    if (eligibleList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            T.t('Please select customers with valid mobile numbers to send WhatsApp messages.'),
          ),
          backgroundColor: Colors.amber.shade900,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
        title: Row(
          children: [
            Expanded(
              child: Text(
                T.t('Send WhatsApp Messages'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              tooltip: T.t('Close'),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => Navigator.of(dialogCtx).pop(false),
            ),
          ],
        ),
        content: Text(
          '${T.t('Send milk delivery messages to')} ${eligibleList.length} ${T.t('customers via WhatsApp Business API?')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(T.t('Cancel')),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            icon: const Icon(LucideIcons.send, size: 16),
            label: Text(T.t('Send Now')),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xff2d7a55)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _bulkSending = true;
    });

    try {
      final customerIds = eligibleList.map((c) => '${c['customer']['id']}').toList();
      final res = await widget.api.sendBulkDailyWhatsAppEntries(
        customerIds: customerIds,
        date: _formattedDate,
      );

      if (mounted) {
        final jobId = res['jobId'] as String?;
        final eligibleCount =
            (res['eligibleCount'] as num?)?.toInt() ?? eligibleList.length;
        final ineligibleCount = (res['ineligibleCount'] as num?)?.toInt() ?? 0;

        _selectedCustomerIds.clear();
        _selectionMode = false;
        _bulkSending = false;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ineligibleCount > 0
                  ? '${T.t('Background job started')}: sending to $eligibleCount customers ($ineligibleCount skipped).'
                  : '${T.t('Background job started')}: sending to $eligibleCount customers.',
            ),
            backgroundColor: const Color(0xff2d7a55),
            duration: const Duration(seconds: 4),
          ),
        );

        if (jobId != null) {
          _startJobPolling(jobId, eligibleCount);
        } else {
          await _loadData();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _bulkSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${T.t('Error during bulk send')}: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _bulkSending = false);
      }
    }
  }

  void _startJobPolling(String jobId, int total) {
    _jobPollTimer?.cancel();
    setState(() {
      _activeJobTotal = total;
      _activeJobSent = 0;
      _activeJobFailed = 0;
      _activeJobStatus = 'processing';
    });

    // Refresh immediately to show initial pending status
    _loadData(silent: true);

    int polls = 0;
    _jobPollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      polls++;
      if (!mounted) {
        timer.cancel();
        return;
      }

      try {
        final job = await widget.api.getBulkJobStatus(jobId);
        if (!mounted) return;

        final status = job['status'] as String? ?? 'processing';
        final sent = (job['sentCount'] as num?)?.toInt() ?? 0;
        final failed = (job['failedCount'] as num?)?.toInt() ?? 0;
        final jobTotal = (job['eligibleCount'] as num?)?.toInt() ?? total;

        setState(() {
          _activeJobSent = sent;
          _activeJobFailed = failed;
          _activeJobTotal = jobTotal;
          _activeJobStatus = status;
        });

        // Silently update list so newly sent items turn green
        await _loadData(silent: true);

        if (status == 'completed' || status == 'failed' || status == 'partially_completed' || polls >= 60) {
          timer.cancel();
          if (mounted) {
            setState(() {
              _activeJobStatus = null;
            });

            final bool isAllFailed = (sent == 0 && failed > 0) || status == 'failed';
            final bool isPartial = failed > 0 && sent > 0;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isAllFailed
                      ? '${T.t('Failed to send WhatsApp messages')}: $failed ${T.t('failed')}. ${T.t('Please check your WhatsApp API connection.')}'
                      : isPartial
                          ? '${T.t('Partially completed')}: $sent ${T.t('sent')}, $failed ${T.t('failed')}'
                          : '${T.t('Bulk messages finished')}: $sent ${T.t('sent')}',
                ),
                backgroundColor: isAllFailed
                    ? Colors.red.shade700
                    : isPartial
                        ? Colors.orange.shade800
                        : const Color(0xff2d7a55),
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      } catch (e) {
        if (polls >= 30) {
          timer.cancel();
          if (mounted) {
            setState(() {
              _activeJobStatus = null;
            });
          }
        }
      }
    });
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
        return T.t('Opened');
      case 'pending':
        return T.t('Pending');
      case 'failed':
        return T.t('Failed');
      default:
        return T.t('Not Sent');
    }
  }

  List<Map<String, dynamic>> _filteredCustomers() {
    if (_dailyData == null) return [];
    final list = (_dailyData!['customers'] as List? ?? [])
        .whereType<Map>()
        .map((c) => Map<String, dynamic>.from(c))
        .toList();

    return list.where((item) {
      final customer = item['customer'] as Map? ?? {};
      final name = '${customer['name'] ?? ''}'.toLowerCase();
      final phone = '${customer['phoneNumber'] ?? ''}'.toLowerCase();
      final number = '${customer['uniqueNumber'] ?? ''}'.toLowerCase();

      // Search filter
      final q = _searchQuery.toLowerCase().trim();
      final matchesSearch =
          q.isEmpty || name.contains(q) || phone.contains(q) || number.contains(q);
      if (!matchesSearch) return false;

      // Category filter
      final status = '${item['messageLog']?['status'] ?? 'not_sent'}';
      final hasEntry = item['hasEntry'] == true;
      final isSent = status == 'sent' || status == 'opened_in_whatsapp';

      switch (_selectedFilter) {
        case 'entry_done':
          // Entries done should NOT display sent message customers
          return hasEntry && !isSent;
        case 'sent':
          return isSent;
        case 'pending':
          return !isSent;
        case 'failed':
          return status == 'failed';
        case 'no_entry':
          return !hasEntry;
        case 'all':
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final summary = _dailyData?['summary'] as Map? ?? {};
    final dashboardCtrl = Get.isRegistered<DashboardController>()
        ? Get.find<DashboardController>()
        : null;
    final dairy = dashboardCtrl != null && dashboardCtrl.dairyName.value.isNotEmpty
        ? dashboardCtrl.dairyName.value
        : '${_dailyData?['dairyName'] ?? ''}'.trim();
    final dairyName = dairy.isNotEmpty ? dairy : T.t('Dairy Desk');
    final ownerName = dashboardCtrl != null && dashboardCtrl.ownerName.value.isNotEmpty
        ? dashboardCtrl.ownerName.value
        : '${_dailyData?['ownerName'] ?? ''}'.trim();
    final customers = _filteredCustomers();

    // Calculate dynamic counts across all customers
    final allCustomersRaw = (_dailyData?['customers'] as List? ?? [])
        .whereType<Map>()
        .map((c) => Map<String, dynamic>.from(c))
        .toList();

    int countReadyToSend = 0;
    int countSent = 0;
    int countPending = 0;
    int countFailed = 0;
    int countNoEntry = 0;
    final int countAll = allCustomersRaw.length;

    for (final item in allCustomersRaw) {
      final status = '${item['messageLog']?['status'] ?? 'not_sent'}';
      final hasEntry = item['hasEntry'] == true;
      final isSent = status == 'sent' || status == 'opened_in_whatsapp';

      if (hasEntry && !isSent) countReadyToSend++;
      if (isSent) countSent++;
      if (!isSent) countPending++;
      if (status == 'failed') countFailed++;
      if (!hasEntry) countNoEntry++;
    }

    // Eligible selected customers (valid phone and NOT sent)
    final eligibleSelected = customers.where((c) {
      final cid = '${c['customer']['id']}';
      final customer = c['customer'] as Map? ?? {};
      final log = c['messageLog'] as Map? ?? {};
      final status = '${log['status'] ?? 'not_sent'}';
      final isSent = status == 'sent' || status == 'opened_in_whatsapp';
      return _selectedCustomerIds.contains(cid) &&
          _hasValidPhone(customer) &&
          !isSent;
    }).toList();

    // All eligible customers in current filtered list
    final allEligibleInView = customers.where((c) {
      final cust = c['customer'] as Map? ?? {};
      final log = c['messageLog'] as Map? ?? {};
      final status = '${log['status'] ?? 'not_sent'}';
      final isSent = status == 'sent' || status == 'opened_in_whatsapp';
      return _hasValidPhone(cust) && !isSent;
    }).toList();

    final allEligibleIds = allEligibleInView
        .map((c) => '${c['customer']['id']}')
        .toSet();

    final allEligibleSelected = allEligibleIds.isNotEmpty &&
        allEligibleIds.every((id) => _selectedCustomerIds.contains(id));

    final isToday = _formattedDate ==
        DateTime.now().toIso8601String().substring(0, 10);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xff1b4d36),
        elevation: 0,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dairyName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: -.2,
                color: Colors.white,
              ),
            ),
            if (ownerName.isNotEmpty)
              Text(
                '${T.t("Welcome back")}, $ownerName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xffdcefe3),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            // Date Picker Row (Sleek & Compact)
            Container(
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xffe2e8f0)),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: T.t('Yesterday'),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    iconSize: 18,
                    icon: const Icon(LucideIcons.chevronLeft),
                    onPressed: _previousDay,
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            LucideIcons.calendar,
                            size: 14,
                            color: Color(0xff2d7a55),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formattedDateDisplay,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: Color(0xff1b4d36),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isToday)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xffdcefe3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        T.t('Today'),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xff2d7a55),
                        ),
                      ),
                    )
                  else
                    IconButton(
                      icon: const Icon(LucideIcons.calendarCheck, size: 18, color: Color(0xff2d7a55)),
                      tooltip: T.t('Today'),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      onPressed: _goToToday,
                    ),
                  IconButton(
                    tooltip: T.t('Select date'),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    iconSize: 18,
                    icon: const Icon(LucideIcons.chevronRight),
                    onPressed: _nextDay,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Daily Summary Metrics Card (Compact & Professional)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xffe2e8f0)),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: const Color(0xffe8f5e9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  LucideIcons.milk,
                                  size: 14,
                                  color: Color(0xff2d7a55),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      T.t('Total Liters'),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    Text(
                                      '${summary['totalLiters'] ?? 0} L',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xff2d7a55),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 24, color: const Color(0xffe2e8f0)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: const Color(0xfff0fdf4),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  LucideIcons.indianRupee,
                                  size: 14,
                                  color: Color(0xff166534),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      T.t('Total Amount'),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    Text(
                                      '₹${summary['totalAmount'] ?? 0}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xff1f2937),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(height: 1, color: const Color(0xfff1f5f9)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryBadge(
                            label: T.t('Entries Done'),
                            count: '${summary['completedEntriesCount'] ?? 0}/${summary['totalCustomers'] ?? 0}',
                            color: const Color(0xff2d7a55),
                          ),
                        ),
                        Expanded(
                          child: _SummaryBadge(
                            label: T.t('Entries Missing'),
                            count: '${summary['missingEntriesCount'] ?? 0}',
                            color: Colors.amber.shade900,
                          ),
                        ),
                        Expanded(
                          child: _SummaryBadge(
                            label: T.t('Sent'),
                            count: '${(summary['sentCount'] ?? 0) + (summary['openedCount'] ?? 0)}',
                            color: Colors.teal.shade800,
                          ),
                        ),
                        Expanded(
                          child: _SummaryBadge(
                            label: T.t('Pending'),
                            count: '${(summary['pendingCount'] ?? 0) + (summary['notSentCount'] ?? 0)}',
                            color: Colors.blueGrey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Search Bar & Selection Button
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: T.t('Search by name or mobile number'),
                        hintStyle: const TextStyle(fontSize: 12),
                        prefixIcon: const Icon(LucideIcons.search, size: 16),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xffe2e8f0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xffe2e8f0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xff2d7a55)),
                        ),
                        fillColor: Colors.white,
                        filled: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectionMode = !_selectionMode;
                      if (!_selectionMode) {
                        _selectedCustomerIds.clear();
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: _selectionMode ? const Color(0xff1b4d36) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _selectionMode ? const Color(0xff1b4d36) : const Color(0xffe2e8f0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _selectionMode ? LucideIcons.checkSquare : LucideIcons.square,
                          size: 16,
                          color: _selectionMode ? Colors.white : const Color(0xff2d7a55),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _selectionMode ? T.t('Cancel') : T.t('Select'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _selectionMode ? Colors.white : const Color(0xff2d7a55),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Filter Chips (Defaulting to Entries Done, with dynamic counts)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: T.t('Entries Done'),
                    count: countReadyToSend,
                    icon: LucideIcons.sendHorizontal,
                    selected: _selectedFilter == 'entry_done',
                    onTap: () => setState(() => _selectedFilter = 'entry_done'),
                  ),
                  const SizedBox(width: 6),
                  _FilterChip(
                    label: T.t('Sent'),
                    count: countSent,
                    icon: LucideIcons.checkCheck,
                    selected: _selectedFilter == 'sent',
                    onTap: () => setState(() => _selectedFilter = 'sent'),
                  ),
                  const SizedBox(width: 6),
                  _FilterChip(
                    label: T.t('Pending'),
                    count: countPending,
                    icon: LucideIcons.clock,
                    selected: _selectedFilter == 'pending',
                    onTap: () => setState(() => _selectedFilter = 'pending'),
                  ),
                  const SizedBox(width: 6),
                  _FilterChip(
                    label: T.t('All'),
                    count: countAll,
                    icon: LucideIcons.users,
                    selected: _selectedFilter == 'all',
                    onTap: () => setState(() => _selectedFilter = 'all'),
                  ),
                  if (countFailed > 0) ...[
                    const SizedBox(width: 6),
                    _FilterChip(
                      label: T.t('Failed'),
                      count: countFailed,
                      icon: LucideIcons.alertCircle,
                      selected: _selectedFilter == 'failed',
                      onTap: () => setState(() => _selectedFilter = 'failed'),
                    ),
                  ],
                  const SizedBox(width: 6),
                  _FilterChip(
                    label: T.t('No Entry'),
                    count: countNoEntry,
                    icon: LucideIcons.circleSlash,
                    selected: _selectedFilter == 'no_entry',
                    onTap: () => setState(() => _selectedFilter = 'no_entry'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Background Job Progress Banner (if active)
            if (_activeJobStatus == 'processing')
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xff2d7a55).withValues(alpha: 0.12),
                      const Color(0xff2d7a55).withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xff2d7a55).withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Color(0xff2d7a55),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                T.t('Sending messages in background...'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xff2d7a55),
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$_activeJobSent / $_activeJobTotal ${T.t('sent')}'
                                '${_activeJobFailed > 0 ? " • $_activeJobFailed ${T.t('failed')}" : ""}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _activeJobTotal > 0
                            ? (_activeJobSent + _activeJobFailed) / _activeJobTotal
                            : null,
                        backgroundColor:
                            const Color(0xff2d7a55).withValues(alpha: 0.15),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xff2d7a55),
                        ),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      T.t('You can continue using the app. The server is delivering messages asynchronously.'),
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),

            // Bulk Mode Action Banner (if active)
            if (_selectionMode)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: allEligibleSelected && eligibleSelected.isNotEmpty
                        ? [
                            const Color(0xff14532d),
                            const Color(0xff166534),
                          ]
                        : [
                            const Color(0xfff0fdf4),
                            const Color(0xffdcfce7),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: allEligibleSelected && eligibleSelected.isNotEmpty
                        ? const Color(0xff4ade80)
                        : const Color(0xff86efac),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: allEligibleSelected && eligibleSelected.isNotEmpty
                          ? const Color(0xff166534).withValues(alpha: 0.25)
                          : const Color(0xff22c55e).withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: allEligibleSelected && eligibleSelected.isNotEmpty
                                ? const Color(0xff22c55e)
                                : const Color(0xffbbf7d0),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            allEligibleSelected && eligibleSelected.isNotEmpty
                                ? LucideIcons.checkCheck
                                : LucideIcons.users,
                            size: 15,
                            color: allEligibleSelected && eligibleSelected.isNotEmpty
                                ? Colors.white
                                : const Color(0xff14532d),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                allEligibleSelected && eligibleSelected.isNotEmpty
                                    ? '${eligibleSelected.length} ${T.t('All Eligible Selected')}'
                                    : '${_selectedCustomerIds.length} ${T.t('Selected')} • ${eligibleSelected.length} ${T.t('Eligible')}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: allEligibleSelected && eligibleSelected.isNotEmpty
                                      ? Colors.white
                                      : const Color(0xff14532d),
                                ),
                              ),
                              Text(
                                allEligibleSelected && eligibleSelected.isNotEmpty
                                    ? T.t('Ready to send WhatsApp delivery updates')
                                    : (allEligibleIds.isEmpty
                                        ? T.t('No unsent eligible customers')
                                        : '${allEligibleIds.length - eligibleSelected.length} ${T.t('eligible remaining')}'),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: allEligibleSelected && eligibleSelected.isNotEmpty
                                      ? const Color(0xffbbf7d0)
                                      : const Color(0xff166534),
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            setState(() {
                              if (allEligibleSelected) {
                                _selectedCustomerIds.clear();
                              } else {
                                _selectedCustomerIds.addAll(allEligibleIds);
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: allEligibleSelected && eligibleSelected.isNotEmpty
                                  ? Colors.white
                                  : const Color(0xff166534),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  allEligibleSelected && eligibleSelected.isNotEmpty
                                      ? LucideIcons.x
                                      : LucideIcons.checkCheck,
                                  size: 12,
                                  color: allEligibleSelected && eligibleSelected.isNotEmpty
                                      ? const Color(0xff14532d)
                                      : Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  allEligibleSelected && eligibleSelected.isNotEmpty
                                      ? T.t('Deselect All')
                                      : T.t('Select All Eligible'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: allEligibleSelected && eligibleSelected.isNotEmpty
                                        ? const Color(0xff14532d)
                                        : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_selectedCustomerIds.length > eligibleSelected.length)
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: allEligibleSelected && eligibleSelected.isNotEmpty
                              ? Colors.black.withValues(alpha: 0.25)
                              : Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: allEligibleSelected && eligibleSelected.isNotEmpty
                                ? const Color(0xff86efac).withValues(alpha: 0.3)
                                : Colors.amber.shade200,
                          ),
                        ),
                        child: Text(
                          'ℹ️ ${_selectedCustomerIds.length - eligibleSelected.length} ${T.t('selected customer(s) already sent or missing today\'s entry (skipped).')}',
                          style: TextStyle(
                            fontSize: 10,
                            color: allEligibleSelected && eligibleSelected.isNotEmpty
                                ? const Color(0xfffef08a)
                                : Colors.amber.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    FilledButton.icon(
                      onPressed: eligibleSelected.isEmpty || _bulkSending
                          ? null
                          : () => _sendBulkToSelected(eligibleSelected),
                      icon: _bulkSending
                          ? DairyMilkLoader.mini(color: Colors.white, size: 16)
                          : const Icon(LucideIcons.send, size: 15),
                      label: Text(
                        _bulkSending
                            ? T.t('Sending WhatsApp SMS...')
                            : (eligibleSelected.isEmpty
                                ? T.t('Select eligible customers above')
                                : '${T.t('Send WhatsApp SMS')} (${eligibleSelected.length} ${T.t('Customers')})'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: allEligibleSelected && eligibleSelected.isNotEmpty
                            ? const Color(0xff22c55e)
                            : const Color(0xff166534),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        disabledForegroundColor: Colors.grey.shade600,
                        minimumSize: const Size.fromHeight(36),
                        padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                        elevation: eligibleSelected.isEmpty ? 0 : 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Customer List
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: DairyMilkLoader(
                    size: 48,
                    message: 'Loading messages...',
                  ),
                ),
              )
            else if (_errorMessage != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _loadData,
                        child: Text(T.t('Try again')),
                      ),
                    ],
                  ),
                ),
              )
            else if (customers.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(
                        LucideIcons.inbox,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        T.t('No customers found'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...customers.map(
                (item) {
                  final customer = item['customer'] as Map? ?? {};
                  final entry = item['entry'] as Map?;
                  final log = item['messageLog'] as Map? ?? {};
                  final hasEntry = item['hasEntry'] == true;
                  final cid = '${customer['id']}';

                  final name = '${customer['name'] ?? 'Customer'}';
                  final phone = '${customer['phoneNumber'] ?? ''}'.trim();
                  final uniqueNumber = '${customer['uniqueNumber'] ?? '—'}';
                  final liters = entry != null
                      ? '${entry['liters']} L'
                      : (hasEntry
                          ? '${customer['defaultLiters'] ?? 0} L'
                          : '—');
                  final rate = entry != null
                      ? '₹${entry['price']}'
                      : '₹${customer['defaultPrice'] ?? '—'}';
                  final total = entry != null ? '₹${entry['total']}' : '—';
                  final status = '${log['status'] ?? 'not_sent'}';
                  final lastAttempt = log['lastAttemptedAt'] != null
                      ? '${log['lastAttemptedAt']}'.substring(11, 16)
                      : null;

                  final isSelected = _selectedCustomerIds.contains(cid);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xff2d7a55)
                            : const Color(0xffe3ebe6),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        if (_selectionMode) {
                          setState(() {
                            if (isSelected) {
                              _selectedCustomerIds.remove(cid);
                            } else {
                              _selectedCustomerIds.add(cid);
                            }
                          });
                        } else {
                          Get.to(
                            () => CustomerMessageDetailsScreen(
                              api: widget.api,
                              customerItem: item,
                              date: _formattedDate,
                              dairyName: dairyName,
                              onStatusUpdated: _loadData,
                            ),
                          );
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Row 1: Avatar/Checkbox, Name & Number, Status Badge & Time
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (_selectionMode)
                                  Checkbox(
                                    value: isSelected,
                                    onChanged: (v) {
                                      setState(() {
                                        if (v == true) {
                                          _selectedCustomerIds.add(cid);
                                        } else {
                                          _selectedCustomerIds.remove(cid);
                                        }
                                      });
                                    },
                                  )
                                else
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: const Color(0xffdcefe3),
                                    child: Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xff2d7a55),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xffe8f0ec),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '#$uniqueNumber',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xff2d7a55),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(
                                            _hasValidPhone(customer) ? LucideIcons.phone : LucideIcons.phoneOff,
                                            size: 12,
                                            color: _hasValidPhone(customer)
                                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                                : Colors.amber.shade900,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              phone.isNotEmpty
                                                  ? _formatDisplayPhone(phone)
                                                  : T.t('No phone number available'),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: _hasValidPhone(customer)
                                                    ? Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant
                                                    : Colors.amber.shade900,
                                                fontWeight: _hasValidPhone(customer)
                                                    ? FontWeight.normal
                                                    : FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          if (!_hasValidPhone(customer)) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: Colors.amber.shade100,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                T.t('No Phone'),
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.amber.shade900,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(status)
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _getStatusColor(status)
                                              .withValues(alpha: 0.25),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        _getStatusLabel(status),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: _getStatusColor(status),
                                        ),
                                      ),
                                    ),
                                    if (lastAttempt != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        lastAttempt,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),
                            const Divider(height: 1, color: Color(0xfff1f5f9)),
                            const SizedBox(height: 8),

                            // Row 2: Milk entry metrics
                            Row(
                              children: [
                                if (hasEntry) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xfff0fdf4),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xffbbf7d0), width: 0.8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(LucideIcons.droplets, size: 12, color: Color(0xff2d7a55)),
                                        const SizedBox(width: 4),
                                        Text(
                                          liters,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xff166534),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xfff8fafc),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xffe2e8f0), width: 0.8),
                                    ),
                                    child: Text(
                                      '$rate/L',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xffecfdf5),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xffa7f3d0), width: 0.8),
                                    ),
                                    child: Text(
                                      total,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xff065f46),
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade50,
                                      borderRadius:
                                          BorderRadius.circular(6),
                                      border: Border.all(color: Colors.amber.shade200, width: 0.8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(LucideIcons.circleSlash, size: 12, color: Colors.amber.shade900),
                                        const SizedBox(width: 4),
                                        Text(
                                          T.t('No milk entry'),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.amber.shade900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Row 3: Full-width responsive action buttons
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 34,
                                    child: FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: !hasEntry
                                            ? Colors.grey.shade300
                                            : (!_hasValidPhone(customer)
                                                ? Colors.amber.shade800
                                                : const Color(0xff2d7a55)),
                                        foregroundColor: !hasEntry ? Colors.grey.shade600 : Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        elevation: 0,
                                      ),
                                      icon: _sendingCustomerId == cid
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Icon(
                                              !_hasValidPhone(customer)
                                                  ? LucideIcons.phoneCall
                                                  : LucideIcons.send,
                                              size: 14,
                                            ),
                                      label: Text(
                                        _sendingCustomerId == cid
                                            ? T.t('Sending...')
                                            : (!_hasValidPhone(customer)
                                                ? T.t('Add Phone')
                                                : T.t('Send WhatsApp SMS')),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      onPressed: !hasEntry ||
                                              _sendingCustomerId != null ||
                                              _bulkSending
                                          ? null
                                          : () => _sendSingleWhatsApp(item),
                                    ),
                                  ),
                                ),
                                if (hasEntry && _hasValidPhone(customer)) ...[
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    height: 34,
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xff25D366),
                                        side: const BorderSide(color: Color(0xff25D366), width: 1.2),
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      icon: const Icon(
                                        LucideIcons.messageCircle,
                                        color: Color(0xff25D366),
                                        size: 15,
                                      ),
                                      label: Text(
                                        T.t('WhatsApp'),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xff25D366),
                                        ),
                                      ),
                                      onPressed: () => _launchDirectWhatsApp(
                                        _cleanPhone('${customer['phoneNumber']}'),
                                        _buildQuickMessage(item),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
      floatingActionButton: _selectionMode && eligibleSelected.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _bulkSending ? null : () => _sendBulkToSelected(eligibleSelected),
              backgroundColor: const Color(0xff2d7a55),
              icon: _bulkSending
                  ? DairyMilkLoader.mini(color: Colors.white, size: 20)
                  : const Icon(LucideIcons.send, color: Colors.white),
              label: Text(
                '${T.t('Send to')} ${eligibleSelected.length} ${T.t('eligible')}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            )
          : null,
    );
  }
}

class _SummaryBadge extends StatelessWidget {
  const _SummaryBadge({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final String count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          count,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xff1b4d36) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? const Color(0xff1b4d36)
                : const Color(0xffe2e8f0),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xff1b4d36).withValues(alpha: 0.18),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: selected ? Colors.white : const Color(0xff2d7a55),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : const Color(0xff1f2937),
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.22)
                      : const Color(0xfff1f5f9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : const Color(0xff4b5563),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
