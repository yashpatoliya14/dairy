// ignore_for_file: prefer_interpolation_to_compose_strings
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/dashboard_controller.dart';
import '../services/api_service.dart';
import '../services/app_language.dart';
import 'dairy_milk_loader.dart';

enum BillType { daily, monthly }

class SendWhatsAppBillSheet extends StatefulWidget {
  const SendWhatsAppBillSheet({
    super.key,
    required this.api,
    required this.customer,
    this.initialBillType = BillType.daily,
    this.initialMonthName,
    this.initialTotalDays,
    this.initialMonthlyLiters,
    this.initialRate,
    this.initialMonthlyAmount,
    this.initialPaidAmount,
    this.initialPreviousDue,
    this.initialMonthToDateBill,
    this.initialAdvanceCredit,
  });

  final ApiService api;
  final Map<String, dynamic> customer;
  final BillType initialBillType;
  final String? initialMonthName;
  final int? initialTotalDays;
  final double? initialMonthlyLiters;
  final double? initialRate;
  final double? initialMonthlyAmount;
  final double? initialPaidAmount;
  final double? initialPreviousDue;
  final double? initialMonthToDateBill;
  final double? initialAdvanceCredit;

  static Future<void> show(
    BuildContext context, {
    required ApiService api,
    required Map<String, dynamic> customer,
    BillType initialBillType = BillType.daily,
    String? initialMonthName,
    int? initialTotalDays,
    double? initialMonthlyLiters,
    double? initialRate,
    double? initialMonthlyAmount,
    double? initialPaidAmount,
    double? initialPreviousDue,
    double? initialMonthToDateBill,
    double? initialAdvanceCredit,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SendWhatsAppBillSheet(
        api: api,
        customer: customer,
        initialBillType: initialBillType,
        initialMonthName: initialMonthName,
        initialTotalDays: initialTotalDays,
        initialMonthlyLiters: initialMonthlyLiters,
        initialRate: initialRate,
        initialMonthlyAmount: initialMonthlyAmount,
        initialPaidAmount: initialPaidAmount,
        initialPreviousDue: initialPreviousDue,
        initialMonthToDateBill: initialMonthToDateBill,
        initialAdvanceCredit: initialAdvanceCredit,
      ),
    );
  }

  @override
  State<SendWhatsAppBillSheet> createState() => _SendWhatsAppBillSheetState();
}

class _SendWhatsAppBillSheetState extends State<SendWhatsAppBillSheet> {
  BillType _billType = BillType.daily;

  // Controllers
  late final TextEditingController _phoneController;
  late final TextEditingController _dailyLitersController;
  late final TextEditingController _rateController;
  late final TextEditingController _monthToDateBillController;
  late final TextEditingController _pastOverdueController;

  // Monthly mode controllers
  late final TextEditingController _monthNameController;
  late final TextEditingController _totalDaysController;
  late final TextEditingController _monthlyLitersController;
  late final TextEditingController _monthlyAmountController;
  late final TextEditingController _paidAmountController;
  late final TextEditingController _advanceCreditController;

  DateTime _selectedDate = DateTime.now();

  bool _sending = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _billType = widget.initialBillType;

    final customer = widget.customer;
    final rawPhone =
        '${customer['phoneNumber'] ?? customer['phone'] ?? ''}'.trim();
    final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    final cleanPhone = digits.length == 10 ? '91$digits' : digits;

    final defaultLiters = _asDouble(customer['liters'], 1.0);
    final defaultPrice = _asDouble(customer['price'], 60.0);
    final effectiveRate = widget.initialRate ?? defaultPrice;

    _phoneController = TextEditingController(text: cleanPhone);
    _dailyLitersController = TextEditingController(
      text: defaultLiters.toStringAsFixed(2),
    );
    _rateController = TextEditingController(
      text: effectiveRate.toStringAsFixed(2),
    );

    final initialTodayAmt = defaultLiters * effectiveRate;
    final seedMtd = widget.initialMonthToDateBill ??
        (customer['thisMonthBill'] != null
            ? double.tryParse('${customer['thisMonthBill']}')
            : null) ??
        initialTodayAmt;
    _monthToDateBillController = TextEditingController(
      text: seedMtd.toStringAsFixed(2),
    );

