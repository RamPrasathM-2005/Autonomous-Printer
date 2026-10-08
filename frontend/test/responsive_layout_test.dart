import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/config/theme.dart';
import 'package:frontend/config/api_config.dart';
import 'package:frontend/models/document.dart';
import 'package:frontend/screens/upload_screen.dart';
import 'package:frontend/screens/print_options_screen.dart';
import 'package:frontend/screens/document_editor_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final reviewRoot = Platform.environment['UI_REVIEW_FLUTTER_ROOT'];
  setUpAll(() async {
    if (reviewRoot == null) return;
    for (final entry in {
      'Roboto': 'roboto-regular.ttf',
      'Ahem': 'roboto-regular.ttf',
      'MaterialIcons': 'MaterialIcons-Regular.otf',
    }.entries) {
      final loader = FontLoader(entry.key);
      loader.addFont(
        File('$reviewRoot/bin/cache/artifacts/material_fonts/${entry.value}')
            .readAsBytes()
            .then((bytes) => ByteData.sublistView(bytes)),
      );
      await loader.load();
    }
  });
  final document = UploadedDocument(
    documentId: 'layout-doc',
    originalFilename: 'Sample document.pdf',
    pages: 3,
    size: 2048,
    status: 'UPLOADED',
  );
  for (final width in [320.0, 390.0, 768.0, 1280.0]) {
    for (final screen in ['upload', 'settings', 'editor']) {
      testWidgets('$screen layout at $width', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        ApiConfig.backendUrl = 'http://127.0.0.1:8000';
        final boundary = GlobalKey();
        final page = switch (screen) {
          'upload' => const UploadScreen(),
          'settings' => PrintOptionsScreen(documents: [document]),
          _ => DocumentEditorScreen(
            initialConfig: DocumentPrintConfig(document: document),
          ),
        };
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              home: page,
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (screen == 'upload') {
          expect(find.text('Ready to Print?'), findsOneWidget);
          expect(find.text('Upload File'), findsOneWidget);
          final nearby = tester.getRect(
            find.byTooltip('Select Department'),
          );
          final local = tester.getRect(find.text('Local connection'));
          expect(nearby.left, lessThan(local.left));
          expect((nearby.center.dy - local.center.dy).abs(), lessThan(12));
        }
        if (screen == 'settings') {
          await tester.tap(find.text('Landscape'));
          await tester.pumpAndSettle();
        }
        if (reviewRoot != null && (width == 390 || width == 1280)) {
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File('build/ui-review/$screen-${width.toInt()}.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      });
    }
  }
}
