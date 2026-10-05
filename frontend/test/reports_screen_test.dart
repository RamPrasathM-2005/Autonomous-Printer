import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/config/theme.dart';
import 'package:frontend/screens/admin/reports_screen.dart';
import 'package:frontend/screens/admin/job_detail_dialog.dart';

void main() {
  testWidgets('ReportsScreen renders gracefully with desktop dimensions', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ReportsScreen(),
      ),
    );

    // Initial state: loading indicator
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    // After settle: either report loads or error card with retry button
    expect(find.text('Department Reports'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ReportsScreen accepts initialDepartmentId without crash', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ReportsScreen(initialDepartmentId: 2),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Department Reports'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('JobDetailDialog renders job specifications and error diagnostics', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: JobDetailDialog(
            jobId: 'job_test_001',
            initialData: {
              'id': 'job_test_001',
              'order_id': 'ORD-999',
              'document_name': 'Final_Project_Report.pdf',
              'status': 'FAILED',
              'error_code': 'PAPER_JAM',
              'error_message': 'Hardware station reported a paper jam in tray 1.',
              'pages': 12,
              'copies': 2,
              'total_sheets': 24,
              'is_color': true,
              'is_duplex': false,
              'user_name': 'Jane Doe',
              'user_email': 'jane@example.com',
              'user_roll_number': 'CS2026',
              'department_name': 'Computer Science',
              'printer_name': 'Engineering Hallway HP LaserJet',
              'cups_printer_name': 'hp_laserjet_eng',
              'amount': 48.0,
              'currency': 'INR',
              'created_at': '2026-10-05T10:00:00Z',
              'completed_at': null,
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Final_Project_Report.pdf'), findsNWidgets(2));
    expect(find.text('Failure Diagnostic: PAPER_JAM'), findsOneWidget);
    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.text('Engineering Hallway HP LaserJet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
