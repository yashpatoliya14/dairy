import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'package:dairy/main.dart';
import 'package:dairy/services/api_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('ForgotPasswordPage loads with email field and submit button',
      (tester) async {
    final api = ApiService(baseUrl: 'https://example.com');
    await tester.pumpWidget(
      GetMaterialApp(
        home: ForgotPasswordPage(api: api, initialEmail: 'test@example.com'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Forgot password'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('test@example.com'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Send reset code'), findsOneWidget);
  });

  testWidgets('ResetPasswordPage loads code, password, confirm and resend buttons',
      (tester) async {
    final api = ApiService(baseUrl: 'https://example.com');
    await tester.pumpWidget(
      GetMaterialApp(
        home: ResetPasswordPage(
          api: api,
          email: 'test@example.com',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reset password'), findsWidgets);
    expect(find.text('New password'), findsOneWidget);
    expect(find.text('Confirm new password'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Reset password'), findsOneWidget);
  });
}
