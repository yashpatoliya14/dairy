import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/app_language.dart';

class PaymentEntrySheet extends StatefulWidget {
  const PaymentEntrySheet({
    super.key,
    required this.customerName,
    required this.customerNumber,
    required this.month,
    required this.year,
    required this.monthName,
    required this.totalLiters,
    required this.effectiveRate,
    required this.totalAmount,
    this.previousDue = 0.0,
    this.previousAdvance = 0.0,
    this.pastMonthsBreakdown = const [],
    required this.daysInMonth,
    required this.activeDeliveryDays,
    required this.initialReceived,
    required this.initialNote,
    required this.initialDate,
    required this.hasExistingPayment,
    required this.onSave,
    this.onDelete,
  });

  final String customerName;
  final String customerNumber;
  final int month;
  final int year;
  final String monthName;
  final double totalLiters;
  final double effectiveRate;
  final double totalAmount;
  final double previousDue;
  final double previousAdvance;
  final List<String> pastMonthsBreakdown;
  final int daysInMonth;
  final int activeDeliveryDays;
  final double? initialReceived;
  final String initialNote;
  final DateTime? initialDate;
  final bool hasExistingPayment;
  final Future<void> Function({
    required double receivedAmount,
    String? note,
    DateTime? receivedDate,
  }) onSave;
  final Future<void> Function()? onDelete;

  @override
  State<PaymentEntrySheet> createState() => _PaymentEntrySheetState();
}

class _PaymentEntrySheetState extends State<PaymentEntrySheet> {
  late final TextEditingController _receivedController;
  late final TextEditingController _noteController;
  late DateTime _selectedDate;
  String _selectedMode = '';
  bool _saving = false;

  final _formKey = GlobalKey<FormState>();

  double get _totalPayable {
    final net = widget.totalAmount + widget.previousDue - widget.previousAdvance;
    return net > 0 ? net : 0.0;
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initialReceived ?? _totalPayable;
    _receivedController = TextEditingController(
      text: initial > 0
          ? (initial == initial.truncateToDouble()
              ? initial.toStringAsFixed(0)
              : initial.toStringAsFixed(2))
          : '',
    );
    _noteController = TextEditingController(text: widget.initialNote);
    _selectedDate = widget.initialDate ?? DateTime.now();

    final lower = widget.initialNote.toLowerCase();
    if (lower.contains('cash')) {
      _selectedMode = 'Cash';
    } else if (lower.contains('upi')) {
      _selectedMode = 'UPI';
    } else if (lower.contains('bank')) {
      _selectedMode = 'Bank Transfer';
    } else if (lower.contains('cheque')) {
      _selectedMode = 'Cheque';
    }
  }

