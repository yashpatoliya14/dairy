import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../controllers/monthly_entries_controller.dart';
import '../services/api_service.dart';
import '../services/app_language.dart';
import '../widgets/dairy_milk_loader.dart';
import '../widgets/send_whatsapp_bill_sheet.dart' as whatsapp_sheet;
import '../widgets/payment_entry_sheet.dart';

class CustomerBillPage extends StatefulWidget {
  const CustomerBillPage({
    super.key,
    required this.api,
    required this.customer,
    required this.controller,
  });

  final ApiService api;
  final Map<String, dynamic> customer;
  final MonthlyEntriesController controller;

  @override
  State<CustomerBillPage> createState() => _CustomerBillPageState();
}

class _CustomerBillPageState extends State<CustomerBillPage> {
  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  String _monthLabel(int month, int year) {
    final name = (month >= 1 && month <= 12) ? _monthNames[month - 1] : 'Month';
    return '$name $year';
  }

  String _numberToIndianWords(double number) {
    if (number <= 0) return 'Zero Rupees Only';
    final rounded = number.round();
    final units = [
      '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
      'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
      'Seventeen', 'Eighteen', 'Nineteen',
    ];
    final tens = [
      '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety',
    ];

    String convertLessThanThousand(int n) {
      if (n == 0) return '';
      if (n < 20) return units[n];
      if (n < 100) {
        return tens[n ~/ 10] + (n % 10 != 0 ? ' ${units[n % 10]}' : '');
      }
      return '${units[n ~/ 100]} Hundred${n % 100 != 0 ? ' and ${convertLessThanThousand(n % 100)}' : ''}';
    }

    final crore = rounded ~/ 10000000;
    final lakh = (rounded % 10000000) ~/ 100000;
    final thousand = (rounded % 100000) ~/ 1000;
    final remainder = rounded % 1000;

    final parts = <String>[];
    if (crore > 0) parts.add('${convertLessThanThousand(crore)} Crore');
    if (lakh > 0) parts.add('${convertLessThanThousand(lakh)} Lakh');
    if (thousand > 0) parts.add('${convertLessThanThousand(thousand)} Thousand');
    if (remainder > 0) parts.add(convertLessThanThousand(remainder));

    return '${parts.join(' ')} Rupees Only';
  }

