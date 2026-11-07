import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/api_service.dart';
import '../services/app_language.dart';
import '../widgets/monthly_entries_screen.dart';
import '../widgets/payment_entry_sheet.dart';

class MonthlyMilkCardScreen extends StatefulWidget {
  const MonthlyMilkCardScreen({
    super.key,
    required this.api,
    required this.customer,
  });

  final ApiService api;
  final Map<String, dynamic> customer;

  @override
  State<MonthlyMilkCardScreen> createState() => _MonthlyMilkCardScreenState();
}

class _MonthlyMilkCardScreenState extends State<MonthlyMilkCardScreen> {
  late int _selectedYear;
  late int _selectedMonth;

  bool _isEditMode = false;
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasMutatedData = false;
  Map<String, dynamic>? _paymentData;

  // Keyed by 'YYYY-MM-DD'
  final Map<String, Map<String, dynamic>> _entriesByDate = {};

  final List<String> _monthNames = const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  final List<String> _weekdayNames = const [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    _loadMonthEntries();
  }

  String get _customerId => '${widget.customer['id']}'.trim();

  String get _customerName =>
      '${widget.customer['name'] ?? widget.customer['fullName'] ?? 'Customer'}';

  String get _customerNumber =>
      '${widget.customer['uniqueNumber'] ?? widget.customer['customerNumber'] ?? '—'}';

  double get _defaultLiters => _asDouble(widget.customer['liters'], 1.0);

  double get _defaultPrice => _asDouble(widget.customer['price'], 60.0);

  String get _monthKey =>
      '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}';

