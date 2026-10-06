import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../config/theme.dart';
import '../../services/admin_api_service.dart';
import '../../utils/download_helper.dart';
import '../../widgets/admin/stat_card.dart';
import 'admin_shell.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _users = [];
  List<dynamic> _departments = [];

  int _currentPage = 1;
  int _totalPages = 1;
  int _totalUsers = 0;
  final int _limit = 15;

  String _searchQuery = '';
  int? _selectedDeptId;
  String? _selectedRole;
  bool? _selectedIsActive;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final depts = await AdminApiService.getDepartments();
      if (mounted) {
        setState(() {
          _departments = depts;
        });
      }
    } catch (_) {}
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await AdminApiService.getUsers(
        page: _currentPage,
        limit: _limit,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        departmentId: _selectedDeptId,
        role: _selectedRole,
        isActive: _selectedIsActive,
      );

      if (mounted) {
        setState(() {
          _users = res['users'] as List<dynamic>? ?? [];
          _totalUsers = res['total'] as int? ?? 0;
          _totalPages = res['total_pages'] as int? ?? 1;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showEditUserDialog(Map<String, dynamic> user) async {
    final nameCtrl = TextEditingController(text: user['full_name'] ?? '');
    int? selectedDept = user['department_id'] as int?;
    String selectedRole = user['role'] ?? 'USER';
    bool isActive = user['is_active'] == true;

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primarySurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person_outline, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Manage User Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${user['email'] ?? user['roll_number'] ?? 'User #${user['id']}'}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textMuted)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int?>(
                    value: selectedDept,
                    decoration: InputDecoration(
                      labelText: 'Department',
                      prefixIcon: const Icon(Icons.business_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Unassigned'),
                      ),
                      ..._departments.map((d) => DropdownMenuItem<int?>(
                            value: d['id'] as int,
                            child: Text('${d['name']} (${d['code']})'),
                          )),
                    ],
                    onChanged: (val) {
                      setDialogState(() => selectedDept = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: InputDecoration(
                      labelText: 'System Role',
                      prefixIcon: const Icon(Icons.security_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'USER', child: Text('Standard User / Student')),
                      DropdownMenuItem(value: 'ADMIN', child: Text('Administrator')),
                      DropdownMenuItem(value: 'SUPER_ADMIN', child: Text('Super Admin')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedRole = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Account Active', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Allow student or staff to log in and print', style: TextStyle(fontSize: 12)),
                    value: isActive,
                    activeColor: AppTheme.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      setDialogState(() => isActive = val);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                try {
                  await AdminApiService.updateUser(user['id'] as int, {
                    'full_name': nameCtrl.text.trim(),
                    'department_id': selectedDept ?? 0,
                    'role': selectedRole,
                    'is_active': isActive,
                  });
                  if (ctx.mounted) Navigator.of(ctx).pop(true);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.danger),
                    );
                  }
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );

    if (updated == true) {
      _loadUsers();
    }
  }

  Future<void> _downloadTemplate() async {
    try {
      final bytes = await AdminApiService.downloadRosterTemplate();
      await downloadFile(bytes, 'student_roster_template.xlsx');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Roster template (.xlsx) downloaded successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download template: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _showImportRosterDialog() async {
    String? pickedFileName;
    Uint8List? pickedFileBytes;
    bool isImporting = false;
    Map<String, dynamic>? importResult;
    String? importError;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primarySurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.upload_file_rounded, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Import Student & Staff Roster', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Upload an Excel (.xlsx) or CSV (.csv) roster with headers: Roll Number, Full Name, Email, Phone, Department Code, Role.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                if (importResult != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.success.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 20),
                            SizedBox(width: 8),
                            Text('Roster Import Completed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.success)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('• Total Rows Processed: ${importResult!['total_rows']}', style: const TextStyle(fontSize: 13)),
                        Text('• New Accounts Created: ${importResult!['created']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text('• Existing Accounts Updated: ${importResult!['updated']}', style: const TextStyle(fontSize: 13)),
                        if ((importResult!['failed'] as num? ?? 0) > 0)
                          Text('• Failed / Skipped Rows: ${importResult!['failed']}', style: const TextStyle(fontSize: 13, color: AppTheme.danger)),
                      ],
                    ),
                  ),
                ] else ...[
                  InkWell(
                    onTap: isImporting
                        ? null
                        : () async {
                            try {
                              final List<PlatformFile> files = await FilePicker.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: ['xlsx', 'xls', 'csv'],
                              );
                              if (files.isNotEmpty) {
                                final file = files.first;
                                final bytes = await file.readAsBytes();
                                setDialogState(() {
                                  pickedFileName = file.name;
                                  pickedFileBytes = bytes;
                                  importError = null;
                                });
                              }
                            } catch (e) {
                              setDialogState(() {
                                importError = 'Failed to select file: $e';
                              });
                            }
                          },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceSubtle,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: pickedFileName != null ? AppTheme.primary : AppTheme.border,
                          width: pickedFileName != null ? 1.5 : 1,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              pickedFileName != null ? Icons.description_rounded : Icons.cloud_upload_outlined,
                              size: 40,
                              color: pickedFileName != null ? AppTheme.primary : AppTheme.textMuted,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              pickedFileName ?? 'Click to select .xlsx or .csv roster file',
                              style: TextStyle(
                                fontWeight: pickedFileName != null ? FontWeight.bold : FontWeight.w500,
                                fontSize: 14,
                                color: pickedFileName != null ? AppTheme.primary : AppTheme.textPrimary,
                              ),
                            ),
                            if (pickedFileBytes != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text('${(pickedFileBytes!.lengthInBytes / 1024).toStringAsFixed(1)} KB',
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _downloadTemplate();
                        },
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Download Sample Template (.xlsx)', style: TextStyle(fontSize: 12)),
                      ),
                      if (pickedFileName != null)
                        TextButton(
                          onPressed: () => setDialogState(() {
                            pickedFileName = null;
                            pickedFileBytes = null;
                          }),
                          child: const Text('Clear File', style: TextStyle(color: AppTheme.danger, fontSize: 12)),
                        ),
                    ],
                  ),
                  if (importError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(importError!, style: const TextStyle(color: AppTheme.danger, fontSize: 12)),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(importResult != null ? 'Done' : 'Cancel'),
            ),
            if (importResult == null)
              FilledButton.icon(
                onPressed: (pickedFileBytes == null || isImporting)
                    ? null
                    : () async {
                        setDialogState(() {
                          isImporting = true;
                          importError = null;
                        });
                        try {
                          final res = await AdminApiService.importUserRoster(pickedFileBytes!, pickedFileName!);
                          setDialogState(() {
                            isImporting = false;
                            importResult = res;
                          });
                          _loadUsers();
                        } catch (e) {
                          setDialogState(() {
                            isImporting = false;
                            importError = e.toString().replaceAll('Exception: ', '');
                          });
                        }
                      },
                icon: isImporting
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.file_upload_outlined, size: 16),
                label: Text(isImporting ? 'Importing Roster...' : 'Upload & Ingest Roster'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      currentSection: AdminNavSection.users,
      title: 'Users & Directory',
      onRefresh: _loadUsers,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final activeCount = _users.where((u) => u['is_active'] == true).length;
    final totalPagesSum = _users.fold<int>(0, (sum, u) => sum + ((u['total_pages'] as num?)?.toInt() ?? 0));
    final totalSpentSum = _users.fold<double>(0.0, (sum, u) => sum + ((u['total_spent'] as num?)?.toDouble() ?? 0.0));

    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Summary Row
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 900;
                return GridView.count(
                  crossAxisCount: isNarrow ? 2 : 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableCardImpossiblePhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: isNarrow ? 1.6 : 1.45,
                  children: [
                    StatCard(
                      title: 'Total Users',
                      value: '$_totalUsers',
                      icon: Icons.people_outline_rounded,
                      iconColor: AppTheme.primary,
                      subtitle: 'Registered Accounts',
                    ),
                    StatCard(
                      title: 'Active Accounts',
                      value: '$activeCount',
                      icon: Icons.how_to_reg_outlined,
                      iconColor: AppTheme.success,
                      subtitle: 'Permitted to Print',
                    ),
                    StatCard(
                      title: 'Pages Printed',
                      value: '$totalPagesSum',
                      icon: Icons.description_outlined,
                      iconColor: const Color(0xFF0284C7),
                      subtitle: 'Across Loaded Users',
                    ),
                    StatCard(
                      title: 'Total Spending',
                      value: '₹${totalSpentSum.toStringAsFixed(2)}',
                      icon: Icons.account_balance_wallet_outlined,
                      iconColor: const Color(0xFFF59E0B),
                      subtitle: 'Volume Value',
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Toolbar
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppTheme.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Search box
                    SizedBox(
                      width: 280,
                      child: TextField(
                        onChanged: (val) {
                          _searchQuery = val.trim();
                          _currentPage = 1;
                          _loadUsers();
                        },
                        decoration: InputDecoration(
                          hintText: 'Search roll no, name, email...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),

                    // Department Filter
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          value: _selectedDeptId,
                          isDense: true,
                          style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                          items: [
                            const DropdownMenuItem<int?>(value: null, child: Text('Department: All Departments')),
                            ..._departments.map((d) => DropdownMenuItem<int?>(
                                  value: d['id'] as int,
                                  child: Text('Department: ${d['name']}'),
                                )),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedDeptId = val;
                              _currentPage = 1;
                            });
                            _loadUsers();
                          },
                        ),
                      ),
                    ),

                    // Role Filter
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _selectedRole,
                          isDense: true,
                          style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                          items: const [
                            DropdownMenuItem<String?>(value: null, child: Text('Role: All Roles')),
                            DropdownMenuItem<String?>(value: 'USER', child: Text('Role: Students / Users')),
                            DropdownMenuItem<String?>(value: 'ADMIN', child: Text('Role: Administrators')),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedRole = val;
                              _currentPage = 1;
                            });
                            _loadUsers();
                          },
                        ),
                      ),
                    ),

                    // Refresh Button
                    OutlinedButton.icon(
                      onPressed: _loadUsers,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Refresh', style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),

                    // Download Roster Template (.xlsx)
                    OutlinedButton.icon(
                      onPressed: _downloadTemplate,
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Template (.xlsx)', style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),

                    // Import Roster (.xlsx / .csv)
                    FilledButton.icon(
                      onPressed: _showImportRosterDialog,
                      icon: const Icon(Icons.upload_file_rounded, size: 16),
                      label: const Text('Import Roster', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // User Table Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppTheme.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('User Directory ($_totalUsers total)',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        Text('Page $_currentPage of $_totalPages',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_isLoading)
                      const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
                    else if (_error != null)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(child: Text(_error!, style: const TextStyle(color: AppTheme.danger))),
                      )
                    else
                      _buildUsersTable(_users),
                    const SizedBox(height: 16),
                    _buildPaginationControls(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTable(List<dynamic> users) {
    if (users.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        alignment: Alignment.center,
        child: const Text('No users found matching current filters.', style: TextStyle(color: AppTheme.textMuted)),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppTheme.surfaceSubtle),
        columns: const [
          DataColumn(label: Text('Student / User', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Roll / ID', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Department', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Role', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Total Orders', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Pages Printed', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Spent', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w700))),
        ],
        rows: users.map((u) {
          final isActive = u['is_active'] == true;
          final role = (u['role'] ?? 'USER').toString().toUpperCase();

          return DataRow(
            cells: [
              DataCell(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(u['full_name'] ?? 'Unnamed User', style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(u['email'] ?? u['phone'] ?? '-', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
              ),
              DataCell(Text(u['roll_number'] ?? '-')),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySurface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    u['department_name'] ?? 'Unassigned',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primary),
                  ),
                ),
              ),
              DataCell(_buildRoleBadge(role)),
              DataCell(_buildActiveBadge(isActive)),
              DataCell(Text('${u['total_orders'] ?? 0}')),
              DataCell(Text('${u['total_pages'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text('₹${((u['total_spent'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}')),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Edit User Account',
                      onPressed: () => _showEditUserDialog(u),
                    ),
                    IconButton(
                      icon: const Icon(Icons.receipt_long_outlined, size: 18, color: AppTheme.primary),
                      tooltip: 'View Print Jobs',
                      onPressed: () {
                        Navigator.of(context).pushNamed(
                          '/admin/reports',
                          arguments: {'user_id': u['id']},
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    final isAdmin = role.contains('ADMIN');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isAdmin ? const Color(0xFFEDE9FE) : AppTheme.surfaceSubtle,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        role,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isAdmin ? const Color(0xFF7C3AED) : AppTheme.textMuted,
        ),
      ),
    );
  }

  Widget _buildActiveBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.success.withOpacity(0.12) : AppTheme.danger.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isActive ? 'Active' : 'Suspended',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isActive ? AppTheme.success : AppTheme.danger,
        ),
      ),
    );
  }

  Widget _buildPaginationControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Showing ${(_currentPage - 1) * _limit + 1} - ${((_currentPage - 1) * _limit + _users.length)} of $_totalUsers',
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        Row(
          children: [
            OutlinedButton(
              onPressed: _currentPage > 1
                  ? () {
                      setState(() => _currentPage--);
                      _loadUsers();
                    }
                  : null,
              child: const Text('Previous'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _currentPage < _totalPages
                  ? () {
                      setState(() => _currentPage++);
                      _loadUsers();
                    }
                  : null,
              child: const Text('Next'),
            ),
          ],
        ),
      ],
    );
  }
}
class NeverScrollableCardImpossiblePhysics extends ScrollPhysics {
  const NeverScrollableCardImpossiblePhysics({super.parent});
  @override
  NeverScrollableCardImpossiblePhysics applyTo(ScrollPhysics? ancestor) {
    return NeverScrollableCardImpossiblePhysics(parent: buildParent(ancestor));
  }
  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) => false;
}