  void _copyBill() {
    final c = widget.controller;
    final monthName = _monthLabel(c.selectedMonth.value, c.selectedYear.value);
    final totalAmount = c.billTotalAmount;
    final words = _numberToIndianWords(totalAmount);
    final dairy = c.dairyName.value.isNotEmpty ? c.dairyName.value : 'Dairy Desk';
    final distributor = c.distributorName.value.isNotEmpty ? c.distributorName.value : 'Dairy Owner';
    final phone = c.distributorPhone.value.isNotEmpty ? c.distributorPhone.value : '';

    final text = [
      '🧾 *MILK BILL STATEMENT*',
      'Dairy: $dairy',
      'Customer: ${c.customerName} (#${c.customerNumber})',
      'Month: $monthName',
      '• Delivery Days: ${c.activeDeliveryDays} / ${c.daysInMonth.value}',
      '• Total Milk: ${c.totalLiters.value.toStringAsFixed(2)} L',
      '• Rate: ₹${c.effectiveRate.toStringAsFixed(2)}/L',
      '• Monthly Bill: ₹${totalAmount.toStringAsFixed(2)}',
      if (c.pastMonthsDue.value > 0)
        '• Past Overdue: ₹${c.pastMonthsDue.value.toStringAsFixed(2)}',
      if (c.hasPayment.value) ...[
        '• Amount Received: ₹${c.paymentReceived.value.toStringAsFixed(2)}',
        if (c.balanceDue > 0)
          '• *Balance Due: ₹${c.balanceDue.toStringAsFixed(2)}*'
        else
          '• *Status: Fully Paid (₹0.00 Due)*',
      ] else ...[
        '• *Net Total Due: ₹${totalAmount.toStringAsFixed(2)}*',
      ],
      '  ($words)',
      if (phone.isNotEmpty) '📞 Distributor: $distributor ($phone)',
    ].join('\n');

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(T.t('Bill copied to clipboard')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openPaymentSheet() async {
    final c = widget.controller;
    final monthName = _monthLabel(c.selectedMonth.value, c.selectedYear.value);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PaymentEntrySheet(
        customerName: c.customerName,
        customerNumber: c.customerNumber,
        month: c.selectedMonth.value,
        year: c.selectedYear.value,
        monthName: monthName,
        totalLiters: c.totalLiters.value,
        effectiveRate: c.effectiveRate,
        totalAmount: c.billTotalAmount,
        previousDue: c.grossPastDue.value,
        previousAdvance: c.grossPastAdvance.value,
        pastMonthsBreakdown: c.pastMonthsBreakdown,
        daysInMonth: c.daysInMonth.value,
        activeDeliveryDays: c.activeDeliveryDays,
        initialReceived: c.hasPayment.value ? c.paymentReceived.value : null,
        initialNote: c.paymentNote.value,
        initialDate: c.paymentDate.value,
        hasExistingPayment: c.hasPayment.value,
        onSave: ({
          required double receivedAmount,
          String? note,
          DateTime? receivedDate,
        }) async {
          await c.savePayment(
            receivedAmount: receivedAmount,
            note: note,
            receivedDate: receivedDate,
          );
          if (mounted) setState(() {});
        },
        onDelete: () async {
          await c.deletePayment();
          if (mounted) setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;

    return Obx(() {
      // Show loader while data is being fetched
      if (c.loading.value) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              '${T.t('Bill')} - ${c.customerName}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xff166534),
            elevation: 0,
          ),
          body: const Center(
            child: DairyMilkLoader(size: 48, message: 'Loading bill...'),
          ),
        );
      }

      final monthName = _monthLabel(c.selectedMonth.value, c.selectedYear.value);
      final daysInMonth = c.daysInMonth.value;
      final totalLiters = c.totalLiters.value;
      final totalAmount = c.billTotalAmount;
      final effectiveRate = c.effectiveRate;
      final activeDays = c.activeDeliveryDays;
      final offDays = c.zeroDeliveryDays + c.missingDays;
      final dailyAvg = c.averageDailyLiters;
      final invoiceNumber =
          'INV-${c.selectedYear.value}${c.selectedMonth.value.toString().padLeft(2, '0')}-${c.customerNumber}';
      final now = DateTime.now();
      final todayFormatted =
          '${now.day.toString().padLeft(2, '0')} ${_monthNames[now.month - 1].substring(0, 3)} ${now.year}';
      final words = _numberToIndianWords(totalAmount);

      return Scaffold(
        appBar: AppBar(
          title: Text(
            '${T.t('Bill')} - ${c.customerName}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xff166534),
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(LucideIcons.refreshCw, size: 20),
              tooltip: T.t('Refresh'),
              onPressed: () async {
                await widget.controller.loadMonth();
                if (mounted) setState(() {});
              },
            ),
            IconButton(
              icon: const Icon(LucideIcons.copy, size: 20),
              tooltip: T.t('Copy Bill'),
              onPressed: _copyBill,
            ),
            IconButton(
              icon: const Icon(LucideIcons.messageCircle, size: 20),
              tooltip: T.t('Send WhatsApp Bill'),
              onPressed: () {
                whatsapp_sheet.SendWhatsAppBillSheet.show(
                  context,
                  api: widget.api,
                  customer: widget.customer,
                  initialBillType: whatsapp_sheet.BillType.monthly,
                  initialMonthName: monthName,
                  initialTotalDays: daysInMonth,
                  initialMonthlyLiters: totalLiters,
                  initialRate: effectiveRate,
                  initialMonthlyAmount: totalAmount,
                  initialPaidAmount: c.hasPayment.value ? c.paymentReceived.value : 0.0,
                  initialPreviousDue: c.pastMonthsDue.value,
                  initialMonthToDateBill: totalAmount,
                  initialAdvanceCredit: c.grossPastAdvance.value > 0 ? c.grossPastAdvance.value : c.netAdvance.value,
                );
              },
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            await widget.controller.loadMonth();
            if (mounted) setState(() {});
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Dairy Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xfff0fdf4), Color(0xffdcfce7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xff86efac)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          c.dairyName.value.isNotEmpty ? c.dairyName.value : 'Dairy Desk',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xff166534),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: c.isFullyPaid
                                ? const Color(0xff166534)
                                : c.isPartiallyPaid
                                    ? const Color(0xffd97706)
                                    : const Color(0xff1e40af),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            c.isFullyPaid
                                ? T.t('Fully Paid')
                                : c.isPartiallyPaid
                                    ? T.t('Partially Paid')
                                    : T.t('Unpaid'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${T.t('Invoice No.')} $invoiceNumber  •  $todayFormatted',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Customer & Period Details Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xffe2e8f0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      T.t('Billed To'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff475569),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          c.customerName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff0f172a),
                          ),
                        ),
                        Text(
                          '#${c.customerNumber}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    _detailRow(T.t('Billing Period'), monthName),
                    const SizedBox(height: 6),
                    _detailRow(T.t('Delivery Days'), '$activeDays / $daysInMonth ${T.t('Days')}'),
                    const SizedBox(height: 6),
                    _detailRow(T.t('Absent / Off Days'), '$offDays ${T.t('Days')}'),
                    const SizedBox(height: 6),
                    _detailRow(T.t('Daily Average'), '${dailyAvg.toStringAsFixed(2)} L/day'),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Quantity & Rates Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xffe2e8f0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      T.t('Bill Breakdown'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff475569),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _detailRow(T.t('Total Milk Supplied'), '${totalLiters.toStringAsFixed(2)} L', isBold: true),
                    const SizedBox(height: 6),
                    _detailRow(T.t('Rate per Liter'), '₹${effectiveRate.toStringAsFixed(2)}/L', isBold: true),
                    const Divider(height: 18),
                    _detailRow(T.t('This Month Bill'), '₹${totalAmount.toStringAsFixed(2)}'),
                    if (c.pastMonthsDue.value > 0) ...[
                      const SizedBox(height: 6),
                      _detailRow(
                        c.pastMonthsBreakdown.isNotEmpty
                            ? '${T.t('Past Overdue')} (${c.pastMonthsBreakdown.join(', ')})'
                            : T.t('Past Overdue'),
                        '+₹${c.pastMonthsDue.value.toStringAsFixed(2)}',
                        color: const Color(0xffdc2626),
                      ),
                    ],
                    if ((c.grossPastAdvance.value > 0
                            ? c.grossPastAdvance.value
                            : c.netAdvance.value) > 0) ...[
                      const SizedBox(height: 6),
                      _detailRow(
                        T.t('Advance Credit'),
                        '-₹${(c.grossPastAdvance.value > 0 ? c.grossPastAdvance.value : c.netAdvance.value).toStringAsFixed(2)}',
                        color: const Color(0xff16a34a),
                      ),
                    ],
                    if (c.hasPayment.value) ...[
                      const SizedBox(height: 6),
                      _detailRow(
                        '${T.t('Amount Received')}${c.paymentDate.value != null ? ' (${c.paymentDate.value!.day}/${c.paymentDate.value!.month})' : ''}',
                        '-₹${c.paymentReceived.value.toStringAsFixed(2)}',
                        color: const Color(0xff2563eb),
                        isBold: true,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Net Due Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: c.isFullyPaid
                      ? const Color(0xff064e3b)
                      : c.isPartiallyPaid
                          ? const Color(0xff78350f)
                          : const Color(0xff064e3b),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          c.isFullyPaid
                              ? '${T.t('Amount Paid')} (${T.t('Fully Paid')})'
                              : T.t('Net Total Due'),
                          style: TextStyle(
                            color: c.isPartiallyPaid
                                ? const Color(0xfffef08a)
                                : const Color(0xffa7f3d0),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          c.isFullyPaid
                              ? '₹${(c.paymentReceived.value > 0 ? c.paymentReceived.value : totalAmount).toStringAsFixed(2)}'
                              : '₹${c.netTotalPayable.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      c.isFullyPaid
                          ? '${_numberToIndianWords(c.paymentReceived.value > 0 ? c.paymentReceived.value : totalAmount)}  •  ${T.t('Remaining Due')}: ₹0.00'
                          : words,
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Bottom Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openPaymentSheet,
                      icon: const Icon(LucideIcons.receipt, size: 16),
                      label: Text(
                        c.hasPayment.value
                            ? T.t('Edit Payment')
                            : T.t('Payment Entry'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        whatsapp_sheet.SendWhatsAppBillSheet.show(
                          context,
                          api: widget.api,
                          customer: widget.customer,
                          initialBillType: whatsapp_sheet.BillType.monthly,
                          initialMonthName: monthName,
                          initialTotalDays: daysInMonth,
                          initialMonthlyLiters: totalLiters,
                          initialRate: effectiveRate,
                          initialMonthlyAmount: totalAmount,
                          initialPaidAmount: c.hasPayment.value ? c.paymentReceived.value : 0.0,
                          initialPreviousDue: c.pastMonthsDue.value,
                          initialMonthToDateBill: totalAmount,
                          initialAdvanceCredit: c.grossPastAdvance.value > 0 ? c.grossPastAdvance.value : c.netAdvance.value,
                        );
                      },
                      icon: const Icon(LucideIcons.messageCircle, size: 16),
                      label: Text(
                        T.t('Send WhatsApp'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xff25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  });
  }

  Widget _detailRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: const Color(0xff475569),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color ?? const Color(0xff0f172a),
          ),
        ),
      ],
    );
  }
}
