import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'src/providers/app_provider.dart';
import 'src/providers/config_provider.dart';
import 'src/providers/document_provider.dart';
import 'src/providers/order_provider.dart';
import 'src/providers/otp_provider.dart';
import 'src/providers/payment_provider.dart';
import 'src/providers/print_status_provider.dart';
import 'src/providers/printer_status_provider.dart';
import 'src/screens/splash_screen.dart';
import 'src/screens/home_screen.dart';
import 'src/screens/upload_screen.dart';
import 'src/screens/uploaded_documents_screen.dart';
import 'src/screens/order_summary_screen.dart';
import 'src/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientation to portrait for mobile kiosk workflows
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => PrinterStatusProvider()),
        ChangeNotifierProvider(create: (_) => DocumentProvider()),
        ChangeNotifierProvider(create: (_) => ConfigProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => PaymentProvider()),
        ChangeNotifierProvider(create: (_) => OtpProvider()),
        ChangeNotifierProvider(create: (_) => PrintStatusProvider()),
      ],
      child: const AutonomousPrinterApp(),
    ),
  );
}

class AutonomousPrinterApp extends StatelessWidget {
  const AutonomousPrinterApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();

    return MaterialApp(
      title: 'Autonomous Printer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: appProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const SplashScreen(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/upload': (context) => const UploadScreen(),
        '/documents': (context) => const UploadedDocumentsScreen(),
        '/order-summary': (context) => const OrderSummaryScreen(),
      },
    );
  }
}
