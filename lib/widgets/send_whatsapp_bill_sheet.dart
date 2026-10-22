import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../services/app_language.dart';

enum BillType { daily, monthly }

class SendWhatsAppBillSheet extends StatefulWidget {
  const SendWhatsAppBillSheet({
    super.key,
    required this.api,
    required this.customer,
  });

  final ApiService api;
  final Map<String, dynamic> customer;

  static Future<void> show(
    BuildContext context, {
    required ApiService api,
    required Map<String, dynamic> customer,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SendWhatsAppBillSheet(api: api, customer: customer),
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
  late final TextEditingController _notesController;

  // Monthly mode controllers
  late final TextEditingController _monthNameController;
  late final TextEditingController _totalDaysController;
  late final TextEditingController _monthlyLitersController;
  late final TextEditingController _previousDueController;

  DateTime _selectedDate = DateTime.now();
  String _session = 'Morning';

  bool _sending = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();

    final customer = widget.customer;
    final rawPhone = '${customer['phoneNumber'] ?? customer['phone'] ?? ''}'.trim();
    final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    final cleanPhone = digits.length == 10 ? '91$digits' : digits;

    final defaultLiters = _asDouble(customer['liters'], 1.0);
    final defaultPrice = _asDouble(customer['price'], 60.0);

    _phoneController = TextEditingController(text: cleanPhone);
    _dailyLitersController = TextEditingController(
      text: defaultLiters.toStringAsFixed(1),
    );
    _rateController = TextEditingController(
      text: defaultPrice.toStringAsFixed(2),
    );
    _notesController = TextEditingController();

    // Monthly defaults
    final now = DateTime.now();
    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    _monthNameController = TextEditingController(
      text: '${monthNames[now.month - 1]} ${now.year}',
    );
    _totalDaysController = TextEditingController(text: '30');
    _monthlyLitersController = TextEditingController(
      text: (defaultLiters * 30).toStringAsFixed(1),
    );
    _previousDueController = TextEditingController(text: '0');

    _session = now.hour < 14 ? 'Morning' : 'Evening';
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _dailyLitersController.dispose();
    _rateController.dispose();
    _notesController.dispose();
    _monthNameController.dispose();
    _totalDaysController.dispose();
    _monthlyLitersController.dispose();
    _previousDueController.dispose();
    super.dispose();
  }

  double _asDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? fallback;
  }

  void _onDaysChanged(String value) {
    final days = double.tryParse(value) ?? 0;
    final litersPerDay = double.tryParse(_dailyLitersController.text) ?? 0;
    setState(() {
      _monthlyLitersController.text = (days * litersPerDay).toStringAsFixed(1);
    });
  }

  String get _customerName {
    final c = widget.customer;
    return '${c['name'] ?? c['fullName'] ?? 'Customer'}'.trim();
  }

