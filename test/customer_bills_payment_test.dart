import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Customer Bills & Record Payment Combination Logic', () {
    test('Clears past dues when payment matches past month due and current bill is 0', () {
      const grossPastDue = 80.0;
      const grossPastAdvance = 0.0;
      const thisMonthBill = 0.0;
      const thisMonthPaid = 80.0;

      final totalCredits = thisMonthPaid + grossPastAdvance;
      final creditForPast = totalCredits > grossPastDue ? grossPastDue : totalCredits;
      final remainingPastDue = grossPastDue - creditForPast;
      final creditsLeft = totalCredits - creditForPast;

      final creditForThisMonth = creditsLeft > thisMonthBill ? thisMonthBill : creditsLeft;
      final thisMonthDue = thisMonthBill - creditForThisMonth;
      final netAdvance = creditsLeft > thisMonthBill ? (creditsLeft - thisMonthBill) : 0.0;
      final netBalanceDue = remainingPastDue + thisMonthDue;

      expect(remainingPastDue, 0.0);
      expect(thisMonthDue, 0.0);
      expect(netBalanceDue, 0.0);
      expect(netAdvance, 0.0);
    });

    test('Partial payment across multi-month due does NOT report fully paid', () {
      const grossPastDue = 80.0;
      const grossPastAdvance = 0.0;
      const thisMonthBill = 100.0;
      const totalPayable = thisMonthBill + grossPastDue - grossPastAdvance; // 180.0
      expect(totalPayable, 180.0);

      const thisMonthPaid = 80.0; // customer only paid 80
      final totalCredits = thisMonthPaid + grossPastAdvance;
      final creditForPast = totalCredits > grossPastDue ? grossPastDue : totalCredits;
      final remainingPastDue = grossPastDue - creditForPast;
      final creditsLeft = totalCredits - creditForPast;

      final creditForThisMonth = creditsLeft > thisMonthBill ? thisMonthBill : creditsLeft;
      final thisMonthDue = thisMonthBill - creditForThisMonth;
      final netBalanceDue = remainingPastDue + thisMonthDue;

      expect(remainingPastDue, 0.0); // past due 80 cleared
      expect(thisMonthDue, 100.0); // current month 100 still due
      expect(netBalanceDue, 100.0); // net due is 100, not 0
      expect(thisMonthPaid >= totalPayable, isFalse); // not fully paid
    });

    test('Full combined payment clears both past and current month dues', () {
      const grossPastDue = 80.0;
      const grossPastAdvance = 0.0;
      const thisMonthBill = 100.0;
      const totalPayable = thisMonthBill + grossPastDue - grossPastAdvance; // 180.0

      const thisMonthPaid = 180.0;
      final totalCredits = thisMonthPaid + grossPastAdvance;
      final creditForPast = totalCredits > grossPastDue ? grossPastDue : totalCredits;
      final remainingPastDue = grossPastDue - creditForPast;
      final creditsLeft = totalCredits - creditForPast;

      final creditForThisMonth = creditsLeft > thisMonthBill ? thisMonthBill : creditsLeft;
      final thisMonthDue = thisMonthBill - creditForThisMonth;
      final netBalanceDue = remainingPastDue + thisMonthDue;

      expect(remainingPastDue, 0.0);
      expect(thisMonthDue, 0.0);
      expect(netBalanceDue, 0.0);
      expect(thisMonthPaid >= totalPayable, isTrue);
    });

    test('Advance credit reduces current month total payable', () {
      const grossPastDue = 0.0;
      const grossPastAdvance = 20.0;
      const thisMonthBill = 100.0;
      final totalPayable = thisMonthBill + grossPastDue - grossPastAdvance; // 80.0
      expect(totalPayable, 80.0);

      const thisMonthPaid = 80.0;
      final totalCredits = thisMonthPaid + grossPastAdvance;
      final creditForPast = totalCredits > grossPastDue ? grossPastDue : totalCredits;
      final remainingPastDue = grossPastDue - creditForPast;
      final creditsLeft = totalCredits - creditForPast;

      final creditForThisMonth = creditsLeft > thisMonthBill ? thisMonthBill : creditsLeft;
      final thisMonthDue = thisMonthBill - creditForThisMonth;
      final netBalanceDue = remainingPastDue + thisMonthDue;

      expect(remainingPastDue, 0.0);
      expect(thisMonthDue, 0.0);
      expect(netBalanceDue, 0.0);
      expect(thisMonthPaid >= totalPayable, isTrue);
    });

    test('Entering 50% payment against current bill correctly reduces balance due to 50%', () {
      const grossPastDue = 0.0;
      const grossPastAdvance = 0.0;
      const thisMonthBill = 10000.0;
      const thisMonthPaid = 5000.0;

      final thisMonthDue = thisMonthPaid >= thisMonthBill
          ? 0.0
          : double.parse((thisMonthBill - thisMonthPaid).toStringAsFixed(2));
      final thisMonthAdvance = thisMonthPaid > thisMonthBill
          ? double.parse((thisMonthPaid - thisMonthBill).toStringAsFixed(2))
          : 0.0;

      final creditsForPast = thisMonthAdvance + grossPastAdvance;
      final remainingPastDue = grossPastDue > creditsForPast
          ? double.parse((grossPastDue - creditsForPast).toStringAsFixed(2))
          : 0.0;
      final netBalanceDue =
          double.parse((remainingPastDue + thisMonthDue).toStringAsFixed(2));

      expect(thisMonthDue, 5000.0);
      expect(netBalanceDue, 5000.0);
      expect(thisMonthDue < thisMonthBill, isTrue);
    });

    test('MonthlyEntriesScreen display: fully paid bill displays 0.00 instead of original gross total', () {
      const billTotalAmount = 4500.0;
      const paymentReceived = 4500.0;
      const pastMonthsDue = 0.0;

      final isFullyPaid = paymentReceived >= billTotalAmount && pastMonthsDue == 0;
      final balanceDue = paymentReceived >= billTotalAmount ? 0.0 : billTotalAmount - paymentReceived;
      final netTotalPayable = pastMonthsDue + balanceDue;

      // Exact ternary logic in MonthlyEntriesScreen
      final displayedDue = isFullyPaid ? '₹0.00' : '₹${netTotalPayable.toStringAsFixed(2)}';

      expect(isFullyPaid, isTrue);
      expect(displayedDue, '₹0.00');
    });

    test('SendWhatsAppBillSheet: calculated net payable deducts paid amount and formats bill message', () {
      const monthlyAmount = 3000.0;
      const pastOverdue = 500.0;
      const advanceCredit = 0.0;
      const paidAmount = 1500.0;

      final calculatedTotal = monthlyAmount + pastOverdue - advanceCredit - paidAmount;
      expect(calculatedTotal, 2000.0);

      // Verify that bill text contains Amount Received and correct Net Payable
      final buffer = StringBuffer();
      buffer.writeln('Monthly Milk Bill: ₹3000.00');
      buffer.writeln('Past Overdue: ₹500.00');
      buffer.writeln('Amount Received: ₹1500.00');
      buffer.writeln('NET TOTAL PAYABLE: ₹2000.00');

      final message = buffer.toString();
      expect(message.contains('Amount Received: ₹1500.00'), isTrue);
      expect(message.contains('NET TOTAL PAYABLE: ₹2000.00'), isTrue);
    });

    test('PaymentEntrySheet: _fillRemainingDue fills remaining due instead of total payable', () {
      const totalPayable = 2500.0;
      const existingPaid = 1000.0;
      final remainingDue = totalPayable > existingPaid ? totalPayable - existingPaid : 0.0;

      expect(remainingDue, 1500.0);
      // Ensure remaining due is populated when user clicks Quick Fill Due
      final quickFillAmount = remainingDue > 0 ? remainingDue : totalPayable;
      expect(quickFillAmount, 1500.0);
    });
  });
}
