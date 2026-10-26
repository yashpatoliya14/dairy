import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../services/app_language.dart';
import 'customer_message_details_screen.dart';

class WhatsAppMessagingScreen extends StatefulWidget {
  const WhatsAppMessagingScreen({
    super.key,
    required this.api,
    this.initialDate,
  });

  final ApiService api;
  final DateTime? initialDate;

  @override
  State<WhatsAppMessagingScreen> createState() =>
      _WhatsAppMessagingScreenState();
}

class _WhatsAppMessagingScreenState extends State<WhatsAppMessagingScreen> {
  late DateTime _selectedDate;
  bool _loading = true;
  String _searchQuery = '';
  String _selectedFilter = 'all'; // 'all', 'pending', 'sent', 'failed', 'no_entry'

  Map<String, dynamic>? _dailyData;
  String? _errorMessage;

  // Multi-select for bulk workflow
  bool _selectionMode = false;
  final Set<String> _selectedCustomerIds = {};

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    _loadData();
  }

  String get _formattedDate =>
      _selectedDate.toIso8601String().substring(0, 10);

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final res = await widget.api.getDailySummary(date: _formattedDate);
      if (mounted) {
        setState(() {
          _dailyData = res;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _selectedCustomerIds.clear();
      });
      await _loadData();
    }
  }

  void _previousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
      _selectedCustomerIds.clear();
    });
    _loadData();
  }

  void _nextDay() {
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
      _selectedCustomerIds.clear();
    });
    _loadData();
  }

  void _goToToday() {
    setState(() {
      _selectedDate = DateTime.now();
      _selectedCustomerIds.clear();
    });
    _loadData();
  }

  String _cleanPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '91$digits';
    return digits;
  }

  String _buildQuickMessage(Map<String, dynamic> item) {
    final currentLang = Get.find<AppLanguageController>().language.value;
    final customer = item['customer'] as Map? ?? {};
    final entry = item['entry'] as Map?;

    final name = '${customer['name'] ?? 'Customer'}'.trim();
    final liters = entry != null
        ? '${entry['liters']}'
        : '${customer['defaultLiters'] ?? '0'}';
    final price = entry != null
        ? '${entry['price']}'
        : '${customer['defaultPrice'] ?? '0'}';
    final total = entry != null
        ? '${entry['total']}'
        : (double.tryParse(liters) != null && double.tryParse(price) != null)
            ? (double.parse(liters) * double.parse(price)).toStringAsFixed(2)
            : '0.00';

    final dairy = '${_dailyData?['dairyName'] ?? ''}'.trim();
    final dairyName = dairy.isNotEmpty ? dairy : 'Dairy Desk';

    if (currentLang == 'gu') {
      return 'નમસ્તે $name,\n\n'
          'આજની દૂધની વિગત ($_formattedDate):\n\n'
          'કુલ દૂધ: $liters લીટર\n'
          'દૂધનો દર: ₹$price/લીટર\n'
          'કુલ રકમ: ₹$total\n\n'
          'આભાર!\n'
          '$dairyName';
    } else if (currentLang == 'hi') {
      return 'नमस्ते $name,\n\n'
          'आज का दूध विवरण ($_formattedDate):\n\n'
          'कुल दूध: $liters लीटर\n'
          'दर: ₹$price/लीटर\n'
          'कुल राशि: ₹$total\n\n'
          'धन्यवाद!\n'
          '$dairyName';
    } else {
      return 'Hello $name,\n\n'
          'Today\'s Milk Details ($_formattedDate):\n\n'
          'Total Milk: $liters Liters\n'
          'Rate: ₹$price/Liter\n'
          'Total Amount: ₹$total\n\n'
          'Thank you!\n'
          '$dairyName';
    }
  }

  Future<void> _quickSendWhatsApp(Map<String, dynamic> item) async {
    final customer = item['customer'] as Map? ?? {};
    final phone = '${customer['phoneNumber'] ?? ''}'.trim();
    final cleanPhone = _cleanPhone(phone);

    if (cleanPhone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(T.t('Please enter a valid phone number')),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    final message = _buildQuickMessage(item);
    final encodedMessage = Uri.encodeComponent(message);

    final nativeUri = Uri.parse(
      'whatsapp://send?phone=$cleanPhone&text=$encodedMessage',
    );
    final webUri = Uri.parse(
      'https://wa.me/$cleanPhone?text=$encodedMessage',
    );

    try {
      bool launched = false;
      if (await canLaunchUrl(nativeUri)) {
        launched = await launchUrl(
          nativeUri,
          mode: LaunchMode.externalApplication,
        );
      }
      if (!launched && await canLaunchUrl(webUri)) {
        launched = await launchUrl(
          webUri,
          mode: LaunchMode.externalApplication,
        );
      }

      if (launched) {
        await widget.api.updateDailyMessageStatus(
          customerId: '${customer['id']}',
          date: _formattedDate,
          status: 'opened_in_whatsapp',
          messageContent: message,
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        try {
          await widget.api.updateDailyMessageStatus(
            customerId: '${customer['id']}',
            date: _formattedDate,
            status: 'failed',
            messageContent: message,
            errorMessage: e.toString(),
          );
          await _loadData();
        } catch (_) {}

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${T.t('Could not open WhatsApp')}: $e'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'sent':
        return const Color(0xff2d7a55);
      case 'opened_in_whatsapp':
        return Colors.teal.shade700;
      case 'pending':
        return Colors.blue.shade700;
      case 'failed':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'sent':
        return T.t('Sent');
      case 'opened_in_whatsapp':
        return T.t('Opened');
      case 'pending':
        return T.t('Pending');
      case 'failed':
        return T.t('Failed');
      default:
        return T.t('Not Sent');
    }
  }

  List<Map<String, dynamic>> _filteredCustomers() {
    if (_dailyData == null) return [];
    final list = (_dailyData!['customers'] as List? ?? [])
        .whereType<Map>()
        .map((c) => Map<String, dynamic>.from(c))
        .toList();

    return list.where((item) {
      final customer = item['customer'] as Map? ?? {};
      final name = '${customer['name'] ?? ''}'.toLowerCase();
      final phone = '${customer['phoneNumber'] ?? ''}'.toLowerCase();
      final number = '${customer['uniqueNumber'] ?? ''}'.toLowerCase();

      // Search filter
      final q = _searchQuery.toLowerCase().trim();
      final matchesSearch =
          q.isEmpty || name.contains(q) || phone.contains(q) || number.contains(q);
      if (!matchesSearch) return false;

      // Category filter
      final status = '${item['messageLog']?['status'] ?? 'not_sent'}';
      final hasEntry = item['hasEntry'] == true;

      switch (_selectedFilter) {
        case 'pending':
          return status == 'pending' || status == 'not_sent';
        case 'sent':
          return status == 'sent' || status == 'opened_in_whatsapp';
        case 'failed':
          return status == 'failed';
        case 'no_entry':
          return !hasEntry;
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final summary = _dailyData?['summary'] as Map? ?? {};
    final dairyName = '${_dailyData?['dairyName'] ?? ''}'.trim();
    final customers = _filteredCustomers();

    final isToday = _formattedDate ==
        DateTime.now().toIso8601String().substring(0, 10);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          dairyName.isNotEmpty ? '$dairyName • ${T.t('Messages')}' : T.t('Send Messages'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: _selectionMode
                ? T.t('Close')
                : T.t('Select All'),
            icon: Icon(
              _selectionMode
                  ? LucideIcons.x
                  : LucideIcons.checkSquare,
            ),
            onPressed: () {
              setState(() {
                _selectionMode = !_selectionMode;
                if (!_selectionMode) {
                  _selectedCustomerIds.clear();
                }
              });
            },
          ),
          IconButton(
            tooltip: T.t('Refresh customers'),
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: _loading ? null : _loadData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            // Date Picker Row
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xffe3ebe6)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: T.t('Yesterday'),
                      icon: const Icon(LucideIcons.chevronLeft),
                      onPressed: _previousDay,
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                LucideIcons.calendar,
                                size: 18,
                                color: Color(0xff2d7a55),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isToday ? '${T.t('Today')} ($_formattedDate)' : _formattedDate,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (!isToday)
                      TextButton(
                        onPressed: _goToToday,
                        child: Text(T.t('Today')),
                      ),
                    IconButton(
                      tooltip: T.t('Select date'),
                      icon: const Icon(LucideIcons.chevronRight),
                      onPressed: _nextDay,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Daily Summary Metrics Card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xffe3ebe6)),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                T.t('Total Liters'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${summary['totalLiters'] ?? 0} L',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xff2d7a55),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                T.t('Total Amount'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${summary['totalAmount'] ?? 0}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _SummaryBadge(
                          label: T.t('Entries Done'),
                          count: '${summary['completedEntriesCount'] ?? 0}/${summary['totalCustomers'] ?? 0}',
                          color: const Color(0xff2d7a55),
                        ),
                        _SummaryBadge(
                          label: T.t('Entries Missing'),
                          count: '${summary['missingEntriesCount'] ?? 0}',
                          color: Colors.amber.shade900,
                        ),
                        _SummaryBadge(
                          label: T.t('Sent'),
                          count: '${(summary['sentCount'] ?? 0) + (summary['openedCount'] ?? 0)}',
                          color: Colors.teal.shade800,
                        ),
                        _SummaryBadge(
                          label: T.t('Pending'),
                          count: '${(summary['pendingCount'] ?? 0) + (summary['notSentCount'] ?? 0)}',
                          color: Colors.blueGrey,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Search Bar
            TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: T.t('Search by name or mobile number'),
                prefixIcon: const Icon(LucideIcons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                fillColor: Colors.white,
                filled: true,
              ),
            ),

            const SizedBox(height: 10),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: T.t('All'),
                    selected: _selectedFilter == 'all',
                    onTap: () => setState(() => _selectedFilter = 'all'),
                  ),
                  const SizedBox(width: 6),
                  _FilterChip(
                    label: T.t('Pending'),
                    selected: _selectedFilter == 'pending',
                    onTap: () => setState(() => _selectedFilter = 'pending'),
                  ),
                  const SizedBox(width: 6),
                  _FilterChip(
                    label: T.t('Sent'),
                    selected: _selectedFilter == 'sent',
                    onTap: () => setState(() => _selectedFilter = 'sent'),
                  ),
                  const SizedBox(width: 6),
                  _FilterChip(
                    label: T.t('Failed'),
                    selected: _selectedFilter == 'failed',
                    onTap: () => setState(() => _selectedFilter = 'failed'),
                  ),
                  const SizedBox(width: 6),
                  _FilterChip(
                    label: T.t('No milk entry'),
                    selected: _selectedFilter == 'no_entry',
                    onTap: () => setState(() => _selectedFilter = 'no_entry'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Bulk Mode Action Banner (if active)
            if (_selectionMode)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xffdcefe3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text(
                      '${_selectedCustomerIds.length} ${T.t('Selected')}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xff2d7a55),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (_selectedCustomerIds.length == customers.length) {
                            _selectedCustomerIds.clear();
                          } else {
                            _selectedCustomerIds.addAll(
                              customers.map(
                                (c) => '${c['customer']['id']}',
                              ),
                            );
                          }
                        });
                      },
                      child: Text(
                        _selectedCustomerIds.length == customers.length
                            ? T.t('Deselect All')
                            : T.t('Select All'),
                      ),
                    ),
                  ],
                ),
              ),

            // Customer List
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_errorMessage != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _loadData,
                        child: Text(T.t('Try again')),
                      ),
                    ],
                  ),
                ),
              )
            else if (customers.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(
                        LucideIcons.inbox,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        T.t('No customers found'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...customers.map(
                (item) {
                  final customer = item['customer'] as Map? ?? {};
                  final entry = item['entry'] as Map?;
                  final log = item['messageLog'] as Map? ?? {};
                  final hasEntry = item['hasEntry'] == true;
                  final cid = '${customer['id']}';

                  final name = '${customer['name'] ?? 'Customer'}';
                  final phone = '${customer['phoneNumber'] ?? ''}'.trim();
                  final uniqueNumber = '${customer['uniqueNumber'] ?? '—'}';
                  final liters = entry != null
                      ? '${entry['liters']} L'
                      : (hasEntry
                          ? '${customer['defaultLiters'] ?? 0} L'
                          : '—');
                  final rate = entry != null
                      ? '₹${entry['price']}'
                      : '₹${customer['defaultPrice'] ?? '—'}';
                  final total = entry != null ? '₹${entry['total']}' : '—';
                  final status = '${log['status'] ?? 'not_sent'}';
                  final lastAttempt = log['lastAttemptedAt'] != null
                      ? '${log['lastAttemptedAt']}'.substring(11, 16)
                      : null;

                  final isSelected = _selectedCustomerIds.contains(cid);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xff2d7a55)
                            : const Color(0xffe3ebe6),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        if (_selectionMode) {
                          setState(() {
                            if (isSelected) {
                              _selectedCustomerIds.remove(cid);
                            } else {
                              _selectedCustomerIds.add(cid);
                            }
                          });
                        } else {
                          Get.to(
                            () => CustomerMessageDetailsScreen(
                              api: widget.api,
                              customerItem: item,
                              date: _formattedDate,
                              dairyName: dairyName,
                              onStatusUpdated: _loadData,
                            ),
                          );
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            if (_selectionMode)
                              Checkbox(
                                value: isSelected,
                                onChanged: (v) {
                                  setState(() {
                                    if (v == true) {
                                      _selectedCustomerIds.add(cid);
                                    } else {
                                      _selectedCustomerIds.remove(cid);
                                    }
                                  });
                                },
                              )
                            else
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: const Color(0xffdcefe3),
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xff2d7a55),
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
                                          name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xffe8f0ec),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '#$uniqueNumber',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xff2d7a55),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    phone.isNotEmpty
                                        ? phone
                                        : T.t('No phone number available'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: phone.isNotEmpty
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant
                                          : Colors.red.shade400,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      if (hasEntry) ...[
                                        Text(
                                          '$liters  •  $rate  •  $total',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ] else ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade100,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            T.t('No milk entry'),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.amber.shade900,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(status)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _getStatusLabel(status),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: _getStatusColor(status),
                                    ),
                                  ),
                                ),
                                if (lastAttempt != null) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    lastAttempt,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  tooltip: T.t('Open in WhatsApp'),
                                  icon: const Icon(
                                    LucideIcons.messageCircle,
                                    color: Color(0xff25D366),
                                    size: 22,
                                  ),
                                  onPressed: () => _quickSendWhatsApp(item),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryBadge extends StatelessWidget {
  const _SummaryBadge({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final String count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xff2d7a55) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xff2d7a55)
                : const Color(0xffe3ebe6),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}