  String _formatDate(DateTime d) {
    final monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day.toString().padLeft(2, '0')} ${monthNames[d.month - 1]} ${d.year}';
  }

  String _buildFormattedMessage() {
    final name = _customerName;
    final note = _notesController.text.trim();
    final rate = double.tryParse(_rateController.text) ?? 0.0;

    if (_billType == BillType.daily) {
      final liters = double.tryParse(_dailyLitersController.text) ?? 0.0;
      final total = liters * rate;
      final dateStr = _formatDate(_selectedDate);

      final lines = [
        '🥛 *DAILY MILK DELIVERY UPDATE* 🥛',
        '━━━━━━━━━━━━━━━━━━━━━━━━━━━',
        '👤 *Customer:* $name',
        '📅 *Date:* $dateStr',
        '⏰ *Session:* $_session',
        '━━━━━━━━━━━━━━━━━━━━━━━━━━━',
        '📦 *Today\'s Quantity:* ${liters.toStringAsFixed(1)} Liters',
        '💰 *Rate:* ₹${rate.toStringAsFixed(2)} / Liter',
        '💵 *Today\'s Total:* ₹${total.toStringAsFixed(2)}',
        if (note.isNotEmpty) '\n📝 *Note:* $note',
        '━━━━━━━━━━━━━━━━━━━━━━━━━━━',
        '🙏 *Thank you for choosing our dairy!*',
      ];
      return lines.join('\n');
    } else {
      final month = _monthNameController.text.trim();
      final days = int.tryParse(_totalDaysController.text) ?? 30;
      final totalLiters = double.tryParse(_monthlyLitersController.text) ?? 0.0;
      final monthlyAmount = totalLiters * rate;
      final prevDue = double.tryParse(_previousDueController.text) ?? 0.0;
      final netPayable = monthlyAmount + prevDue;

      final lines = [
        '🧾 *MONTHLY MILK BILLING STATEMENT* 🧾',
        '━━━━━━━━━━━━━━━━━━━━━━━━━━━',
        '👤 *Customer:* $name',
        '📅 *Billing Month:* $month',
        '🗓️ *Total Delivery Days:* $days Days',
        '━━━━━━━━━━━━━━━━━━━━━━━━━━━',
        '🥛 *Total Milk Delivered:* ${totalLiters.toStringAsFixed(1)} Liters',
        '💰 *Rate per Liter:* ₹${rate.toStringAsFixed(2)} / Liter',
        '💵 *Monthly Milk Charge:* ₹${monthlyAmount.toStringAsFixed(2)}',
        if (prevDue > 0) '⚠️ *Previous Balance Due:* ₹${prevDue.toStringAsFixed(2)}',
        '━━━━━━━━━━━━━━━━━━━━━━━━━━━',
        '💳 *NET TOTAL PAYABLE:* ₹${netPayable.toStringAsFixed(2)}',
        if (note.isNotEmpty) '\n📝 *Note:* $note',
        '━━━━━━━━━━━━━━━━━━━━━━━━━━━',
        '📲 *Please complete payment by cash or UPI.*',
        '🙏 *Thank you for your business!*',
      ];
      return lines.join('\n');
    }
  }

  Future<void> _sendViaBackend() async {
    final cleanPhone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.length < 10) {
      setState(() {
        _errorMessage = T.t('Please enter a valid phone number with country code (e.g. 919876543210)');
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
    final note = _notesController.text.trim();

    try {
      if (_billType == BillType.daily) {
        final liters = double.tryParse(_dailyLitersController.text) ?? 0.0;
        final total = liters * rate;
        await widget.api.sendWhatsAppBill({
          'to': cleanPhone,
          'customerName': _customerName,
          'type': 'daily',
          'date': _formatDate(_selectedDate),
          'deliverySession': _session,
          'liters': liters,
          'ratePerLiter': rate,
          'totalAmount': total,
          'notes': note.isEmpty ? null : note,
          'useTemplate': true,
        });
      } else {
        final totalLiters = double.tryParse(_monthlyLitersController.text) ?? 0.0;
        final monthlyAmount = totalLiters * rate;
        final prevDue = double.tryParse(_previousDueController.text) ?? 0.0;
        await widget.api.sendWhatsAppBill({
          'to': cleanPhone,
          'customerName': _customerName,
          'type': 'monthly',
          'monthName': _monthNameController.text.trim(),
          'totalDays': int.tryParse(_totalDaysController.text) ?? 30,
          'totalLiters': totalLiters,
          'liters': totalLiters,
          'ratePerLiter': rate,
          'monthlyAmount': monthlyAmount,
          'totalAmount': monthlyAmount,
          'previousDue': prevDue,
          'notes': note.isEmpty ? null : note,
          'useTemplate': true,
        });
      }

      setState(() {
        _successMessage = T.t('WhatsApp message sent successfully!');
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

    final nativeUri = Uri.parse('whatsapp://send?phone=$cleanPhone&text=$encodedMessage');
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
    final number =
        '${widget.customer['uniqueNumber'] ?? widget.customer['customerNumber'] ?? '—'}';
    final rate = double.tryParse(_rateController.text) ?? 0.0;

    double calculatedTotal = 0;
    if (_billType == BillType.daily) {
      final liters = double.tryParse(_dailyLitersController.text) ?? 0.0;
      calculatedTotal = liters * rate;
    } else {
      final totalLiters = double.tryParse(_monthlyLitersController.text) ?? 0.0;
      final prevDue = double.tryParse(_previousDueController.text) ?? 0.0;
      calculatedTotal = (totalLiters * rate) + prevDue;
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            decoration: const BoxDecoration(
              color: Color(0xff2d7a55),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    LucideIcons.messageCircle,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        T.t('Send WhatsApp Milk Bill'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$_customerName • #$number',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),

          // Scrollable Form Body
          Flexible(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Mode Toggle Tabs (Daily vs Monthly)
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xfff0f4f1),
                    borderRadius: BorderRadius.circular(12),
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
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _billType == BillType.daily
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _billType == BillType.daily
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.06),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  LucideIcons.sunMedium,
                                  size: 16,
                                  color: _billType == BillType.daily
                                      ? const Color(0xff2d7a55)
                                      : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  T.t('Daily Milk Update'),
                                  style: TextStyle(
                                    fontWeight: _billType == BillType.daily
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: _billType == BillType.daily
                                        ? const Color(0xff2d7a55)
                                        : Colors.grey.shade700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
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
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _billType == BillType.monthly
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _billType == BillType.monthly
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.06),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  LucideIcons.receiptText,
                                  size: 16,
                                  color: _billType == BillType.monthly
                                      ? const Color(0xff2d7a55)
                                      : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  T.t('Monthly Total Bill'),
                                  style: TextStyle(
                                    fontWeight: _billType == BillType.monthly
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: _billType == BillType.monthly
                                        ? const Color(0xff2d7a55)
                                        : Colors.grey.shade700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

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
                        const Icon(LucideIcons.circleCheck, color: Color(0xff059669), size: 20),
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
                  const SizedBox(height: 14),
                ],
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xfffef2f2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xfffecaca)),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.circleAlert, color: Color(0xffdc2626), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Color(0xff991b1b),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Recipient WhatsApp Number
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: T.t('Recipient WhatsApp Number'),
                    hintText: '919876543210',
                    prefixIcon: const Icon(LucideIcons.phone, size: 18),
                    helperText: T.t('Include country code (e.g. 91 for India), no + or spaces.'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 14),

                // Mode Specific Fields
                if (_billType == BillType.daily) ...[
                  // Date and Session Row
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickDate,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: T.t('Delivery Date'),
                              prefixIcon: const Icon(LucideIcons.calendar, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(
                              _formatDate(_selectedDate),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _session,
                          decoration: InputDecoration(
                            labelText: T.t('Session'),
                            prefixIcon: const Icon(LucideIcons.clock, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Morning', child: Text('🌅 Morning')),
                            DropdownMenuItem(value: 'Evening', child: Text('🌇 Evening')),
                            DropdownMenuItem(value: 'Full Day', child: Text('☀️ Full Day')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _session = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Liters and Rate
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _dailyLitersController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: T.t('Today\'s Liters'),
                            prefixIcon: const Icon(LucideIcons.droplet, size: 18),
                            suffixText: 'L',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _rateController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: T.t('Rate / Liter'),
                            prefixIcon: const Icon(LucideIcons.indianRupee, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Monthly Fields
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _monthNameController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: T.t('Billing Month'),
                            prefixIcon: const Icon(LucideIcons.calendar, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _totalDaysController,
                          keyboardType: TextInputType.number,
                          onChanged: _onDaysChanged,
                          decoration: InputDecoration(
                            labelText: T.t('Days'),
                            suffixText: 'days',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _monthlyLitersController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: T.t('Total Month Liters'),
                            prefixIcon: const Icon(LucideIcons.droplet, size: 18),
                            suffixText: 'L',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _rateController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: T.t('Rate / Liter'),
                            prefixIcon: const Icon(LucideIcons.indianRupee, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Previous Due
                  TextField(
                    controller: _previousDueController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: T.t('Previous Due / Balance (₹)'),
                      prefixIcon: const Icon(LucideIcons.circleAlert, size: 18),
                      hintText: '0',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
                const SizedBox(height: 14),

                // Note Field
                TextField(
                  controller: _notesController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: T.t('Optional Note'),
                    hintText: _billType == BillType.daily
                        ? 'Delivered to doorstep / Paid in cash'
                        : 'UPI: dairy@upi / Pay before 5th',
                    prefixIcon: const Icon(LucideIcons.fileText, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 16),

                // Total Summary Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xfff0fdf4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xffbbf7d0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _billType == BillType.daily
                            ? T.t('Today\'s Total Amount:')
                            : T.t('Net Total Payable:'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xff166534),
                        ),
                      ),
                      Text(
                        '₹${calculatedTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff166534),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Live Preview Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xfff8fafc),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(LucideIcons.eye, size: 16, color: Color(0xff2d7a55)),
                              const SizedBox(width: 6),
                              Text(
                                T.t('Live Message Preview'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Color(0xff334155),
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: _buildFormattedMessage()));
                              Get.snackbar(
                                T.t('Copied!'),
                                T.t('Message copied to clipboard'),
                                duration: const Duration(seconds: 2),
                                snackPosition: SnackPosition.BOTTOM,
                              );
                            },
                            child: Row(
                              children: [
                                const Icon(LucideIcons.copy, size: 14, color: Color(0xff2d7a55)),
                                const SizedBox(width: 4),
                                Text(
                                  T.t('Copy'),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xff2d7a55),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(
                          _buildFormattedMessage(),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11.5,
                            height: 1.4,
                            color: Color(0xff1e293b),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Actions
                Row(
                  children: [
                    // Open in WhatsApp App button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _openWhatsAppDirect,
                        icon: const Icon(LucideIcons.messageSquare, size: 18),
                        label: Text(T.t('Open in WhatsApp')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xff128C7E),
                          side: const BorderSide(color: Color(0xff128C7E)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Send via API button
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _sending ? null : _sendViaBackend,
                        icon: _sending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(LucideIcons.send, size: 18),
                        label: Text(_sending ? T.t('Sending...') : T.t('Send Bill')),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xff2d7a55),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
