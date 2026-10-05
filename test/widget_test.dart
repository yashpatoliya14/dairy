import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dairy/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows the dairy login screen', (tester) async {
    await tester.pumpWidget(const DairyApp());
    await tester.pumpAndSettle();

    expect(find.text('Dairy Desk'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });

  testWidgets('can switch to signup', (tester) async {
    await tester.pumpWidget(const DairyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('New to Dairy Desk? Create an account'));
    await tester.pump();

    expect(find.text('Dairy name'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });
}
