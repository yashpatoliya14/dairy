import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../controllers/dashboard_controller.dart';
import '../services/api_service.dart';
import '../services/app_language.dart';
import 'monthly_entries_screen.dart';
import 'payment_entry_sheet.dart';
import 'send_whatsapp_bill_sheet.dart';

class CustomerBillItem {
  CustomerBillItem({
    required this.customer,
    required this.thisMonthLiters,
    required this.defaultPrice,
    required this.thisMonthBill,
    required this.thisMonthPaid,
    required this.thisMonthDue,
    required this.activeDays,
    required this.grossPastDue,
    required this.grossPastAdvance,
    required this.pastMonthsDue,
    required this.pastMonthsAdvance,
    required this.pastMonthsBreakdown,
    required this.netBalanceDue,
    required this.netAdvance,
    required this.paymentNote,
    required this.paymentDate,
    required this.hasPayment,
  });

  final Map<String, dynamic> customer;
  final double thisMonthLiters;
  final double defaultPrice;
  final double thisMonthBill;
  final double thisMonthPaid;
  final double thisMonthDue;
  final int activeDays;
  final double grossPastDue;
  final double grossPastAdvance;
  final double pastMonthsDue;
  final double pastMonthsAdvance;
  final List<String> pastMonthsBreakdown;
  final double netBalanceDue;
  final double netAdvance;
  final String paymentNote;
  final DateTime? paymentDate;
  final bool hasPayment;

  String get customerId => '${customer['id'] ?? ''}'.trim();
  String get name => '${customer['name'] ?? customer['fullName'] ?? 'Customer'}';
  String get number => '${customer['uniqueNumber'] ?? customer['customerNumber'] ?? '—'}';
  String get phone => '${customer['phoneNumber'] ?? customer['phone'] ?? ''}'.trim();
  double get defaultLiters => _asDouble(customer['liters'], 1.0);

  static double _asDouble(dynamic val, [double fallback = 0.0]) {
    if (val is num) return val.toDouble();
    return double.tryParse('$val') ?? fallback;
  }
}

class CustomerBillsScreen extends StatefulWidget {
  const CustomerBillsScreen({
    super.key,
    required this.api,
    required this.controller,
  });

  final ApiService api;
  final DashboardController controller;

  @override
  State<CustomerBillsScreen> createState() => _CustomerBillsScreenState();
}

class _CustomerBillsScreenState extends State<CustomerBillsScreen> {
  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  late int _selectedYear;
  late int _selectedMonth;
  final RxString _filter = 'all'.obs; // all, due, partial, paid, advance
  final TextEditingController _searchController = TextEditingController();
  final RxString _searchQuery = ''.obs;

  final RxBool _loading = false.obs;
  final RxList<CustomerBillItem> _billItems = <CustomerBillItem>[].obs;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    _loadBills();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _monthLabel(int month, int year) {
    return '${T.t(_monthNames[month - 1])} $year';
  }

  Future<void> _loadBills() async {
    _loading.value = true;
    try {
      final customers = await widget.api.getCustomers();
      final items = <CustomerBillItem>[];

      // Fetch each customer bill concurrently
      final futures = customers.map((c) => _computeCustomerBill(c)).toList();
      final results = await Future.wait(futures);
      items.addAll(results);

      // Sort by customer unique number ascending
      items.sort((a, b) {
        final aNum = int.tryParse(a.number) ?? 999999;
        final bNum = int.tryParse(b.number) ?? 999999;
        return aNum.compareTo(bNum);
      });

      _billItems.assignAll(items);
    } catch (_) {
    } finally {
      _loading.value = false;
    }
  }

