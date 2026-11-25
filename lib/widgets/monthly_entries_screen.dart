import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../controllers/monthly_entries_controller.dart';
import '../services/api_service.dart';
import '../services/app_language.dart';
import '../views/customer_bill_page.dart';
import 'dairy_milk_loader.dart';
import 'payment_entry_sheet.dart';
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
    final tagId = widget.customer['id'] ?? widget.customer['cid'] ?? '';
    controller = Get.put(
      MonthlyEntriesController(widget.api),
      tag: 'monthly_$tagId',
    );
    controller.setCustomer(widget.customer);
  }

  @override
  void dispose() {
    final tagId = widget.customer['id'] ?? widget.customer['cid'] ?? '';
    Get.delete<MonthlyEntriesController>(
      tag: 'monthly_$tagId',
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
        backgroundColor: const Color(0xff1b4d36),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        title: Obx(() => Text(
          _monthLabel(
            controller.selectedMonth.value,
            controller.selectedYear.value,
          ),
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        )),
        actions: [
          IconButton(
            tooltip: T.t('Refresh'),
            onPressed: controller.loadMonth,
            icon: const Icon(LucideIcons.refreshCw, color: Colors.white),
          ),
          Obx(() => controller.undoStack.isNotEmpty
              ? IconButton(
                  tooltip: T.t('Undo'),
                  onPressed: controller.saving.value ? null : _handleUndo,
                  icon: const Icon(LucideIcons.undo2, color: Colors.white),
                )
              : const SizedBox.shrink()),
          IconButton(
            tooltip: T.t('Select month'),
            onPressed: () => _pickMonthYear(context),
            icon: const Icon(LucideIcons.calendarDays, color: Colors.white),
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
      floatingActionButton: Obx(() {
        if (controller.loading.value && controller.entries.isEmpty) {
          return const SizedBox.shrink();
        }
        return FloatingActionButton.extended(
          onPressed: () => _openPaymentEntrySheet(context),
          icon: Icon(
            controller.hasPayment.value
                ? LucideIcons.circleCheck
                : LucideIcons.receipt,
            color: Colors.white,
          ),
          label: Text(
            controller.hasPayment.value
                ? '${T.t('Payment Entry')} (₹${controller.paymentReceived.value.toStringAsFixed(2)})'
                : T.t('Payment Entry'),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color(0xff2d7a55),
        );
      }),
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
              controller.customerNumber.isNotEmpty &&
                      controller.customerNumber != '—'
                  ? controller.customerNumber
                  : (controller.customerName.isEmpty
                      ? '?'
                      : controller.customerName[0].toUpperCase()),
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
    return Container(
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xffe2e8f0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: T.t('Previous month'),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            iconSize: 18,
            onPressed: controller.previousMonth,
            icon: const Icon(LucideIcons.chevronLeft),
          ),
          Obx(() => InkWell(
            onTap: () => _pickMonthYear(context),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.calendarDays, size: 14, color: Color(0xff2d7a55)),
                  const SizedBox(width: 6),
                  Text(
                    _monthLabel(
                      controller.selectedMonth.value,
                      controller.selectedYear.value,
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Color(0xff1b4d36),
                    ),
                  ),
                ],
              ),
            ),
          )),
          IconButton(
            tooltip: T.t('Next month'),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            iconSize: 18,
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
    final totalAmount = controller.billTotalAmount;
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
                  InkWell(
                    onTap: () => _showFullInvoiceDialog(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
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
                                        color: controller.isFullyPaid
                                            ? const Color(0xffdcfce7)
                                            : controller.isPartiallyPaid
                                                ? const Color(0xfffef3c7)
                                                : const Color(0xffdcfce7),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: controller.isFullyPaid
                                              ? const Color(0xff86efac)
                                              : controller.isPartiallyPaid
                                                  ? const Color(0xfffcd34d)
                                                  : const Color(0xff86efac),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        controller.isFullyPaid
                                            ? T.t('Fully Paid')
                                            : controller.isPartiallyPaid
                                                ? T.t('Partially Paid')
                                                : T.t('Billed'),
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: controller.isFullyPaid
                                              ? const Color(0xff166534)
                                              : controller.isPartiallyPaid
                                                  ? const Color(0xffb45309)
                                                  : const Color(0xff166534),
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
                              LucideIcons.arrowUpRight,
                              color: Color(0xff2d7a55),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 8),

                  // 4-Column Professional Metric Chips (Responsive 2x2 or 4x1)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final totalLitersChip = _CompactMetric(
                        icon: Icons.local_drink_outlined,
                        label: T.t('Total Liters'),
                        value: '${totalLiters.toStringAsFixed(2)} L',
                        color: const Color(0xff2d7a55),
                        bgColor: const Color(0xffdcefe3),
                      );
                      final rateChip = _CompactMetric(
                        icon: Icons.payments_outlined,
                        label: T.t('Rate per Liter'),
                        value: '₹${effectiveRate.toStringAsFixed(2)}/L',
                        color: const Color(0xff0284c7),
                        bgColor: const Color(0xffe0f2fe),
                      );
                      final daysChip = _CompactMetric(
                        icon: LucideIcons.calendarCheck,
                        label: T.t('Delivery Days'),
                        value: '$activeDays/$daysInMonth',
                        color: const Color(0xff7c3aed),
                        bgColor: const Color(0xffede9fe),
                      );
                      final amountChip = _CompactMetric(
                        icon: LucideIcons.receipt,
                        label: T.t('Total Amount'),
                        value: '₹${totalAmount.toStringAsFixed(2)}',
                        color: const Color(0xff166534),
                        bgColor: const Color(0xffbbf7d0),
                        isHighlight: true,
                      );

                      if (constraints.maxWidth < 340) {
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: totalLitersChip),
                                const SizedBox(width: 6),
                                Expanded(child: rateChip),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(child: daysChip),
                                const SizedBox(width: 6),
                                Expanded(child: amountChip),
                              ],
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: totalLitersChip),
                          const SizedBox(width: 6),
                          Expanded(child: rateChip),
                          const SizedBox(width: 6),
                          Expanded(child: daysChip),
                          const SizedBox(width: 6),
                          Expanded(child: amountChip),
                        ],
                      );
                    },
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

                  if (controller.hasPayment.value) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: controller.isFullyPaid
                            ? const Color(0xfff0fdf4)
                            : const Color(0xfffffbeb),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: controller.isFullyPaid
                              ? const Color(0xffbbf7d0)
                              : const Color(0xfffef08a),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            controller.isFullyPaid
                                ? LucideIcons.circleCheck
                                : LucideIcons.circleAlert,
                            size: 14,
                            color: controller.isFullyPaid
                                ? const Color(0xff16a34a)
                                : const Color(0xffd97706),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${T.t('Received')}: ₹${controller.paymentReceived.value.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: controller.isFullyPaid
                                        ? const Color(0xff166534)
                                        : const Color(0xff92400e),
                                  ),
                                ),
                                Text(
                                  controller.isFullyPaid
                                      ? '${T.t('Fully Paid')} (₹0.00 ${T.t('Due')})'
                                      : '${T.t('Balance Due')}: ₹${controller.balanceDue.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: controller.isFullyPaid
                                        ? const Color(0xff166534)
                                        : const Color(0xffb45309),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Quick Action 1: Payment Entry Button
                  FilledButton.icon(
                    onPressed: () => _openPaymentEntrySheet(context),
                    icon: Icon(
                      controller.hasPayment.value
                          ? LucideIcons.circleCheck
                          : LucideIcons.receipt,
                      size: 16,
                    ),
                    label: Text(
                      controller.hasPayment.value
                          ? '${T.t('Payment Entry')} (₹${controller.paymentReceived.value.toStringAsFixed(2)} ${T.t('Received')})'
                          : T.t('Payment Entry'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: controller.isFullyPaid
                          ? const Color(0xff065f46)
                          : const Color(0xff1e40af),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: const Size.fromHeight(36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Quick Action Row 2: (WhatsApp Bill & Copy Bill)
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
                              initialMonthlyAmount: totalAmount,
                              initialPaidAmount: controller.hasPayment.value
                                  ? controller.paymentReceived.value
                                  : 0.0,
                              initialPreviousDue: controller.pastMonthsDue.value,
                              initialAdvanceCredit: controller.netAdvance.value,
                              initialMonthToDateBill: totalAmount,
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
    final totalAmount = controller.billTotalAmount;
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
      '• Total Quantity: ${totalLiters.toStringAsFixed(2)} L',
      '• Rate: ₹${effectiveRate.toStringAsFixed(2)}/L',
      '• Monthly Charge: ₹${totalAmount.toStringAsFixed(2)}',
      if (controller.hasPayment.value) ...[
        '• Amount Received: ₹${controller.paymentReceived.value.toStringAsFixed(2)}',
        if (controller.balanceDue > 0)
          '• *Balance Due: ₹${controller.balanceDue.toStringAsFixed(2)}*'
        else
          '• *Status: Fully Paid (₹0.00 Due)*',
      ] else ...[
        '• Previous Due: ₹0.00',
        '• *Net Total Due: ₹${totalAmount.toStringAsFixed(2)}*',
      ],
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

  Future<void> _showFullInvoiceDialog(BuildContext context) async {
    await Get.to(
      () => CustomerBillPage(
        api: widget.api,
        customer: widget.customer,
        controller: controller,
      ),
    );
    await controller.loadMonth();
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

  Widget _buildPresetBadge({
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xfff0fdf4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xff86efac), width: 1),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xff166534),
          ),
        ),
      ),
    );
  }

  Future<void> _openDayEditor(
    BuildContext context,
    int day,
    Map<String, dynamic>? existingEntry,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final double existingLiters =
        existingEntry != null ? _asDouble(existingEntry['liters']) : 0.0;
    final double defaultPrice = controller.customerDefaultPrice;
    final double existingPrice = (controller.customerDefaultPrice > 0)
        ? controller.customerDefaultPrice
        : (existingEntry != null
            ? _asDouble(existingEntry['price'])
            : defaultPrice);
    final double existingTotal = existingEntry != null
        ? _asDouble(existingEntry['total'], existingLiters * existingPrice)
        : 0.0;
    final bool hasExisting = existingEntry != null && existingLiters > 0;

    final double defaultLiters = controller.customerDefaultLiters > 0
        ? controller.customerDefaultLiters
        : 1.0;

    String mode = 'add'; // 'add' (accumulate with last entry) or 'replace'
    final initialLiters = hasExisting ? defaultLiters : defaultLiters;

    final litersCtrl = TextEditingController(
      text: initialLiters.toStringAsFixed(2),
    );
    final priceCtrl = TextEditingController(
      text: existingPrice.toStringAsFixed(2),
    );
    final formKey = GlobalKey<FormState>();
    double curLiters = initialLiters;
    double curPrice = existingPrice;

    final dateLabel =
        '$day ${_monthNames[controller.selectedMonth.value - 1].substring(0, 3)} ${controller.selectedYear.value}';

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final double previewLiters = (hasExisting && mode == 'add')
              ? (existingLiters + curLiters)
              : curLiters;
          final double previewTotal = previewLiters * curPrice;

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            titlePadding: const EdgeInsets.fromLTRB(16, 16, 12, 0),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xffdcefe3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    LucideIcons.milk,
                    size: 18,
                    color: Color(0xff2d7a55),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        controller.customerName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        dateLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
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
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Existing Entry Banner & Mode Switcher
                    if (hasExisting) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xfff0fdf4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xffbbf7d0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${T.t('Earlier Today')}:',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xff166534),
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  '${existingLiters.toStringAsFixed(2)} L • ₹${existingTotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xff166534),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ChoiceChip(
                                    label: Text(
                                      '+ ${T.t("Add with Last Entry")}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: mode == 'add'
                                            ? Colors.white
                                            : const Color(0xff166534),
                                      ),
                                    ),
                                    selected: mode == 'add',
                                    selectedColor: const Color(0xff2d7a55),
                                    backgroundColor: Colors.white,
                                    onSelected: (selected) {
                                      if (selected) {
                                        setDialogState(() {
                                          mode = 'add';
                                          curLiters = defaultLiters;
                                          litersCtrl.text = defaultLiters.toStringAsFixed(2);
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ChoiceChip(
                                    label: Text(
                                      T.t('Replace Entry'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: mode == 'replace'
                                            ? Colors.white
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                    selected: mode == 'replace',
                                    selectedColor: Colors.orange.shade800,
                                    backgroundColor: Colors.white,
                                    onSelected: (selected) {
                                      if (selected) {
                                        setDialogState(() {
                                          mode = 'replace';
                                          curLiters = existingLiters;
                                          litersCtrl.text = existingLiters.toStringAsFixed(2);
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    Row(
                      children: [
                        Material(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: curLiters > 0
                                ? () {
                                    setDialogState(() {
                                      curLiters = (curLiters - 0.25).clamp(0.0, 999.0);
                                      curLiters = double.parse(curLiters.toStringAsFixed(2));
                                      litersCtrl.text = curLiters.toStringAsFixed(2);
                                    });
                                  }
                                : null,
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: Icon(Icons.remove, color: Colors.red.shade400),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: litersCtrl,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: (hasExisting && mode == 'add')
                                  ? T.t('Liters to add (+)')
                                  : (hasExisting)
                                      ? T.t('Total Liters (Replace)')
                                      : T.t('Liters'),
                              suffixText: 'L',
                            ),
                            onChanged: (val) {
                              final parsed = double.tryParse(val.trim());
                              if (parsed != null && parsed >= 0) {
                                setDialogState(() => curLiters = parsed);
                              }
                            },
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return T.t('Required');
                              }
                              if (double.tryParse(val.trim()) == null) {
                                return T.t('Invalid number');
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: const Color(0xffdcefe3),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setDialogState(() {
                                curLiters = curLiters + 0.25;
                                curLiters = double.parse(curLiters.toStringAsFixed(2));
                                litersCtrl.text = curLiters.toStringAsFixed(2);
                              });
                            },
                            child: const SizedBox(
                              width: 44,
                              height: 44,
                              child: Icon(Icons.add, color: Color(0xff2d7a55)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Presets
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildPresetBadge(
                          label: '+250 ml',
                          onTap: () {
                            setDialogState(() {
                              curLiters = double.parse(
                                (curLiters + 0.25).toStringAsFixed(2),
                              );
                              litersCtrl.text = curLiters.toStringAsFixed(2);
                            });
                          },
                        ),
                        _buildPresetBadge(
                          label: '+500 ml',
                          onTap: () {
                            setDialogState(() {
                              curLiters = double.parse(
                                (curLiters + 0.50).toStringAsFixed(2),
                              );
                              litersCtrl.text = curLiters.toStringAsFixed(2);
                            });
                          },
                        ),
                        _buildPresetBadge(
                          label: '+750 ml',
                          onTap: () {
                            setDialogState(() {
                              curLiters = double.parse(
                                (curLiters + 0.75).toStringAsFixed(2),
                              );
                              litersCtrl.text = curLiters.toStringAsFixed(2);
                            });
                          },
                        ),
                        _buildPresetBadge(
                          label: '+1 L',
                          onTap: () {
                            setDialogState(() {
                              curLiters = double.parse(
                                (curLiters + 1.00).toStringAsFixed(2),
                              );
                              litersCtrl.text = curLiters.toStringAsFixed(2);
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: T.t('Price per liter'),
                        prefixText: '₹ ',
                      ),
                      onChanged: (val) {
                        final parsed = double.tryParse(val.trim());
                        if (parsed != null && parsed >= 0) {
                          setDialogState(() => curPrice = parsed);
                        }
                      },
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return T.t('Required');
                        }
                        if (double.tryParse(val.trim()) == null) {
                          return T.t('Invalid number');
                        }
                        return null;
                      },
                    ),

                    // Final Total Preview Banner
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: mode == 'add' ? const Color(0xffecfdf5) : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: mode == 'add' ? const Color(0xffa7f3d0) : Colors.orange.shade200,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${T.t("Final Today")}: ${previewLiters.toStringAsFixed(2)} L',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: mode == 'add' ? const Color(0xff065f46) : Colors.orange.shade900,
                            ),
                          ),
                          Text(
                            '₹${previewTotal.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: mode == 'add' ? const Color(0xff065f46) : Colors.orange.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            actions: [
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xff2d7a55),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(42),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  if (formKey.currentState?.validate() != true) return;
                  Navigator.of(dialogCtx).pop(true);
                },
                child: Text(
                  T.t('Save Entry'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          );
        },
      ),
    );

    litersCtrl.dispose();
    priceCtrl.dispose();

    if (saved != true || !mounted) return;

    final success = await controller.saveEntry(
      day: day,
      liters: curLiters,
      price: curPrice,
      mode: hasExisting ? mode : 'add',
    );

    if (!mounted) return;

    final double finalLiters = (hasExisting && mode == 'add')
        ? (existingLiters + curLiters)
        : curLiters;
    final double finalTotal = finalLiters * curPrice;

    if (success) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text('${T.t('Milk entry saved')} (${finalLiters.toStringAsFixed(2)} L • ₹${finalTotal.toStringAsFixed(2)})'),
          backgroundColor: const Color(0xff2d7a55),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: T.t('Undo'),
            textColor: Colors.amberAccent,
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

  Future<void> _openPaymentEntrySheet(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final monthName = _monthLabel(
      controller.selectedMonth.value,
      controller.selectedYear.value,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PaymentEntrySheet(
        customerName: controller.customerName,
        customerNumber: controller.customerNumber,
        month: controller.selectedMonth.value,
        year: controller.selectedYear.value,
        monthName: monthName,
        totalLiters: controller.totalLiters.value,
        effectiveRate: controller.effectiveRate,
        totalAmount: controller.billTotalAmount,
        previousDue: controller.grossPastDue.value,
        previousAdvance: controller.grossPastAdvance.value,
        pastMonthsBreakdown: controller.pastMonthsBreakdown,
        daysInMonth: controller.daysInMonth.value,
        activeDeliveryDays: controller.activeDeliveryDays,
        initialReceived: controller.hasPayment.value
            ? controller.paymentReceived.value
            : null,
        initialNote: controller.paymentNote.value,
        initialDate: controller.paymentDate.value,
        hasExistingPayment: controller.hasPayment.value,
        onSave: ({
          required double receivedAmount,
          String? note,
          DateTime? receivedDate,
        }) async {
          final success = await controller.savePayment(
            receivedAmount: receivedAmount,
            note: note,
            receivedDate: receivedDate,
          );
          await controller.loadPayment();
          await controller.loadMonth();
          if (!mounted) return;
          if (success) {
            messenger.clearSnackBars();
            messenger.showSnackBar(
              SnackBar(
                content: Text(T.t('Payment saved successfully')),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
              ),
            );
          } else {
            messenger.showSnackBar(
              SnackBar(
                content: Text(T.t('Could not save payment')),
                backgroundColor: Colors.red.shade700,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        onDelete: controller.hasPayment.value
            ? () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            T.t('Delete Payment?'),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          tooltip: T.t('Close'),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.of(dCtx).pop(false),
                        ),
                      ],
                    ),
                    content: Text(
                      T.t('This will remove the payment record for this month.'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dCtx).pop(false),
                        child: Text(T.t('Cancel')),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(dCtx).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                        ),
                        child: Text(T.t('Delete')),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  final success = await controller.deletePayment();
                  await controller.loadPayment();
                  await controller.loadMonth();
                  if (!mounted) return;
                  if (success) {
                    messenger.clearSnackBars();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(T.t('Payment deleted')),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                }
              }
            : null,
      ),
    );
  }

  static double _asDouble(dynamic value, [double fallback = 0]) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? fallback;
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
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 11,
                color: color,
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
              maxLines: 1,
            ),
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
    final price = defaultPrice > 0
        ? defaultPrice
        : (hasEntry ? _asDouble(entry!['price']) : defaultPrice);
    final total = hasEntry ? (liters * price) : 0.0;
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
                            isZero ? '0.00 L' : '${liters.toStringAsFixed(2)} L',
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
                  hasEntry ? '₹${price.toStringAsFixed(2)}' : (defaultPrice > 0 ? '₹${defaultPrice.toStringAsFixed(2)}' : '—'),
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
