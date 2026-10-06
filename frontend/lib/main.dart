import 'package:flutter/material.dart';

import 'config/api_config.dart';
import 'config/theme.dart';
import 'screens/upload_screen.dart';
import 'screens/admin_login_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/departments_screen.dart';
import 'screens/admin/reports_screen.dart';
import 'screens/admin/printers_screen.dart';
import 'screens/admin/users_screen.dart';
import 'screens/admin/settings_screen.dart';

import 'services/customer_auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.init();
  await CustomerAuthService().init();
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
      routes: {
        '/admin/login': (_) => const AdminLoginScreen(),
        '/admin/dashboard': (_) => const AdminDashboardScreen(),
        '/admin/departments': (_) => const DepartmentsScreen(),
        '/admin/printers': (_) => const PrintersScreen(),
        '/admin/users': (_) => const UsersScreen(),
        '/admin/settings': (_) => const SettingsScreen(),
        '/admin/reports': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          int? deptId;
          if (args is int) {
            deptId = args;
          } else if (args is Map<String, dynamic>) {
            deptId = args['department_id'] as int?;
          }
          return ReportsScreen(initialDepartmentId: deptId);
        },
      },
    );
  }
}
