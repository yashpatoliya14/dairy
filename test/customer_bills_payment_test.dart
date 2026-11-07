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
  });
}
