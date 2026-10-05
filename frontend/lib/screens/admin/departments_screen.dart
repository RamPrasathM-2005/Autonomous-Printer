import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/admin_api_service.dart';
import '../../widgets/admin/stat_card.dart';
import 'admin_shell.dart';
import 'department_detail_dialog.dart';

class DepartmentsScreen extends StatefulWidget {
  const DepartmentsScreen({super.key});

  @override
  State<DepartmentsScreen> createState() => _DepartmentsScreenState();
}

class _DepartmentsScreenState extends State<DepartmentsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _departments = [];
  String _searchQuery = '';
  String _sortBy = 'name'; // 'name', 'pages', 'users', 'jobs'
  bool _sortAsc = true;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await AdminApiService.getDepartments();
      if (mounted) {
        setState(() {
          _departments = items;
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

  List<Map<String, dynamic>> _getFilteredAndSortedDepartments() {
    var list = _departments.where((d) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final name = (d['name'] ?? '').toString().toLowerCase();
      final code = (d['code'] ?? '').toString().toLowerCase();
      final desc = (d['description'] ?? '').toString().toLowerCase();
      return name.contains(q) || code.contains(q) || desc.contains(q);
    }).toList();

    list.sort((a, b) {
      int cmp = 0;
      switch (_sortBy) {
        case 'pages':
          final pA = (a['pages_count'] as num?) ?? 0;
          final pB = (b['pages_count'] as num?) ?? 0;
          cmp = pA.compareTo(pB);
          break;
        case 'users':
          final uA = (a['users_count'] as num?) ?? 0;
          final uB = (b['users_count'] as num?) ?? 0;
          cmp = uA.compareTo(uB);
          break;
        case 'jobs':
          final jA = (a['jobs_count'] as num?) ?? 0;
          final jB = (b['jobs_count'] as num?) ?? 0;
          cmp = jA.compareTo(jB);
          break;
        case 'name':
        default:
          final nA = (a['name'] ?? '').toString();
          final nB = (b['name'] ?? '').toString();
          cmp = nA.compareTo(nB);
          break;
      }
      return _sortAsc ? cmp : -cmp;
    });

    return list;
  }

  Widget _buildKpiRibbon() {
    final totalDepts = _departments.length;
    final totalUsers = _departments.fold<int>(0, (sum, d) => sum + ((d['users_count'] as num?)?.toInt() ?? 0));
    final totalPrinters = _departments.fold<int>(0, (sum, d) => sum + ((d['printers_count'] as num?)?.toInt() ?? 0));
    final totalPages = _departments.fold<int>(0, (sum, d) => sum + ((d['pages_count'] as num?)?.toInt() ?? 0));

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
            title: 'Configured Departments',
            value: '$totalDepts',
            icon: Icons.business_rounded,
            iconColor: AppTheme.primary,
            subtitle: 'Active business units',
          ),
          StatCard(
            title: 'Department Staff & Users',
            value: '$totalUsers',
            icon: Icons.people_alt_rounded,
            iconColor: const Color(0xFF7C3AED),
            subtitle: 'Enrolled in departments',
          ),
          StatCard(
            title: 'Assigned Printers',
            value: '$totalPrinters',
            icon: Icons.print_rounded,
            iconColor: AppTheme.success,
            subtitle: 'Allocated hardware',
          ),
          StatCard(
            title: 'Total Pages Printed',
            value: '$totalPages',
            icon: Icons.receipt_long_rounded,
            iconColor: const Color(0xFFD97706),
            subtitle: 'Cumulative consumption',
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

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredAndSortedDepartments();

    return AdminShell(
      currentSection: AdminNavSection.departments,
      title: 'Department Management',
      onRefresh: _loadDepartments,
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(strokeWidth: 2),
                  SizedBox(height: 16),
                  Text('Loading department directory...'),
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
                            'Unable to load departments',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary)),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: _loadDepartments,
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
                                'Department Directory & Utilization',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Manage business units, view associated users and hardware allocations.',
                                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                          OutlinedButton.icon(
                            onPressed: _loadDepartments,
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Refresh'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // KPI Ribbon
                      _buildKpiRibbon(),
                      const SizedBox(height: 24),

                      // Search & Filter Toolbar
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: AppTheme.border),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 40,
                                  child: TextField(
                                    decoration: InputDecoration(
                                      hintText: 'Search departments by name or code (e.g. HR, Finance, IT)...',
                                      hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                                      prefixIcon: const Icon(Icons.search, size: 18),
                                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
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
                                    onChanged: (val) => setState(() => _searchQuery = val),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Sort dropdown
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceSubtle,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _sortBy,
                                    icon: Icon(_sortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 16),
                                    items: const [
                                      DropdownMenuItem(value: 'name', child: Text('Sort by Name')),
                                      DropdownMenuItem(value: 'pages', child: Text('Sort by Pages')),
                                      DropdownMenuItem(value: 'users', child: Text('Sort by Users')),
                                      DropdownMenuItem(value: 'jobs', child: Text('Sort by Jobs')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          if (_sortBy == val) {
                                            _sortAsc = !_sortAsc;
                                          } else {
                                            _sortBy = val;
                                            _sortAsc = val == 'name';
                                          }
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Departments Table
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
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${filtered.length} Departments Found',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                                  ),
                                  if (_searchQuery.isNotEmpty)
                                    TextButton.icon(
                                      icon: const Icon(Icons.clear, size: 16),
                                      label: const Text('Clear Filter'),
                                      onPressed: () => setState(() => _searchQuery = ''),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (filtered.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(40),
                                  alignment: Alignment.center,
                                  child: const Column(
                                    children: [
                                      Icon(Icons.business_outlined, size: 48, color: AppTheme.textMuted),
                                      SizedBox(height: 12),
                                      Text(
                                        'No departments match your search query.',
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
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
                                      DataColumn(label: Text('Department', style: TextStyle(fontWeight: FontWeight.w700))),
                                      DataColumn(label: Text('Code', style: TextStyle(fontWeight: FontWeight.w700))),
                                      DataColumn(label: Text('Users', style: TextStyle(fontWeight: FontWeight.w700))),
                                      DataColumn(label: Text('Printers', style: TextStyle(fontWeight: FontWeight.w700))),
                                      DataColumn(label: Text('Print Jobs', style: TextStyle(fontWeight: FontWeight.w700))),
                                      DataColumn(label: Text('Pages', style: TextStyle(fontWeight: FontWeight.w700))),
                                      DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.w700))),
                                    ],
                                    rows: filtered.map((d) {
                                      final deptId = d['id'] as int;
                                      final deptName = d['name'] ?? '';
                                      final deptCode = d['code'] ?? '';
                                      final desc = d['description'] as String?;

                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 34,
                                                  height: 34,
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.primarySurface,
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: const Icon(Icons.business_rounded, size: 18, color: AppTheme.primary),
                                                ),
                                                const SizedBox(width: 10),
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text(deptName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                                    if (desc != null && desc.isNotEmpty)
                                                      Text(desc, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          DataCell(
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primarySurface,
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: AppTheme.primaryBorder),
                                              ),
                                              child: Text(
                                                deptCode,
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryDark),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.people_alt_outlined, size: 15, color: AppTheme.textSecondary),
                                                const SizedBox(width: 6),
                                                Text('${d['users_count'] ?? 0}'),
                                              ],
                                            ),
                                          ),
                                          DataCell(
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.print_outlined, size: 15, color: AppTheme.textSecondary),
                                                const SizedBox(width: 6),
                                                Text('${d['printers_count'] ?? 0}'),
                                              ],
                                            ),
                                          ),
                                          DataCell(
                                            Text('${d['jobs_count'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w500)),
                                          ),
                                          DataCell(
                                            Text(
                                              '${d['pages_count'] ?? 0}',
                                              style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primaryDark),
                                            ),
                                          ),
                                          DataCell(
                                            OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                visualDensity: VisualDensity.compact,
                                              ),
                                              icon: const Icon(Icons.visibility_outlined, size: 15),
                                              label: const Text('View'),
                                              onPressed: () => DepartmentDetailDialog.show(context, deptId, deptName),
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
                      ),
                    ],
                  ),
                ),
    );
  }
}
