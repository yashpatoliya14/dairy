import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../controllers/monthly_entries_controller.dart';
import '../services/api_service.dart';
import '../services/app_language.dart';
import 'dairy_milk_loader.dart';
import 'send_whatsapp_bill_sheet.dart';

/// Full-screen monthly milk entry table for a single customer.
class MonthlyEntriesScreen extends StatefulWidget {
  const MonthlyEntriesScreen({
    super.key,
    required this.api,
    required this.customer,
  });

  final ApiService api;
  final Map<String, dynamic> customer;

  @override
  State<MonthlyEntriesScreen> createState() => _MonthlyEntriesScreenState();
}

class _MonthlyEntriesScreenState extends State<MonthlyEntriesScreen> {
  late final MonthlyEntriesController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(
      MonthlyEntriesController(widget.api),
      tag: 'monthly_${widget.customer['id']}',
    );
    controller.setCustomer(widget.customer);
  }

  @override
  void dispose() {
    Get.delete<MonthlyEntriesController>(
      tag: 'monthly_${widget.customer['id']}',
    );
    super.dispose();
  }

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  String _monthLabel(int month, int year) {
    return '${T.t(_monthNames[month - 1])} $year';
  }

  String _dayLabel(int day, int month) {
    final m = T.t(_monthNames[month - 1]).substring(0, 3);
    return '$day $m';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(
          _monthLabel(
            controller.selectedMonth.value,
            controller.selectedYear.value,
          ),
        )),
        actions: [
          Obx(() => controller.undoStack.isNotEmpty
              ? IconButton(
                  tooltip: T.t('Undo'),
                  onPressed: controller.saving.value ? null : _handleUndo,
                  icon: const Icon(LucideIcons.undo2),
                )
              : const SizedBox.shrink()),
          IconButton(
            tooltip: T.t('Select month'),
            onPressed: () => _pickMonthYear(context),
            icon: const Icon(LucideIcons.calendarDays),
          ),
        ],
      ),
      body: Column(
        children: [
          // Customer header card
          _buildCustomerHeader(context),
          // Month navigation bar
          _buildMonthNav(context, cs),
          // Small Professional Bill and Table
          Expanded(
            child: Obx(() {
              if (controller.loading.value && controller.entries.isEmpty) {
                return const Center(
                  child: DairyMilkLoader(
                    size: 48,
                    message: 'Loading monthly entries...',
                  ),
                );
              }
              if (controller.error.isNotEmpty && controller.entries.isEmpty) {
                return _buildError(context);
              }
              return RefreshIndicator(
                onRefresh: controller.loadMonth,
                child: _buildTable(context, cs),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xffdcefe3),
            child: Text(
              controller.customerName.isEmpty
                  ? '?'
                  : controller.customerName[0].toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xff2d7a55),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.customerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${T.t('Customer no.')} ${controller.customerNumber}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthNav(BuildContext context, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: T.t('Previous month'),
            onPressed: controller.previousMonth,
            icon: const Icon(LucideIcons.chevronLeft),
          ),
          Obx(() => TextButton(
            onPressed: () => _pickMonthYear(context),
            child: Text(
              _monthLabel(
                controller.selectedMonth.value,
                controller.selectedYear.value,
              ),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: cs.primary,
              ),
            ),
          )),
          IconButton(
            tooltip: T.t('Next month'),
            onPressed: controller.nextMonth,
            icon: const Icon(LucideIcons.chevronRight),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              controller.error.value,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: controller.loadMonth,
              icon: const Icon(LucideIcons.refreshCw),
              label: Text(T.t('Try again')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable(BuildContext context, ColorScheme cs) {
    final days = controller.daysInMonth.value;
    final now = DateTime.now();
    final isCurrentMonth = controller.selectedYear.value == now.year &&
        controller.selectedMonth.value == now.month;
    // Index 0: Small Professional Bill
    // Index 1: Table Column Headers
    // Index 2 .. days + 1: Day Rows
    final totalItems = days + 2;

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
      itemCount: totalItems,
      itemBuilder: (context, index) {
        if (index == 0) {
          // 1. FIRST: Small and Professional Bill
          return _buildSmallProfessionalBill(context, cs);
        }
        if (index == 1) {
          // 2. THEN: Table Column Header
          return _buildTableHeader(context, cs);
        }

        // 3. Daily milk table rows
        final day = index - 1;
        final entry = controller.entryForDay(day);
        final isToday = isCurrentMonth && day == now.day;
        final isPast = _isDayPast(day);

        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _DayRow(
            day: day,
            year: controller.selectedYear.value,
            month: controller.selectedMonth.value,
            dayLabel: _dayLabel(day, controller.selectedMonth.value),
            entry: entry,
            defaultPrice: controller.customerDefaultPrice,
            isToday: isToday,
            isPast: isPast,
            cs: cs,
            onTap: () => _openDayEditor(context, day, entry),
          ),
        );
      },
    );
  }

  Widget _buildTableHeader(BuildContext context, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 0, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(
              T.t('DATE / DAY'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: cs.primary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              T.t('LITERS (L)'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: cs.primary,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              T.t('RATE (₹)'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: cs.primary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              T.t('TOTAL (₹)'),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: cs.primary,
              ),
            ),
          ),
          const SizedBox(width: 38), // Space for action button
        ],
      ),
    );
  }

  Widget _buildSmallProfessionalBill(BuildContext context, ColorScheme cs) {
    final monthName = _monthLabel(
      controller.selectedMonth.value,
      controller.selectedYear.value,
    );
    final daysInMonth = controller.daysInMonth.value;
    final totalLiters = controller.totalLiters.value;
    final totalAmount = controller.totalAmount.value;
    final activeDays = controller.activeDeliveryDays;
    final effectiveRate = controller.effectiveRate;
    final invoiceNumber =
        'INV-${controller.selectedYear.value}${controller.selectedMonth.value.toString().padLeft(2, '0')}-${controller.customerNumber}';
    final words = _numberToIndianWords(totalAmount);
    final dairy = controller.dairyName.value.isNotEmpty
        ? controller.dairyName.value
        : 'Dairy Desk';

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xff2d7a55).withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Accent Line
            Container(
              height: 4,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xff15803d),
                    Color(0xff22c55e),
                    Color(0xff16a34a),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Invoice Header Bar: Dairy Name + Status Badge + Full view button
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xffdcfce7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          LucideIcons.receiptText,
                          color: Color(0xff166534),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    dairy,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: Color(0xff166534),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xffdcfce7),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(0xff86efac),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    T.t('Billed'),
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xff166534),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${T.t('Invoice No.')} $invoiceNumber  •  $monthName',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        iconSize: 18,
                        tooltip: T.t('View Full Invoice'),
                        onPressed: () => _showFullInvoiceDialog(context),
                        icon: const Icon(
                          LucideIcons.maximize2,
                          color: Color(0xff2d7a55),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 8),

                  // 4-Column Professional Metric Chips
                  Row(
                    children: [
                      // Total Liters
                      Expanded(
                        child: _CompactMetric(
                          icon: Icons.local_drink_outlined,
                          label: T.t('Total Liters'),
                          value: '${totalLiters.toStringAsFixed(1)} L',
                          color: const Color(0xff2d7a55),
                          bgColor: const Color(0xffdcefe3),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Rate per Liter
                      Expanded(
                        child: _CompactMetric(
                          icon: Icons.payments_outlined,
                          label: T.t('Rate per Liter'),
                          value: '₹${effectiveRate.toStringAsFixed(0)}/L',
                          color: const Color(0xff0284c7),
                          bgColor: const Color(0xffe0f2fe),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Days Delivered
                      Expanded(
                        child: _CompactMetric(
                          icon: LucideIcons.calendarCheck,
                          label: T.t('Delivery Days'),
                          value: '$activeDays/$daysInMonth',
                          color: const Color(0xff7c3aed),
                          bgColor: const Color(0xffede9fe),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Total Sum
                      Expanded(
                        child: _CompactMetric(
                          icon: LucideIcons.receipt,
                          label: T.t('Total Amount'),
                          value: '₹${totalAmount.toStringAsFixed(2)}',
                          color: const Color(0xff166534),
                          bgColor: const Color(0xffbbf7d0),
                          isHighlight: true,
                        ),
                      ),
                    ],
                  ),

                  if (totalAmount > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xfff8fafc),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            LucideIcons.check,
                            size: 12,
                            color: Color(0xff166534),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${T.t('Total Amount Payable')}: ₹${totalAmount.toStringAsFixed(2)} ($words)',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xff1e293b),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Quick Action Buttons (WhatsApp Bill & Copy Bill)
                  Row(
                    children: [
                      // Send WhatsApp Bill
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            SendWhatsAppBillSheet.show(
                              context,
                              api: widget.api,
                              customer: widget.customer,
                              initialBillType: BillType.monthly,
                              initialMonthName: monthName,
                              initialTotalDays: daysInMonth,
                              initialMonthlyLiters: totalLiters,
                              initialRate: effectiveRate,
                              initialPreviousDue: 0.0,
                            );
                          },
                          icon: const Icon(LucideIcons.messageCircle, size: 15),
                          label: Text(
                            T.t('Send WhatsApp Bill'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xff25D366),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            minimumSize: const Size.fromHeight(36),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Copy Bill
                      OutlinedButton.icon(
                        onPressed: () => _copyBillToClipboard(context),
                        icon: const Icon(LucideIcons.copy, size: 14),
                        label: Text(
                          T.t('Copy Bill'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          minimumSize: const Size(0, 36),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
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
      ),
    );
  }

  void _copyBillToClipboard(BuildContext context) {
    final monthName = _monthLabel(
      controller.selectedMonth.value,
      controller.selectedYear.value,
    );
    final daysInMonth = controller.daysInMonth.value;
    final totalLiters = controller.totalLiters.value;
    final totalAmount = controller.totalAmount.value;
    final effectiveRate = controller.effectiveRate;
    final activeDays = controller.activeDeliveryDays;
    final dairy = controller.dairyName.value.isNotEmpty
        ? controller.dairyName.value
        : 'Dairy Desk';
    final distributor = controller.distributorName.value.isNotEmpty
        ? controller.distributorName.value
        : 'Haresh Sambad';
    final phone = controller.distributorPhone.value.isNotEmpty
        ? controller.distributorPhone.value
        : '+91 9104152524';
    final words = _numberToIndianWords(totalAmount);

    final text = [
      '🥛 *$dairy - Monthly Milk Bill* 🥛',
      '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
      'Hello ${controller.customerName},',
      '',
      'Your milk bill for $monthName ($daysInMonth Days) has been generated.',
      '',
      '📋 *DELIVERY & BILL DETAILS:*',
      '• Customer: ${controller.customerName} (#${controller.customerNumber})',
      '• Delivery Days: $activeDays / $daysInMonth Days',
      '• Total Quantity: ${totalLiters.toStringAsFixed(1)} L',
      '• Rate: ₹${effectiveRate.toStringAsFixed(2)}/L',
      '• Monthly Charge: ₹${totalAmount.toStringAsFixed(2)}',
      '• Previous Due: ₹0.00',
      '• *Net Total Due: ₹${totalAmount.toStringAsFixed(2)}*',
      '  ($words)',
      '',
      '💳 *Payment Modes:* UPI (GPay/PhonePe/Paytm), Cash & Bank',
      '📞 *Distributor:* $distributor ($phone)',
      '',
      'Please settle the bill by the 5th of next month.',
      'Thank you for choosing $dairy!',
    ].join('\n');

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(T.t('Bill copied to clipboard')),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showFullInvoiceDialog(BuildContext context) {
    final monthName = _monthLabel(
      controller.selectedMonth.value,
      controller.selectedYear.value,
    );
    final daysInMonth = controller.daysInMonth.value;
    final totalLiters = controller.totalLiters.value;
    final totalAmount = controller.totalAmount.value;
    final effectiveRate = controller.effectiveRate;
    final activeDays = controller.activeDeliveryDays;
    final offDays = controller.zeroDeliveryDays + controller.missingDays;
    final dailyAvg = controller.averageDailyLiters;
    final invoiceNumber =
        'INV-${controller.selectedYear.value}${controller.selectedMonth.value.toString().padLeft(2, '0')}-${controller.customerNumber}';
    final now = DateTime.now();
    final todayFormatted =
        '${now.day.toString().padLeft(2, '0')} ${_monthNames[now.month - 1].substring(0, 3)} ${now.year}';
    final words = _numberToIndianWords(totalAmount);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(LucideIcons.receiptText, color: Color(0xff166534)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${T.t('Bill')} - ${controller.customerName}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xfff0fdf4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xffbbf7d0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.dairyName.value.isNotEmpty
                          ? controller.dairyName.value
                          : 'Dairy Desk',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xff166534),
                      ),
                    ),
                    Text(
                      'Invoice: $invoiceNumber  •  Date: $todayFormatted',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _BillDetailRow(
                label: T.t('Customer no.'),
                value: controller.customerNumber,
              ),
              const SizedBox(height: 6),
              _BillDetailRow(label: T.t('Month'), value: monthName),
              const SizedBox(height: 6),
              _BillDetailRow(
                label: T.t('Delivery Days'),
                value: '$activeDays / $daysInMonth Days',
              ),
              const SizedBox(height: 6),
              _BillDetailRow(
                label: T.t('Absent / Off Days'),
                value: '$offDays Days',
              ),
              const SizedBox(height: 6),
              _BillDetailRow(
                label: T.t('Daily Average'),
                value: '${dailyAvg.toStringAsFixed(2)} L/day',
              ),
              const Divider(height: 20),
              _BillDetailRow(
                label: T.t('Total Milk Supplied'),
                value: '${totalLiters.toStringAsFixed(1)} L',
                isBold: true,
              ),
              const SizedBox(height: 6),
              _BillDetailRow(
                label: T.t('Rate per Liter'),
                value: '₹${effectiveRate.toStringAsFixed(2)}/L',
                isBold: true,
              ),
              const SizedBox(height: 6),
              _BillDetailRow(
                label: T.t('Subtotal'),
                value: '₹${totalAmount.toStringAsFixed(2)}',
              ),
              const SizedBox(height: 6),
              _BillDetailRow(label: T.t('Previous Due'), value: '₹0.00'),
              const Divider(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xff064e3b),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          T.t('Total Amount Payable'),
                          style: const TextStyle(
                            color: Color(0xffa7f3d0),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '₹${totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    if (totalAmount > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        words,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(T.t('Close')),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _copyBillToClipboard(context);
            },
            icon: const Icon(LucideIcons.copy, size: 16),
            label: Text(T.t('Copy Bill')),
          ),
        ],
      ),
    );
  }

  static String _numberToIndianWords(double amount) {
    final integerPart = amount.floor();
    if (integerPart == 0) return 'Zero Rupees Only';

    final units = [
      '',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine',
      'Ten',
      'Eleven',
      'Twelve',
      'Thirteen',
      'Fourteen',
      'Fifteen',
      'Sixteen',
      'Seventeen',
      'Eighteen',
      'Nineteen',
    ];
    final tens = [
      '',
      '',
      'Twenty',
      'Thirty',
      'Forty',
      'Fifty',
      'Sixty',
      'Seventy',
      'Eighty',
      'Ninety',
    ];

    String convertUnder1000(int n) {
      String s = '';
      if (n >= 100) {
        s += '${units[n ~/ 100]} Hundred ';
        n %= 100;
      }
      if (n >= 20) {
        s += '${tens[n ~/ 10]} ';
        n %= 10;
      }
      if (n > 0) {
        s += '${units[n]} ';
      }
      return s.trim();
    }

    int num = integerPart;
    String result = '';

    final crore = num ~/ 10000000;
    num %= 10000000;
    final lakh = num ~/ 100000;
    num %= 100000;
    final thousand = num ~/ 1000;
    num %= 1000;
    final remainder = num;

    if (crore > 0) {
      result += '${convertUnder1000(crore)} Crore ';
    }
    if (lakh > 0) {
      result += '${convertUnder1000(lakh)} Lakh ';
    }
    if (thousand > 0) {
      result += '${convertUnder1000(thousand)} Thousand ';
    }
    if (remainder > 0) {
      result += '${convertUnder1000(remainder)} ';
    }

    result = result.trim();
    final paise = ((amount - integerPart) * 100).round();
    if (paise > 0) {
      return '$result Rupees and $paise Paise Only';
    }
    return '$result Rupees Only';
  }

  bool _isDayPast(int day) {
    final now = DateTime.now();
    final entryDate = DateTime(
      controller.selectedYear.value,
      controller.selectedMonth.value,
      day,
    );
    return !entryDate.isAfter(now);
  }

  Future<void> _openDayEditor(
    BuildContext context,
    int day,
    Map<String, dynamic>? existingEntry,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final litersValue = existingEntry != null
        ? _asDouble(existingEntry['liters'])
        : controller.customerDefaultLiters;
    final priceValue = existingEntry != null
        ? _asDouble(existingEntry['price'])
        : controller.customerDefaultPrice;

    final result = await showModalBottomSheet<Map<String, double>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _EntryEditorSheet(
        day: day,
        month: controller.selectedMonth.value,
        year: controller.selectedYear.value,
        initialLiters: litersValue,
        initialPrice: priceValue,
        defaultLiters: controller.customerDefaultLiters,
        isNew: existingEntry == null,
        customerName: controller.customerName,
        increment: controller.increment,
      ),
    );

    if (result == null || !mounted) return;

    final success = await controller.saveEntry(
      day: day,
      liters: result['liters']!,
      price: result['price']!,
    );

    if (!mounted) return;

    if (success) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text(T.t('Milk entry saved')),
          action: SnackBarAction(
            label: T.t('Undo'),
            onPressed: _handleUndo,
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(T.t('Could not save entry. Try again.')),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _handleUndo() async {
    final messenger = ScaffoldMessenger.of(context);
    final success = await controller.undo();
    if (!mounted) return;

    if (success) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(content: Text(T.t('Entry undone'))),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(T.t('Undo failed. Entry is unchanged.')),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _pickMonthYear(BuildContext context) async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: DateTime(
        controller.selectedYear.value,
        controller.selectedMonth.value,
      ),
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (result != null) {
      controller.setMonthYear(result.year, result.month);
    }
  }

  static double _asDouble(dynamic value, [double fallback = 0]) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? fallback;
  }
}

// ─── Bill Detail Row ─────────────────────────────────────────────────────────

class _BillDetailRow extends StatelessWidget {
  const _BillDetailRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  final String label;
  final String value;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade700,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: isBold ? Colors.black87 : Colors.grey.shade900,
          ),
        ),
      ],
    );
  }
}

