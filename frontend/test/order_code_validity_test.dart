import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/config/theme.dart';
import 'package:frontend/models/order.dart';
import 'package:frontend/screens/otp_release_screen.dart';
import 'package:frontend/services/order_recovery_service.dart';
import 'package:frontend/widgets/otp_display.dart';

void main() {
  for (final expiry in [null, '2000-01-01T00:00:00Z']) {
    testWidgets(
      'Release code screen has no countdown with legacy expiry $expiry',
      (tester) async {
        final otp = OrderOtp.fromJson({
          'orderId': 'permanent-order',
          'otp': '123456',
          'expiresAt': expiry,
          'selectedPrinter': 'HP_LaserJet_400_M401dn_F36EC0',
          'printerSelectionLocked': true,
        });
        var status = 'WAITING_FOR_OTP';
        PrintOrder currentOrder() => PrintOrder(
          id: 'permanent-order',
          documentId: 'doc',
          printServerId: 'station',
          printSettings: PrintSettings(),
          totalPages: 1,
          copies: 1,
          amount: 2,
          currency: 'INR',
          status: status,
          createdAt: '2026-10-06T10:00:00Z',
        );
        addTearDown(OrderRecoveryService().clearAll);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: OtpReleaseScreen(
              orderId: 'permanent-order',
              loadOrder: () async => currentOrder(),
              loadOtp: () async => otp,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('No expiry'), findsOneWidget);
        expect(find.text('Expired'), findsNothing);
        expect(find.text('00:00'), findsNothing);
        await tester.pump(const Duration(minutes: 20));
        await tester.pump();
        expect(find.text('No expiry'), findsOneWidget);
        expect(find.text('Expired'), findsNothing);
        status = 'COMPLETED';
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect(find.text('No expiry'), findsNothing);
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Shared release-code card describes validity without expiry', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OtpDisplayCard(otp: '123456')),
      ),
    );
    expect(
      find.text('Valid until the order is released or cancelled.'),
      findsOneWidget,
    );
    expect(find.textContaining('Expires:'), findsNothing);
  });
}