  int get _daysInSelectedMonth =>
      DateTime(_selectedYear, _selectedMonth + 1, 0).day;

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedYear == now.year && _selectedMonth == now.month;
  }

  bool get _isPastMonth {
    final now = DateTime.now();
    if (_selectedYear < now.year) return true;
    if (_selectedYear == now.year && _selectedMonth < now.month) return true;
    return false;
  }

  bool get _isFutureMonth {
    final now = DateTime.now();
    if (_selectedYear > now.year) return true;
    if (_selectedYear == now.year && _selectedMonth > now.month) return true;
    return false;
  }

  /// Calculates dynamic Total Pay and stats according to strict rules:
  /// - Current month: sum entries from Day 1 through today only.
  /// - Past month: sum entries for the full month.
  /// - Future month: 0.0.
  _CardCalculations _computeCalculations() {
    if (_isFutureMonth) {
      return const _CardCalculations(
        totalPay: 0.0,
        totalLiters: 0.0,
        recordedDays: 0,
        applicableDays: 0,
        hasEntries: false,
      );
    }

    final now = DateTime.now();
    final maxDay = _isCurrentMonth
        ? (now.day > _daysInSelectedMonth ? _daysInSelectedMonth : now.day)
        : _daysInSelectedMonth;

    double totalPay = 0.0;
    double totalLiters = 0.0;
    int recordedDays = 0;

    for (int day = 1; day <= maxDay; day++) {
      final dateKey =
          '$_monthKey-${day.toString().padLeft(2, '0')}';
      final entry = _entriesByDate[dateKey];
      if (entry != null) {
        final liters = _asDouble(entry['liters'], 0.0);
        final entryPrice = _asDouble(entry['price'], 0.0);
        final price = _defaultPrice > 0 ? _defaultPrice : (entryPrice > 0 ? entryPrice : _defaultPrice);
        final total = liters * price;
        totalPay += total;
        totalLiters += liters;
        recordedDays++;
      }
    }

    return _CardCalculations(
      totalPay: totalPay,
      totalLiters: totalLiters,
      recordedDays: recordedDays,
      applicableDays: maxDay,
      hasEntries: _entriesByDate.isNotEmpty,
    );
  }

  double get _paymentReceived =>
      _paymentData != null ? _asDouble(_paymentData!['receivedAmount'], 0.0) : 0.0;
  bool get _hasPayment => _paymentData != null;
  bool _isFullyPaid(double totalPay) =>
      _hasPayment && _paymentReceived >= totalPay && totalPay > 0;
  double _balanceDue(double totalPay) => totalPay - _paymentReceived;

  Future<void> _loadPayment() async {
    try {
      final data = await widget.api.getPaymentEntry(
        customerId: _customerId,
        year: _selectedYear,
        month: _selectedMonth,
      );
      if (mounted) {
        setState(() {
          _paymentData = data;
        });
      }
    } catch (e) {
      developer.log('Failed to load payment: $e', name: 'MonthlyMilkCard');
    }
  }

  Future<void> _loadMonthEntries() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final monthString = _monthKey;
      final list = await widget.api.getMilkEntries(
        _customerId,
        month: monthString,
      );

      _entriesByDate.clear();
      for (final item in list) {
        final rawDate = '${item['entryDate'] ?? ''}';
        if (rawDate.length >= 10) {
          final dateKey = rawDate.substring(0, 10);
          _entriesByDate[dateKey] = item;
        }
      }

      await _loadPayment();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      developer.log(
        'Failed to load milk entries for $_monthKey: $e',
        name: 'MonthlyMilkCard',
        error: e,
        stackTrace: stack,
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _previousMonth() {
    setState(() {
      if (_selectedMonth == 1) {
        _selectedMonth = 12;
        _selectedYear -= 1;
      } else {
        _selectedMonth -= 1;
      }
    });
    _loadMonthEntries();
  }

  void _nextMonth() {
    setState(() {
      if (_selectedMonth == 12) {
        _selectedMonth = 1;
        _selectedYear += 1;
      } else {
        _selectedMonth += 1;
      }
    });
    _loadMonthEntries();
  }

  void _goToCurrentMonth() {
    final now = DateTime.now();
    if (_selectedYear == now.year && _selectedMonth == now.month) return;
    setState(() {
      _selectedYear = now.year;
      _selectedMonth = now.month;
    });
    _loadMonthEntries();
  }

  Future<void> _pickMonthYear() async {
    int tempYear = _selectedYear;
    int tempMonth = _selectedMonth;

    final picked = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        T.t('Select Month & Year'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: () {
                              setModalState(() => tempYear--);
                            },
                          ),
                          Text(
                            '$tempYear',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: () {
                              setModalState(() => tempYear++);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(12, (index) {
                      final m = index + 1;
                      final isSelected =
                          m == tempMonth && tempYear == _selectedYear;
                      return ChoiceChip(
                        label: Text(_monthNames[index].substring(0, 3)),
                        selected: isSelected,
                        selectedColor: const Color(0xff2d7a55),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setModalState(() => tempMonth = m);
                          }
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(T.t('Apply')),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (picked == true && mounted) {
      if (tempYear != _selectedYear || tempMonth != _selectedMonth) {
        setState(() {
          _selectedYear = tempYear;
          _selectedMonth = tempMonth;
        });
        _loadMonthEntries();
      }
    }
  }

  void _onDateTileTapped(int day, Map<String, dynamic>? entry) {
    if (!_isEditMode) {
      _showReadOnlyDetails(day, entry);
      return;
    }

    _openEntryEditorSheet(day, entry);
  }

  void _showReadOnlyDetails(int day, Map<String, dynamic>? entry) {
    final dateObj = DateTime(_selectedYear, _selectedMonth, day);
    final weekdayStr = _weekdayNames[dateObj.weekday - 1];
    final displayDate =
        '$weekdayStr, $day ${_monthNames[_selectedMonth - 1]} $_selectedYear';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final liters = entry != null ? _asDouble(entry['liters'], 0.0) : null;
        final price = entry != null ? _asDouble(entry['price'], 0.0) : null;
        final total = entry != null
            ? _asDouble(entry['total'], (liters ?? 0) * (price ?? 0))
            : null;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xffdcefe3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      LucideIcons.calendarCheck,
                      color: Color(0xff2d7a55),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayDate,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          T.t('Card View Mode (Read-Only)'),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              if (entry != null) ...[
                _buildInfoRow(
                  label: T.t('Daily Milk Quantity'),
                  value: '${liters!.toStringAsFixed(2)} L',
                  icon: LucideIcons.milk,
                ),
                const SizedBox(height: 10),
                _buildInfoRow(
                  label: T.t('Price / Rate per Liter'),
                  value: '₹${price!.toStringAsFixed(2)}',
                  icon: LucideIcons.tag,
                ),
                const SizedBox(height: 10),
                _buildInfoRow(
                  label: T.t('Daily Total Amount'),
                  value: '₹${total!.toStringAsFixed(2)}',
                  icon: LucideIcons.indianRupee,
                  isBold: true,
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.grey.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          T.t('No milk entry was recorded on this date.'),
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(T.t('Close')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xff2d7a55),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() => _isEditMode = true);
                        _openEntryEditorSheet(day, entry);
                      },
                      icon: const Icon(Icons.edit, size: 16),
                      label: Text(T.t('Edit Entry')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _openEntryEditorSheet(int day, Map<String, dynamic>? entry) {
    final dateKey = '$_monthKey-${day.toString().padLeft(2, '0')}';
    final dateObj = DateTime(_selectedYear, _selectedMonth, day);
    final weekdayStr = _weekdayNames[dateObj.weekday - 1];
    final displayDate =
        '$weekdayStr, $day ${_monthNames[_selectedMonth - 1]} $_selectedYear';

    final initialLiters = entry != null
        ? _asDouble(entry['liters'], _defaultLiters)
        : _defaultLiters;
    final initialPrice = entry != null
        ? _asDouble(entry['price'], _defaultPrice)
        : _defaultPrice;

    final litersController = TextEditingController(
      text: initialLiters.toStringAsFixed(2),
    );
    final priceController = TextEditingController(
      text: initialPrice.toStringAsFixed(2),
    );

    bool isSubmitting = false;
    String? localError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final lVal = double.tryParse(
                  litersController.text.trim().replaceAll(',', '.'),
                ) ??
                0.0;
            final pVal = double.tryParse(
                  priceController.text.trim().replaceAll(',', '.'),
                ) ??
                0.0;
            final calculatedTotal = lVal * pVal;

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: entry != null
                                ? const Color(0xffe0f2fe)
                                : const Color(0xffdcefe3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            entry != null
                                ? Icons.edit_note
                                : Icons.add_circle_outline,
                            color: entry != null
                                ? const Color(0xff0369a1)
                                : const Color(0xff2d7a55),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry != null
                                    ? T.t('Edit Milk Entry')
                                    : T.t('Add Milk Entry'),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                displayDate,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    if (localError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xfffee2e2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Color(0xffdc2626),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                localError!,
                                style: const TextStyle(
                                  color: Color(0xffb91c1c),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                T.t('Quantity (Liters)'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: litersController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*[\.,]?\d{0,2}'),
                                  ),
                                ],
                                decoration: InputDecoration(
                                  hintText: '0.00',
                                  suffixText: 'L',
                                  filled: true,
                                  fillColor: const Color(0xfff8fafc),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onChanged: (_) => setModalState(() {}),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                T.t('Rate (₹/L)'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: priceController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*[\.,]?\d{0,2}'),
                                  ),
                                ],
                                decoration: InputDecoration(
                                  hintText: '0.00',
                                  prefixText: '₹ ',
                                  filled: true,
                                  fillColor: const Color(0xfff8fafc),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onChanged: (_) => setModalState(() {}),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Quick Fill Buttons
                    Row(
                      children: [
                        Text(
                          T.t('Quick:'),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          label: Text(
                            '${_defaultLiters.toStringAsFixed(1)} L',
                          ),
                          onPressed: () {
                            litersController.text =
                                _defaultLiters.toStringAsFixed(2);
                            setModalState(() {});
                          },
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 6),
                        ActionChip(
                          label: Text(T.t('0 L (Off-day)')),
                          onPressed: () {
                            litersController.text = '0.00';
                            setModalState(() {});
                          },
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Live Total Preview
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xfff0fdf4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xffbbf7d0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            T.t('Calculated Entry Total:'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xff166534),
                            ),
                          ),
                          Text(
                            '₹${calculatedTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff166534),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Action Buttons
                    Row(
                      children: [
                        if (entry != null) ...[
                          IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xfffee2e2),
                            ),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Color(0xffdc2626),
                            ),
                            tooltip: T.t('Delete Entry'),
                            onPressed: isSubmitting
                                ? null
                                : () => _confirmAndDeleteEntry(
                                      sheetContext: sheetContext,
                                      day: day,
                                      dateKey: dateKey,
                                      entry: entry,
                                      setModalState: setModalState,
                                    ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSubmitting
                                ? null
                                : () => Navigator.pop(sheetContext),
                            child: Text(T.t('Cancel')),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xff2d7a55),
                            ),
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    final cleanLiters = litersController.text
                                        .trim()
                                        .replaceAll(',', '.');
                                    final cleanPrice = priceController.text
                                        .trim()
                                        .replaceAll(',', '.');

                                    final l = double.tryParse(cleanLiters);
                                    final p = double.tryParse(cleanPrice);

                                    if (l == null || l < 0) {
                                      setModalState(() {
                                        localError = T.t(
                                          'Please enter a valid liters quantity',
                                        );
                                      });
                                      return;
                                    }
                                    if (p == null || p < 0) {
                                      setModalState(() {
                                        localError =
                                            T.t('Please enter a valid price');
                                      });
                                      return;
                                    }

                                    final scaffoldMessenger =
                                        ScaffoldMessenger.of(context);
                                    final navigator =
                                        Navigator.of(sheetContext);

                                    setModalState(() {
                                      isSubmitting = true;
                                      localError = null;
                                    });

                                    try {
                                      final result =
                                          await widget.api.addMilkEntry(
                                        _customerId,
                                        date: dateObj,
                                        liters: l,
                                        price: p,
                                      );

                                      // Update local cache
                                      _entriesByDate[dateKey] = {
                                        'id': result['id'] ??
                                            entry?['id'] ??
                                            '',
                                        'entryDate': dateKey,
                                        'liters': l,
                                        'price': p,
                                        'total': l * p,
                                      };
                                      _hasMutatedData = true;

                                      if (mounted) {
                                        setState(() {});
                                      }
                                      navigator.pop();

                                      scaffoldMessenger.showSnackBar(
                                        SnackBar(
                                          backgroundColor:
                                              const Color(0xff166534),
                                          content: Text(
                                            entry != null
                                                ? T.t(
                                                    'Milk entry updated successfully',
                                                  )
                                                : T.t(
                                                    'Milk entry created successfully',
                                                  ),
                                          ),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    } catch (err) {
                                      setModalState(() {
                                        isSubmitting = false;
                                        localError = err.toString();
                                      });
                                    }
                                  },
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    entry != null
                                        ? T.t('Update Entry')
                                        : T.t('Save Entry'),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmAndDeleteEntry({
    required BuildContext sheetContext,
    required int day,
    required String dateKey,
    required Map<String, dynamic> entry,
    required void Function(void Function()) setModalState,
  }) async {
    final entryId = '${entry['id'] ?? ''}'.trim();
    final liters = _asDouble(entry['liters'], 0.0);
    final total = _asDouble(entry['total'], 0.0);

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(sheetContext);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xffdc2626)),
            const SizedBox(width: 8),
            Text(T.t('Delete Entry?')),
          ],
        ),
        content: Text(
          '${T.t('Are you sure you want to delete milk entry for')} $day ${_monthNames[_selectedMonth - 1]}?\n\n'
          '${liters.toStringAsFixed(2)} L (₹${total.toStringAsFixed(2)}) ${T.t('will be deducted from monthly total.')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(T.t('Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xffdc2626),
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(T.t('Delete')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      if (entryId.isNotEmpty) {
        await widget.api.deleteMilkEntry(_customerId, entryId);
      } else {
        await widget.api.addMilkEntry(
          _customerId,
          date: DateTime(_selectedYear, _selectedMonth, day),
          liters: 0.0,
          price: 0.0,
        );
      }

      _entriesByDate.remove(dateKey);
      _hasMutatedData = true;

      if (mounted) {
        setState(() {});
      }
      navigator.pop();

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(T.t('Milk entry deleted successfully')),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xffb91c1c),
          content: Text('${T.t('Failed to delete entry')}: $e'),
        ),
      );
    }
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    required IconData icon,
    bool isBold = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xff2d7a55)),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: isBold ? const Color(0xff166534) : Colors.black,
          ),
        ),
      ],
    );
  }

  double _asDouble(dynamic value, [double fallback = 0.0]) {
    if (value is num) return value.toDouble();
    if (value == null) return fallback;
    return double.tryParse(value.toString().replaceAll(',', '.')) ?? fallback;
  }

  @override
  Widget build(BuildContext context) {
    final calculations = _computeCalculations();
    final now = DateTime.now();

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (_hasMutatedData) {
          developer.log('Milk card data changed', name: 'MonthlyMilkCard');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                T.t('Monthly Milk Card'),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                '$_customerName (#$_customerNumber)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: T.t('Tabular View'),
              icon: const Icon(
                LucideIcons.tableProperties,
                color: Color(0xff2d7a55),
              ),
              onPressed: () {
                Navigator.of(context)
                    .push(
                      MaterialPageRoute(
                        builder: (_) => MonthlyEntriesScreen(
                          api: widget.api,
                          customer: widget.customer,
                        ),
                      ),
                    )
                    .then((_) => _loadMonthEntries());
              },
            ),
            // Mode Toggle Button: View Mode <-> Edit Mode
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: _isEditMode
                    ? const Color(0xffb45309)
                    : const Color(0xff2d7a55),
                backgroundColor: _isEditMode
                    ? const Color(0xfffef3c7)
                    : const Color(0xffdcefe3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              onPressed: () {
                setState(() {
                  _isEditMode = !_isEditMode;
                });
              },
              icon: Icon(
                _isEditMode ? Icons.check_circle_outline : Icons.edit_note,
                size: 18,
              ),
              label: Text(
                _isEditMode ? T.t('Done') : T.t('Edit Card'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _loadMonthEntries,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            children: [
              // 1. Month / Year Selector Header
              _buildMonthNavigator(),

              const SizedBox(height: 10),

              // 2. Dynamic Total Pay & Monthly Summary Card
              _buildMonthlySummaryCard(calculations),

              const SizedBox(height: 10),

              // 3. Edit Mode Notice Banner
              if (_isEditMode)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xfffffbeb),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xfffde68a)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.pencil,
                        size: 16,
                        color: Color(0xffb45309),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          T.t(
                            'Edit Mode Active: Tap any calendar day below to add, edit, or delete delivery entries.',
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xff92400e),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xfff8fafc),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xffe2e8f0)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.lock,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          T.t(
                            'Read-Only View: Tapping a day shows details. Tap "Edit Card" above to make changes.',
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12),

              // 4. Loading or Error or Date Table
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_errorMessage != null)
                Card(
                  color: const Color(0xfffee2e2),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.cloud_off,
                          color: Color(0xffdc2626),
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xff991b1b)),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _loadMonthEntries,
                          child: Text(T.t('Retry')),
                        ),
                      ],
                    ),
                  ),
                )
              else
                _buildDateWiseMusterLedger(now),

              const SizedBox(height: 80),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openPaymentEntrySheet(calculations),
          icon: Icon(
            _hasPayment ? LucideIcons.circleCheck : LucideIcons.receipt,
            color: Colors.white,
          ),
          label: Text(
            _hasPayment
                ? '${T.t('Payment Entry')} (₹${_paymentReceived.toStringAsFixed(0)})'
                : T.t('Payment Entry'),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color(0xff2d7a55),
        ),
      ),
    );
  }

  Widget _buildMonthNavigator() {
    final isCurrent = _isCurrentMonth;

    return Container(
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xffe2e8f0)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            tooltip: T.t('Previous Month'),
            onPressed: _previousMonth,
          ),
          Expanded(
            child: InkWell(
              onTap: _pickMonthYear,
              borderRadius: BorderRadius.circular(6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    LucideIcons.calendar,
                    size: 14,
                    color: Color(0xff2d7a55),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_monthNames[_selectedMonth - 1]} $_selectedYear',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff1b4d36),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, color: Colors.grey, size: 16),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            tooltip: T.t('Next Month'),
            onPressed: _nextMonth,
          ),
          if (!isCurrent)
            TextButton(
              onPressed: _goToCurrentMonth,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
              ),
              child: Text(
                T.t('Today'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMonthlySummaryCard(_CardCalculations calc) {
    String calculationScopeText;
    Color scopeBadgeColor;
    Color scopeTextColor;

    if (_isCurrentMonth) {
      final now = DateTime.now();
      calculationScopeText =
          '${T.t('Dynamic Total to Date')} (Day 1 - ${now.day})';
      scopeBadgeColor = const Color(0xffdcfce7);
      scopeTextColor = const Color(0xff15803d);
    } else if (_isPastMonth) {
      calculationScopeText =
          '${T.t('Complete Month Total')} (Day 1 - $_daysInSelectedMonth)';
      scopeBadgeColor = const Color(0xffe0f2fe);
      scopeTextColor = const Color(0xff0369a1);
    } else {
      calculationScopeText = T.t('Upcoming Month (No deliveries yet)');
      scopeBadgeColor = Colors.grey.shade100;
      scopeTextColor = Colors.grey.shade600;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff1b4d36), Color(0xff2d7a55)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff2d7a55).withAlpha(46),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                T.t('TOTAL PAY'),
                style: const TextStyle(
                  color: Color(0xffbbf7d0),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scopeBadgeColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  calculationScopeText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: scopeTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text(
                '₹ ',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              Text(
                calc.totalPay.toStringAsFixed(2),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 1,
            color: Colors.white.withAlpha(38),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryStat(
                label: T.t('Total Milk'),
                value: '${calc.totalLiters.toStringAsFixed(2)} L',
              ),
              _buildSummaryStat(
                label: T.t('Recorded Days'),
                value: '${calc.recordedDays} / ${calc.applicableDays}',
              ),
              _buildSummaryStat(
                label: T.t('Customer Rate'),
                value: '₹${_defaultPrice.toStringAsFixed(2)}/L',
              ),
            ],
          ),
          if (_hasPayment) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _isFullyPaid(calc.totalPay)
                    ? const Color(0xffdcfce7)
                    : const Color(0xfffef3c7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isFullyPaid(calc.totalPay)
                      ? const Color(0xff86efac)
                      : const Color(0xfffcd34d),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isFullyPaid(calc.totalPay)
                            ? LucideIcons.circleCheck
                            : LucideIcons.circleAlert,
                        size: 16,
                        color: _isFullyPaid(calc.totalPay)
                            ? const Color(0xff166534)
                            : const Color(0xffb45309),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${T.t('Received')}: ₹${_paymentReceived.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _isFullyPaid(calc.totalPay)
                              ? const Color(0xff166534)
                              : const Color(0xff92400e),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _isFullyPaid(calc.totalPay)
                        ? T.t('Fully Paid')
                        : '${T.t('Balance Due')}: ₹${_balanceDue(calc.totalPay).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _isFullyPaid(calc.totalPay)
                          ? const Color(0xff166534)
                          : const Color(0xffb45309),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _openPaymentEntrySheet(calc),
            icon: Icon(
              _hasPayment ? LucideIcons.circleCheck : LucideIcons.receipt,
              size: 16,
            ),
            label: Text(
              _hasPayment
                  ? '${T.t('Payment Entry')} (₹${_paymentReceived.toStringAsFixed(0)} ${T.t('Received')})'
                  : T.t('Payment Entry'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _isFullyPaid(calc.totalPay)
                  ? const Color(0xff065f46)
                  : Colors.white,
              foregroundColor: _isFullyPaid(calc.totalPay)
                  ? Colors.white
                  : const Color(0xff1b4d36),
              minimumSize: const Size.fromHeight(40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPaymentEntrySheet(_CardCalculations calc) async {
    final messenger = ScaffoldMessenger.of(context);
    final monthName = _monthNames[_selectedMonth - 1];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PaymentEntrySheet(
        customerName: _customerName,
        customerNumber: _customerNumber,
        month: _selectedMonth,
        year: _selectedYear,
        monthName: '$monthName $_selectedYear',
        totalLiters: calc.totalLiters,
        effectiveRate: _defaultPrice,
        totalAmount: calc.totalPay,
        daysInMonth: _daysInSelectedMonth,
        activeDeliveryDays: calc.recordedDays,
        initialReceived: _hasPayment ? _paymentReceived : null,
        initialNote: '${_paymentData?['note'] ?? ''}',
        initialDate: _paymentData?['receivedDate'] != null
            ? DateTime.tryParse('${_paymentData!['receivedDate']}')
            : null,
        hasExistingPayment: _hasPayment,
        onSave: ({
          required double receivedAmount,
          String? note,
          DateTime? receivedDate,
        }) async {
          try {
            await widget.api.savePaymentEntry(
              customerId: _customerId,
              year: _selectedYear,
              month: _selectedMonth,
              billAmount: calc.totalPay,
              receivedAmount: receivedAmount,
              note: note,
              receivedDate: receivedDate,
            );
            await _loadPayment();
            messenger.clearSnackBars();
            messenger.showSnackBar(
              SnackBar(
                content: Text(T.t('Payment saved successfully')),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
              ),
            );
          } catch (e) {
            messenger.showSnackBar(
              SnackBar(content: Text(T.t('Could not save payment'))),
            );
          }
        },
        onDelete: () async {
          try {
            await widget.api.deletePaymentEntry(
              customerId: _customerId,
              year: _selectedYear,
              month: _selectedMonth,
            );
            await _loadPayment();
            messenger.clearSnackBars();
            messenger.showSnackBar(
              SnackBar(
                content: Text(T.t('Payment deleted')),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
              ),
            );
          } catch (e) {
            messenger.showSnackBar(
              SnackBar(content: Text(T.t('Could not delete payment'))),
            );
          }
        },
      ),
    );
  }

  Widget _buildSummaryStat({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xffa7f3d0),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildDateWiseMusterLedger(DateTime now) {
    final daysCount = _daysInSelectedMonth;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xfff1f5f9),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 54,
                  child: Text(
                    T.t('DATE'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    T.t('DELIVERY / QUANTITY'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                Text(
                  T.t('AMOUNT (₹)'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                if (_isEditMode) const SizedBox(width: 24),
              ],
            ),
          ),
          const Divider(height: 1),

          // Date Rows (1 to 28/29/30/31)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: daysCount,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, indent: 12, endIndent: 12),
            itemBuilder: (context, index) {
              final day = index + 1;
              final dateKey = '$_monthKey-${day.toString().padLeft(2, '0')}';
              final entry = _entriesByDate[dateKey];

              final dateObj = DateTime(_selectedYear, _selectedMonth, day);
              final weekdayIndex = dateObj.weekday - 1;
              final weekday = _weekdayNames[weekdayIndex];
              final isToday = _isCurrentMonth && (day == now.day);
              final isFutureDay = _isCurrentMonth && (day > now.day);

              return _buildCalendarRow(
                day: day,
                weekday: weekday,
                isToday: isToday,
                isFutureDay: isFutureDay,
                entry: entry,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarRow({
    required int day,
    required String weekday,
    required bool isToday,
    required bool isFutureDay,
    required Map<String, dynamic>? entry,
  }) {
    final hasEntry = entry != null;
    final liters = hasEntry ? _asDouble(entry['liters'], 0.0) : 0.0;
    final price = hasEntry ? _asDouble(entry['price'], 0.0) : 0.0;
    final total = hasEntry ? _asDouble(entry['total'], liters * price) : 0.0;
    final isZeroRecorded = hasEntry && liters == 0.0;

    Color rowBgColor = Colors.transparent;
    if (isToday) {
      rowBgColor = const Color(0xfff0fdf4);
    } else if (isFutureDay) {
      rowBgColor = const Color(0xfffafafa);
    }

    return InkWell(
      onTap: () => _onDateTileTapped(day, entry),
      child: Container(
        color: rowBgColor,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Date column with Day & Weekday
            SizedBox(
              width: 54,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        day.toString().padLeft(2, '0'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              isToday ? FontWeight.bold : FontWeight.w600,
                          color: isToday
                              ? const Color(0xff2d7a55)
                              : (isFutureDay
                                  ? Colors.grey.shade400
                                  : Colors.black87),
                        ),
                      ),
                      if (isToday) ...[
                        const SizedBox(width: 4),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xff2d7a55),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    weekday,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                      color: isToday
                          ? const Color(0xff2d7a55)
                          : (isFutureDay
                              ? Colors.grey.shade400
                              : Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ),

            // Middle Column: Milk info or status
            Expanded(
              child: hasEntry
                  ? (isZeroRecorded
                      ? Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border:
                                    Border.all(color: Colors.orange.shade200),
                              ),
                              child: Text(
                                T.t('0 L (Off-day)'),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Text(
                              '${liters.toStringAsFixed(2)} L',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xff0f172a),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '@ ₹${price.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ))
                  : (isFutureDay
                      ? Text(
                          '— ${T.t('Upcoming')}',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey.shade400,
                          ),
                        )
                      : Text(
                          '— ${T.t('No entry')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        )),
            ),

            // Right Column: Amount
            if (hasEntry)
              Text(
                '₹${total.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isZeroRecorded
                      ? Colors.grey.shade500
                      : const Color(0xff166534),
                ),
              )
            else
              Text(
                '—',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade400,
                ),
              ),

            // Edit Indicator
            if (_isEditMode) ...[
              const SizedBox(width: 8),
              Icon(
                hasEntry ? Icons.edit_outlined : Icons.add_circle_outline,
                size: 18,
                color: hasEntry
                    ? const Color(0xff0284c7)
                    : const Color(0xff2d7a55),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CardCalculations {
  const _CardCalculations({
    required this.totalPay,
    required this.totalLiters,
    required this.recordedDays,
    required this.applicableDays,
    required this.hasEntries,
  });

  final double totalPay;
  final double totalLiters;
  final int recordedDays;
  final int applicableDays;
  final bool hasEntries;
}