  Future<CustomerBillItem> _computeCustomerBill(Map<String, dynamic> c) async {
    final customerId = '${c['id'] ?? ''}'.trim();
    final defaultPrice = CustomerBillItem._asDouble(c['price'], 0.0);

    // 1. Current month data
    double thisMonthLiters = 0.0;
    double thisMonthBill = 0.0;
    int activeDays = 0;

    try {
      final monthData = await widget.api.getMilkEntriesForMonth(
        customerId,
        year: _selectedYear,
        month: _selectedMonth,
      );
      thisMonthLiters = CustomerBillItem._asDouble(monthData['totalLiters'], 0.0);
      final rawAmount = CustomerBillItem._asDouble(monthData['totalAmount'], 0.0);
      thisMonthBill = defaultPrice > 0 ? (thisMonthLiters * defaultPrice) : rawAmount;
      final entriesList = monthData['entries'] as List? ?? [];
      activeDays = entriesList.where((e) => CustomerBillItem._asDouble(e['liters'], 0) > 0).length;
    } catch (_) {}

    // 2. Current month payment
    double thisMonthPaid = 0.0;
    String paymentNote = '';
    DateTime? paymentDate;
    bool hasPayment = false;

    try {
      final pay = await widget.api.getPaymentEntry(
        customerId: customerId,
        year: _selectedYear,
        month: _selectedMonth,
      );
      if (pay != null) {
        hasPayment = true;
        thisMonthPaid = CustomerBillItem._asDouble(pay['receivedAmount'], 0.0);
        paymentNote = '${pay['note'] ?? ''}';
        if (pay['receivedDate'] != null) {
          paymentDate = DateTime.tryParse('${pay['receivedDate']}');
        }
      }
    } catch (_) {}

    // 3. Past 3 Months Ledger Rollover (overpaid advance or pending dues)
    double grossPastDue = 0.0;
    double grossPastAdvance = 0.0;
    final pastMonthsBreakdown = <String>[];

    for (int offset = 1; offset <= 3; offset++) {
      int prevM = _selectedMonth - offset;
      int prevY = _selectedYear;
      while (prevM <= 0) {
        prevM += 12;
        prevY -= 1;
      }

      try {
        final prevMonthData = await widget.api.getMilkEntriesForMonth(
          customerId,
          year: prevY,
          month: prevM,
        );
        final prevLiters = CustomerBillItem._asDouble(prevMonthData['totalLiters'], 0.0);
        final prevRawAmount = CustomerBillItem._asDouble(prevMonthData['totalAmount'], 0.0);
        final prevBill = defaultPrice > 0 ? (prevLiters * defaultPrice) : prevRawAmount;

        final prevPay = await widget.api.getPaymentEntry(
          customerId: customerId,
          year: prevY,
          month: prevM,
        );
        final prevPaid = prevPay != null
            ? CustomerBillItem._asDouble(prevPay['receivedAmount'], 0.0)
            : 0.0;

        if (prevBill > 0 || prevPaid > 0) {
          final diff = prevBill - prevPaid;
          final mName = T.t(_monthNames[prevM - 1]).substring(0, 3);
          if (diff > 0.5) {
            grossPastDue += diff;
            pastMonthsBreakdown.add('$mName: ₹${diff.toStringAsFixed(0)} due');
          } else if (diff < -0.5) {
            final advance = -diff;
            grossPastAdvance += advance;
            pastMonthsBreakdown.add('$mName: +₹${advance.toStringAsFixed(0)} overpaid');
          }
        }
      } catch (_) {}
    }

    // 4. Net calculations with FIFO credit allocation:
    // Credits available = thisMonthPaid + grossPastAdvance
    final totalCredits = thisMonthPaid + grossPastAdvance;

    // Apply credits towards gross past dues first (oldest debt cleared first)
    final creditForPast = totalCredits > grossPastDue ? grossPastDue : totalCredits;
    final remainingPastDue = grossPastDue - creditForPast;
    final creditsLeft = totalCredits - creditForPast;

    // Remaining credits apply to this month's bill
    final creditForThisMonth = creditsLeft > thisMonthBill ? thisMonthBill : creditsLeft;
    final thisMonthDue = thisMonthBill - creditForThisMonth;
    final netAdvance = creditsLeft > thisMonthBill ? (creditsLeft - thisMonthBill) : 0.0;
    final netBalanceDue = remainingPastDue + thisMonthDue;

    return CustomerBillItem(
      customer: c,
      thisMonthLiters: thisMonthLiters,
      defaultPrice: defaultPrice,
      thisMonthBill: thisMonthBill,
      thisMonthPaid: thisMonthPaid,
      thisMonthDue: thisMonthDue,
      activeDays: activeDays,
      grossPastDue: grossPastDue,
      grossPastAdvance: grossPastAdvance,
      pastMonthsDue: remainingPastDue,
      pastMonthsAdvance: grossPastAdvance,
      pastMonthsBreakdown: pastMonthsBreakdown,
      netBalanceDue: netBalanceDue,
      netAdvance: netAdvance,
      paymentNote: paymentNote,
      paymentDate: paymentDate,
      hasPayment: hasPayment,
    );
  }