    final seedPastDue = widget.initialPreviousDue ??
        (customer['pastMonthsDue'] != null || customer['grossPastDue'] != null
            ? double.tryParse('${customer['pastMonthsDue'] ?? customer['grossPastDue']}')
            : null) ??
        0.0;
    _pastOverdueController = TextEditingController(
      text: seedPastDue.toStringAsFixed(2),
    );

    // Monthly defaults (strictly calculated based on actual entries; if 0 entries, bill is ₹0.00)
    final now = DateTime.now();
    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    _monthNameController = TextEditingController(
      text: widget.initialMonthName ?? '${monthNames[now.month - 1]} ${now.year}',
    );
    _totalDaysController = TextEditingController(
      text: widget.initialTotalDays != null
          ? '${widget.initialTotalDays}'
          : (customer['activeDays'] != null ? '${customer['activeDays']}' : '0'),
    );
    _monthlyLitersController = TextEditingController(
      text: widget.initialMonthlyLiters != null
          ? widget.initialMonthlyLiters!.toStringAsFixed(2)
          : (customer['totalLiters'] != null
              ? _asDouble(customer['totalLiters'], 0.0).toStringAsFixed(2)
              : '0.00'),
    );
    final initialMonthAmt = widget.initialMonthlyAmount ??
        (customer['thisMonthBill'] != null
            ? double.tryParse('${customer['thisMonthBill']}')
            : null) ??
        (widget.initialMonthlyLiters != null && widget.initialRate != null
            ? double.parse((widget.initialMonthlyLiters! * widget.initialRate!)
                .toStringAsFixed(2))
            : 0.0);
    _monthlyAmountController = TextEditingController(
      text: initialMonthAmt.toStringAsFixed(2),
    );
    final seedPaid = widget.initialPaidAmount ??
        (customer['thisMonthPaid'] != null
            ? double.tryParse('${customer['thisMonthPaid']}')
            : null) ??
        0.0;
    _paidAmountController = TextEditingController(
      text: seedPaid > 0 ? seedPaid.toStringAsFixed(2) : '0.00',
    );
    final seedAdvance = widget.initialAdvanceCredit ??
        (customer['advanceApplied'] != null || customer['grossPastAdvance'] != null || customer['netAdvance'] != null
            ? double.tryParse('${customer['advanceApplied'] ?? customer['grossPastAdvance'] ?? customer['netAdvance']}')
            : null) ??
        0.0;
    _advanceCreditController = TextEditingController(
      text: seedAdvance.toStringAsFixed(2),
    );

