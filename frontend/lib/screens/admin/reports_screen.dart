import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/admin_api_service.dart';
import '../../widgets/admin/stat_card.dart';
import 'admin_shell.dart';
import 'job_detail_dialog.dart';

class ReportsScreen extends StatefulWidget {
  final int? initialDepartmentId;

  const ReportsScreen({super.key, this.initialDepartmentId});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _departments = [];
  int? _selectedDepartmentId;
  int? _selectedUserId;
  String? _selectedPrinterId;
  String _datePreset = 'all'; // 'all', 'today', '7d', '30d', 'month'
  String? _selectedStatus; // null for all, 'COMPLETED', 'FAILED', 'CANCELLED'
  bool? _isColor; // null for all, true for color, false for bw

  Map<String, dynamic>? _reportData;

  // Phase 4: Detailed Print Jobs state
  List<dynamic> _jobs = [];
  int _jobsTotal = 0;
  int _jobsPage = 1;
  final int _jobsPageSize = 10;
  int _jobsTotalPages = 1;
  bool _isLoadingJobs = false;
  String _jobSearchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedDepartmentId = widget.initialDepartmentId;
    _initData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    try {
      final depts = await AdminApiService.getDepartments();
      if (mounted) {
        setState(() {
          _departments = depts;
        });
      }
    } catch (_) {}
    await Future.wait([
      _loadReport(),
      _loadJobs(page: 1),
    ]);
  }

  String? _getStartDateForPreset() {
    final now = DateTime.now();
    switch (_datePreset) {
      case 'today':
        return DateTime(now.year, now.month, now.day).toIso8601String();
      case '7d':
        return now.subtract(const Duration(days: 7)).toIso8601String();
      case '30d':
        return now.subtract(const Duration(days: 30)).toIso8601String();
      case 'month':
        return DateTime(now.year, now.month, 1).toIso8601String();
      case 'all':
      default:
        return null;
    }
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await AdminApiService.getDepartmentReport(
        departmentId: _selectedDepartmentId,
        userId: _selectedUserId,
        printerId: _selectedPrinterId,
        startDate: _getStartDateForPreset(),
        status: _selectedStatus,
        isColor: _isColor,
      );
      if (mounted) {
        setState(() {
          _reportData = data;
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

  Future<void> _loadJobs({int page = 1}) async {
    setState(() {
      _isLoadingJobs = true;
      _jobsPage = page;
    });

    try {
      final res = await AdminApiService.getDetailedPrintJobs(
        departmentId: _selectedDepartmentId,
        userId: _selectedUserId,
        printerId: _selectedPrinterId,
        status: _selectedStatus,
        isColor: _isColor,
        startDate: _getStartDateForPreset(),
        search: _jobSearchQuery,
        page: page,
        pageSize: _jobsPageSize,
      );
      if (mounted) {
        setState(() {
          _jobs = res['jobs'] as List? ?? [];
          _jobsTotal = (res['total'] as num?)?.toInt() ?? 0;
          _jobsTotalPages = (res['total_pages'] as num?)?.toInt() ?? 1;
          _isLoadingJobs = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingJobs = false;
        });
      }
    }
  }

  void _onFilterChanged() {
    _loadReport();
    _loadJobs(page: 1);
  }

  Widget _buildFilterToolbar() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
            // Department Selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceSubtle,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: _selectedDepartmentId,
                  hint: const Text('Department: All Departments', style: TextStyle(fontSize: 13)),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Department: All Departments', style: TextStyle(fontSize: 13)),
                    ),
                    if (_selectedDepartmentId != null &&
                        !_departments.any((d) => d['id'] == _selectedDepartmentId))
                      DropdownMenuItem<int?>(
                        value: _selectedDepartmentId,
                        child: Text(
                          'Dept: ${_reportData?['summary']?['department_name'] ?? 'Department #$_selectedDepartmentId'}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ..._departments.map((d) {
                      return DropdownMenuItem<int?>(
                        value: d['id'] as int?,
                        child: Text('Dept: ${d['name']} (${d['code']})', style: const TextStyle(fontSize: 13)),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedDepartmentId = val);
                    _onFilterChanged();
                  },
                ),
              ),
            ),

            // Date Range Preset
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceSubtle,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _datePreset,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Period: All Time', style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: 'today', child: Text('Period: Today', style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: '7d', child: Text('Period: Last 7 Days', style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: '30d', child: Text('Period: Last 30 Days', style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: 'month', child: Text('Period: This Month', style: TextStyle(fontSize: 13))),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _datePreset = val);
                      _onFilterChanged();
                    }
                  },
                ),
              ),
            ),

            // Status Filter
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceSubtle,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _selectedStatus,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Status: All Statuses', style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: 'COMPLETED', child: Text('Status: Completed', style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: 'FAILED', child: Text('Status: Failed', style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: 'CANCELLED', child: Text('Status: Cancelled', style: TextStyle(fontSize: 13))),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedStatus = val);
                    _onFilterChanged();
                  },
                ),
              ),
            ),

            // Color / B&W Filter
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceSubtle,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<bool?>(
                  value: _isColor,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Type: Color & B&W', style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: true, child: Text('Type: Color Only', style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: false, child: Text('Type: B&W Only', style: TextStyle(fontSize: 13))),
                  ],
                  onChanged: (val) {
                    setState(() => _isColor = val);
                    _onFilterChanged();
                  },
                ),
              ),
            ),

            // Reset Filter Button
            if (_selectedDepartmentId != null ||
                _selectedUserId != null ||
                _selectedPrinterId != null ||
                _datePreset != 'all' ||
                _selectedStatus != null ||
                _isColor != null ||
                _jobSearchQuery.isNotEmpty)
              TextButton.icon(
                icon: const Icon(Icons.clear_all_rounded, size: 16),
                label: const Text('Reset All Filters'),
                onPressed: () {
                  setState(() {
                    _selectedDepartmentId = null;
                    _selectedUserId = null;
                    _selectedPrinterId = null;
                    _datePreset = 'all';
                    _selectedStatus = null;
                    _isColor = null;
                    _jobSearchQuery = '';
                    _searchController.clear();
                  });
                  _onFilterChanged();
                },
              ),
          ],
        ),

        // Active Drill-down Chips
        if (_selectedUserId != null || _selectedPrinterId != null) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              if (_selectedUserId != null)
                InputChip(
                  label: Text('User Filter: ID #$_selectedUserId', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  avatar: const Icon(Icons.person, size: 16),
                  onDeleted: () {
                    setState(() => _selectedUserId = null);
                    _onFilterChanged();
                  },
                ),
              if (_selectedPrinterId != null)
                InputChip(
                  label: Text('Printer: $_selectedPrinterId', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  avatar: const Icon(Icons.print, size: 16),
                  onDeleted: () {
                    setState(() => _selectedPrinterId = null);
                    _onFilterChanged();
                  },
                ),
            ],
          ),
        ],
      ],
    ),
  ),
);
}

  Widget _buildSummaryKpiGrid(Map<String, dynamic> summary) {
    final jobs = '${summary['total_jobs'] ?? 0}';
    final pages = '${summary['total_pages'] ?? 0}';
    final success = '${summary['successful_jobs'] ?? 0}';
    final failed = '${summary['failed_jobs'] ?? 0}';
    final avgPages = '${summary['avg_pages_per_job'] ?? 0}';
    final amount = '₹${summary['total_amount'] ?? 0}';

    final totalJobs = (summary['total_jobs'] as num?)?.toInt() ?? 0;
    final succJobs = (summary['successful_jobs'] as num?)?.toInt() ?? 0;
    final successRate = totalJobs > 0 ? (succJobs / totalJobs * 100).toStringAsFixed(1) : '100';

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 4;
        if (constraints.maxWidth < 650) {
          crossAxisCount = 1;
        } else if (constraints.maxWidth < 1100) {
          crossAxisCount = 2;
        }

        final cards = [
          StatCard(
            title: 'Reported Print Jobs',
            value: jobs,
            icon: Icons.receipt_long_rounded,
            iconColor: AppTheme.primary,
            subtitle: 'Matching criteria',
          ),
          StatCard(
            title: 'Total Pages Printed',
            value: pages,
            icon: Icons.file_copy_rounded,
            iconColor: const Color(0xFF0891B2),
            subtitle: 'Cumulative sheet count',
          ),
          StatCard(
            title: 'Successful Jobs',
            value: success,
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
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.success),
              ),
            ),
            subtitle: 'Completion reliability',
          ),
          StatCard(
            title: 'Failed / Cancelled',
            value: failed,
            icon: Icons.cancel_rounded,
            iconColor: AppTheme.danger,
            subtitle: 'Unsuccessful attempts',
          ),
          StatCard(
            title: 'Average Pages / Job',
            value: avgPages,
            icon: Icons.bar_chart_rounded,
            iconColor: const Color(0xFF7C3AED),
            subtitle: 'Mean document length',
          ),
          StatCard(
            title: 'Billing Value',
            value: amount,
            icon: Icons.currency_rupee_rounded,
            iconColor: const Color(0xFFD97706),
            subtitle: 'Calculated tariff',
          ),
        ];

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: crossAxisCount == 1 ? 2.6 : (crossAxisCount == 2 ? 1.8 : 1.45),
          ),
          itemCount: cards.length,
          itemBuilder: (context, i) => cards[i],
        );
      },
    );
  }

  Widget _buildVisualBreakdowns(Map<String, dynamic> summary) {
    final colorPages = (summary['color_pages'] as num?)?.toInt() ?? 0;
    final bwPages = (summary['bw_pages'] as num?)?.toInt() ?? 0;
    final totalPages = colorPages + bwPages;
    final colorPct = totalPages > 0 ? (colorPages / totalPages * 100).toStringAsFixed(1) : '0.0';
    final bwPct = totalPages > 0 ? (bwPages / totalPages * 100).toStringAsFixed(1) : '100.0';

    final succJobs = (summary['successful_jobs'] as num?)?.toInt() ?? 0;
    final failJobs = ((summary['failed_jobs'] as num?)?.toInt() ?? 0) + ((summary['cancelled_jobs'] as num?)?.toInt() ?? 0);
    final totalDecided = succJobs + failJobs;
    final successRate = totalDecided > 0 ? (succJobs / totalDecided * 100).toStringAsFixed(1) : '100.0';

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
                    Icon(Icons.palette_outlined, color: Color(0xFF9333EA), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Color vs. Black & White Pages',
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
                    Text('Color: $colorPages pages ($colorPct%)',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF7E22CE))),
                    Text('B&W: $bwPages pages ($bwPct%)',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
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
                    Icon(Icons.verified_outlined, color: AppTheme.success, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Job Success & Reliability Ratio',
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
                          flex: totalDecided > 0 ? succJobs : 1,
                          child: Container(color: AppTheme.success),
                        ),
                        Expanded(
                          flex: totalDecided > 0 ? failJobs : 0,
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
                    Text('Successful: $succJobs ($successRate%)',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.success)),
                    Text('Failed / Cancelled: $failJobs',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.danger)),
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

  Widget _buildUserStatsTable(List<dynamic> users) {
    if (users.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: const Text('No user records found for the selected period.', style: TextStyle(color: AppTheme.textMuted)),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppTheme.surfaceSubtle),
        columns: const [
          DataColumn(label: Text('User', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('ID / Roll No', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Jobs Submitted', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Total Pages', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Color Pages', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('B&W Pages', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Success Rate', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.w700))),
        ],
        rows: users.map((u) {
          final sRate = u['success_rate']?.toString() ?? '100';
          return DataRow(
            cells: [
              DataCell(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(u['user_name'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (u['email'] != null)
                      Text(u['email'], style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
              ),
              DataCell(Text(u['roll_number'] ?? '-')),
              DataCell(Text('${u['total_jobs'] ?? 0}')),
              DataCell(Text('${u['total_pages'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w700))),
              DataCell(Text('${u['color_pages'] ?? 0}', style: const TextStyle(color: Color(0xFF7E22CE), fontWeight: FontWeight.w600))),
              DataCell(Text('${u['bw_pages'] ?? 0}')),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.successSurface,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('$sRate%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.success)),
                ),
              ),
              DataCell(
                IconButton(
                  icon: const Icon(Icons.receipt_long_outlined, size: 18, color: AppTheme.primary),
                  tooltip: 'View print jobs for this user',
                  onPressed: () {
                    setState(() {
                      _selectedUserId = u['user_id'];
                      _tabController.animateTo(2);
                    });
                    _loadJobs(page: 1);
                  },
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPrinterUtilizationTable(List<dynamic> printers) {
    if (printers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: const Text('No printer workload recorded for this criteria.', style: TextStyle(color: AppTheme.textMuted)),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppTheme.surfaceSubtle),
        columns: const [
          DataColumn(label: Text('Printer Name', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Queue Identifier', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Jobs Handled', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Pages Dispatched', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Workload Share', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Reliability', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.w700))),
        ],
        rows: printers.map((p) {
          final util = p['utilization_percentage']?.toString() ?? '0';
          final sRate = p['success_rate']?.toString() ?? '100';
          return DataRow(
            cells: [
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.print_outlined, size: 16, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Text(p['printer_name'] ?? 'Printer', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              DataCell(Text(p['cups_printer_name'] ?? '-', style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
              DataCell(Text('${p['total_jobs'] ?? 0}')),
              DataCell(Text('${p['total_pages'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w700))),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 50,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: ((p['utilization_percentage'] as num?)?.toDouble() ?? 0) / 100,
                          backgroundColor: AppTheme.surfaceSubtle,
                          color: AppTheme.primary,
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('$util%'),
                  ],
                ),
              ),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.successSurface,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('$sRate%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.success)),
                ),
              ),
              DataCell(
                IconButton(
                  icon: const Icon(Icons.receipt_long_outlined, size: 18, color: AppTheme.primary),
                  tooltip: 'View jobs on this printer',
                  onPressed: () {
                    setState(() {
                      _selectedPrinterId = p['printer_id'];
                      _tabController.animateTo(2);
                    });
                    _loadJobs(page: 1);
                  },
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildJobStatusChip(String status) {
    Color bg;
    Color text;

    switch (status.toUpperCase()) {
      case 'COMPLETED':
        bg = AppTheme.successSurface;
        text = AppTheme.success;
        break;
      case 'FAILED':
      case 'FINAL_FAILED':
        bg = AppTheme.dangerSurface;
        text = AppTheme.danger;
        break;
      case 'CANCELLED':
        bg = AppTheme.warningSurface;
        text = AppTheme.warning;
        break;
      case 'PRINTING':
        bg = AppTheme.primarySurface;
        text = AppTheme.primary;
        break;
      case 'QUEUED':
      default:
        bg = AppTheme.surfaceSubtle;
        text = AppTheme.textSecondary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: text),
      ),
    );
  }

  Widget _buildJobsTable() {
    if (_isLoadingJobs) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2),
            SizedBox(height: 12),
            Text('Querying print job audit logs...', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Search and page controls bar
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                width: 320,
                height: 38,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search doc, user, or job ID...',
                    hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _jobSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _jobSearchQuery = '');
                              _loadJobs(page: 1);
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    filled: true,
                    fillColor: AppTheme.surfaceSubtle,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                  ),
                  onSubmitted: (val) {
                    setState(() => _jobSearchQuery = val);
                    _loadJobs(page: 1);
                  },
                ),
              ),
              Row(
                children: [
                  Text(
                    'Showing ${(_jobs.isEmpty ? 0 : (_jobsPage - 1) * _jobsPageSize + 1)} - ${((_jobsPage - 1) * _jobsPageSize + _jobs.length)} of $_jobsTotal',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _jobsPage > 1 ? () => _loadJobs(page: _jobsPage - 1) : null,
                    tooltip: 'Previous page',
                  ),
                  Text('$_jobsPage / $_jobsTotalPages', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _jobsPage < _jobsTotalPages ? () => _loadJobs(page: _jobsPage + 1) : null,
                    tooltip: 'Next page',
                  ),
                ],
              ),
            ],
          ),
        ),

        // Jobs Data Table
        Expanded(
          child: _jobs.isEmpty
              ? Container(
                  alignment: Alignment.center,
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_outlined, size: 40, color: AppTheme.textMuted),
                      SizedBox(height: 8),
                      Text('No print jobs match the selected filter criteria.', style: TextStyle(color: AppTheme.textSecondary)),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(AppTheme.surfaceSubtle),
                      columns: const [
                        DataColumn(label: Text('Job ID', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Document', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('User / Dept', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Station', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Specs', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.w700))),
                      ],
                      rows: _jobs.map((job) {
                        final status = job['status'] ?? 'QUEUED';
                        final isColor = job['is_color'] == true;
                        return DataRow(
                          cells: [
                            DataCell(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(job['id'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'monospace', fontSize: 12)),
                                  Text(job['created_at']?.toString().split('T').first ?? '', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                                ],
                              ),
                            ),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 180),
                                child: Text(
                                  job['document_name'] ?? 'Document',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ),
                            ),
                            DataCell(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(job['user_name'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                  Text(job['department_name'] ?? 'General', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                ],
                              ),
                            ),
                            DataCell(
                              Text(job['printer_name'] ?? 'Local Station', style: const TextStyle(fontSize: 12)),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('${job['pages']}p (${job['copies']}x)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isColor ? const Color(0xFFFAF5FF) : AppTheme.surfaceSubtle,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: isColor ? const Color(0xFFE9D5FF) : AppTheme.border),
                                    ),
                                    child: Text(
                                      isColor ? 'C' : 'B/W',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: isColor ? const Color(0xFF7E22CE) : AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(_buildJobStatusChip(status)),
                            DataCell(Text('₹${job['amount'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.visibility_outlined, size: 18, color: AppTheme.primary),
                                tooltip: 'Inspect print job details',
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => JobDetailDialog(
                                      jobId: job['id'],
                                      initialData: job,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = _reportData != null ? (_reportData!['summary'] as Map<String, dynamic>?) : null;
    final deptTitle = summary != null ? summary['department_name'] : 'Department Printing Reports';

    return AdminShell(
      currentSection: AdminNavSection.reports,
      title: 'Department Reports',
      onRefresh: _loadReport,
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(strokeWidth: 2),
                  SizedBox(height: 16),
                  Text('Compiling department report analytics...'),
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
                          Text('Unable to generate report',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary)),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: _loadReport,
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
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Report: $deptTitle',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Comprehensive print consumption, user ranking, and printer hardware statistics.',
                                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              _loadReport();
                              _loadJobs(page: _jobsPage);
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Refresh'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Filter Toolbar
                      _buildFilterToolbar(),
                      const SizedBox(height: 20),

                      // KPI Cards
                      if (summary != null) ...[
                        _buildSummaryKpiGrid(summary),
                        const SizedBox(height: 24),
                        _buildVisualBreakdowns(summary),
                        const SizedBox(height: 24),
                      ],

                      // Tabbed Detailed Tables (User stats, Printer utilization & Detailed Print Jobs)
                      Card(
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
                              TabBar(
                                controller: _tabController,
                                labelColor: AppTheme.primary,
                                unselectedLabelColor: AppTheme.textSecondary,
                                indicatorColor: AppTheme.primary,
                                tabs: [
                                  Tab(
                                    text:
                                        'User-wise Statistics (${(_reportData!['user_stats'] as List? ?? []).length})',
                                  ),
                                  Tab(
                                    text:
                                        'Printer Utilization (${(_reportData!['printer_stats'] as List? ?? []).length})',
                                  ),
                                  Tab(
                                    text: 'Detailed Print Jobs ($_jobsTotal)',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 520,
                                child: TabBarView(
                                  controller: _tabController,
                                  children: [
                                    _buildUserStatsTable(_reportData!['user_stats'] ?? []),
                                    _buildPrinterUtilizationTable(_reportData!['printer_stats'] ?? []),
                                    _buildJobsTable(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
