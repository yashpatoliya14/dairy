import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../controllers/dashboard_controller.dart';
import '../services/api_service.dart';
import '../services/app_language.dart';
import 'customer_bills_screen.dart';
import 'daily_collection_screen.dart';

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

      return Scaffold(
        backgroundColor: const Color(0xfff1f5f9),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          elevation: 0,
          backgroundColor: const Color(0xff1b4d36),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  LucideIcons.milk,
                  color: Colors.white,
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
                        color: Colors.white,
                      ),
                    ),
                    if (controller.ownerName.value.isNotEmpty)
                      Text(
                        '${T.t("Welcome back")}, ${controller.ownerName.value}',
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
            ],
          ),
        ),
        body: RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              // Date Navigator Bar
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xffe2e8f0)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(LucideIcons.chevronLeft, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      onPressed: controller.previousDay,
                    ),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
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
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              LucideIcons.calendar,
                              size: 14,
                              color: Color(0xff2d7a55),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _formatDateTitle(controller.selectedDate.value),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: Color(0xff1b4d36),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (controller.isSelectedDateToday)
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
                        onPressed: controller.goToToday,
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
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Get.to(
                        () => DailyCollectionScreen(
                          api: api,
                          controller: controller,
                        ),
                      ),
                      child: _buildMetricCard(
                        icon: LucideIcons.clipboardCheck,
                        iconBg: const Color(0xffe0f2fe),
                        iconColor: const Color(0xff0369a1),
                        title: T.t('Collection Progress'),
                        value: '$completedCount / $totalCustomers',
                        subtitle: '${(completionPct * 100).toStringAsFixed(0)}% ${T.t("Completed")}',
                        badgeColor: const Color(0xff0369a1),
                        showTapArrow: true,
                      ),
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

              // Progress Bar Card (Clickable to Collection Page)
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Get.to(
                  () => DailyCollectionScreen(
                    api: api,
                    controller: controller,
                  ),
                ),
                child: Container(
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
                      icon: LucideIcons.receiptText,
                      label: T.t('Bills'),
                      color: const Color(0xffd97706),
                      onTap: () => Get.to(
                        () => CustomerBillsScreen(
                          api: api,
                          controller: controller,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
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
        height: 84,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xffe3ebe6)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
            Expanded(
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff374151),
                    height: 1.15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
