import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

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
    // Default to 'missing' (Pending) so distributors see who still needs milk recorded
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
      final completionPct = totalCustomers > 0
          ? (completedCount / totalCustomers).clamp(0.0, 1.0)
          : 0.0;

      final allItems = controller.dailyCustomerItems;
      final filter = controller.dailyFilter.value;

      final missingCount = allItems.where((item) {
        final hasEntry = item['hasEntry'] == true || item['entry'] != null;
        return !hasEntry;
      }).length;

      final filteredByTab = allItems.where((item) {
        final hasEntry = item['hasEntry'] == true || item['entry'] != null;
        if (filter == 'missing') return !hasEntry;
        if (filter == 'completed') return hasEntry;
        return true;
      }).toList();

      String normalizeDigits(String s) {
        const gujToEng = {
          '૦': '0', '૧': '1', '૨': '2', '૩': '3', '૪': '4',
          '૫': '5', '૬': '6', '૭': '7', '૮': '8', '૯': '9',
          '०': '0', '१': '1', '२': '2', '३': '3', '४': '4',
          '५': '5', '६': '6', '७': '7', '८': '8', '९': '9',
        };
        var res = s;
        gujToEng.forEach((guj, eng) {
          res = res.replaceAll(guj, eng);
        });
        return res;
      }

      final rawQuery = _searchQuery.value.trim().toLowerCase();
      final query = normalizeDigits(rawQuery);
      final queryDigitsOnly = query.replaceAll(RegExp(r'[^0-9]'), '');

      final displayedItems = filteredByTab.where((item) {
        if (query.isEmpty) return true;
        final customer = item['customer'] as Map? ?? {};
        final name = '${customer['name'] ?? ''}'.toLowerCase();
        final rawNumber = normalizeDigits('${customer['uniqueNumber'] ?? customer['customerNumber'] ?? customer['number'] ?? ''}'.trim().toLowerCase());
        final cleanNumber = rawNumber.replaceAll(RegExp(r'[^0-9]'), '');
        final phone = '${customer['phoneNumber'] ?? ''}'.toLowerCase();

        // 1. Name match (matches English or Gujarati name)
        if (name.contains(query) || name.contains(rawQuery)) return true;

        // 2. Direct Unique Number match (e.g. user typed "1", "#1", "૧", "#૧")
        if (rawNumber == query || ('#$rawNumber') == query || rawNumber.contains(query)) return true;

        // 3. Numeric query match on uniqueNumber (e.g. user typed 1, 2, 3...)
        if (queryDigitsOnly.isNotEmpty && cleanNumber.isNotEmpty) {
          if (cleanNumber == queryDigitsOnly || cleanNumber.startsWith(queryDigitsOnly)) {
            return true;
          }
        }

        // 4. Phone number match
        if (phone.contains(query) || (queryDigitsOnly.length >= 3 && phone.contains(queryDigitsOnly))) return true;

        return false;
      }).toList();

      displayedItems.sort((a, b) {
        final custA = a['customer'] as Map? ?? {};
        final custB = b['customer'] as Map? ?? {};
        final rawNumA = normalizeDigits('${custA['uniqueNumber'] ?? custA['customerNumber'] ?? ''}'.trim());
        final rawNumB = normalizeDigits('${custB['uniqueNumber'] ?? custB['customerNumber'] ?? ''}'.trim());
        final numA = int.tryParse(rawNumA.replaceAll(RegExp(r'[^0-9]'), '')) ?? 999999;
        final numB = int.tryParse(rawNumB.replaceAll(RegExp(r'[^0-9]'), '')) ?? 999999;
        if (numA != numB) return numA.compareTo(numB);
        return '${custA['name']}'.compareTo('${custB['name']}');
      });

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
                          label: '${controller.todayLiters.value.toStringAsFixed(2)} L',
                          color: const Color(0xff0369a1),
                          bg: const Color(0xffe0f2fe),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Filter Chips (Pending, Completed, All)
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
                    hintText: T.t('Search (Name, #Number)'),
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
                            : filter == 'completed'
                                ? LucideIcons.inbox
                                : LucideIcons.users,
                        size: 40,
                        color: filter == 'missing'
                            ? const Color(0xff2d7a55)
                            : Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        filter == 'missing'
                            ? T.t('All customer entries completed')
                            : filter == 'completed'
                                ? T.t('No entries recorded for this date')
                                : T.t('No customers found'),
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

    final phone = '${customer['phoneNumber'] ?? ''}'.trim();

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _openRecordMilkDialog(
        context,
        customerId: customerId,
        name: name,
        number: number,
        defaultLiters: defaultLiters,
        defaultPrice: hasEntry ? recordedPrice : defaultPrice,
        existingEntry: hasEntry ? entry : null,
        phoneNumber: phone,
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
                          '${recordedLiters.toStringAsFixed(2)} L • ₹${recordedTotal.toStringAsFixed(2)}',
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
                      '${T.t("Expected")}: ${defaultLiters.toStringAsFixed(2)} L @ ₹${defaultPrice.toStringAsFixed(2)}',
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
                  existingEntry: null,
                  phoneNumber: phone,
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(
                      LucideIcons.messageCircle,
                      size: 20,
                      color: Color(0xff25D366),
                    ),
                    tooltip: T.t('Send WhatsApp receipt'),
                    onPressed: () => _sendQuickWhatsApp(
                      context: context,
                      customer: customer,
                      entry: entry,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      LucideIcons.pencil,
                      size: 18,
                      color: Color(0xff2d7a55),
                    ),
                    tooltip: T.t('Edit / Re-enter'),
                    onPressed: () => _openRecordMilkDialog(
                      context,
                      customerId: customerId,
                      name: name,
                      number: number,
                      defaultLiters: defaultLiters,
                      defaultPrice: recordedPrice,
                      existingEntry: entry,
                      phoneNumber: phone,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _buildDailyWhatsAppMessage({
    required String customerName,
    required double liters,
    required double price,
    required double total,
    required String dateFormatted,
  }) {
    final dairy = widget.controller.dairyName.value.trim();
    final dairyName = dairy.isNotEmpty ? dairy : 'Dairy Desk';
    final langController = Get.isRegistered<AppLanguageController>()
        ? Get.find<AppLanguageController>()
        : null;
    final lang = langController?.language.value ?? 'en';

    final lStr = liters.toStringAsFixed(2);
    final pStr = price.toStringAsFixed(2);
    final tStr = total.toStringAsFixed(2);

    if (lang == 'gu') {
      return 'નમસ્તે $customerName,\n\n'
          'આજની દૂધની વિગત ($dateFormatted):\n\n'
          'કુલ દૂધ: $lStr લીટર\n'
          'દૂધનો દર: ₹$pStr/લીટર\n'
          'કુલ રકમ: ₹$tStr\n\n'
          'આભાર!\n'
          '$dairyName';
    } else if (lang == 'hi') {
      return 'नमस्ते $customerName,\n\n'
          'आज का दूध विवरण ($dateFormatted):\n\n'
          'कुल दूध: $lStr लीटर\n'
          'दर: ₹$pStr/लीटर\n'
          'कुल राशि: ₹$tStr\n\n'
          'धन्यवाद!\n'
          '$dairyName';
    } else {
      return 'Hello $customerName,\n\n'
          'Today\'s Milk Details ($dateFormatted):\n\n'
          'Total Milk: $lStr Liters\n'
          'Rate: ₹$pStr/Liter\n'
          'Total Amount: ₹$tStr\n\n'
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

  Future<void> _sendQuickWhatsApp({
    required BuildContext context,
    required Map customer,
    required Map? entry,
  }) async {
    final customerId = '${customer['id'] ?? ''}';
    final name = '${customer['name'] ?? 'Customer'}'.trim();
    final phone = '${customer['phoneNumber'] ?? ''}'.trim();
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');

    if (cleanPhone.length < 10) {
      _promptAddPhoneNumber(
        context,
        customerId: customerId,
        customerName: name,
        entry: entry,
      );
      return;
    }

    final dateFormatted = widget.controller.selectedDate.value.toIso8601String().substring(0, 10);
    final liters = (entry?['liters'] as num?)?.toDouble() ?? 0.0;
    final price = (entry?['price'] as num?)?.toDouble() ?? 0.0;
    final total = (entry?['total'] as num?)?.toDouble() ?? (liters * price);

    final message = _buildDailyWhatsAppMessage(
      customerName: name,
      liters: liters,
      price: price,
      total: total,
      dateFormatted: dateFormatted,
    );

    try {
      final res = await widget.controller.api.sendDailyWhatsAppEntry(
        customerId: customerId,
        date: dateFormatted,
        message: message,
      );

      if (context.mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${T.t('WhatsApp message sent to')} $name via Business API!'),
              backgroundColor: const Color(0xff2d7a55),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${T.t('Failed to send WhatsApp message')}: ${res['error'] ?? 'API Error'}'),
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${T.t('Error sending WhatsApp message')}: $e'),
            backgroundColor: Colors.red.shade700,
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
  }

  Future<void> _promptAddPhoneNumber(
    BuildContext context, {
    required String customerId,
    required String customerName,
    Map? entry,
  }) async {
    final phoneCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${T.t('Add Phone Number')} - $customerName'),
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
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(T.t('Cancel')),
          ),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState?.validate() != true) return;
              try {
                final cleaned = phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
                await widget.controller.api.updateCustomer(customerId, {
                  'phoneNumber': cleaned,
                });
                await widget.controller.loadCustomers();
                if (ctx.mounted) Navigator.of(ctx).pop(true);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Error saving phone: $e')),
                  );
                }
              }
            },
            child: Text(T.t('Save')),
          ),
        ],
      ),
    );

    if (updated == true && entry != null && context.mounted) {
      final customer = widget.controller.customers.firstWhereOrNull(
        (c) => '${c['id']}' == customerId,
      ) ?? {'id': customerId, 'name': customerName, 'phoneNumber': phoneCtrl.text};
      _sendQuickWhatsApp(context: context, customer: customer, entry: entry);
    }
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
    Map? existingEntry,
    String? phoneNumber,
  }) async {
    final double existingLiters =
        (existingEntry?['liters'] as num?)?.toDouble() ?? 0.0;
    final double existingPrice =
        (existingEntry?['price'] as num?)?.toDouble() ?? defaultPrice;
    final double existingTotal = (existingEntry?['total'] as num?)?.toDouble() ??
        (existingLiters * existingPrice);

    String mode = 'add'; // 'add' (accumulate with last entry) or 'replace'

    final initialLiters = (existingEntry != null)
        ? defaultLiters
        : defaultLiters;
    final litersCtrl = TextEditingController(
      text: initialLiters.toStringAsFixed(2),
    );
    final priceCtrl = TextEditingController(
      text: existingPrice.toStringAsFixed(2),
    );
    final formKey = GlobalKey<FormState>();
    double curLiters = initialLiters;
    double curPrice = existingPrice;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final double previewLiters = (mode == 'add')
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
                    // Existing Entry Banner & Mode Switcher (Always available)
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
                                        curLiters = existingLiters > 0 ? existingLiters : defaultLiters;
                                        litersCtrl.text = curLiters.toStringAsFixed(2);
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
                              labelText: mode == 'add'
                                  ? T.t('Liters to add (+)')
                                  : T.t('Total Liters (Replace)'),
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

    if (saved == true) {
      final inputLiters = double.tryParse(litersCtrl.text.trim()) ?? defaultLiters;
      final inputPrice = double.tryParse(priceCtrl.text.trim()) ?? defaultPrice;

      final success = await widget.controller.saveCustomerMilkEntry(
        customerId,
        inputLiters,
        inputPrice,
        mode: mode,
      );

      final double finalLiters = (mode == 'add')
          ? (existingLiters + inputLiters)
          : inputLiters;
      final double finalTotal = finalLiters * inputPrice;

      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$name: ${finalLiters.toStringAsFixed(2)} L • ₹${finalTotal.toStringAsFixed(2)}'),
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
