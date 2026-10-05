import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/config/theme.dart';
import 'package:frontend/screens/admin/department_detail_dialog.dart';
import 'package:frontend/screens/admin/departments_screen.dart';

void main() {
  testWidgets('DepartmentDetailDialog renders and handles unauthenticated state gracefully', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: DepartmentDetailDialog(
            departmentId: 1,
            departmentName: 'Human Resources',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verifies retry button or error handling without exception
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('DepartmentsScreen renders enterprise shell without overflow', (tester) async {
    // Set a realistic enterprise screen size (1024x768)
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const DepartmentsScreen(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Department Management'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
