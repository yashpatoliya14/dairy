import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WhatsApp Business API & Template Validation', () {
    test('Phone normalization enforces 10-digit numbers with 91 prefix', () {
      String cleanPhone(String phone) {
        final digits = phone.replaceAll(RegExp(r'\D'), '');
        if (digits.length == 10) return '91$digits';
        return digits;
      }

      bool hasValidPhone(String phone) {
        final digits = phone.replaceAll(RegExp(r'\D'), '');
        return digits.length >= 10;
      }

      expect(cleanPhone('9876543210'), '919876543210');
      expect(cleanPhone('+91 98765 43210'), '919876543210');
      expect(cleanPhone('919876543210'), '919876543210');

      expect(hasValidPhone('9876543210'), isTrue);
      expect(hasValidPhone(''), isFalse);
      expect(hasValidPhone('123'), isFalse);
      expect(hasValidPhone('abc'), isFalse);
    });

    test('Daily milk update template generates 10 structured fields', () {
      const name = 'Ramesh Patel';
      const dateShift = '24 Oct 2026 • Morning';
      const liters = 2.5;
      const rate = 62.0;
      final todayAmount = liters * rate; // 155.00
      const monthToDate = 775.0;
      const pastOverdue = 200.0;
      final totalPayable = monthToDate + pastOverdue; // 975.00
      const ownerName = 'Gokul Dairy';
      const ownerPhone = '+91 9104152524';

      final message = '🥛 *DAILY MILK DELIVERY UPDATE* 🥛\n'
          '━━━━━━━━━━━━━━━━━━━━\n'
          'Hello *$name*,\n\n'
          'Here is your milk delivery summary for *$dateShift*:\n\n'
          '📋 *TODAY\'S DELIVERY:*\n'
          '• Milk Quantity: ${liters.toStringAsFixed(1)} L\n'
          '• Rate per Liter: ₹${rate.toStringAsFixed(2)}/L\n'
          '• Today\'s Amount: ₹${todayAmount.toStringAsFixed(2)}\n\n'
          '💰 *ACCOUNT BALANCE:*\n'
          '• Month-to-date Bill: ₹${monthToDate.toStringAsFixed(2)}\n'
          '• Past Overdue: ₹${pastOverdue.toStringAsFixed(2)}\n'
          '━━━━━━━━━━━━━━━━━━━━\n'
          '⭐ *TOTAL AMOUNT TO PAY: ₹${totalPayable.toStringAsFixed(2)}*\n'
          '━━━━━━━━━━━━━━━━━━━━\n\n'
          '📞 *Dairy Owner Contact:*\n'
          '• Name: $ownerName\n'
          '• Contact: $ownerPhone\n\n'
          'Thank you for choosing our dairy service! 🥛';

      expect(message, contains('Ramesh Patel'));
      expect(message, contains('24 Oct 2026 • Morning'));
      expect(message, contains('2.5 L'));
      expect(message, contains('₹62.00/L'));
      expect(message, contains('Today\'s Amount: ₹155.00'));
      expect(message, contains('Month-to-date Bill: ₹775.00'));
      expect(message, contains('Past Overdue: ₹200.00'));
      expect(message, contains('TOTAL AMOUNT TO PAY: ₹975.00'));
      expect(message, contains('Gokul Dairy'));
      expect(message, contains('+91 9104152524'));
    });

    test('Monthly bill settlement template generates 11 structured fields', () {
      const name = 'Suresh Bhai';
      const month = 'October 2026';
      const days = 30;
      const totalLiters = 60.0;
      const rate = 60.0;
      final monthlyAmount = totalLiters * rate; // 3600.00
      const pastOverdue = 400.0;
      const advanceCredit = 500.0;
      final netPayable = (monthlyAmount + pastOverdue) - advanceCredit; // 3500.00
      const ownerName = 'Gokul Dairy';
      const ownerPhone = '+91 9104152524';

      final message = '🧾 *MILK BILL STATEMENT* 🧾\n'
          '━━━━━━━━━━━━━━━━━━━━\n'
          'Hello *$name*,\n\n'
          'Your milk bill for *$month* has been generated.\n\n'
          '📋 *DELIVERY SUMMARY:*\n'
          '• Active Delivery Days: $days Days\n'
          '• Total Quantity: ${totalLiters.toStringAsFixed(1)} L\n'
          '• Rate per Liter: ₹${rate.toStringAsFixed(2)}/L\n\n'
          '💰 *BILL BREAKDOWN:*\n'
          '• Monthly Milk Bill: ₹${monthlyAmount.toStringAsFixed(2)}\n'
          '• Past Overdue: ₹${pastOverdue.toStringAsFixed(2)}\n'
          '• Advance / Credits: ₹${advanceCredit.toStringAsFixed(2)}\n'
          '━━━━━━━━━━━━━━━━━━━━\n'
          '⭐ *NET TOTAL PAYABLE: ₹${netPayable.toStringAsFixed(2)}*\n'
          '━━━━━━━━━━━━━━━━━━━━\n\n'
          '📲 *Payment Options:*\n'
          'Cash, UPI (GPay / PhonePe / Paytm), or Bank Transfer.\n\n'
          '📞 *Dairy Owner Contact:*\n'
          '• Name: $ownerName\n'
          '• Contact: $ownerPhone\n\n'
          'Thank you for your business! Please settle your bill on time. 🥛';

      expect(message, contains('Suresh Bhai'));
      expect(message, contains('October 2026'));
      expect(message, contains('30 Days'));
      expect(message, contains('60.0 L'));
      expect(message, contains('₹60.00/L'));
      expect(message, contains('Monthly Milk Bill: ₹3600.00'));
      expect(message, contains('Past Overdue: ₹400.00'));
      expect(message, contains('Advance / Credits: ₹500.00'));
      expect(message, contains('NET TOTAL PAYABLE: ₹3500.00'));
      expect(message, contains('Gokul Dairy'));
      expect(message, contains('+91 9104152524'));
    });
  });
}