  @override
  void dispose() {
    _receivedController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double get _currentReceived =>
      double.tryParse(_receivedController.text.trim()) ?? 0.0;

  void _fillTotalAmount() {
    setState(() {
      _receivedController.text =
          _totalPayable == _totalPayable.truncateToDouble()
              ? _totalPayable.toStringAsFixed(0)
              : _totalPayable.toStringAsFixed(2);
    });
  }

  void _fillThisMonthOnly() {
    setState(() {
      _receivedController.text =
          widget.totalAmount == widget.totalAmount.truncateToDouble()
              ? widget.totalAmount.toStringAsFixed(0)
              : widget.totalAmount.toStringAsFixed(2);
    });
  }

  void _fillHalfAmount() {
    final half = _totalPayable / 2;
    setState(() {
      _receivedController.text = half == half.truncateToDouble()
          ? half.toStringAsFixed(0)
          : half.toStringAsFixed(2);
    });
  }

  void _selectMode(String mode) {
    setState(() {
      if (_selectedMode == mode) {
        _selectedMode = '';
      } else {
        _selectedMode = mode;
        if (_noteController.text.trim().isEmpty) {
          _noteController.text = mode;
        }
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(widget.year - 1),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final received = double.parse(_receivedController.text.trim());
    final note = _noteController.text.trim();
    final finalNote = note.isNotEmpty
        ? note
        : (_selectedMode.isNotEmpty ? _selectedMode : '');
    await widget.onSave(
      receivedAmount: received,
      note: finalNote,
      receivedDate: _selectedDate,
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final received = _currentReceived;
    final target = _totalPayable;
    final balance = target - received;
    final isFullyPaid = received >= target && target > 0;
    final isPartiallyPaid = received > 0 && received < target;
    final isOverPaid = received > target;
    final hasCombinedDebt = widget.previousDue > 0 || widget.previousAdvance > 0;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header with Title & Customer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  T.t('Payment Entry'),
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xff111827),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${widget.customerName} (#${widget.customerNumber})  •  ${widget.monthName}',
                              style: TextStyle(
                                fontSize: 13,
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(LucideIcons.x, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ─── MONTHLY BILL & COMBINED BALANCE SUMMARY CARD ──────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xfff0fdf4), Color(0xffdcfce7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xff86efac),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  LucideIcons.receipt,
                                  size: 15,
                                  color: Color(0xff166534),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  hasCombinedDebt ? T.t('Customer Bills') : T.t('Monthly Bill'),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xff166534),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xff86efac),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                '${widget.activeDeliveryDays}/${widget.daysInMonth} ${T.t('Days')}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xff166534),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Deliveries row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              hasCombinedDebt
                                  ? '${T.t('This Month Bill')} (${widget.totalLiters.toStringAsFixed(1)} L @ ₹${widget.effectiveRate.toStringAsFixed(2)})'
                                  : '${widget.totalLiters.toStringAsFixed(1)} L  @  ₹${widget.effectiveRate.toStringAsFixed(2)}/L',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            Text(
                              '₹${widget.totalAmount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: hasCombinedDebt ? 14 : 22,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xff14532d),
                              ),
                            ),
                          ],
                        ),

                        // If previousDue > 0
                        if (widget.previousDue > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(LucideIcons.history, size: 12, color: Color(0xffdc2626)),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        widget.pastMonthsBreakdown.isNotEmpty
                                            ? '${T.t('Past Due')} (${widget.pastMonthsBreakdown.join(', ')})'
                                            : T.t('Past Due'),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xffb91c1c),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '+₹${widget.previousDue.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xffdc2626),
                                ),
                              ),
                            ],
                          ),
                        ],

                        // If previousAdvance > 0
                        if (widget.previousAdvance > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  const Icon(LucideIcons.sparkles, size: 12, color: Color(0xff16a34a)),
                                  const SizedBox(width: 4),
                                  Text(
                                    T.t('Advance Credit'),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xff166534),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '-₹${widget.previousAdvance.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xff16a34a),
                                ),
                              ),
                            ],
                          ),
                        ],

                        // Net Total Row (if multi-month)
                        if (hasCombinedDebt) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Divider(height: 1, color: Color(0xff86efac)),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                T.t('Net Total Due'),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xff14532d),
                                ),
                              ),
                              Text(
                                '₹${_totalPayable.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xff14532d),
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Previously Recorded Payment Badge (if any)
                  if (widget.hasExistingPayment && widget.initialReceived != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xffeff6ff),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xffbfdbfe), width: 0.8),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.history, size: 13, color: Color(0xff2563eb)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${T.t('Previously Recorded')}: ₹${widget.initialReceived!.toStringAsFixed(2)}${widget.initialDate != null ? ' (${widget.initialDate!.day}/${widget.initialDate!.month}/${widget.initialDate!.year})' : ''}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xff1e40af),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // ─── AMOUNT RECEIVED INPUT ─────────────────────────────────
                  Text(
                    T.t('Amount Received'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xff374151),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _receivedController,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xff111827),
                    ),
                    decoration: InputDecoration(
                      prefixIcon: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Text(
                          '₹',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff166534),
                          ),
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                      hintText: '0.00',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xffd1d5db)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xff166534), width: 2),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return T.t('Please enter received amount');
                      }
                      final parsed = double.tryParse(v.trim());
                      if (parsed == null || parsed < 0) {
                        return T.t('Enter a valid positive number');
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 8),

                  // ─── QUICK PRESET BUTTONS ──────────────────────────────────
                  Row(
                    children: [
                      ActionChip(
                        avatar: const Icon(LucideIcons.checkCheck, size: 14),
                        label: Text(
                          '${hasCombinedDebt ? T.t('Total Due') : T.t('Full Amount')} (₹${_totalPayable.toStringAsFixed(0)})',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        onPressed: _fillTotalAmount,
                        backgroundColor: const Color(0xfff0fdf4),
                        side: const BorderSide(color: Color(0xff86efac)),
                      ),
                      if (hasCombinedDebt && widget.totalAmount > 0) ...[
                        const SizedBox(width: 6),
                        ActionChip(
                          avatar: const Icon(LucideIcons.calendar, size: 14),
                          label: Text(
                            '${T.t('This Month')} (₹${widget.totalAmount.toStringAsFixed(0)})',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          onPressed: _fillThisMonthOnly,
                          backgroundColor: const Color(0xfff8fafc),
                          side: const BorderSide(color: Color(0xffe2e8f0)),
                        ),
                      ],
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar: const Icon(LucideIcons.percent, size: 14),
                        label: Text(
                          '50% (₹${(_totalPayable / 2).toStringAsFixed(0)})',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        onPressed: _fillHalfAmount,
                        backgroundColor: const Color(0xfff8fafc),
                        side: const BorderSide(color: Color(0xffe2e8f0)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ─── LIVE BALANCE INDICATOR BANNER ────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: isFullyPaid
                          ? const Color(0xfff0fdf4)
                          : isPartiallyPaid
                              ? const Color(0xfffffbeb)
                              : isOverPaid
                                  ? const Color(0xffeff6ff)
                                  : const Color(0xfff8fafc),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isFullyPaid
                            ? const Color(0xff86efac)
                            : isPartiallyPaid
                                ? const Color(0xfffde047)
                                : isOverPaid
                                    ? const Color(0xff93c5fd)
                                    : const Color(0xffe2e8f0),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isFullyPaid
                                  ? LucideIcons.circleCheck
                                  : isPartiallyPaid
                                      ? LucideIcons.circleAlert
                                      : isOverPaid
                                          ? LucideIcons.info
                                          : LucideIcons.circleDot,
                              size: 16,
                              color: isFullyPaid
                                  ? const Color(0xff16a34a)
                                  : isPartiallyPaid
                                      ? const Color(0xffd97706)
                                      : isOverPaid
                                          ? const Color(0xff2563eb)
                                          : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isFullyPaid
                                  ? T.t('Fully Paid')
                                  : isOverPaid
                                      ? T.t('Advance / Overpaid')
                                      : isPartiallyPaid
                                          ? T.t('Partially Paid')
                                          : T.t('Unpaid'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isFullyPaid
                                    ? const Color(0xff166534)
                                    : isPartiallyPaid
                                        ? const Color(0xff92400e)
                                        : isOverPaid
                                            ? const Color(0xff1e40af)
                                            : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          balance <= 0
                              ? (balance < 0
                                  ? "+₹${(-balance).toStringAsFixed(2)} ${T.t('Advance')}"
                                  : "₹0.00 ${T.t('Due')}")
                              : '${T.t('Balance Due')}: ₹${balance.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: balance <= 0
                                ? const Color(0xff166534)
                                : const Color(0xffdc2626),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ─── PAYMENT MODE SELECTION ────────────────────────────────
                  Text(
                    T.t('Payment Mode'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xff374151),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final mode in ['Cash', 'UPI', 'Bank Transfer', 'Cheque'])
                        ChoiceChip(
                          label: Text(T.t(mode)),
                          selected: _selectedMode == mode,
                          onSelected: (_) => _selectMode(mode),
                          selectedColor: const Color(0xffdcfce7),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: _selectedMode == mode
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: _selectedMode == mode
                                ? const Color(0xff166534)
                                : const Color(0xff374151),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ─── PAYMENT DATE & NOTE ───────────────────────────────────
                  Text(
                    T.t('Payment Date & Note'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xff374151),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(LucideIcons.calendar, size: 15),
                          label: Text(
                            '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _noteController,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: T.t('e.g. Cash, UPI, Bank Transfer'),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ─── SAVE / DELETE BUTTONS ─────────────────────────────────
                  Row(
                    children: [
                      if (widget.hasExistingPayment && widget.onDelete != null) ...[
                        OutlinedButton(
                          onPressed: _saving
                              ? null
                              : () async {
                                  Navigator.of(context).pop();
                                  await widget.onDelete!();
                                },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            side: BorderSide(color: Colors.red.shade300),
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Icon(Icons.delete_outline, size: 20),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _handleSave,
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(LucideIcons.check, size: 18),
                          label: Text(
                            widget.hasExistingPayment
                                ? T.t('Update Payment')
                                : T.t('Save Payment'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xff166534),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

