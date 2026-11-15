import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/app_language.dart';

enum PaymentEntryMode {
  addNew,
  replace,
}

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
  late PaymentEntryMode _entryMode;
  late final TextEditingController _receivedController;
  late final TextEditingController _noteController;
  late DateTime _selectedDate;
  String _selectedMode = '';
  bool _saving = false;

  final _formKey = GlobalKey<FormState>();

  /// Gross bill + past overdue - advance credit
  double get _grossPayable {
    final net = widget.totalAmount + widget.previousDue - widget.previousAdvance;
    return net > 0 ? net : 0.0;
  }

  /// Old recorded payment for this month (if any)
  double get _oldPayment =>
      (widget.hasExistingPayment && widget.initialReceived != null)
          ? widget.initialReceived!
          : 0.0;

  /// Net Total Due DEDUCTED by old payment!
  double get _netTotalDue {
    final rem = _grossPayable - _oldPayment;
    return rem > 0 ? rem : 0.0;
  }

  @override
  void initState() {
    super.initState();
    _entryMode =
        _oldPayment > 0 ? PaymentEntryMode.addNew : PaymentEntryMode.replace;

    final defaultAmount =
        (_oldPayment > 0 && _entryMode == PaymentEntryMode.addNew)
            ? _netTotalDue
            : _grossPayable;

    _receivedController = TextEditingController(
      text: defaultAmount > 0
          ? (defaultAmount == defaultAmount.truncateToDouble()
              ? defaultAmount.toStringAsFixed(0)
              : defaultAmount.toStringAsFixed(2))
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

  double get _currentEntered =>
      double.tryParse(_receivedController.text.replaceAll(',', '').trim()) ??
      0.0;

  /// Effective total paid that will be stored on the backend
  double get _effectiveTotalPaid {
    if (_oldPayment > 0 && _entryMode == PaymentEntryMode.addNew) {
      return double.parse((_oldPayment + _currentEntered).toStringAsFixed(2));
    }
    return double.parse(_currentEntered.toStringAsFixed(2));
  }

  double get _effectiveRemainingDue {
    final rem = _grossPayable - _effectiveTotalPaid;
    return rem > 0 ? rem : 0.0;
  }

  double get _effectiveAdvance {
    final diff = _effectiveTotalPaid - _grossPayable;
    return diff > 0 ? diff : 0.0;
  }

  void _fillRemainingDue() {
    setState(() {
      _receivedController.text =
          _netTotalDue == _netTotalDue.truncateToDouble()
              ? _netTotalDue.toStringAsFixed(0)
              : _netTotalDue.toStringAsFixed(2);
    });
  }

  void _fillGrossTotal() {
    setState(() {
      _receivedController.text =
          _grossPayable == _grossPayable.truncateToDouble()
              ? _grossPayable.toStringAsFixed(0)
              : _grossPayable.toStringAsFixed(2);
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

  void _fillHalfDue() {
    final target = (_oldPayment > 0 && _entryMode == PaymentEntryMode.addNew)
        ? _netTotalDue
        : _grossPayable;
    final half = target / 2;
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
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final totalToSave = _effectiveTotalPaid;
    final note = _noteController.text.trim();
    final finalNote = note.isNotEmpty
        ? note
        : (_selectedMode.isNotEmpty ? _selectedMode : '');
    try {
      await widget.onSave(
        receivedAmount: totalToSave,
        note: finalNote,
        receivedDate: _selectedDate,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _buildBillRow({
    required String label,
    required String value,
    required Color color,
    IconData? icon,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
                    color: isBold ? color : const Color(0xff4b5563),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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

                  // ─── UNIFIED NEAT & CLEAN SUMMARY CARD ──────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xfff8fafc),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xffe2e8f0),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Card Top Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xffecfdf5),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    LucideIcons.receipt,
                                    size: 14,
                                    color: Color(0xff059669),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${widget.monthName} ${T.t('Bill Summary')}',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xff1e293b),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xffcbd5e1),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                '${widget.activeDeliveryDays}/${widget.daysInMonth} ${T.t('Days')} • ${widget.totalLiters.toStringAsFixed(1)}L',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xff475569),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Line 1: Milk Bill
                        _buildBillRow(
                          label: T.t('This Month Bill'),
                          value: '₹${widget.totalAmount.toStringAsFixed(2)}',
                          color: const Color(0xff1e293b),
                        ),

                        // Line 2: Past Due (if > 0)
                        if (widget.previousDue > 0) ...[
                          const SizedBox(height: 5),
                          _buildBillRow(
                            label: widget.pastMonthsBreakdown.isNotEmpty
                                ? '${T.t('Past Due')} (${widget.pastMonthsBreakdown.join(', ')})'
                                : T.t('Past Due'),
                            value: '+₹${widget.previousDue.toStringAsFixed(2)}',
                            color: const Color(0xffdc2626),
                            icon: LucideIcons.history,
                          ),
                        ],

                        // Line 3: Advance Credit (if > 0)
                        if (widget.previousAdvance > 0) ...[
                          const SizedBox(height: 5),
                          _buildBillRow(
                            label: T.t('Advance Credit'),
                            value: '-₹${widget.previousAdvance.toStringAsFixed(2)}',
                            color: const Color(0xff16a34a),
                            icon: LucideIcons.sparkles,
                          ),
                        ],

                        // Line 4: Already Paid (Old Payment) (if > 0)
                        if (_oldPayment > 0) ...[
                          const SizedBox(height: 5),
                          _buildBillRow(
                            label:
                                '${T.t('Already Paid')}${widget.initialDate != null ? ' (${widget.initialDate!.day}/${widget.initialDate!.month})' : ''}',
                            value: '-₹${_oldPayment.toStringAsFixed(2)}',
                            color: const Color(0xff2563eb),
                            icon: LucideIcons.checkCheck,
                            isBold: true,
                          ),
                        ],

                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(height: 1, color: Color(0xffe2e8f0)),
                        ),

                        // Line 5: NET TOTAL DUE (DEDUCTED BY OLD PAYMENT!)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _netTotalDue <= 0
                                      ? T.t('Amount Paid')
                                      : T.t('Net Total Due'),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xff0f172a),
                                  ),
                                ),
                                if (_netTotalDue <= 0)
                                  Text(
                                    '${T.t('Fully Paid')} • ${T.t('Remaining Due')}: ₹0.00',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      color: Color(0xff16a34a),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  )
                                else if (_oldPayment > 0)
                                  Text(
                                    T.t('Remaining balance to clear'),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                            Text(
                              _netTotalDue <= 0
                                  ? '₹${(_oldPayment > 0 ? _oldPayment : _grossPayable).toStringAsFixed(2)}'
                                  : '₹${_netTotalDue.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: _netTotalDue <= 0
                                    ? const Color(0xff16a34a)
                                    : const Color(0xff047857),
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ─── OPTIONAL PAYMENT MODE TOGGLE (When Old Payment Exists) ───
                  if (_oldPayment > 0) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xfff1f5f9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _entryMode = PaymentEntryMode.addNew;
                                  _fillRemainingDue();
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 7),
                                decoration: BoxDecoration(
                                  color: _entryMode == PaymentEntryMode.addNew
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: _entryMode == PaymentEntryMode.addNew
                                      ? const [
                                          BoxShadow(
                                            color: Color(0x0f000000),
                                            blurRadius: 4,
                                            offset: Offset(0, 1),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      LucideIcons.plus,
                                      size: 13,
                                      color: _entryMode == PaymentEntryMode.addNew
                                          ? const Color(0xff059669)
                                          : Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      T.t('Add Payment'),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight:
                                            _entryMode == PaymentEntryMode.addNew
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                        color:
                                            _entryMode == PaymentEntryMode.addNew
                                                ? const Color(0xff059669)
                                                : Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _entryMode = PaymentEntryMode.replace;
                                  _receivedController.text =
                                      _oldPayment == _oldPayment.truncateToDouble()
                                          ? _oldPayment.toStringAsFixed(0)
                                          : _oldPayment.toStringAsFixed(2);
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 7),
                                decoration: BoxDecoration(
                                  color: _entryMode == PaymentEntryMode.replace
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: _entryMode == PaymentEntryMode.replace
                                      ? const [
                                          BoxShadow(
                                            color: Color(0x0f000000),
                                            blurRadius: 4,
                                            offset: Offset(0, 1),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      LucideIcons.pencil,
                                      size: 13,
                                      color: _entryMode == PaymentEntryMode.replace
                                          ? const Color(0xff2563eb)
                                          : Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      T.t('Edit Payment'),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight:
                                            _entryMode == PaymentEntryMode.replace
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                        color:
                                            _entryMode == PaymentEntryMode.replace
                                                ? const Color(0xff2563eb)
                                                : Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // ─── AMOUNT RECEIVED INPUT ─────────────────────────────────
                  Text(
                    (_oldPayment > 0 && _entryMode == PaymentEntryMode.addNew)
                        ? T.t('Amount Received Today')
                        : T.t('Amount Received'),
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
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xff111827),
                    ),
                    decoration: InputDecoration(
                      prefixIcon: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Text(
                          '₹',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff166534),
                          ),
                        ),
                      ),
                      prefixIconConstraints:
                          const BoxConstraints(minWidth: 0, minHeight: 0),
                      hintText: '0.00',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xffd1d5db)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xff166534), width: 2),
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
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (_oldPayment > 0 && _entryMode == PaymentEntryMode.addNew) ...[
                        if (_netTotalDue > 0)
                          ActionChip(
                            avatar: const Icon(LucideIcons.checkCheck,
                                size: 14, color: Color(0xff16a34a)),
                            label: Text(
                              '${T.t('Pay Remaining')} (₹${_netTotalDue.toStringAsFixed(0)})',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xff166534)),
                            ),
                            onPressed: _fillRemainingDue,
                            backgroundColor: const Color(0xfff0fdf4),
                            side: const BorderSide(color: Color(0xff86efac)),
                          ),
                        ActionChip(
                          avatar: const Icon(LucideIcons.percent, size: 14),
                          label: Text(
                            '50% (₹${(_netTotalDue / 2).toStringAsFixed(0)})',
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          onPressed: _fillHalfDue,
                          backgroundColor: const Color(0xfff8fafc),
                          side: const BorderSide(color: Color(0xffe2e8f0)),
                        ),
                      ] else ...[
                        ActionChip(
                          avatar: const Icon(LucideIcons.checkCheck, size: 14),
                          label: Text(
                            '${T.t('Full Amount')} (₹${_grossPayable.toStringAsFixed(0)})',
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          onPressed: _fillGrossTotal,
                          backgroundColor: const Color(0xfff0fdf4),
                          side: const BorderSide(color: Color(0xff86efac)),
                        ),
                        if (widget.previousDue > 0 && widget.totalAmount > 0)
                          ActionChip(
                            avatar: const Icon(LucideIcons.calendar, size: 14),
                            label: Text(
                              '${T.t('This Month')} (₹${widget.totalAmount.toStringAsFixed(0)})',
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            onPressed: _fillThisMonthOnly,
                            backgroundColor: const Color(0xfff8fafc),
                            side: const BorderSide(color: Color(0xffe2e8f0)),
                          ),
                        ActionChip(
                          avatar: const Icon(LucideIcons.percent, size: 14),
                          label: Text(
                            '50% (₹${(_grossPayable / 2).toStringAsFixed(0)})',
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          onPressed: _fillHalfDue,
                          backgroundColor: const Color(0xfff8fafc),
                          side: const BorderSide(color: Color(0xffe2e8f0)),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ─── LIVE BALANCE INDICATOR BANNER ────────────────────────
                  Builder(
                    builder: (context) {
                      final rem = _effectiveRemainingDue;
                      final adv = _effectiveAdvance;
                      final isSettled = rem <= 0 && adv <= 0 && _effectiveTotalPaid > 0;
                      final isOver = adv > 0;
                      final isPartial = rem > 0 && _effectiveTotalPaid > 0;

                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSettled
                              ? const Color(0xfff0fdf4)
                              : isPartial
                                  ? const Color(0xfffffbeb)
                                  : isOver
                                      ? const Color(0xffeff6ff)
                                      : const Color(0xfff8fafc),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSettled
                                ? const Color(0xff86efac)
                                : isPartial
                                    ? const Color(0xfffde047)
                                    : isOver
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
                                  isSettled
                                      ? LucideIcons.circleCheck
                                      : isPartial
                                          ? LucideIcons.circleAlert
                                          : isOver
                                              ? LucideIcons.info
                                              : LucideIcons.circleDot,
                                  size: 15,
                                  color: isSettled
                                      ? const Color(0xff16a34a)
                                      : isPartial
                                          ? const Color(0xffd97706)
                                          : isOver
                                              ? const Color(0xff2563eb)
                                              : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isSettled
                                      ? T.t('Fully Paid')
                                      : isOver
                                          ? T.t('Advance / Overpaid')
                                          : isPartial
                                              ? T.t('Partially Paid')
                                              : T.t('Unpaid'),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: isSettled
                                        ? const Color(0xff166534)
                                        : isPartial
                                            ? const Color(0xff92400e)
                                            : isOver
                                                ? const Color(0xff1e40af)
                                                : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              isSettled
                                  ? '₹0.00 ${T.t('Due')}'
                                  : isOver
                                      ? '+₹${adv.toStringAsFixed(2)} ${T.t('Advance')}'
                                      : '${T.t('Due')}: ₹${rem.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: isSettled
                                    ? const Color(0xff166534)
                                    : isOver
                                        ? const Color(0xff1e40af)
                                        : const Color(0xffdc2626),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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
                      for (final mode in [
                        'Cash',
                        'UPI',
                        'Bank Transfer',
                        'Cheque'
                      ])
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
                      if (widget.hasExistingPayment &&
                          widget.onDelete != null) ...[
                        OutlinedButton.icon(
                          onPressed: _saving
                              ? null
                              : () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (dCtx) => AlertDialog(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      titlePadding: const EdgeInsets.fromLTRB(
                                          20, 16, 12, 0),
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              T.t('Delete Payment?'),
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.close,
                                                size: 20),
                                            tooltip: T.t('Close'),
                                            visualDensity:
                                                VisualDensity.compact,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () =>
                                                Navigator.of(dCtx).pop(false),
                                          ),
                                        ],
                                      ),
                                      content: Text(
                                        T.t(
                                            'This will remove the recorded payment and reset the customer dues to unpaid.'),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(dCtx).pop(false),
                                          child: Text(T.t('Cancel')),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.of(dCtx).pop(true),
                                          style: FilledButton.styleFrom(
                                            backgroundColor:
                                                Colors.red.shade700,
                                          ),
                                          child: Text(T.t('Delete')),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    if (context.mounted) {
                                      Navigator.of(context).pop();
                                    }
                                    await widget.onDelete!();
                                  }
                                },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            side: BorderSide(color: Colors.red.shade300),
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: Text(
                            T.t('Delete'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
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