// ─── Compact Metric Widget ───────────────────────────────────────────────────

class _CompactMetric extends StatelessWidget {
  const _CompactMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.bgColor,
    this.isHighlight = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color bgColor;
  final bool isHighlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: isHighlight ? 0.4 : 0.2),
          width: isHighlight ? 1.2 : 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(height: 3),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 11,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Day Row Widget ──────────────────────────────────────────────────────────

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.year,
    required this.month,
    required this.dayLabel,
    required this.entry,
    required this.defaultPrice,
    required this.isToday,
    required this.isPast,
    required this.cs,
    required this.onTap,
  });

  final int day;
  final int year;
  final int month;
  final String dayLabel;
  final Map<String, dynamic>? entry;
  final double defaultPrice;
  final bool isToday;
  final bool isPast;
  final ColorScheme cs;
  final VoidCallback onTap;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final hasEntry = entry != null;
    final liters = hasEntry ? _asDouble(entry!['liters']) : 0.0;
    final price = hasEntry ? _asDouble(entry!['price']) : defaultPrice;
    final total = hasEntry ? _asDouble(entry!['total'], fallback: liters * price) : 0.0;
    final isZero = hasEntry && liters == 0;

    final entryDate = DateTime(year, month, day);
    final weekdayName = _weekdays[entryDate.weekday - 1];

    return Material(
      color: isToday
          ? cs.primary.withValues(alpha: .07)
          : hasEntry
              ? Colors.white
              : Colors.grey.shade50,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: isToday
                ? Border.all(color: cs.primary.withValues(alpha: .4), width: 1.5)
                : Border.all(color: Colors.grey.shade200, width: 0.8),
          ),
          child: Row(
            children: [
              // Column 1: Date & Day
              SizedBox(
                width: 78,
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isToday
                            ? cs.primary
                            : hasEntry
                                ? const Color(0xffdcefe3)
                                : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$day',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: isToday
                              ? Colors.white
                              : hasEntry
                                  ? const Color(0xff2d7a55)
                                  : Colors.grey.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          weekdayName,
                          style: TextStyle(
                            fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                            fontSize: 12,
                            color: isToday ? cs.primary : Colors.grey.shade700,
                          ),
                        ),
                        if (isToday)
                          Text(
                            T.t('Today'),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: cs.primary,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Column 2: Quantity in Liters
              Expanded(
                flex: 3,
                child: Center(
                  child: hasEntry
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isZero
                                ? Colors.orange.shade50
                                : const Color(0xffdcefe3),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isZero
                                  ? Colors.orange.shade200
                                  : const Color(0xffbbf7d0),
                            ),
                          ),
                          child: Text(
                            isZero ? '0.0 L' : '${liters.toStringAsFixed(1)} L',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: isZero
                                  ? Colors.orange.shade800
                                  : const Color(0xff2d7a55),
                            ),
                          ),
                        )
                      : Text(
                          '—',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: isPast ? Colors.red.shade400 : Colors.grey.shade400,
                          ),
                        ),
                ),
              ),

              // Column 3: Rate per Liter
              Expanded(
                flex: 2,
                child: Text(
                  hasEntry ? '₹${price.toStringAsFixed(0)}' : (defaultPrice > 0 ? '₹${defaultPrice.toStringAsFixed(0)}' : '—'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              // Column 4: Day Total
              Expanded(
                flex: 3,
                child: Text(
                  hasEntry ? '₹${total.toStringAsFixed(2)}' : '—',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: hasEntry && !isZero ? cs.primary : Colors.grey.shade500,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Column 5: Edit Button / Icon
              InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: hasEntry
                        ? cs.primary.withValues(alpha: 0.08)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    hasEntry ? LucideIcons.pencil : LucideIcons.plus,
                    size: 14,
                    color: hasEntry ? cs.primary : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static double _asDouble(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? fallback;
  }
}

// ─── Entry Editor Bottom Sheet ───────────────────────────────────────────────

class _EntryEditorSheet extends StatefulWidget {
  const _EntryEditorSheet({
    required this.day,
    required this.month,
    required this.year,
    required this.initialLiters,
    required this.initialPrice,
    required this.defaultLiters,
    required this.isNew,
    required this.customerName,
    required this.increment,
  });

  final int day;
  final int month;
  final int year;
  final double initialLiters;
  final double initialPrice;
  final double defaultLiters;
  final bool isNew;
  final String customerName;
  final double increment;

  @override
  State<_EntryEditorSheet> createState() => _EntryEditorSheetState();
}

class _EntryEditorSheetState extends State<_EntryEditorSheet> {
  late double liters;
  late TextEditingController litersController;
  late TextEditingController priceController;
  final formKey = GlobalKey<FormState>();

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    liters = widget.initialLiters;
    litersController = TextEditingController(
      text: _formatNum(widget.initialLiters),
    );
    priceController = TextEditingController(
      text: _formatNum(widget.initialPrice),
    );
  }

  @override
  void dispose() {
    litersController.dispose();
    priceController.dispose();
    super.dispose();
  }

  void _increment() {
    setState(() {
      liters = double.parse(
        (liters + widget.increment).toStringAsFixed(2),
      );
      litersController.text = _formatNum(liters);
    });
  }

  void _decrement() {
    if (liters - widget.increment < 0) return;
    setState(() {
      liters = double.parse(
        (liters - widget.increment).toStringAsFixed(2),
      );
      litersController.text = _formatNum(liters);
    });
  }

  void _onLitersChanged(String value) {
    final parsed = double.tryParse(value.trim());
    if (parsed != null && parsed >= 0) {
      setState(() => liters = parsed);
    }
  }

  String _formatNum(double value) =>
      value == value.truncateToDouble()
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final monthName = T.t(_monthNames[widget.month - 1]);
    final title = widget.isNew
        ? T.t('Add entry')
        : T.t('Edit entry');
    final dateLabel = '${widget.day} $monthName ${widget.year}';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
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
            // Title
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.customerName}  •  $dateLabel',
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            // Quick Presets Row
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ActionChip(
                  avatar: const Icon(LucideIcons.ban, size: 14, color: Colors.orange),
                  label: Text(T.t('Absent (0 L)')),
                  onPressed: () {
                    setState(() {
                      liters = 0.0;
                      litersController.text = '0';
                    });
                  },
                ),
                if (widget.defaultLiters > 0)
                  ActionChip(
                    avatar: const Icon(Icons.local_drink, size: 14, color: Color(0xff2d7a55)),
                    label: Text('${widget.defaultLiters.toStringAsFixed(1)} L'),
                    onPressed: () {
                      setState(() {
                        liters = widget.defaultLiters;
                        litersController.text = _formatNum(liters);
                      });
                    },
                  ),
                ActionChip(
                  label: const Text('+0.5 L'),
                  onPressed: () {
                    setState(() {
                      liters = double.parse((liters + 0.5).toStringAsFixed(2));
                      litersController.text = _formatNum(liters);
                    });
                  },
                ),
                ActionChip(
                  label: const Text('+1.0 L'),
                  onPressed: () {
                    setState(() {
                      liters = double.parse((liters + 1.0).toStringAsFixed(2));
                      litersController.text = _formatNum(liters);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Plus / Minus controls
            Text(
              T.t('Liters'),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Minus button
                _QuantityButton(
                  icon: LucideIcons.minus,
                  onTap: liters > 0 ? _decrement : null,
                  color: Colors.red.shade400,
                ),
                const SizedBox(width: 12),
                // Liters input
                Expanded(
                  child: TextFormField(
                    controller: litersController,
                    autofocus: false,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: InputDecoration(
                      suffixText: 'L',
                      suffixStyle: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                      filled: true,
                      fillColor: cs.primary.withValues(alpha: .05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: cs.primary.withValues(alpha: .2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: cs.primary.withValues(alpha: .2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: cs.primary, width: 2),
                      ),
                    ),
                    onChanged: _onLitersChanged,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return T.t('Required');
                      }
                      final n = double.tryParse(value.trim());
                      if (n == null || !n.isFinite) {
                        return T.t('Enter a valid number');
                      }
                      if (n < 0) return T.t('Cannot be negative');
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Plus button
                _QuantityButton(
                  icon: LucideIcons.plus,
                  onTap: _increment,
                  color: const Color(0xff2d7a55),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                '${T.t('Increment')}: ${widget.increment.toStringAsFixed(1)} L',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Price input
            TextFormField(
              controller: priceController,
              autofocus: false,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: T.t('Price per liter'),
                prefixIcon: const Icon(Icons.payments_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return T.t('Required');
                }
                final n = double.tryParse(value.trim());
                if (n == null || !n.isFinite) {
                  return T.t('Enter a valid number');
                }
                if (n < 0) return T.t('Cannot be negative');
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Total preview
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    T.t('Total Amount'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '₹${_previewTotal.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Save button
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                T.t('Save entry'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double get _previewTotal {
    final price = double.tryParse(priceController.text.trim()) ?? 0;
    return liters * price;
  }

  void _save() {
    if (!formKey.currentState!.validate()) return;
    final litersVal = double.parse(litersController.text.trim());
    final priceVal = double.parse(priceController.text.trim());
    Navigator.of(context).pop({
      'liters': litersVal,
      'price': priceVal,
    });
  }
}

// ─── Quantity Button ─────────────────────────────────────────────────────────

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({
    required this.icon,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onTap != null ? color.withValues(alpha: .12) : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 28,
            color: onTap != null ? color : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }
}
