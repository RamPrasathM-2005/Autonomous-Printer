import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/admin_api_service.dart';
import '../../widgets/admin/stat_card.dart';
import 'admin_shell.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _metrics;
  String _activityFilter = '';

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await AdminApiService.getDashboardMetrics();
      if (mounted) {
        setState(() {
          _metrics = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildStatusChip(String status) {
    Color bg;
    Color text;
    IconData icon;

    switch (status.toUpperCase()) {
      case 'COMPLETED':
        bg = AppTheme.successSurface;
        text = AppTheme.success;
        icon = Icons.check_circle_outline;
        break;
      case 'FAILED':
      case 'FINAL_FAILED':
        bg = AppTheme.dangerSurface;
        text = AppTheme.danger;
        icon = Icons.error_outline;
        break;
      case 'CANCELLED':
        bg = AppTheme.warningSurface;
        text = AppTheme.warning;
        icon = Icons.cancel_outlined;
        break;
      case 'PRINTING':
        bg = AppTheme.primarySurface;
        text = AppTheme.primary;
        icon = Icons.sync_rounded;
        break;
      case 'QUEUED':
      default:
        bg = AppTheme.surfaceSubtle;
        text = AppTheme.textSecondary;
        icon = Icons.hourglass_empty_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: text),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: text),
          ),
        ],
      ),
    );
  }

  Widget _buildColorTypeChip(bool isColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isColor ? const Color(0xFFFAF5FF) : AppTheme.surfaceSubtle,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isColor ? const Color(0xFFE9D5FF) : AppTheme.border,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 3,
            backgroundColor: isColor ? const Color(0xFF9333EA) : AppTheme.textSecondary,
          ),
          const SizedBox(width: 5),
          Text(
            isColor ? 'Color' : 'B&W',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isColor ? const Color(0xFF7E22CE) : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(Map<String, dynamic> data) {
    final depts = data['total_departments']?.toString() ?? '0';
    final users = data['total_users']?.toString() ?? '0';
    final printers = data['total_printers']?.toString() ?? '0';
    final jobs = data['total_print_jobs']?.toString() ?? '0';
    final pages = data['total_pages_printed']?.toString() ?? '0';
    final successful = data['successful_print_jobs']?.toString() ?? '0';
    final failed = data['failed_print_jobs']?.toString() ?? '0';
    final successRate = data['success_rate']?.toString() ?? '100';

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 4;
        if (constraints.maxWidth < 600) {
          crossAxisCount = 1;
        } else if (constraints.maxWidth < 950) {
          crossAxisCount = 2;
        } else if (constraints.maxWidth < 1300) {
          crossAxisCount = 3;
        }

        final cards = [
          StatCard(
            title: 'Total Departments',
            value: depts,
            icon: Icons.business_rounded,
            iconColor: const Color(0xFF2563EB),
            subtitle: 'Configured business units',
          ),
          StatCard(
            title: 'Registered Users',
            value: users,
            icon: Icons.people_alt_rounded,
            iconColor: const Color(0xFF7C3AED),
            subtitle: 'Staff & students',
          ),
          StatCard(
            title: 'Station Printers',
            value: printers,
            icon: Icons.print_rounded,
            iconColor: const Color(0xFF059669),
            subtitle: 'Active print hardware',
          ),
          StatCard(
            title: 'Total Print Jobs',
            value: jobs,
            icon: Icons.receipt_long_rounded,
            iconColor: const Color(0xFFD97706),
            subtitle: 'Lifetime processed',
          ),
          StatCard(
            title: 'Total Pages Printed',
            value: pages,
            icon: Icons.file_copy_rounded,
            iconColor: const Color(0xFF0891B2),
            subtitle: 'Physical paper count',
          ),
          StatCard(
            title: 'Successful Print Jobs',
            value: successful,
            icon: Icons.check_circle_rounded,
            iconColor: AppTheme.success,
            badge: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.successSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.successBorder),
              ),
              child: Text(
                '$successRate%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.success,
                ),
              ),
            ),
            subtitle: 'Reliability rate',
          ),
          StatCard(
            title: 'Failed / Cancelled',
            value: failed,
            icon: Icons.cancel_rounded,
            iconColor: AppTheme.danger,
            subtitle: 'Requires maintenance',
          ),
        ];

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: crossAxisCount == 1 ? 2.5 : (crossAxisCount == 2 ? 1.7 : 1.45),
          ),
          itemCount: cards.length,
          itemBuilder: (context, i) => cards[i],
        );
      },
    );
  }

  Widget _buildColorAndHealthRow(Map<String, dynamic> data) {
    final colorPages = (data['color_pages'] as num?)?.toInt() ?? 0;
    final bwPages = (data['bw_pages'] as num?)?.toInt() ?? 0;
    final totalPages = colorPages + bwPages;
    final colorPct = totalPages > 0 ? (colorPages / totalPages * 100).toStringAsFixed(1) : '0.0';
    final bwPct = totalPages > 0 ? (bwPages / totalPages * 100).toStringAsFixed(1) : '100.0';

    final successfulJobs = (data['successful_print_jobs'] as num?)?.toInt() ?? 0;
    final failedJobs = (data['failed_print_jobs'] as num?)?.toInt() ?? 0;
    final totalDecided = successfulJobs + failedJobs;
    final successRate = totalDecided > 0 ? (successfulJobs / totalDecided * 100).toStringAsFixed(1) : '100.0';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 800;

        final colorCard = Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppTheme.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.palette_outlined, color: AppTheme.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Color vs. Black & White Printing',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 14,
                    child: Row(
                      children: [
                        Expanded(
                          flex: totalPages > 0 ? colorPages : 0,
                          child: Container(color: const Color(0xFF9333EA)),
                        ),
                        Expanded(
                          flex: totalPages > 0 ? bwPages : 1,
                          child: Container(color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(radius: 5, backgroundColor: Color(0xFF9333EA)),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Color: $colorPages pages ($colorPct%)',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                            Text('${data['color_jobs'] ?? 0} jobs',
                                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const CircleAvatar(radius: 5, backgroundColor: Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('B&W: $bwPages pages ($bwPct%)',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                            Text('${data['bw_jobs'] ?? 0} jobs',
                                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );

        final healthCard = Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppTheme.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.health_and_safety_outlined, color: AppTheme.success, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Print Job Reliability & Health',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 14,
                    child: Row(
                      children: [
                        Expanded(
                          flex: totalDecided > 0 ? successfulJobs : 1,
                          child: Container(color: AppTheme.success),
                        ),
                        Expanded(
                          flex: totalDecided > 0 ? failedJobs : 0,
                          child: Container(color: AppTheme.danger),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(radius: 5, backgroundColor: AppTheme.success),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Successful: $successfulJobs ($successRate%)',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                            const Text('Dispatched & printed',
                                style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const CircleAvatar(radius: 5, backgroundColor: AppTheme.danger),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Failed / Cancelled: $failedJobs',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                            const Text('Hardware or user error',
                                style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );

        if (isNarrow) {
          return Column(
            children: [
              colorCard,
              const SizedBox(height: 16),
              healthCard,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: colorCard),
            const SizedBox(width: 16),
            Expanded(child: healthCard),
          ],
        );
      },
    );
  }

  Widget _buildDepartmentSummaryTable(List<dynamic> depts) {
    if (depts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.account_tree_outlined, color: AppTheme.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Department Utilization Overview',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${depts.length} departments',
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).pushReplacementNamed('/admin/departments'),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                      label: const Text('Manage', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppTheme.surfaceSubtle),
                columns: const [
                  DataColumn(label: Text('Department', style: TextStyle(fontWeight: FontWeight.w700))),
                  DataColumn(label: Text('Code', style: TextStyle(fontWeight: FontWeight.w700))),
                  DataColumn(label: Text('Users', style: TextStyle(fontWeight: FontWeight.w700))),
                  DataColumn(label: Text('Printers', style: TextStyle(fontWeight: FontWeight.w700))),
                  DataColumn(label: Text('Print Jobs', style: TextStyle(fontWeight: FontWeight.w700))),
                  DataColumn(label: Text('Pages', style: TextStyle(fontWeight: FontWeight.w700))),
                  DataColumn(label: Text('Report', style: TextStyle(fontWeight: FontWeight.w700))),
                ],
                rows: depts.map((d) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.folder_outlined, size: 16, color: AppTheme.primary),
                            const SizedBox(width: 8),
                            Text(d['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primarySurface,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            d['code'] ?? '',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryDark,
                            ),
                          ),
                        ),
                      ),
                      DataCell(Text(d['users_count']?.toString() ?? '0')),
                      DataCell(Text(d['printers_count']?.toString() ?? '0')),
                      DataCell(Text(d['jobs_count']?.toString() ?? '0')),
                      DataCell(
                        Text(
                          d['pages_count']?.toString() ?? '0',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.assessment_outlined, size: 18, color: AppTheme.primary),
                          tooltip: 'View Department Report',
                          onPressed: () {
                            Navigator.of(context).pushNamed(
                              '/admin/reports',
                              arguments: {'department_id': d['id']},
                            );
                          },
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityTable(List<dynamic> activities) {
    final filtered = activities.where((act) {
      if (_activityFilter.isEmpty) return true;
      final q = _activityFilter.toLowerCase();
      final doc = (act['document_name'] ?? '').toString().toLowerCase();
      final user = (act['user_name'] ?? '').toString().toLowerCase();
      final dept = (act['department_name'] ?? '').toString().toLowerCase();
      final printer = (act['printer_name'] ?? '').toString().toLowerCase();
      final id = (act['id'] ?? '').toString().toLowerCase();
      return doc.contains(q) || user.contains(q) || dept.contains(q) || printer.contains(q) || id.contains(q);
    }).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.history_rounded, color: AppTheme.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Recent Printing Activity',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
                SizedBox(
                  width: 240,
                  height: 38,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search recent activity...',
                      hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                      filled: true,
                      fillColor: AppTheme.surfaceSubtle,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                    ),
                    onChanged: (val) => setState(() => _activityFilter = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (filtered.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                child: const Column(
                  children: [
                    Icon(Icons.inbox_outlined, size: 36, color: AppTheme.textMuted),
                    SizedBox(height: 8),
                    Text(
                      'No recent printing activity matches your search.',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(AppTheme.surfaceSubtle),
                  columns: const [
                    DataColumn(label: Text('Job ID', style: TextStyle(fontWeight: FontWeight.w700))),
                    DataColumn(label: Text('Document', style: TextStyle(fontWeight: FontWeight.w700))),
                    DataColumn(label: Text('User', style: TextStyle(fontWeight: FontWeight.w700))),
                    DataColumn(label: Text('Department', style: TextStyle(fontWeight: FontWeight.w700))),
                    DataColumn(label: Text('Printer', style: TextStyle(fontWeight: FontWeight.w700))),
                    DataColumn(label: Text('Pages', style: TextStyle(fontWeight: FontWeight.w700))),
                    DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.w700))),
                    DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w700))),
                    DataColumn(label: Text('Created At', style: TextStyle(fontWeight: FontWeight.w700))),
                  ],
                  rows: filtered.map((act) {
                    final isColor = act['is_color'] == true;
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            act['id'] ?? '',
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.picture_as_pdf_outlined, size: 16, color: AppTheme.danger),
                              const SizedBox(width: 6),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 180),
                                child: Text(
                                  act['document_name'] ?? 'Document',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                        DataCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(act['user_name'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.w600)),
                              if (act['user_email'] != null)
                                Text(act['user_email'], style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                            ],
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primarySurface,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              act['department_name'] ?? 'General',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryDark),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(act['printer_name'] ?? 'Local Station', style: const TextStyle(fontSize: 12)),
                        ),
                        DataCell(
                          Text(
                            '${act['pages']} (${act['copies']}x)',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        DataCell(_buildColorTypeChip(isColor)),
                        DataCell(_buildStatusChip(act['status'] ?? 'QUEUED')),
                        DataCell(
                          Text(act['created_at'] ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      currentSection: AdminNavSection.dashboard,
      title: 'Infrastructure Dashboard',
      onRefresh: _loadMetrics,
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(strokeWidth: 2),
                  SizedBox(height: 16),
                  Text('Loading admin metrics...', style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Card(
                    margin: const EdgeInsets.all(24),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            'Unable to load dashboard',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary)),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: _loadMetrics,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header greeting
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Enterprise Printing Dashboard',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Real-time overview of departments, print stations, and usage analytics.',
                                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                          OutlinedButton.icon(
                            onPressed: _loadMetrics,
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Refresh'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Metrics Cards
                      _buildMetricsGrid(_metrics!),
                      const SizedBox(height: 24),

                      // Color breakdown & System Health
                      _buildColorAndHealthRow(_metrics!),
                      const SizedBox(height: 24),

                      // Department Breakdown Summary
                      _buildDepartmentSummaryTable(_metrics!['department_summary'] ?? []),
                      const SizedBox(height: 24),

                      // Recent Printing Activity
                      _buildRecentActivityTable(_metrics!['recent_activity'] ?? []),
                    ],
                  ),
                ),
    );
  }
}
