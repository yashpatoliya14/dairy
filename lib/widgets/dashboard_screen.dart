import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../controllers/dashboard_controller.dart';
import '../services/api_service.dart';
import '../services/app_language.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.api,
    required this.controller,
    required this.onNavigateTab,
    required this.onOpenAddCustomer,
  });

  final ApiService api;
  final DashboardController controller;
  final void Function(int tabIndex) onNavigateTab;
  final VoidCallback onOpenAddCustomer;

  String _formatDateTitle(DateTime date) {
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day;

    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dateStr = '${date.day} ${months[date.month - 1]} ${date.year}';

    if (isToday) return '${T.t("Today")}, $dateStr';
    if (isYesterday) return '${T.t("Yesterday")}, $dateStr';
    return dateStr;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final totalCustomers = controller.todayTotalCustomers.value > 0
          ? controller.todayTotalCustomers.value
          : controller.customers.length;
      final completedCount = controller.todayEntriesDone.value;
      final missingCount = controller.todayMissingCount.value;
      final totalLiters = controller.todayLiters.value;
      final totalAmount = controller.todayTotalAmount.value;
      final avgLiters = completedCount > 0 ? (totalLiters / completedCount).toStringAsFixed(1) : '0.0';
      final avgPrice = totalLiters > 0
          ? (totalAmount / totalLiters).toStringAsFixed(1)
          : controller.defaultPrice.value.toStringAsFixed(1);
      final completionPct = totalCustomers > 0
          ? (completedCount / totalCustomers).clamp(0.0, 1.0)
          : 0.0;

      final allItems = controller.dailyCustomerItems;
      final filter = controller.dailyFilter.value;

      final filteredItems = allItems.where((item) {
        final hasEntry = item['hasEntry'] == true || item['entry'] != null;
        if (filter == 'missing') return !hasEntry;
        if (filter == 'completed') return hasEntry;
        return true;
      }).toList();

      return Scaffold(
        backgroundColor: const Color(0xfff7faf8),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          elevation: 0,
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xffdcefe3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  LucideIcons.milk,
                  color: Color(0xff2d7a55),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.dairyName.value.isEmpty
                          ? T.t('Dairy Desk')
                          : controller.dairyName.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.3,
                      ),
                    ),
                    if (controller.ownerName.value.isNotEmpty)
                      Text(
                        '${T.t("Welcome back")}, ${controller.ownerName.value}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: T.t('Refresh'),
              icon: controller.loading.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xff2d7a55),
                      ),
                    )
                  : const Icon(LucideIcons.refreshCw, size: 20),
              onPressed: controller.loading.value ? null : controller.load,
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              // Date Navigator Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xffe3ebe6)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(LucideIcons.chevronLeft, size: 20),
                      visualDensity: VisualDensity.compact,
                      onPressed: controller.previousDay,
                    ),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: controller.selectedDate.value,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 30)),
                          );
                          if (picked != null) {
                            await controller.setSelectedDate(picked);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                LucideIcons.calendar,
                                size: 16,
                                color: Color(0xff2d7a55),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _formatDateTitle(controller.selectedDate.value),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: Color(0xff1f2937),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (!controller.isSelectedDateToday)
                      TextButton(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: controller.goToToday,
                        child: Text(
                          T.t('Today'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xff2d7a55),
                          ),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(LucideIcons.chevronRight, size: 20),
                      visualDensity: VisualDensity.compact,
                      onPressed: controller.nextDay,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // KPI Cards Grid (2x2)
              Row(
                children: [
                  // Milk Collected
                  Expanded(
                    child: _buildMetricCard(
                      icon: LucideIcons.milk,
                      iconBg: const Color(0xffdcefe3),
                      iconColor: const Color(0xff2d7a55),
                      title: T.t('Total Milk'),
                      value: '${totalLiters.toStringAsFixed(1)} L',
                      subtitle: '$avgLiters L / ${T.t("Entries")}',
                      badgeColor: const Color(0xff2d7a55),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Total Revenue
                  Expanded(
                    child: _buildMetricCard(
                      icon: LucideIcons.indianRupee,
                      iconBg: const Color(0xfffef3c7),
                      iconColor: const Color(0xffb45309),
                      title: T.t('Total Amount'),
                      value: '₹ ${totalAmount.toStringAsFixed(0)}',
                      subtitle: 'Avg ₹$avgPrice / L',
                      badgeColor: const Color(0xffb45309),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // Collection Progress
                  Expanded(
                    child: _buildMetricCard(
                      icon: LucideIcons.clipboardCheck,
                      iconBg: const Color(0xffe0f2fe),
                      iconColor: const Color(0xff0369a1),
                      title: T.t('Collection Progress'),
                      value: '$completedCount / $totalCustomers',
                      subtitle: '${(completionPct * 100).toStringAsFixed(0)}% ${T.t("Completed")}',
                      badgeColor: const Color(0xff0369a1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // WhatsApp Broadcast Status
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => onNavigateTab(2), // Jump to messages
                      child: _buildMetricCard(
                        icon: LucideIcons.messageCircle,
                        iconBg: const Color(0xffdcfce7),
                        iconColor: const Color(0xff16a34a),
                        title: T.t('Messages'),
                        value: '${controller.todaySentCount.value + controller.todayOpenedCount.value} ${T.t("Notified")}',
                        subtitle: '${controller.todayNotSentCount.value} ${T.t("Pending")}',
                        badgeColor: const Color(0xff16a34a),
                        showTapArrow: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Progress Bar Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xffe3ebe6)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          T.t('Collection Progress'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xff1f2937),
                          ),
                        ),
                        Text(
                          '${(completionPct * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xff2d7a55),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: completionPct,
                        minHeight: 8,
                        backgroundColor: const Color(0xffe5e7eb),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xff2d7a55)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildStatusBadge(
                          label: '$completedCount ${T.t("Recorded")}',
                          color: const Color(0xff15803d),
                          bg: const Color(0xffdcfce7),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusBadge(
                          label: '$missingCount ${T.t("Missing")}',
                          color: const Color(0xffb45309),
                          bg: const Color(0xfffef3c7),
                        ),
                        const Spacer(),
                        Text(
                          '$totalCustomers ${T.t("Customers")}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Quick Actions Bar
              Text(
                T.t('Quick Actions'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xff1f2937),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildActionTile(
                      icon: LucideIcons.userPlus,
                      label: T.t('Add customer'),
                      color: const Color(0xff2d7a55),
                      onTap: onOpenAddCustomer,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionTile(
                      icon: LucideIcons.send,
                      label: T.t('Broadcast Messages'),
                      color: const Color(0xff25D366),
                      onTap: () => onNavigateTab(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionTile(
                      icon: LucideIcons.users,
                      label: T.t('Customer Directory'),
                      color: const Color(0xff0284c7),
                      onTap: () => onNavigateTab(1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionTile(
                      icon: LucideIcons.settings,
                      label: T.t('Settings'),
                      color: const Color(0xff64748b),
                      onTap: () => onNavigateTab(3),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Today's Collection Roster Header & Filter Chips
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    T.t('Collection Summary'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xff1f2937),
                    ),
                  ),
                  Text(
                    '${filteredItems.length} ${T.t("Customers")}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: '${T.t("All")} (${allItems.length})',
                      selected: filter == 'all',
                      onSelected: () => controller.setDailyFilter('all'),
                    ),
                    const SizedBox(width: 8),
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
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Customers Collection List
              if (controller.loading.value && allItems.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: Color(0xff2d7a55)),
                  ),
                )
              else if (filteredItems.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xffe3ebe6)),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          filter == 'missing'
                              ? LucideIcons.partyPopper
                              : LucideIcons.inbox,
                          size: 36,
                          color: filter == 'missing'
                              ? const Color(0xff2d7a55)
                              : Colors.grey.shade400,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          filter == 'missing'
                              ? T.t('All customer entries completed')
                              : T.t('No entries recorded for this date'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...filteredItems.map((item) => _buildDailyCustomerCard(context, item)),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
    required Color badgeColor,
    bool showTapArrow = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffe3ebe6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              if (showTapArrow)
                Icon(
                  LucideIcons.arrowUpRight,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge({
    required String label,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xffe3ebe6)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xff374151),
                height: 1.1,
              ),
            ),
          ],
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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

  Widget _buildDailyCustomerCard(BuildContext context, Map<String, dynamic> item) {
    final customer = item['customer'] as Map? ?? {};
    final entry = item['entry'] as Map?;
    final hasEntry = item['hasEntry'] == true || entry != null;

    final customerId = '${customer['id'] ?? ''}';
    final name = '${customer['name'] ?? 'Customer'}'.trim();
    final number = '${customer['uniqueNumber'] ?? ''}';
    final defaultLiters = (customer['defaultLiters'] as num?)?.toDouble() ?? 1.0;
    final defaultPrice = (customer['defaultPrice'] as num?)?.toDouble() ?? 0.0;

    final recordedLiters = (entry?['liters'] as num?)?.toDouble() ?? defaultLiters;
    final recordedPrice = (entry?['price'] as num?)?.toDouble() ?? defaultPrice;
    final recordedTotal = (entry?['total'] as num?)?.toDouble() ?? (recordedLiters * recordedPrice);

    final messageLog = item['messageLog'] as Map? ?? {};
    final status = '${messageLog['status'] ?? 'not_sent'}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasEntry ? const Color(0xffe3ebe6) : const Color(0xfffde68a),
          width: hasEntry ? 1 : 1.4,
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
                color: hasEntry ? const Color(0xff166534) : const Color(0xff92400e),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name and milk stats
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
                      _buildMessageStatusPill(status),
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

          // Action button
          if (!hasEntry)
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xff2d7a55),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                minimumSize: const Size(68, 34),
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
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            )
          else
            IconButton(
              icon: const Icon(LucideIcons.pencil, size: 18, color: Color(0xff2d7a55)),
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
    );
  }

  Widget _buildMessageStatusPill(String status) {
    Color bg;
    Color text;
    String label;

    switch (status) {
      case 'sent':
        bg = const Color(0xffdcfce7);
        text = const Color(0xff16a34a);
        label = 'Sent';
        break;
      case 'opened_in_whatsapp':
        bg = const Color(0xffccfbf1);
        text = const Color(0xff0f766e);
        label = 'Opened';
        break;
      case 'failed':
        bg = const Color(0xfffee2e2);
        text = const Color(0xffdc2626);
        label = 'Failed';
        break;
      default:
        bg = const Color(0xfff3f4f6);
        text = const Color(0xff6b7280);
        label = 'Not sent';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: text,
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xffdcefe3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(LucideIcons.milk, size: 18, color: Color(0xff2d7a55)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    if (number.isNotEmpty)
                      Text(
                        '#$number',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                  ],
                ),
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
                          onTap: () {
                            setDialogState(() {
                              curLiters = (curLiters - 0.5).clamp(0.0, 999.0);
                              litersCtrl.text = curLiters == curLiters.truncateToDouble()
                                  ? curLiters.toStringAsFixed(0)
                                  : curLiters.toStringAsFixed(2);
                            });
                          },
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
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                            if (val == null || val.trim().isEmpty) return T.t('Required');
                            if (double.tryParse(val.trim()) == null) return T.t('Invalid number');
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
                              curLiters = curLiters + 0.5;
                              litersCtrl.text = curLiters == curLiters.truncateToDouble()
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
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: T.t('Price per liter'),
                      prefixText: '₹ ',
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return T.t('Required');
                      if (double.tryParse(val.trim()) == null) return T.t('Invalid number');
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text(T.t('Cancel')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xff2d7a55),
              ),
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.of(dialogCtx).pop(true);
              },
              child: Text(T.t('Save entry')),
            ),
          ],
        ),
      ),
    );

    if (saved == true && context.mounted) {
      final liters = double.parse(litersCtrl.text.trim());
      final price = double.parse(priceCtrl.text.trim());
      final success = await controller.saveCustomerMilkEntry(
        customerId,
        liters,
        price,
        date: controller.selectedDate.value,
      );
      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(T.t('Milk entry saved')),
              backgroundColor: const Color(0xff2d7a55),
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