    _loadCustomerBalanceAndEntries();
  }

  Future<void> _loadCustomerBalanceAndEntries() async {
    final customerId =
        '${widget.customer['id'] ?? widget.customer['cid'] ?? ''}'.trim();
    if (customerId.isEmpty) return;
    final now = DateTime.now();

    try {
      // 1. Fetch exact customer ledger summary from backend
      final summary = await widget.api.getCustomerBillSummary(
        customerId: customerId,
        year: now.year,
        month: now.month,
      );

      if (mounted && summary.isNotEmpty) {
        final mtd = double.tryParse('${summary['thisMonthBill']}');
        final past = double.tryParse('${summary['pastMonthsDue'] ?? summary['grossPastDue']}');
        final adv = double.tryParse('${summary['advanceApplied'] ?? summary['grossPastAdvance'] ?? summary['netAdvance']}');
        final paid = double.tryParse('${summary['thisMonthPaid']}');
        final totLiters = double.tryParse('${summary['totalLiters']}');
        final days = summary['activeDays'] ?? summary['deliveryDays'];

        setState(() {
          if (mtd != null && mtd > 0) {
            _monthToDateBillController.text = mtd.toStringAsFixed(2);
            _monthlyAmountController.text = mtd.toStringAsFixed(2);
          }
          if (past != null) {
            _pastOverdueController.text = past.toStringAsFixed(2);
          }
          if (adv != null) {
            _advanceCreditController.text = adv.toStringAsFixed(2);
          }
          if (paid != null) {
            _paidAmountController.text = paid.toStringAsFixed(2);
          }
          if (totLiters != null && totLiters > 0) {
            _monthlyLitersController.text = totLiters.toStringAsFixed(2);
          }
          if (days != null && '$days' != '0') {
            _totalDaysController.text = '$days';
          }
        });
      }
    } catch (_) {}

    // 2. Fetch monthly entries if monthly amount was not directly provided
    if (widget.initialMonthlyAmount == null) {
      await _loadMonthlyEntriesForBill();
    }
  }

  Future<void> _loadMonthlyEntriesForBill() async {
    final customerId =
        '${widget.customer['id'] ?? widget.customer['cid'] ?? ''}'.trim();
    if (customerId.isEmpty) return;
    final now = DateTime.now();
    try {
      final monthData = await widget.api.getMilkEntriesForMonth(
        customerId,
        year: now.year,
        month: now.month,
      );
      final entriesList = monthData['entries'] as List? ?? [];
      if (entriesList.isEmpty) {
        return;
      }
      double totalLiters = 0.0;
      double totalAmount = 0.0;
      final activeDaysSet = <String>{};
      final defaultPrice = _asDouble(widget.customer['price'], 60.0);
      for (final e in entriesList) {
        if (e is Map) {
          final l = _asDouble(e['liters'], 0.0);
          totalLiters += l;
          final total = _asDouble(e['total'], -1.0);
          if (total >= 0) {
            totalAmount += total;
          } else {
            final p = _asDouble(e['price'], defaultPrice);
            totalAmount += double.parse((l * p).toStringAsFixed(2));
          }
          if (e['entryDate'] != null) {
            activeDaysSet.add('${e['entryDate']}');
          }
        }
      }
      if (mounted) {
        setState(() {
          _totalDaysController.text = '${activeDaysSet.length}';
          _monthlyLitersController.text = totalLiters.toStringAsFixed(2);
          if (double.tryParse(_monthlyAmountController.text) == 0.0 || _monthlyAmountController.text.isEmpty) {
            _monthlyAmountController.text = totalAmount.toStringAsFixed(2);
          }
          if (double.tryParse(_monthToDateBillController.text) == 0.0 || _monthToDateBillController.text.isEmpty) {
            _monthToDateBillController.text = totalAmount.toStringAsFixed(2);
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _dailyLitersController.dispose();
    _rateController.dispose();
    _monthToDateBillController.dispose();
    _pastOverdueController.dispose();
    _monthNameController.dispose();
    _totalDaysController.dispose();
    _monthlyLitersController.dispose();
    _monthlyAmountController.dispose();
    _paidAmountController.dispose();
    _advanceCreditController.dispose();
    super.dispose();
  }

  double _asDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? fallback;
  }

  void _onDaysChanged(String value) {
    final days = double.tryParse(value) ?? 0;
    final litersPerDay = double.tryParse(_dailyLitersController.text) ?? 0;
    final rate = double.tryParse(_rateController.text) ?? 0;
    setState(() {
      if (days <= 0) {
        _monthlyLitersController.text = '0.00';
        _monthlyAmountController.text = '0.00';
      } else {
        final newLiters = days * litersPerDay;
        _monthlyLitersController.text = newLiters.toStringAsFixed(2);
        _monthlyAmountController.text = (newLiters * rate).toStringAsFixed(2);
      }
    });
  }

  void _onDailyLitersOrRateChanged() {
    setState(() {});
  }

  String get _customerName {
    final c = widget.customer;
    return '${c['name'] ?? c['fullName'] ?? 'Customer'}'.trim();
  }

  String get _customerUniqueNumber {
    final c = widget.customer;
    return '${c['uniqueNumber'] ?? c['customerNumber'] ?? '—'}';
  }

  bool get _hasValidPhone {
    final clean = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty) return false;
    if (clean.startsWith('91') && clean.length >= 12) {
      final after91 = clean.substring(2);
      return after91.length == 10 && RegExp(r'^[6-9]\d{9}$').hasMatch(after91);
    }
    if (clean.length == 10) {
      return RegExp(r'^[6-9]\d{9}$').hasMatch(clean);
    }
    if (clean.length == 11 && RegExp(r'^[6-9]').hasMatch(clean)) {
      return false;
    }
    return clean.length >= 10 && clean.length <= 15;
  }

  String _formatDate(DateTime d) {
    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day.toString().padLeft(2, '0')} ${monthNames[d.month - 1]} ${d.year}';
  }

  String _getDistributorName() {
    final dashboardCtrl = Get.isRegistered<DashboardController>()
        ? Get.find<DashboardController>()
        : null;
    final dairy = dashboardCtrl?.dairyName.value.trim() ?? '';
    final owner = dashboardCtrl?.ownerName.value.trim() ?? '';
    if (dairy.isNotEmpty) return dairy;
    if (owner.isNotEmpty) return owner;
    return 'Dairy Owner';
  }

  String _getDistributorPhone() {
    return '+91 9104152524';
  }

  String _buildFormattedMessage() {
    final name = _customerName;
    final rate = double.tryParse(_rateController.text) ?? 0.0;
    final distributorName = _getDistributorName();
    final distributorPhone = _getDistributorPhone();

    if (_billType == BillType.daily) {
      final liters = double.tryParse(_dailyLitersController.text) ?? 0.0;
      final todayAmount = liters * rate;
      final monthToDate = double.tryParse(_monthToDateBillController.text) ?? todayAmount;
      final pastOverdue = double.tryParse(_pastOverdueController.text) ?? 0.0;
      final totalPayable = monthToDate + pastOverdue;
      final dateStr = _formatDate(_selectedDate);

      return '🥛 *DAILY MILK COLLECTION UPDATE* 🥛\n'
          '━━━━━━━━━━━━━━━━━━━━\n'
          'Hello *$name*,\n\n'
          'Your milk delivery has been recorded successfully:\n\n'
          '📅 *Date:* $dateStr\n'
          '🥛 *Today\'s Milk:* ${liters.toStringAsFixed(1)} L @ ₹${rate.toStringAsFixed(2)}/L\n'
          '💵 *Today\'s Amount:* ₹${todayAmount.toStringAsFixed(2)}\n\n'
          '📊 *ACCOUNT BALANCE STATUS:*\n'
          '• Current Month (Till Date): ₹${monthToDate.toStringAsFixed(2)}\n'
          '• Past Overdue: ₹${pastOverdue.toStringAsFixed(2)}\n'
          '━━━━━━━━━━━━━━━━━━━━\n'
          '💳 *TOTAL AMOUNT TO PAY: ₹${totalPayable.toStringAsFixed(2)}*\n'
          '━━━━━━━━━━━━━━━━━━━━\n\n'
          '📞 *For queries or corrections:*\n'
          '$distributorName ($distributorPhone)\n\n'
          'Thank you! 🥛';
    } else {
      final month = _monthNameController.text.trim();
      final days = int.tryParse(_totalDaysController.text) ?? 30;
      final totalLiters = double.tryParse(_monthlyLitersController.text) ?? 0.0;
      final monthlyAmount = double.tryParse(_monthlyAmountController.text) ??
          (widget.initialMonthlyAmount ?? (totalLiters * rate));
      final paidAmount = double.tryParse(_paidAmountController.text) ?? 0.0;
      final pastOverdue = double.tryParse(_pastOverdueController.text) ?? 0.0;
      final advanceCredit = double.tryParse(_advanceCreditController.text) ?? 0.0;

      final gross = monthlyAmount + pastOverdue;
      final totalCredits = advanceCredit + paidAmount;
      final netPayable = gross > totalCredits ? (gross - totalCredits) : 0.0;

      final paidRow = paidAmount > 0
          ? '• Amount Received: ₹${paidAmount.toStringAsFixed(2)}\n'
          : '';
      final advanceRow = advanceCredit > 0
          ? '• Advance Credit Applied: -₹${advanceCredit.toStringAsFixed(2)}\n'
          : '';

      return '🧾 *MILK BILL STATEMENT* 🧾\n'
          '━━━━━━━━━━━━━━━━━━━━\n'
          'Hello *$name*,\n\n'
          'Your milk bill for *$month* has been generated.\n\n'
          '📋 *DELIVERY SUMMARY:*\n'
          '• Active Delivery Days: $days Days\n'
          '• Total Quantity: ${totalLiters.toStringAsFixed(2)} L\n'
          '• Rate per Liter: ₹${rate.toStringAsFixed(2)}/L\n\n'
          '💰 *BILL BREAKDOWN:*\n'
          '• Monthly Milk Bill: ₹${monthlyAmount.toStringAsFixed(2)}\n'
          '${pastOverdue > 0 ? "• Past Overdue: +₹${pastOverdue.toStringAsFixed(2)}\\n" : ""}'
          '$advanceRow'
          '$paidRow'
          '━━━━━━━━━━━━━━━━━━━━\n'
          '⭐ *NET TOTAL PAYABLE: ₹${(netPayable > 0 ? netPayable : 0.0).toStringAsFixed(2)}${netPayable == 0 && (monthlyAmount > 0 || pastOverdue > 0) ? ' (Fully Settled)' : ''}*\n'
          '━━━━━━━━━━━━━━━━━━━━\n\n'
          '📲 *Payment Options:*\n'
          'Cash, UPI (GPay / PhonePe / Paytm), or Bank Transfer.\n\n'
          '📞 *Dairy Owner Contact:*\n'
          '• Name: $distributorName\n'
          '• Contact: $distributorPhone\n\n'
          'Thank you for your business! Please settle your bill on time. 🥛';
    }
  }

  Future<void> _sendViaBackend() async {
    final cleanPhone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.length < 10) {
      setState(() {
        _errorMessage = T.t(
          'Please enter a valid phone number with country code (e.g. 919876543210)',
        );
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _sending = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final rate = double.tryParse(_rateController.text) ?? 0.0;
    final pastOverdue = double.tryParse(_pastOverdueController.text) ?? 0.0;
    final distributorName = _getDistributorName();
    final distributorPhone = _getDistributorPhone();

    try {
      if (_billType == BillType.daily) {
        final liters = double.tryParse(_dailyLitersController.text) ?? 0.0;
        final todayAmount = liters * rate;
        final monthToDate = double.tryParse(_monthToDateBillController.text) ?? todayAmount;
        final totalPayable = monthToDate + pastOverdue;

        final res = await widget.api.sendWhatsAppBill({
          'to': cleanPhone,
          'customerName': _customerName,
          'type': 'daily',
          'date': _formatDate(_selectedDate),
          'deliverySession': '',
          'liters': liters,
          'ratePerLiter': rate,
          'totalAmount': todayAmount,
          'monthToDateBill': monthToDate,
          'previousDue': pastOverdue,
          'netPayable': totalPayable,
          'distributorName': distributorName,
          'distributorPhone': distributorPhone,
          'useTemplate': true,
          'templateName': 'daily_milk_delivery_update',
          'languageCode': 'en',
        });
        if (res['error'] != null || res['success'] == false || res['status'] == 'failed') {
          final errStr = res['message'] ?? res['error'] ?? 'WhatsApp API delivery failed';
          setState(() {
            _errorMessage = '$errStr';
            _successMessage = null;
          });
          return;
        }
        if (res['messageId'] == null && res['success'] != true) {
          final errStr = res['message'] ?? res['error'] ?? 'WhatsApp message not accepted by provider';
          setState(() {
            _errorMessage = '$errStr';
            _successMessage = null;
          });
          return;
        }
      } else {
        final totalLiters =
            double.tryParse(_monthlyLitersController.text) ?? 0.0;
        final monthlyAmount =
            double.tryParse(_monthlyAmountController.text) ??
                (widget.initialMonthlyAmount ?? (totalLiters * rate));
        final paidAmount = double.tryParse(_paidAmountController.text) ?? 0.0;
        final advanceCredit =
            double.tryParse(_advanceCreditController.text) ?? 0.0;
        final gross = monthlyAmount + pastOverdue;
        final totalCredits = advanceCredit + paidAmount;
        final netPayable = gross > totalCredits ? (gross - totalCredits) : 0.0;

        final res = await widget.api.sendWhatsAppBill({
          'to': cleanPhone,
          'customerName': _customerName,
          'type': 'monthly',
          'monthName': _monthNameController.text.trim(),
          'totalDays': int.tryParse(_totalDaysController.text) ?? 30,
          'totalLiters': totalLiters,
          'liters': totalLiters,
          'ratePerLiter': rate,
          'monthlyAmount': monthlyAmount,
          'paidAmount': paidAmount,
          'totalAmount': netPayable > 0 ? netPayable : monthlyAmount,
          'previousDue': pastOverdue,
          'advanceCredit': advanceCredit,
          'netPayable': netPayable > 0 ? netPayable : 0.0,
          'distributorName': distributorName,
          'distributorPhone': distributorPhone,
          'useTemplate': true,
          'templateName': 'monthly_milk_bill_settlement',
          'languageCode': 'en',
        });
        if (res['error'] != null || res['success'] == false || res['status'] == 'failed') {
          final errStr = res['message'] ?? res['error'] ?? 'WhatsApp API delivery failed';
          setState(() {
            _errorMessage = '$errStr';
            _successMessage = null;
          });
          return;
        }
        if (res['messageId'] == null && res['success'] != true) {
          final errStr = res['message'] ?? res['error'] ?? 'WhatsApp message not accepted by provider';
          setState(() {
            _errorMessage = '$errStr';
            _successMessage = null;
          });
          return;
        }
      }

      setState(() {
        _successMessage = T.t('WhatsApp template message sent successfully! 🚀');
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _openWhatsAppDirect() async {
    final cleanPhone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.length < 10) {
      setState(() {
        _errorMessage = T.t('Please enter a valid phone number');
      });
      return;
    }

    final message = _buildFormattedMessage();
    final encodedMessage = Uri.encodeComponent(message);

    final nativeUri =
        Uri.parse('whatsapp://send?phone=$cleanPhone&text=$encodedMessage');
    final webUri = Uri.parse('https://wa.me/$cleanPhone?text=$encodedMessage');

    try {
      if (await canLaunchUrl(nativeUri)) {
        await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      setState(() {
        _errorMessage = '${T.t('Could not open WhatsApp')}: $e';
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rate = double.tryParse(_rateController.text) ?? 0.0;
    final pastOverdue = double.tryParse(_pastOverdueController.text) ?? 0.0;

    double calculatedTotal = 0.0;
    if (_billType == BillType.daily) {
      final liters = double.tryParse(_dailyLitersController.text) ?? 0.0;
      final todayAmount = liters * rate;
      calculatedTotal = todayAmount;
    } else {
      final totalLiters = double.tryParse(_monthlyLitersController.text) ?? 0.0;
      final monthlyAmount = double.tryParse(_monthlyAmountController.text) ??
          (widget.initialMonthlyAmount ?? (totalLiters * rate));
      final paidAmount = double.tryParse(_paidAmountController.text) ?? 0.0;
      final advanceCredit = double.tryParse(_advanceCreditController.text) ?? 0.0;
      final curDue = monthlyAmount >= paidAmount ? (monthlyAmount - paidAmount) : 0.0;
      final excess = paidAmount > monthlyAmount ? (paidAmount - monthlyAmount) : 0.0;
      final credit = advanceCredit + excess;
      final remPast = pastOverdue > credit ? (pastOverdue - credit) : 0.0;
      final net = curDue + remPast;
      calculatedTotal = net > 0 ? net : 0.0;
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.94,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: WhatsApp Dark Green gradient
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xff075e54), Color(0xff128c7e)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  child: Text(
                    _customerName.isNotEmpty ? _customerName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _customerName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '#$_customerUniqueNumber',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            _hasValidPhone ? LucideIcons.checkCheck : LucideIcons.phoneOff,
                            color: _hasValidPhone
                                ? const Color(0xff4ade80)
                                : const Color(0xfffcd34d),
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _hasValidPhone
                                ? '+${_phoneController.text}'
                                : T.t('No Mobile Number'),
                            style: TextStyle(
                              color: _hasValidPhone
                                  ? Colors.white.withValues(alpha: 0.9)
                                  : const Color(0xfffcd34d),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                  tooltip: T.t('Close'),
                ),
              ],
            ),
          ),

          // Scrollable Form Body
          Flexible(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
              children: [
                // Mode Toggle Tabs (Daily vs Monthly)
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xfff1f5f3),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xffe2e8e4)),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _billType = BillType.daily;
                              _errorMessage = null;
                              _successMessage = null;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _billType == BillType.daily
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _billType == BillType.daily
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.08),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    LucideIcons.sunMedium,
                                    size: 15,
                                    color: _billType == BillType.daily
                                        ? const Color(0xff075e54)
                                        : Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        T.t('Daily Milk Update'),
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontWeight: _billType == BillType.daily
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: _billType == BillType.daily
                                              ? const Color(0xff075e54)
                                              : Colors.grey.shade700,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _billType = BillType.monthly;
                              _errorMessage = null;
                              _successMessage = null;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _billType == BillType.monthly
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _billType == BillType.monthly
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.08),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    LucideIcons.receiptText,
                                    size: 15,
                                    color: _billType == BillType.monthly
                                        ? const Color(0xff075e54)
                                        : Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        T.t('Monthly Bill Statement'),
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontWeight: _billType == BillType.monthly
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: _billType == BillType.monthly
                                              ? const Color(0xff075e54)
                                              : Colors.grey.shade700,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Success or Error banner
                if (_successMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xffecfdf5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xffa7f3d0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.circleCheck,
                            color: Color(0xff059669), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _successMessage!,
                            style: const TextStyle(
                              color: Color(0xff065f46),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xfffef2f2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xfffecaca)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(LucideIcons.circleAlert,
                                color: Color(0xffdc2626), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Color(0xff991b1b),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_hasValidPhone) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _openWhatsAppDirect,
                            icon: const Icon(LucideIcons.messageCircle,
                                size: 16, color: Color(0xff16a34a)),
                            label: Text(
                              T.t('Send directly via WhatsApp App instead'),
                              style: const TextStyle(
                                color: Color(0xff16a34a),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Warning if Customer Has No Valid Mobile Number
                if (!_hasValidPhone) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xfffffbeb),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xfffde68a)),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.triangleAlert,
                            color: Colors.amber.shade900, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            T.t('Customer has no valid mobile number. Please enter a 10-digit number below to send message.'),
                            style: TextStyle(
                              color: Colors.amber.shade900,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Recipient WhatsApp Number Field
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(15),
                  ],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: T.t('Recipient WhatsApp Number'),
                    hintText: '919876543210',
                    prefixIcon: const Icon(LucideIcons.phone, size: 18),
                    helperText: T.t('Include country code (e.g. 919876543210), digits only.'),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // MODE SPECIFIC INPUT FIELDS
                if (_billType == BillType.daily) ...[
                  // Date Picker (Clean, without Shift selector)
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(10),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: T.t('Delivery Date'),
                        prefixIcon: const Icon(LucideIcons.calendar, size: 18),
                        suffixIcon: const Icon(LucideIcons.calendarClock, size: 16),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        _formatDate(_selectedDate),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Liters and Rate
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _dailyLitersController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          onChanged: (_) => _onDailyLitersOrRateChanged(),
                          decoration: InputDecoration(
                            labelText: T.t('Today Milk'),
                            prefixIcon:
                                const Icon(LucideIcons.droplet, size: 18),
                            suffixText: 'L',
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _rateController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          onChanged: (_) => _onDailyLitersOrRateChanged(),
                          decoration: InputDecoration(
                            labelText: T.t('Rate / Liter'),
                            prefixIcon:
                                const Icon(LucideIcons.indianRupee, size: 18),
                            prefixText: '₹',
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xfff0fdf4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xffbbf7d0)),
                      ),
                      child: Text(
                        "${T.t('Today Amount')}: ₹${((double.tryParse(_dailyLitersController.text) ?? 0.0) * (double.tryParse(_rateController.text) ?? 0.0)).toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xff166534),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Current Month (Till Date) & Past Overdue
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _monthToDateBillController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: T.t('Current Month'),
                            helperText: T.t('Till Date Bill'),
                            prefixIcon:
                                const Icon(LucideIcons.calendarDays, size: 18),
                            prefixText: '₹',
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _pastOverdueController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: T.t('Past Overdue'),
                            helperText: T.t('Unpaid Balance'),
                            prefixIcon:
                                const Icon(LucideIcons.history, size: 18),
                            prefixText: '₹',
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // MONTHLY MODE FIELDS
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _monthNameController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: T.t('Billing Month'),
                            prefixIcon:
                                const Icon(LucideIcons.calendar, size: 18),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _totalDaysController,
                          keyboardType: TextInputType.number,
                          onChanged: _onDaysChanged,
                          decoration: InputDecoration(
                            labelText: T.t('Days'),
                            suffixText: 'days',
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _monthlyLitersController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: T.t('Total Liters'),
                            prefixIcon:
                                const Icon(LucideIcons.droplet, size: 18),
                            suffixText: 'L',
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _rateController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: T.t('Rate / Liter'),
                            prefixIcon:
                                const Icon(LucideIcons.indianRupee, size: 18),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _monthlyAmountController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: T.t('Monthly Milk Bill'),
                            prefixIcon:
                                const Icon(LucideIcons.receiptText, size: 18),
                            prefixText: '₹',
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _paidAmountController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: T.t('Amount Received'),
                            prefixIcon:
                                const Icon(LucideIcons.circleCheck, size: 18),
                            prefixText: '₹',
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _pastOverdueController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: T.t('Past Overdue'),
                            prefixIcon:
                                const Icon(LucideIcons.history, size: 18),
                            prefixText: '₹',
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _advanceCreditController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: T.t('Advance Credit'),
                            prefixIcon: const Icon(LucideIcons.coins, size: 18),
                            prefixText: '₹',
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),

                // NET PAYABLE HIGHLIGHT CARD
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xffe7f7ef), Color(0xfff0fdf4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xff86efac)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _billType == BillType.daily
                                ? T.t("TODAY'S TOTAL AMOUNT")
                                : T.t('NET TOTAL PAYABLE'),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: Color(0xff075e54),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _billType == BillType.daily
                                ? '${T.t("Today's Milk")} (${(double.tryParse(_dailyLitersController.text) ?? 0.0).toStringAsFixed(1)} L @ ₹${rate.toStringAsFixed(2)}/L)'
                                : '${T.t('Bill')} + ${T.t('Past Overdue')} - ${T.t('Advance')}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '₹${calculatedTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xff075e54),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // LIVE WHATSAPP CHAT BUBBLE PREVIEW
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xffece5dd),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xffd1d7db)),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header of Preview
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(LucideIcons.messageSquare,
                                  size: 15, color: Color(0xff075e54)),
                              const SizedBox(width: 6),
                              Text(
                                T.t('WhatsApp Message Preview'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xff075e54),
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(
                                ClipboardData(text: _buildFormattedMessage()),
                              );
                              Get.snackbar(
                                T.t('Copied!'),
                                T.t('Message copied to clipboard'),
                                duration: const Duration(seconds: 2),
                                snackPosition: SnackPosition.BOTTOM,
                              );
                            },
                            child: Row(
                              children: [
                                const Icon(LucideIcons.copy,
                                    size: 13, color: Color(0xff075e54)),
                                const SizedBox(width: 4),
                                Text(
                                  T.t('Copy'),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xff075e54),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // WhatsApp Outgoing Chat Bubble
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.82,
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xffdcf8c6),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(14),
                              topRight: Radius.circular(0),
                              bottomLeft: Radius.circular(14),
                              bottomRight: Radius.circular(14),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _buildFormattedMessage(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.42,
                                  color: Color(0xff111b21),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  const Spacer(),
                                  Text(
                                    '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    LucideIcons.checkCheck,
                                    size: 14,
                                    color: Color(0xff53bdeb),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ACTION BUTTONS
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: (_sending || !_hasValidPhone)
                        ? null
                        : _sendViaBackend,
                    icon: _sending
                        ? DairyMilkLoader.mini(color: Colors.white, size: 18)
                        : const Icon(LucideIcons.send, size: 18),
                    label: Text(
                      _sending
                          ? T.t('Sending WhatsApp Bill...')
                          : T.t('Send WhatsApp Bill (API)'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xff075e54),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      disabledForegroundColor: Colors.grey.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _hasValidPhone ? _openWhatsAppDirect : null,
                    icon: const Icon(LucideIcons.messageCircle,
                        size: 18, color: Color(0xff25D366)),
                    label: Text(
                      T.t('Open in WhatsApp App'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xff075e54),
                      side: const BorderSide(color: Color(0xff25D366), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
