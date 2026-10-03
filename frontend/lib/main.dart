import 'package:flutter/material.dart';

import 'config/api_config.dart';
import 'config/theme.dart';
import 'screens/upload_screen.dart';
import 'screens/admin_login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.init();
  runApp(const PrintApp());
}

class PrintApp extends StatelessWidget {
  const PrintApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Achuppori',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const UploadScreen(),
      routes: {'/admin/login': (_) => const AdminLoginScreen()},
    );
  }
}
