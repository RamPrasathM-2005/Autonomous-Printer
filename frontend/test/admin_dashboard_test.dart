import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/config/theme.dart';
import 'package:frontend/widgets/admin/stat_card.dart';

void main() {
  testWidgets('StatCard renders title, value, icon, and optional badge', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: StatCard(
            title: 'Total Print Jobs',
            value: '1,240',
            icon: Icons.receipt_long_rounded,
            iconColor: const Color(0xFFD97706),
            badge: const Text('98%'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Total Print Jobs'), findsOneWidget);
    expect(find.text('1,240'), findsOneWidget);
    expect(find.text('98%'), findsOneWidget);
    expect(find.byIcon(Icons.receipt_long_rounded), findsOneWidget);
  });
}
