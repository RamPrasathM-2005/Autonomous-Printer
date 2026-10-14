import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/config/theme.dart';
import 'package:frontend/main.dart';
import 'package:frontend/screens/admin_login_screen.dart';
import 'package:frontend/screens/upload_screen.dart';

void main() {
  testWidgets('Customer theme stays separate from administration', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PrintApp());
    expect(find.byType(PrintApp), findsOneWidget);
    final userContext = tester.element(find.byType(UploadScreen));
    expect(
      Theme.of(userContext).textTheme.bodyMedium?.fontFamily,
      AppTheme.userFont,
    );
    Navigator.of(userContext).pushNamed('/admin/login');
    await tester.pumpAndSettle();
    final adminContext = tester.element(find.byType(AdminLoginScreen));
    expect(Theme.of(adminContext).textTheme.bodyMedium?.fontFamily, 'Inter');
    Navigator.of(adminContext).pop();
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(UploadScreen)))
          .textTheme
          .bodyMedium
          ?.fontFamily,
      AppTheme.userFont,
    );
  });
}
