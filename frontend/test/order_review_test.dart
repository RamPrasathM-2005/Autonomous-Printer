import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/document.dart';
import 'package:frontend/screens/order_summary_screen.dart';
import 'package:frontend/widgets/help_action.dart';

void main() {
  for (final width in [360.0, 1280.0]) {
    testWidgets('Order review and removal at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final docs = List.generate(
        2,
        (i) => UploadedDocument(
          documentId: 'doc-$i',
          originalFilename: 'Long document filename $i.pdf',
          pages: 3,
          size: 1200,
          status: 'UPLOADED',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: OrderSummaryScreen(
            configs: docs
                .map((d) => DocumentPrintConfig(document: d, copies: 2))
                .toList(),
            selectedStationId: 'station',
            primaryDocument: docs.first,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Review Your Order'), findsOneWidget);
      expect(find.text('Pay \u20b924.00'), findsOneWidget);

      await tester.tap(find.byTooltip('Remove file').first);
      await tester.pumpAndSettle();
      expect(find.text('Pay \u20b912.00'), findsOneWidget);
      expect(find.text(docs.first.filename), findsNothing);
      final remove = tester.widget<IconButton>(
        find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Remove file',
        ),
      );
      expect(remove.onPressed, isNull);
      await tester.tap(find.text('Help'));
      await tester.pumpAndSettle();
      expect(find.byType(HelpScreen), findsOneWidget);
    });
  }
}
