import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:get/get.dart';

import 'package:dairy/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('shows the dairy login screen', (tester) async {
    await tester.pumpWidget(const DairyApp());
    await tester.pumpAndSettle();

    expect(find.text('Dairy Desk'), findsOneWidget);
    expect(find.text('Email address or mobile number'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.byType(SegmentedButton<bool>), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Log in'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Verify email'), findsNothing);

    Get.reset();
  });

  testWidgets('can switch to signup', (tester) async {
    await tester.pumpWidget(const DairyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create account').first);
    await tester.pump();

    expect(find.text('Dairy name'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Create account'), findsOneWidget);

    Get.reset();
  });
}