  void _previousMonth() {
    if (_selectedMonth == 1) {
      _selectedMonth = 12;
      _selectedYear -= 1;
    } else {
      _selectedMonth -= 1;
    }
    _loadBills();
  }

  void _nextMonth() {
    if (_selectedMonth == 12) {
      _selectedMonth = 1;
      _selectedYear += 1;
    } else {
      _selectedMonth += 1;
    }
    _loadBills();
  }

  Future<void> _pickMonthYear(BuildContext context) async {
    final now = DateTime.now();
    int tempYear = _selectedYear;
    int tempMonth = _selectedMonth;

    final picked = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(T.t('Select month')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      setDialogState(() {
                        tempYear -= 1;
                      });
                    },
                  ),
                  Text(
                    '$tempYear',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: tempYear >= now.year + 1
                        ? null
                        : () {
                            setDialogState(() {
                              tempYear += 1;
                            });
                          },
                  ),
                ],
              ),
              const Divider(),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(12, (index) {
                  final monthNum = index + 1;
                  final isSelected = tempMonth == monthNum;
                  return ChoiceChip(
                    label: Text(T.t(_monthNames[index]).substring(0, 3)),
                    selected: isSelected,
                    selectedColor: const Color(0xff2d7a55),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setDialogState(() {
                          tempMonth = monthNum;
                        });
                      }
                    },
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(T.t('Cancel')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xff2d7a55)),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(T.t('Apply')),
            ),
          ],
        ),
      ),
    );

    if (picked == true && (tempYear != _selectedYear || tempMonth != _selectedMonth)) {
      setState(() {
        _selectedYear = tempYear;
        _selectedMonth = tempMonth;
      });
      _loadBills();
    }
  }

  Future<void> _openPaymentSheet(CustomerBillItem item) async {
    final monthName = _monthLabel(_selectedMonth, _selectedYear);
    final daysInMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PaymentEntrySheet(
        customerName: item.name,
        customerNumber: item.number,
        month: _selectedMonth,
        year: _selectedYear,
        monthName: monthName,
        totalLiters: item.thisMonthLiters,
        effectiveRate: item.defaultPrice,
        totalAmount: item.thisMonthBill,
        previousDue: item.grossPastDue,
        previousAdvance: item.grossPastAdvance,
        pastMonthsBreakdown: item.pastMonthsBreakdown,
        daysInMonth: daysInMonth,
        activeDeliveryDays: item.activeDays,
        initialReceived: item.hasPayment ? item.thisMonthPaid : null,
        initialNote: item.paymentNote,
        initialDate: item.paymentDate,
        hasExistingPayment: item.hasPayment,
        onSave: ({required receivedAmount, note, receivedDate}) async {
          await widget.api.savePaymentEntry(
            customerId: item.customerId,
            year: _selectedYear,
            month: _selectedMonth,
            billAmount: item.thisMonthBill,
            receivedAmount: receivedAmount,
            note: note,
            receivedDate: receivedDate,
          );
          _loadBills();
        },
        onDelete: item.hasPayment
            ? () async {
                await widget.api.deletePaymentEntry(
                  customerId: item.customerId,
                  year: _selectedYear,
                  month: _selectedMonth,
                );
                _loadBills();
              }
            : null,
      ),
    );
  }

  Future<void> _openWhatsAppBill(CustomerBillItem item) async {
    final daysInMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
    final monthName = _monthLabel(_selectedMonth, _selectedYear);

    await SendWhatsAppBillSheet.show(
      context,
      api: widget.api,
      customer: item.customer,
      initialBillType: BillType.monthly,
      initialMonthName: monthName,
      initialTotalDays: daysInMonth,
      initialMonthlyLiters: item.thisMonthLiters,
      initialRate: item.defaultPrice,
      initialPreviousDue: item.pastMonthsDue > 0 ? item.pastMonthsDue : 0.0,
    );
  }

  Future<void> _openMonthlyEntries(CustomerBillItem item) async {
    await Get.to(
      () => MonthlyEntriesScreen(
        api: widget.api,
        customer: item.customer,
      ),
    );
    _loadBills();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xff1b4d36),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Get.back();
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              T.t('Customer Bills'),
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              _monthLabel(_selectedMonth, _selectedYear),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xffdcefe3),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: T.t('Select month'),
            icon: const Icon(LucideIcons.calendarDays, color: Colors.white),
            onPressed: () => _pickMonthYear(context),
          ),
          IconButton(
            tooltip: T.t('Refresh'),
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadBills,
          ),
        ],
      ),
      body: Obx(() {
        final items = _billItems;
        final totalBilled = items.fold<double>(0.0, (sum, i) => sum + i.thisMonthBill);
        final totalCollected = items.fold<double>(0.0, (sum, i) => sum + i.thisMonthPaid);
        final totalDue = items.fold<double>(0.0, (sum, i) => sum + i.netBalanceDue);
        final totalAdvance = items.fold<double>(0.0, (sum, i) => sum + i.netAdvance);

        // Filter items
        final query = _searchQuery.value.trim().toLowerCase();
        final filteredBySearch = items.where((i) {
          if (query.isEmpty) return true;
          return i.name.toLowerCase().contains(query) ||
              i.number.toLowerCase().contains(query) ||
              i.phone.toLowerCase().contains(query);
        }).toList();

        final filter = _filter.value;
        final filtered = filteredBySearch.where((i) {
          if (filter == 'due') return i.netBalanceDue > 0;
          if (filter == 'partial') {
            return i.thisMonthPaid > 0 && i.netBalanceDue > 0;
          }
          if (filter == 'paid') {
            return i.netBalanceDue == 0 && (i.thisMonthBill > 0 || i.grossPastDue > 0) && i.netAdvance == 0;
          }
          if (filter == 'advance') return i.netAdvance > 0;
          return true;
        }).toList();

        return RefreshIndicator(
          onRefresh: _loadBills,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            children: [
              // Month Switcher Header Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xffe2e8f0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, color: Color(0xff1b4d36)),
                      onPressed: _previousMonth,
                      visualDensity: VisualDensity.compact,
                    ),
                    InkWell(
                      onTap: () => _pickMonthYear(context),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.calendar, size: 16, color: Color(0xff1b4d36)),
                            const SizedBox(width: 6),
                            Text(
                              _monthLabel(_selectedMonth, _selectedYear),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xff1b4d36),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, color: Color(0xff1b4d36)),
                      onPressed: _nextMonth,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 4 Executive Summary Cards
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      icon: LucideIcons.receipt,
                      label: T.t('Total Billed'),
                      value: '₹${totalBilled.toStringAsFixed(0)}',
                      color: const Color(0xff0284c7),
                      bgColor: const Color(0xffe0f2fe),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSummaryCard(
                      icon: LucideIcons.circleCheck,
                      label: T.t('Collected'),
                      value: '₹${totalCollected.toStringAsFixed(0)}',
                      color: const Color(0xff16a34a),
                      bgColor: const Color(0xffdcfce7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      icon: LucideIcons.circleAlert,
                      label: T.t('Total Due'),
                      value: '₹${totalDue.toStringAsFixed(0)}',
                      color: const Color(0xffdc2626),
                      bgColor: const Color(0xfffee2e2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSummaryCard(
                      icon: LucideIcons.wallet,
                      label: T.t('Advance Credit'),
                      value: '₹${totalAdvance.toStringAsFixed(0)}',
                      color: const Color(0xff0d9488),
                      bgColor: const Color(0xffccfbf1),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Search Bar
              TextField(
                controller: _searchController,
                onChanged: (val) => _searchQuery.value = val,
                decoration: InputDecoration(
                  hintText: '${T.t("Search")} (${T.t("Name")}, #Number, ${T.t("Phone")})',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.value.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _searchQuery.value = '';
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xffcbd5e1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xffe2e8f0)),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('all', '${T.t("All")} (${items.length})'),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'due',
                      '⚠️ ${T.t("Due")} (${items.where((i) => i.netBalanceDue > 0).length})',
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'partial',
                      '⏳ ${T.t("Partially Paid")} (${items.where((i) => i.thisMonthPaid > 0 && i.netBalanceDue > 0).length})',
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'paid',
                      '✓ ${T.t("Fully Paid")} (${items.where((i) => i.netBalanceDue == 0 && i.thisMonthBill > 0 && i.netAdvance == 0).length})',
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'advance',
                      '✦ ${T.t("Advance")} (${items.where((i) => i.netAdvance > 0).length})',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Customer Bill Cards
              if (_loading.value && items.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (filtered.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(LucideIcons.receiptText, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text(
                        T.t('No Bills Found'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...filtered.map((item) => _buildCustomerCard(item)),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _filter.value == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _filter.value = key,
      selectedColor: const Color(0xff1b4d36),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
        color: isSelected ? Colors.white : const Color(0xff1e293b),
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? const Color(0xff1b4d36) : const Color(0xffcbd5e1),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    );
  }

  Widget _buildCustomerCard(CustomerBillItem item) {
    // Determine status badge
    Color badgeColor;
    Color badgeBg;
    String badgeText;

    if (item.netAdvance > 0) {
      badgeColor = const Color(0xff0d9488);
      badgeBg = const Color(0xffccfbf1);
      badgeText = '✦ ${T.t("Advance")} +₹${item.netAdvance.toStringAsFixed(0)}';
    } else if (item.netBalanceDue == 0 && item.thisMonthBill > 0) {
      badgeColor = const Color(0xff16a34a);
      badgeBg = const Color(0xffdcfce7);
      badgeText = '✓ ${T.t("Fully Paid")}';
    } else if (item.thisMonthPaid > 0 && item.netBalanceDue > 0) {
      badgeColor = const Color(0xffd97706);
      badgeBg = const Color(0xfffef3c7);
      badgeText = '⏳ ${T.t("Partially Paid")}';
    } else if (item.thisMonthBill > 0) {
      badgeColor = const Color(0xffdc2626);
      badgeBg = const Color(0xfffee2e2);
      badgeText = '⚠️ ${T.t("Unpaid")}';
    } else {
      badgeColor = Colors.grey.shade600;
      badgeBg = Colors.grey.shade100;
      badgeText = '₹0';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.netBalanceDue > 0
              ? const Color(0xfffca5a5)
              : const Color(0xffe2e8f0),
          width: item.netBalanceDue > 0 ? 1.2 : 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Unique Number Circle
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xffdcefe3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xffbbf7d0)),
                  ),
                  child: Text(
                    '#${item.number}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Color(0xff166534),
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
                              item.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xff0f172a),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: badgeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (item.phone.isNotEmpty) ...[
                            Icon(LucideIcons.phone, size: 12, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              item.phone,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            '•  ${item.defaultLiters.toStringAsFixed(1)} L @ ₹${item.defaultPrice.toStringAsFixed(0)}/L',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
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

          const Divider(height: 1),

          // Monthly Metrics Grid
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    label: T.t('Delivery'),
                    value: '${item.thisMonthLiters.toStringAsFixed(1)} L',
                    sub: '${item.activeDays} ${T.t("days")}',
                    color: const Color(0xff1e293b),
                  ),
                ),
                Expanded(
                  child: _buildMetricTile(
                    label: T.t('Monthly Bill'),
                    value: '₹${item.thisMonthBill.toStringAsFixed(0)}',
                    sub: '@ ₹${item.defaultPrice.toStringAsFixed(0)}/L',
                    color: const Color(0xff0284c7),
                  ),
                ),
                Expanded(
                  child: _buildMetricTile(
                    label: T.t('Received'),
                    value: '₹${item.thisMonthPaid.toStringAsFixed(0)}',
                    sub: item.hasPayment ? T.t('Paid') : T.t('Unpaid'),
                    color: const Color(0xff16a34a),
                  ),
                ),
                Expanded(
                  child: _buildMetricTile(
                    label: T.t('Balance Due'),
                    value: '₹${item.thisMonthDue.toStringAsFixed(0)}',
                    sub: _monthLabel(_selectedMonth, _selectedYear).split(' ').first,
                    color: item.thisMonthDue > 0 ? const Color(0xffdc2626) : const Color(0xff16a34a),
                  ),
                ),
              ],
            ),
          ),

          // Multi-Month Ledger Alert Row (Rollover details)
          if (item.pastMonthsDue > 0 || (item.grossPastAdvance > 0 && item.netAdvance > 0))
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: item.pastMonthsDue > 0
                      ? const Color(0xfffef2f2)
                      : const Color(0xfff0fdf4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: item.pastMonthsDue > 0
                        ? const Color(0xfffecaca)
                        : const Color(0xffbbf7d0),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      item.pastMonthsDue > 0
                          ? LucideIcons.history
                          : LucideIcons.sparkles,
                      size: 14,
                      color: item.pastMonthsDue > 0
                          ? const Color(0xffdc2626)
                          : const Color(0xff16a34a),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.pastMonthsDue > 0
                            ? '${T.t("Past Due")}: ₹${item.pastMonthsDue.toStringAsFixed(0)} (${item.pastMonthsBreakdown.join(', ')})'
                            : '${T.t("Advance Credit")}: ₹${item.netAdvance.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: item.pastMonthsDue > 0
                              ? const Color(0xff991b1b)
                              : const Color(0xff166534),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (item.grossPastDue > 0 && item.pastMonthsDue == 0 && item.thisMonthPaid > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xfff0fdf4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xffbbf7d0),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.circleCheck,
                      size: 14,
                      color: Color(0xff16a34a),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${T.t("Past Dues Cleared")} (₹${item.grossPastDue.toStringAsFixed(0)} settled)',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xff166534),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Prominent Net Settlement Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: item.netBalanceDue > 0
                  ? const Color(0xffdc2626)
                  : (item.netAdvance > 0
                      ? const Color(0xff0d9488)
                      : const Color(0xff16a34a)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item.netBalanceDue > 0
                      ? T.t('Net Total Due')
                      : (item.netAdvance > 0 ? T.t('Net Advance') : T.t('Fully Paid')),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  item.netBalanceDue > 0
                      ? '₹${item.netBalanceDue.toStringAsFixed(2)}'
                      : (item.netAdvance > 0
                          ? '+₹${item.netAdvance.toStringAsFixed(2)}'
                          : '₹0.00'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Row(
              children: [
                // Record Payment Button
                Expanded(
                  flex: 3,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xff2d7a55),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                      minimumSize: const Size(0, 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _openPaymentSheet(item),
                    icon: const Icon(LucideIcons.wallet, size: 14),
                    label: Text(
                      T.t('Record Payment'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // WhatsApp Bill Button
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xff25D366),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(36, 36),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  tooltip: T.t('Send WhatsApp Bill'),
                  onPressed: () => _openWhatsAppBill(item),
                  icon: const Icon(LucideIcons.messageCircle, size: 16),
                ),
                const SizedBox(width: 6),
                // View Entries Button
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xff1e293b),
                      side: const BorderSide(color: Color(0xffcbd5e1)),
                      padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                      minimumSize: const Size(0, 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _openMonthlyEntries(item),
                    icon: const Icon(LucideIcons.calendar, size: 14),
                    label: Text(
                      T.t('View Entries'),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
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

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String sub,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          sub,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }
}
