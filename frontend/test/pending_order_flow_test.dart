import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/document.dart';
import 'package:frontend/models/order.dart';
import 'package:frontend/models/user_profile.dart';
import 'package:frontend/screens/print_options_screen.dart';
import 'package:frontend/screens/upload_screen.dart';
import 'package:frontend/services/customer_auth_service.dart';
import 'package:frontend/services/order_recovery_service.dart';
import 'package:frontend/widgets/user_orders_dock.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

final class PickedPdf extends PlatformFile {
  @override
  String get name => 'new-document.pdf';
  @override
  Future<Uint8List> readAsBytes() async =>
      Uint8List.fromList('%PDF sample'.codeUnits);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class OrdersAuth extends CustomerAuthService {
  OrdersAuth()
    : super.withClient(MockClient((_) async => http.Response('{}', 200))) {
    userNotifier.value = UserProfile(id: 1, role: 'USER');
  }
  List<PrintOrder> orders = [];
  Completer<List<PrintOrder>>? pending;
  @override
  bool get isLoggedIn => userNotifier.value != null;
  @override
  Future<List<PrintOrder>> fetchMyOrders() =>
      pending?.future ?? Future.value(orders);
}

PrintOrder order(String id, String status) => PrintOrder(
  id: id,
  documentId: 'doc-$id',
  printServerId: 'station',
  printSettings: PrintSettings(),
  totalPages: 1,
  copies: 1,
  amount: 2,
  currency: 'INR',
  status: status,
  createdAt: '2026-10-06T10:00:00Z',
);

void main() {
  for (final stage in ['UNPAID', 'WAITING_FOR_OTP', 'PRINTING']) {
    testWidgets('New file proceeds independently of cached $stage order', (
      tester,
    ) async {
      final recovery = OrderRecoveryService();
      recovery.setActiveOrder('existing-order', stage: stage);
      addTearDown(recovery.clearAll);
      final uploaded = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: UploadScreen(
            loadStations: () async => [],
            pickFiles: () async => [PickedPdf()],
            uploadDocument: (bytes, filename) async {
              uploaded.add(filename);
              return UploadedDocument(
                documentId: 'new-doc',
                originalFilename: filename,
                pages: 1,
                size: bytes.length,
                status: 'UPLOADED',
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ready to Print?'), findsOneWidget);
      await tester.tap(find.text('Upload File'));
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.inactive,
      );
      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await tester.pumpAndSettle();
      expect(find.text('new-document.pdf'), findsOneWidget);
      expect(find.text('Unpaid Order Exists'), findsNothing);
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(uploaded, ['new-document.pdf']);
      final options = tester.widget<PrintOptionsScreen>(
        find.byType(PrintOptionsScreen),
      );
      expect(options.documents.single.id, 'new-doc');
      expect(recovery.activeOrderId, 'existing-order');
      expect(recovery.activeOrderStage, stage);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'Orders dock shows pending count; sheet filters and refreshes live',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = OrdersAuth()
        ..orders = [
          order('old-paid', 'WAITING_FOR_OTP'),
          order('printed', 'COMPLETED'),
        ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: UserOrdersDock(auth: auth)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('View Orders'), findsOneWidget);
      expect(find.text('Release Code'), findsNothing);
      await tester.tap(find.text('View Orders'));
      await tester.pumpAndSettle();
      expect(find.text('old-paid'), findsOneWidget);
      expect(find.text('printed'), findsNothing);
      expect(find.text('Release Code'), findsOneWidget);
      auth.orders = [
        order('old-paid', 'PRINTING'),
        order('new-unpaid', 'CREATED'),
        order('printed', 'COMPLETED'),
      ];
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      expect(find.text('Pending (2)'), findsOneWidget);
      expect(find.text('Release Code'), findsNothing);
      expect(find.text('View progress'), findsOneWidget);
      expect(find.text('Complete Payment'), findsOneWidget);
      await tester.tap(find.text('History (1)'));
      await tester.pumpAndSettle();
      expect(find.text('printed'), findsOneWidget);
      expect(find.text('old-paid'), findsNothing);
      expect(find.text('Invoice'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Logout clears sheet and discards in-flight orders from previous account',
    (tester) async {
      final auth = OrdersAuth()..orders = [order('private-order', 'CREATED')];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: UserOrdersDock(auth: auth)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('View Orders'));
      await tester.pumpAndSettle();
      auth.pending = Completer<List<PrintOrder>>();
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pump();
      auth.userNotifier.value = null;
      auth.pending!.complete([order('private-order', 'CREATED')]);
      await tester.pumpAndSettle();
      expect(find.text('private-order'), findsNothing);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );
}
