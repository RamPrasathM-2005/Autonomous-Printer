import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/config/theme.dart';
import 'package:frontend/screens/admin_login_screen.dart';

void main() {
  testWidgets('Admin form validates inputs and toggles password visibility', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const AdminLoginScreen()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).first,
      'admin@printplatform.local',
    );
    await tester.enterText(find.byType(TextFormField).last, 'AdminPass123!');
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(find.byTooltip('Hide password'), findsOneWidget);
    final password = tester.widget<EditableText>(
      find.byType(EditableText).last,
    );
    expect(password.obscureText, isFalse);
    expect(tester.takeException(), isNull);
  });
}
