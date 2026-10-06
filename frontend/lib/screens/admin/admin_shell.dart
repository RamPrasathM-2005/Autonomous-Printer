import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/admin_auth_service.dart';

enum AdminNavSection {
  dashboard,
  departments,
  reports,
  printers,
  users,
  settings,
}

class AdminShell extends StatelessWidget {
  final AdminNavSection currentSection;
  final Widget body;
  final String title;
  final List<Widget>? actions;
  final VoidCallback? onRefresh;

  const AdminShell({
    super.key,
    required this.currentSection,
    required this.body,
    required this.title,
    this.actions,
    this.onRefresh,
  });

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text('Are you sure you want to end your administrator session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await AdminAuthService.logout();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/admin/login', (_) => false);
      }
    }
  }

  void _navigateTo(BuildContext context, AdminNavSection section) {
    if (section == currentSection) return;

    switch (section) {
      case AdminNavSection.dashboard:
        Navigator.of(context).pushReplacementNamed('/admin/dashboard');
        break;
      case AdminNavSection.departments:
        Navigator.of(context).pushReplacementNamed('/admin/departments');
        break;
      case AdminNavSection.reports:
        Navigator.of(context).pushReplacementNamed('/admin/reports');
        break;
      case AdminNavSection.printers:
        Navigator.of(context).pushReplacementNamed('/admin/printers');
        break;
      case AdminNavSection.users:
        Navigator.of(context).pushReplacementNamed('/admin/users');
        break;
      case AdminNavSection.settings:
        Navigator.of(context).pushReplacementNamed('/admin/settings');
        break;
    }
  }

  Widget _buildNavTile(
    BuildContext context, {
    required AdminNavSection section,
    required String label,
    required IconData icon,
    bool isDrawer = false,
  }) {
    final isSelected = currentSection == section;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: isSelected ? AppTheme.primarySurface : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            if (isDrawer) Navigator.of(context).pop();
            _navigateTo(context, section);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? AppTheme.primaryDark : AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, {bool isDrawer = false}) {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: AppTheme.surfaceWhite,
        border: Border(right: BorderSide(color: AppTheme.border, width: 1)),
      ),
      child: Column(
        children: [
          // Sidebar Brand Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.border, width: 1)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Achuppori',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        'Admin Portal',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Nav Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildNavTile(
                  context,
                  section: AdminNavSection.dashboard,
                  label: 'Dashboard',
                  icon: Icons.dashboard_outlined,
                  isDrawer: isDrawer,
                ),
                _buildNavTile(
                  context,
                  section: AdminNavSection.departments,
                  label: 'Departments',
                  icon: Icons.business_outlined,
                  isDrawer: isDrawer,
                ),
                _buildNavTile(
                  context,
                  section: AdminNavSection.reports,
                  label: 'Reports',
                  icon: Icons.assessment_outlined,
                  isDrawer: isDrawer,
                ),
                _buildNavTile(
                  context,
                  section: AdminNavSection.printers,
                  label: 'Printers',
                  icon: Icons.print_outlined,
                  isDrawer: isDrawer,
                ),
                _buildNavTile(
                  context,
                  section: AdminNavSection.users,
                  label: 'Users',
                  icon: Icons.people_outline,
                  isDrawer: isDrawer,
                ),
                _buildNavTile(
                  context,
                  section: AdminNavSection.settings,
                  label: 'Settings',
                  icon: Icons.settings_outlined,
                  isDrawer: isDrawer,
                ),
              ],
            ),
          ),
          // Sidebar Footer / Logout
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
            ),
            child: Column(
              children: [
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    leading: const Icon(Icons.logout, size: 20, color: AppTheme.danger),
                    title: const Text(
                      'Sign out',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.danger,
                      ),
                    ),
                    onTap: () {
                      if (isDrawer) Navigator.of(context).pop();
                      _handleLogout(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: isDesktop ? null : null, // Uses default Drawer hamburger if not desktop
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.successSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.successBorder, width: 1),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(radius: 3, backgroundColor: AppTheme.success),
                  SizedBox(width: 5),
                  Text(
                    'Online',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (onRefresh != null)
            IconButton(
              tooltip: 'Refresh data',
              icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary),
              onPressed: onRefresh,
            ),
          TextButton.icon(
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('User App'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primary,
              textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.exit_to_app_rounded, color: AppTheme.danger),
            onPressed: () => _handleLogout(context),
          ),
          const SizedBox(width: 12),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppTheme.border),
        ),
      ),
      drawer: isDesktop ? null : Drawer(child: _buildSidebar(context, isDrawer: true)),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDesktop) _buildSidebar(context),
          Expanded(child: body),
        ],
      ),
    );
  }
}
