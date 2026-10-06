import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/admin/printers_screen.dart';
import 'package:frontend/screens/admin/users_screen.dart';
import 'package:frontend/screens/admin/settings_screen.dart';

void main() {
  testWidgets('PrintersScreen renders without crashing', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: PrintersScreen(),
      ),
    );

    // Initial pump shows loader or layout
    await tester.pump();
    expect(find.byType(PrintersScreen), findsOneWidget);
  });

  testWidgets('UsersScreen renders without crashing', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: UsersScreen(),
      ),
    );

    await tester.pump();
    expect(find.byType(UsersScreen), findsOneWidget);
  });

  testWidgets('SettingsScreen renders without crashing', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsScreen(),
      ),
    );

    await tester.pump();
    expect(find.byType(SettingsScreen), findsOneWidget);
  });
}
