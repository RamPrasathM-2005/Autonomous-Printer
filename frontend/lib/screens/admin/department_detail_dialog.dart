import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/admin_api_service.dart';

class DepartmentDetailDialog extends StatefulWidget {
  final int departmentId;
  final String departmentName;

  const DepartmentDetailDialog({
    super.key,
    required this.departmentId,
    required this.departmentName,
  });

  static Future<void> show(BuildContext context, int departmentId, String departmentName) {
    return showDialog(
      context: context,
      builder: (ctx) => DepartmentDetailDialog(
        departmentId: departmentId,
        departmentName: departmentName,
      ),
    );
  }

  @override
  State<DepartmentDetailDialog> createState() => _DepartmentDetailDialogState();
}

class _DepartmentDetailDialogState extends State<DepartmentDetailDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _detail;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDetail();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await AdminApiService.getDepartmentDetail(widget.departmentId);
      if (mounted) {
        setState(() {
          _detail = data;
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
      default:
        bg = AppTheme.surfaceSubtle;
        text = AppTheme.textSecondary;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: text)),
    );
  }

  Widget _buildUsersTab(List<dynamic> users) {
    if (users.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No users currently associated with this department.', style: TextStyle(color: AppTheme.textMuted)),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppTheme.surfaceSubtle),
        columns: const [
          DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Phone', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('ID / Roll No', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Role', style: TextStyle(fontWeight: FontWeight.w700))),
        ],
        rows: users.map((u) {
          return DataRow(cells: [
            DataCell(Text(u['full_name'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.w600))),
            DataCell(Text(u['email'] ?? '-')),
            DataCell(Text(u['phone'] ?? '-')),
            DataCell(Text(u['roll_number'] ?? '-')),
            DataCell(
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppTheme.primarySurface, borderRadius: BorderRadius.circular(4)),
                child: Text(u['role'] ?? 'USER', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryDark)),
              ),
            ),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildPrintersTab(List<dynamic> printers) {
    if (printers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No printers currently assigned to this department.', style: TextStyle(color: AppTheme.textMuted)),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppTheme.surfaceSubtle),
        columns: const [
          DataColumn(label: Text('Printer Name', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('CUPS Queue', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Color', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Duplex', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w700))),
        ],
        rows: printers.map((p) {
          final isColor = p['supports_color'] == true;
          final isDuplex = p['supports_duplex'] == true;
          final isActive = p['is_active'] == true;
          return DataRow(cells: [
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.print_outlined, size: 16, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(p['display_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            )),
            DataCell(Text(p['cups_printer_name'] ?? '', style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
            DataCell(Text(isColor ? 'Color & B&W' : 'B&W Only')),
            DataCell(Text(isDuplex ? '2-Sided' : '1-Sided')),
            DataCell(
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive ? AppTheme.successSurface : AppTheme.dangerSurface,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isActive ? 'Active' : 'Inactive',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isActive ? AppTheme.success : AppTheme.danger),
                ),
              ),
            ),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildJobsTab(List<dynamic> jobs) {
    if (jobs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No print jobs recorded for this department yet.', style: TextStyle(color: AppTheme.textMuted)),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppTheme.surfaceSubtle),
        columns: const [
          DataColumn(label: Text('Job ID', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Document', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('User', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Pages', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.w700))),
        ],
        rows: jobs.map((j) {
          final isColor = j['is_color'] == true;
          return DataRow(cells: [
            DataCell(Text(j['id'] ?? '', style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
            DataCell(Text(j['document_name'] ?? 'Document', style: const TextStyle(fontWeight: FontWeight.w500))),
            DataCell(Text(j['user_name'] ?? 'User')),
            DataCell(Text('${j['pages']} (${j['copies']}x)')),
            DataCell(Text(isColor ? 'Color' : 'B&W', style: TextStyle(color: isColor ? const Color(0xFF7E22CE) : AppTheme.textSecondary, fontWeight: FontWeight.w600))),
            DataCell(_buildStatusChip(j['status'] ?? 'QUEUED')),
            DataCell(Text(j['created_at'] ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
          ]);
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 900,
          maxHeight: size.height * 0.85,
        ),
        child: _isLoading
            ? const Padding(
                padding: EdgeInsets.all(48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(strokeWidth: 2),
                    SizedBox(height: 16),
                    Text('Loading department information...'),
                  ],
                ),
              )
            : _errorMessage != null
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: AppTheme.danger, size: 40),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, style: const TextStyle(color: AppTheme.danger)),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _loadDetail, child: const Text('Retry')),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppTheme.primarySurface,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.business_rounded, color: AppTheme.primary, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        _detail!['name'] ?? widget.departmentName,
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primarySurface,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          _detail!['code'] ?? '',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryDark),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_detail!['description'] != null)
                                    Text(
                                      _detail!['description'],
                                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      ),
                      // Summary Ribbon
                      Container(
                        color: AppTheme.surfaceSubtle,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildMiniKpi('Users', '${_detail!['users_count'] ?? 0}'),
                            _buildMiniKpi('Printers', '${_detail!['printers_count'] ?? 0}'),
                            _buildMiniKpi('Print Jobs', '${_detail!['jobs_count'] ?? 0}'),
                            _buildMiniKpi('Total Pages', '${_detail!['pages_count'] ?? 0}'),
                            _buildMiniKpi('Color Pages', '${_detail!['color_pages'] ?? 0}'),
                            _buildMiniKpi('B&W Pages', '${_detail!['bw_pages'] ?? 0}'),
                          ],
                        ),
                      ),
                      // Tabs Header
                      TabBar(
                        controller: _tabController,
                        labelColor: AppTheme.primary,
                        unselectedLabelColor: AppTheme.textSecondary,
                        indicatorColor: AppTheme.primary,
                        tabs: [
                          Tab(text: 'Users (${(_detail!['users'] as List).length})'),
                          Tab(text: 'Printers (${(_detail!['printers'] as List).length})'),
                          Tab(text: 'Recent Print Jobs (${(_detail!['recent_jobs'] as List).length})'),
                        ],
                      ),
                      // Tab Views
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildUsersTab(_detail!['users'] ?? []),
                            _buildPrintersTab(_detail!['printers'] ?? []),
                            _buildJobsTab(_detail!['recent_jobs'] ?? []),
                          ],
                        ),
                      ),
                      // Dialog Footer Actions
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Close'),
                            ),
                            const SizedBox(width: 12),
                            FilledButton.icon(
                              icon: const Icon(Icons.assessment_outlined, size: 18),
                              label: const Text('Department Report'),
                              onPressed: () {
                                final deptId = _detail!['id'] as int?;
                                Navigator.of(context).pop();
                                Navigator.of(context).pushNamed(
                                  '/admin/reports',
                                  arguments: {'department_id': deptId},
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildMiniKpi(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }
}
