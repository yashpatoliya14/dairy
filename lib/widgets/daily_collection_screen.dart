import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../controllers/dashboard_controller.dart';
import '../services/api_service.dart';
import '../services/app_language.dart';

class DailyCollectionScreen extends StatefulWidget {
  const DailyCollectionScreen({
    super.key,
    required this.api,
    required this.controller,
  });

  final ApiService api;
  final DashboardController controller;

  @override
  State<DailyCollectionScreen> createState() => _DailyCollectionScreenState();
}

class _DailyCollectionScreenState extends State<DailyCollectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  final RxString _searchQuery = ''.obs;

  @override
  void initState() {
    super.initState();
    // Default to 'missing' (Pending) as requested by distributor workflow
    widget.controller.setDailyFilter('missing');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDateTitle(DateTime date) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final weekday = weekdays[date.weekday - 1];
    return '$weekday, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return Obx(() {
      final totalCustomers = controller.todayTotalCustomers.value > 0
          ? controller.todayTotalCustomers.value
          : controller.customers.length;
      final completedCount = controller.todayEntriesDone.value;
      final missingCount = controller.todayMissingCount.value;
      final completionPct = totalCustomers > 0
          ? (completedCount / totalCustomers).clamp(0.0, 1.0)
          : 0.0;

      final allItems = controller.dailyCustomerItems;
      final filter = controller.dailyFilter.value;

      final filteredByTab = allItems.where((item) {
        final hasEntry = item['hasEntry'] == true || item['entry'] != null;
        if (filter == 'missing') return !hasEntry;
        if (filter == 'completed') return hasEntry;
        return true;
      }).toList();

      final query = _searchQuery.value.trim().toLowerCase();
      final displayedItems = filteredByTab.where((item) {
        if (query.isEmpty) return true;
        final customer = item['customer'] as Map? ?? {};
        final name = '${customer['name'] ?? ''}'.toLowerCase();
        final number = '${customer['uniqueNumber'] ?? ''}'.toLowerCase();
        final phone = '${customer['phoneNumber'] ?? ''}'.toLowerCase();
        return name.contains(query) ||
            number.contains(query) ||
            phone.contains(query);
      }).toList();

      return Scaffold(
        backgroundColor: const Color(0xfff1f5f9),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: const Color(0xff1b4d36),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Get.back(),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                T.t('Collection Progress'),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                _formatDateTitle(controller.selectedDate.value),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xffdcefe3),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        body: RefreshIndicator(
          onRefresh: controller.loadTodaySummary,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            children: [
              // Progress Summary Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xffe3ebe6)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${(completionPct * 100).toStringAsFixed(0)}% ${T.t("Completed")}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xff1f2937),
                          ),
                        ),
                        Text(
                          '$completedCount / $totalCustomers ${T.t("Customers")}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: completionPct,
                        minHeight: 7,
                        backgroundColor: const Color(0xffe5e7eb),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xff2d7a55),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildStatusPill(
                          label: '$missingCount ${T.t("Pending")}',
                          color: const Color(0xffb45309),
                          bg: const Color(0xfffef3c7),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusPill(
                          label: '$completedCount ${T.t("Recorded")}',
                          color: const Color(0xff15803d),
                          bg: const Color(0xffdcfce7),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusPill(
                          label: '${controller.todayLiters.value.toStringAsFixed(1)} L',
                          color: const Color(0xff0369a1),
                          bg: const Color(0xffe0f2fe),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: '⚠️ ${T.t("Pending")} ($missingCount)',
                      selected: filter == 'missing',
                      highlight: missingCount > 0,
                      onSelected: () => controller.setDailyFilter('missing'),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: '✓ ${T.t("Completed")} ($completedCount)',
                      selected: filter == 'completed',
                      onSelected: () => controller.setDailyFilter('completed'),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: '${T.t("All")} (${allItems.length})',
                      selected: filter == 'all',
                      onSelected: () => controller.setDailyFilter('all'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Search Bar
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xffe2e8f0)),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => _searchQuery.value = val,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: '${T.t("Search")} (Name, #Number)',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade400,
                    ),
                    prefixIcon: const Icon(
                      LucideIcons.search,
                      size: 16,
                      color: Color(0xff64748b),
                    ),
                    suffixIcon: _searchQuery.value.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              _searchQuery.value = '';
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Customer List
              if (controller.loading.value && allItems.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: Color(0xff2d7a55)),
                  ),
                )
              else if (displayedItems.isEmpty)
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xffe3ebe6)),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        filter == 'missing'
                            ? LucideIcons.partyPopper
                            : LucideIcons.inbox,
                        size: 40,
                        color: filter == 'missing'
                            ? const Color(0xff2d7a55)
                            : Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        filter == 'missing'
                            ? T.t('All customer entries completed')
                            : T.t('No entries recorded for this date'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xff374151),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...displayedItems.map((item) => _buildCustomerCard(context, item)),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildStatusPill({
    required String label,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
    bool highlight = false,
  }) {
    final bgColor = selected
        ? (highlight ? const Color(0xfffef3c7) : const Color(0xffdcefe3))
        : Colors.white;
    final borderColor = selected
        ? (highlight ? const Color(0xfff59e0b) : const Color(0xff2d7a55))
        : const Color(0xffe3ebe6);
    final textColor = selected
        ? (highlight ? const Color(0xffb45309) : const Color(0xff2d7a55))
        : Colors.grey.shade700;

    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: selected ? 1.5 : 1.0),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerCard(BuildContext context, Map<String, dynamic> item) {
    final customer = item['customer'] as Map? ?? {};
    final entry = item['entry'] as Map?;
    final hasEntry = item['hasEntry'] == true || entry != null;

    final customerId = '${customer['id'] ?? ''}';
    final name = '${customer['name'] ?? 'Customer'}'.trim();
    final number = '${customer['uniqueNumber'] ?? ''}';
    final defaultLiters =
        (customer['defaultLiters'] as num?)?.toDouble() ?? 1.0;
    final defaultPrice = (customer['defaultPrice'] as num?)?.toDouble() ?? 0.0;

    final recordedLiters =
        (entry?['liters'] as num?)?.toDouble() ?? defaultLiters;
    final recordedPrice =
        (entry?['price'] as num?)?.toDouble() ?? defaultPrice;
    final recordedTotal = (entry?['total'] as num?)?.toDouble() ??
        (recordedLiters * recordedPrice);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _openRecordMilkDialog(
        context,
        customerId: customerId,
        name: name,
        number: number,
        defaultLiters: hasEntry ? recordedLiters : defaultLiters,
        defaultPrice: hasEntry ? recordedPrice : defaultPrice,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasEntry ? const Color(0xffe3ebe6) : const Color(0xfffde68a),
            width: hasEntry ? 1 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.015),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Unique customer number badge
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: hasEntry ? const Color(0xfff0fdf4) : const Color(0xfffffbeb),
                shape: BoxShape.circle,
                border: Border.all(
                  color: hasEntry ? const Color(0xffbbf7d0) : const Color(0xfffde68a),
                ),
              ),
              child: Text(
                number.isNotEmpty ? '#$number' : '#',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: hasEntry
                      ? const Color(0xff166534)
                      : const Color(0xff92400e),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Name and stats
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xff1f2937),
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (hasEntry)
                    Row(
                      children: [
                        Text(
                          '${recordedLiters.toStringAsFixed(1)} L • ₹${recordedTotal.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xff2d7a55),
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
                          ),
                          child: Text(
                            T.t('Recorded'),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Color(0xff16a34a),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      '${T.t("Expected")}: ${defaultLiters.toStringAsFixed(1)} L @ ₹${defaultPrice.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber.shade900,
                      ),
                    ),
                ],
              ),
            ),

            // Action Button
            if (!hasEntry)
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xff2d7a55),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                  minimumSize: const Size(72, 34),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => _openRecordMilkDialog(
                  context,
                  customerId: customerId,
                  name: name,
                  number: number,
                  defaultLiters: defaultLiters,
                  defaultPrice: defaultPrice,
                ),
                child: Text(
                  '+ ${T.t("Record")}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              IconButton(
                icon: const Icon(
                  LucideIcons.pencil,
                  size: 18,
                  color: Color(0xff2d7a55),
                ),
                tooltip: T.t('Edit'),
                onPressed: () => _openRecordMilkDialog(
                  context,
                  customerId: customerId,
                  name: name,
                  number: number,
                  defaultLiters: recordedLiters,
                  defaultPrice: recordedPrice,
                ),
              ),
          ],
        ),
      ),
    );
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

  Future<void> _openRecordMilkDialog(
    BuildContext context, {
    required String customerId,
    required String name,
    required String number,
    required double defaultLiters,
    required double defaultPrice,
  }) async {
    final litersCtrl = TextEditingController(
      text: defaultLiters == defaultLiters.truncateToDouble()
          ? defaultLiters.toStringAsFixed(0)
          : defaultLiters.toStringAsFixed(2),
    );
    final priceCtrl = TextEditingController(
      text: defaultPrice == defaultPrice.truncateToDouble()
          ? defaultPrice.toStringAsFixed(0)
          : defaultPrice.toStringAsFixed(2),
    );
    final formKey = GlobalKey<FormState>();
    double curLiters = defaultLiters;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
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
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                                    litersCtrl.text =
                                        curLiters == curLiters.truncateToDouble()
                                            ? curLiters.toStringAsFixed(0)
                                            : curLiters.toStringAsFixed(2);
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
                            labelText: T.t('Liters'),
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
                              litersCtrl.text =
                                  curLiters == curLiters.truncateToDouble()
                                      ? curLiters.toStringAsFixed(0)
                                      : curLiters.toStringAsFixed(2);
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
                            litersCtrl.text =
                                curLiters == curLiters.truncateToDouble()
                                    ? curLiters.toStringAsFixed(0)
                                    : curLiters.toStringAsFixed(2);
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
                            litersCtrl.text =
                                curLiters == curLiters.truncateToDouble()
                                    ? curLiters.toStringAsFixed(0)
                                    : curLiters.toStringAsFixed(2);
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
                            litersCtrl.text =
                                curLiters == curLiters.truncateToDouble()
                                    ? curLiters.toStringAsFixed(0)
                                    : curLiters.toStringAsFixed(2);
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
                            litersCtrl.text =
                                curLiters == curLiters.truncateToDouble()
                                    ? curLiters.toStringAsFixed(0)
                                    : curLiters.toStringAsFixed(2);
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
        ),
      ),
    );

    if (saved == true) {
      final liters = double.tryParse(litersCtrl.text.trim()) ?? defaultLiters;
      final price = double.tryParse(priceCtrl.text.trim()) ?? defaultPrice;
      final success = await widget.controller.saveCustomerMilkEntry(
        customerId,
        liters,
        price,
      );

      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$name: ${liters.toStringAsFixed(1)} L • ₹${(liters * price).toStringAsFixed(0)}'),
              backgroundColor: const Color(0xff2d7a55),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(T.t('Could not save milk entry.')),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      }
    }

    litersCtrl.dispose();
    priceCtrl.dispose();
  }
}
