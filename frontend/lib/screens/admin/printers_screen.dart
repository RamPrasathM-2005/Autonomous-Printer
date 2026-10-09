import 'dart:async';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/admin_api_service.dart';
import '../../widgets/admin/stat_card.dart';
import 'admin_shell.dart';

class PrintersScreen extends StatefulWidget {
  const PrintersScreen({super.key});

  @override
  State<PrintersScreen> createState() => _PrintersScreenState();
}

class _PrintersScreenState extends State<PrintersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  Timer? _refreshTimer;
  bool _refreshInFlight = false;
  String? _error;

  List<dynamic> _printers = [];
  List<dynamic> _agents = [];
  List<dynamic> _departments = [];

  String _searchQuery = '';
  String _statusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _loadData(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (_refreshInFlight) return;
    _refreshInFlight = true;
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait([
        AdminApiService.getPrinters(),
        AdminApiService.getPrintAgents(),
        AdminApiService.getDepartments(),
      ]);

      if (mounted) {
        setState(() {
          _error = null;
          _printers = results[0];
          _agents = results[1];
          _departments = results[2];
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
    _refreshInFlight = false;
  }

  List<dynamic> get _filteredPrinters {
    return _printers.where((p) {
      final name = (p['display_name'] ?? '').toString().toLowerCase();
      final cupsName = (p['cups_printer_name'] ?? '').toString().toLowerCase();
      final location = (p['location'] ?? p['server_location'] ?? '').toString().toLowerCase();
      final dept = (p['department_name'] ?? '').toString().toLowerCase();
      final serverId = (p['server_id'] ?? '').toString().toLowerCase();

      final matchesSearch = _searchQuery.isEmpty ||
          name.contains(_searchQuery) ||
          cupsName.contains(_searchQuery) ||
          location.contains(_searchQuery) ||
          dept.contains(_searchQuery) ||
          serverId.contains(_searchQuery);

      final isActive = p['is_active'] == true;

      bool matchesStatus = true;
      if (_statusFilter == 'ACTIVE') {
        matchesStatus = isActive;
      } else if (_statusFilter == 'INACTIVE') {
        matchesStatus = !isActive;
      }

      return matchesSearch && matchesStatus;
    }).toList();
  }

  Future<void> _togglePrinterActive(String printerId) async {
    try {
      await AdminApiService.togglePrinterActive(printerId);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Printer status updated successfully.'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _showRegisterPrinterDialog({Map<String, dynamic>? prefill}) async {
    final nameCtrl = TextEditingController(text: prefill?['display_name'] ?? '');
    final cupsCtrl = TextEditingController(text: prefill?['cups_printer_name'] ?? '');
    final locationCtrl = TextEditingController(text: prefill?['location'] ?? '');
    String? selectedServerId = prefill?['server_id'] ?? (_agents.isNotEmpty ? _agents.first['id'].toString() : null);
    int? selectedDeptId = prefill?['department_id'] as int?;
    bool isEnabled = true;

    if (selectedDeptId == null && selectedServerId != null) {
      final matchingAgent = _agents.firstWhere(
        (a) => a['id'].toString() == selectedServerId,
        orElse: () => null,
      );
      if (matchingAgent != null) {
        selectedDeptId = matchingAgent['department_id'] as int?;
      }
    }

    final created = await showDialog<bool>(
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
                child: const Icon(Icons.print_outlined, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Map CUPS Printer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Register a local CUPS printer to this Print Agent station.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: cupsCtrl,
                    decoration: InputDecoration(
                      labelText: 'CUPS Printer Name (Queue) *',
                      hintText: 'e.g. HP_LaserJet_400_M401dn_E9A0F4',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.settings_ethernet, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Display Name *',
                      hintText: 'e.g. HP LaserJet 400 (Unit 1)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: selectedServerId,
                    decoration: InputDecoration(
                      labelText: 'Assigned Print Agent *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.router_outlined, size: 20),
                    ),
                    items: _agents.map((a) {
                      return DropdownMenuItem<String>(
                        value: a['id'].toString(),
                        child: Text('${a['name']} (${a['id']})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedServerId = val;
                          final matching = _agents.firstWhere((a) => a['id'].toString() == val, orElse: () => null);
                          if (matching != null && matching['department_id'] != null) {
                            selectedDeptId = matching['department_id'] as int?;
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int?>(
                    value: selectedDeptId,
                    decoration: InputDecoration(
                      labelText: 'Department',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.school_outlined, size: 20),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('General / All Campus')),
                      ..._departments.map((d) => DropdownMenuItem<int?>(
                            value: d['id'] as int,
                            child: Text('${d['name']} (${d['code']})'),
                          )),
                    ],
                    onChanged: (val) => setDialogState(() => selectedDeptId = val),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: locationCtrl,
                    decoration: InputDecoration(
                      labelText: 'Location / Notes (Optional)',
                      hintText: 'e.g. Lab Corner, Ground Floor',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.place_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    dense: true,
                    title: const Text('Printer Enabled & Active', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Available for student print releases', style: TextStyle(fontSize: 11)),
                    value: isEnabled,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppTheme.primary,
                    onChanged: (v) => setDialogState(() => isEnabled = v),
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
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
              onPressed: () async {
                final cupsName = cupsCtrl.text.trim();
                final dispName = nameCtrl.text.trim();

                if (cupsName.isEmpty || dispName.isEmpty || selectedServerId == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Please complete CUPS Name, Display Name, and Print Agent.')),
                  );
                  return;
                }

                try {
                  await AdminApiService.createPrinter({
                    'cups_printer_name': cupsName,
                    'display_name': dispName,
                    'server_id': selectedServerId,
                    'department_id': selectedDeptId,
                    'location': locationCtrl.text.trim().isNotEmpty ? locationCtrl.text.trim() : null,
                    'is_enabled': isEnabled,
                    'is_active': false,
                    'device_uri': prefill?['device_uri'],
                    'ip_address': prefill?['ip_address'],
                  });
                  if (ctx.mounted) Navigator.of(ctx).pop(true);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger),
                    );
                  }
                }
              },
              child: const Text('Save & Map Printer'),
            ),
          ],
        ),
      ),
    );

    if (created == true) {
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Printer mapped and activated successfully.'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    }
  }

  Future<void> _showEditPrinterDialog(Map<String, dynamic> printer) async {
    final nameCtrl = TextEditingController(text: printer['display_name'] ?? '');
    final locationCtrl = TextEditingController(text: printer['location'] ?? '');
    int? selectedDeptId = printer['department_id'] as int?;
    String selectedServerId = printer['server_id'] ?? (_agents.isNotEmpty ? _agents.first['id'] : '');
    bool isEnabled = printer['is_enabled'] != false;
    bool isActive = printer['is_active'] == true;

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Edit ${printer['display_name']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Display Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedServerId,
                    decoration: InputDecoration(
                      labelText: 'Assigned Print Agent',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.router_outlined, size: 20),
                    ),
                    items: _agents.map((a) {
                      return DropdownMenuItem<String>(
                        value: a['id'].toString(),
                        child: Text('${a['name']} (${a['id']})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedServerId = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    value: selectedDeptId,
                    decoration: InputDecoration(
                      labelText: 'Department',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.school_outlined, size: 20),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('General / All Campus')),
                      ..._departments.map((d) => DropdownMenuItem<int?>(
                            value: d['id'] as int,
                            child: Text('${d['name']} (${d['code']})'),
                          )),
                    ],
                    onChanged: (val) => setDialogState(() => selectedDeptId = val),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: locationCtrl,
                    decoration: InputDecoration(
                      labelText: 'Location / Notes',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.place_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Printer Enabled', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Toggle routing and user availability', style: TextStyle(fontSize: 11)),
                    value: isEnabled,
                    activeColor: AppTheme.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setDialogState(() {
                      isEnabled = val;
                      isActive = val;
                    }),
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
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
              onPressed: () async {
                try {
                  await AdminApiService.updatePrinter(printer['id'].toString(), {
                    'display_name': nameCtrl.text.trim(),
                    'location': locationCtrl.text.trim().isNotEmpty ? locationCtrl.text.trim() : null,
                    'server_id': selectedServerId,
                    'department_id': selectedDeptId ?? 0,
                    'is_enabled': isEnabled,
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

    if (updated == true) _loadData();
  }

  Future<void> _deletePrinter(Map<String, dynamic> printer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Printer Mapping'),
        content: Text('Are you sure you want to remove "${printer['display_name']}" from Print Agent?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await AdminApiService.deletePrinter(printer['id'].toString());
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Printer mapping deleted successfully.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete failed: $e'), backgroundColor: AppTheme.danger),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      currentSection: AdminNavSection.printers,
      title: 'Printer Management',
      onRefresh: _loadData,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(fontSize: 15, color: AppTheme.danger)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Tabs Header
        Container(
          color: Theme.of(context).cardColor,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: AppTheme.primary,
                  indicatorColor: AppTheme.primary,
                  tabs: [
                    Tab(
                      child: Row(
                        children: [
                          const Text('Registered Printers'),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppTheme.primarySurface, borderRadius: BorderRadius.circular(10)),
                            child: Text('${_printers.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                          ),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        children: [
                          const Text('Print Agents'),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppTheme.surfaceSubtle, borderRadius: BorderRadius.circular(10)),
                            child: Text('${_agents.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Register Printer'),
                style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                onPressed: () => _showRegisterPrinterDialog(),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPrintersTab(),
              _buildAgentsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrintersTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Summary Row
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 900;
                final activeCount = _printers.where((p) => p['is_active'] == true).length;

                return GridView.count(
                  crossAxisCount: isNarrow ? 2 : 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: isNarrow ? 2.2 : 2.5,
                  children: [
                    StatCard(
                      title: 'Total Registered',
                      value: '${_printers.length}',
                      icon: Icons.print_outlined,
                      iconColor: AppTheme.primary,
                      iconBgColor: AppTheme.primarySurface,
                    ),
                    StatCard(
                      title: 'Active Printers',
                      value: '$activeCount',
                      icon: Icons.check_circle_outline,
                      iconColor: AppTheme.success,
                      iconBgColor: AppTheme.success.withOpacity(0.12),
                    ),
                    StatCard(
                      title: 'Print Agents',
                      value: '${_agents.length}',
                      icon: Icons.developer_board_outlined,
                      iconColor: AppTheme.secondary,
                      iconBgColor: AppTheme.secondary.withOpacity(0.12),
                    ),
                    StatCard(
                      title: 'Departments',
                      value: '${_departments.length}',
                      icon: Icons.school_outlined,
                      iconColor: AppTheme.warning,
                      iconBgColor: AppTheme.warning.withOpacity(0.12),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Filter Bar
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
              color: Theme.of(context).cardColor,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search by printer name, CUPS queue, or agent...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                      ),
                    ),
                    const SizedBox(width: 16),
                    DropdownButton<String>(
                      value: _statusFilter,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                        DropdownMenuItem(value: 'ACTIVE', child: Text('Active Only')),
                        DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive Only')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _statusFilter = val);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Printers Data Table
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
              color: Theme.of(context).cardColor,
              child: _buildPrintersTable(_filteredPrinters),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrintersTable(List<dynamic> printers) {
    if (printers.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        alignment: Alignment.center,
        child: const Text('No printers found matching criteria.', style: TextStyle(color: AppTheme.textMuted)),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppTheme.surfaceSubtle),
        columns: const [
          DataColumn(label: Text('Printer Name', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('CUPS Queue', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Assigned Print Agent', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Department', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Location', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w700))),
        ],
        rows: printers.map((p) {
          final String pid = p['id'].toString();
          final bool isActive = p['is_active'] == true;
          final bool isEnabled = p['is_enabled'] != false;

          return DataRow(
            cells: [
              DataCell(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(p['display_name'] ?? 'Unnamed', style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (p['model'] != null)
                      Text(p['model'], style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
              ),
              DataCell(Text(p['cups_printer_name'] ?? '-', style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
              DataCell(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(p['server_name'] ?? p['server_id'] ?? '-', style: const TextStyle(fontSize: 12)),
                    Text(p['server_status'] ?? '', style: TextStyle(fontSize: 10, color: (p['server_status'] == 'ONLINE') ? AppTheme.success : AppTheme.textMuted)),
                  ],
                ),
              ),
              DataCell(Text(p['department_name'] ?? 'All Campus', style: const TextStyle(fontSize: 12))),
              DataCell(Text(p['location'] ?? p['server_location'] ?? '-', style: const TextStyle(fontSize: 12))),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isActive ? AppTheme.success.withOpacity(0.12) : AppTheme.danger.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isActive ? 'ACTIVE' : (isEnabled ? 'VALIDATION PENDING' : 'DISABLED'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isActive ? AppTheme.success : AppTheme.danger,
                    ),
                  ),
                ),
              ),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        isActive ? Icons.toggle_on : Icons.toggle_off_outlined,
                        size: 22,
                        color: isActive ? AppTheme.success : AppTheme.textMuted,
                      ),
                      tooltip: isActive ? 'Deactivate Printer' : 'Activate Printer',
                      onPressed: () => _togglePrinterActive(pid),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Edit Configuration',
                      onPressed: () => _showEditPrinterDialog(p),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                      tooltip: 'Delete Mapping',
                      onPressed: () => _deletePrinter(p),
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

  Widget _buildAgentsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Registered Print Agents (Raspberry Pi Stations)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Agent'),
                onPressed: () => _showAddAgentDialog(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
            color: Theme.of(context).cardColor,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppTheme.surfaceSubtle),
              columns: const [
                DataColumn(label: Text('Agent ID', style: TextStyle(fontWeight: FontWeight.w700))),
                DataColumn(label: Text('Name & Department', style: TextStyle(fontWeight: FontWeight.w700))),
                DataColumn(label: Text('Static IP Address', style: TextStyle(fontWeight: FontWeight.w700))),
                DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w700))),
                DataColumn(label: Text('Printers', style: TextStyle(fontWeight: FontWeight.w700))),
                DataColumn(label: Text('Last Heartbeat', style: TextStyle(fontWeight: FontWeight.w700))),
                DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w700))),
              ],
              rows: _agents.map((a) {
                final isOnline = (a['status'] ?? '').toString().toUpperCase() == 'ONLINE';
                final deptName = a['department_name'] ?? 'General Campus';
                return DataRow(
                  cells: [
                    DataCell(Text(a['id'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(a['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(deptName, style: const TextStyle(fontSize: 11, color: AppTheme.primary)),
                        ],
                      ),
                    ),
                    DataCell(Text('${a['ip_address'] ?? a['hostname'] ?? 'Localhost'}', style: const TextStyle(fontSize: 12))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isOnline ? AppTheme.success.withOpacity(0.12) : AppTheme.danger.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isOnline ? 'ONLINE' : 'OFFLINE',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isOnline ? AppTheme.success : AppTheme.danger),
                        ),
                      ),
                    ),
                    DataCell(Text('${a['printer_count'] ?? 0}')),
                    DataCell(Text(a['last_heartbeat'] ?? 'Never', style: const TextStyle(fontSize: 12))),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            icon: const Icon(Icons.print_outlined, size: 15),
                            label: const Text('Find Printers'),
                            onPressed: () => _showAgentCupsPrintersDialog(a),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            tooltip: 'Edit Agent',
                            onPressed: () => _showEditAgentDialog(a),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                            tooltip: 'Delete Agent',
                            onPressed: () => _deleteAgent(a),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddAgentDialog() async {
    final nameCtrl = TextEditingController();
    final ipCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    int? selectedDeptId = _departments.isNotEmpty ? _departments.first['id'] as int? : null;

    final createdAgent = await showDialog<Map<String, dynamic>?>(
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
                child: const Icon(Icons.router_outlined, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Add Print Agent', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Connect a departmental Raspberry Pi Print Agent station.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int?>(
                    value: selectedDeptId,
                    decoration: InputDecoration(
                      labelText: 'Department *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.school_outlined, size: 20),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('All Campus / General'),
                      ),
                      ..._departments.map(
                        (d) => DropdownMenuItem<int?>(
                          value: d['id'] as int,
                          child: Text('${d['name']} (${d['code']})'),
                        ),
                      ),
                    ],
                    onChanged: (val) => setDialogState(() => selectedDeptId = val),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: ipCtrl,
                    decoration: InputDecoration(
                      labelText: 'Raspberry Pi Static IP Address *',
                      hintText: 'e.g. 172.17.3.6',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.lan_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Print Agent Name *',
                      hintText: 'e.g. CSE Department Print Station',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: descCtrl,
                    decoration: InputDecoration(
                      labelText: 'Description / Location (Optional)',
                      hintText: 'e.g. Ground Floor, CSE Lab 1',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.place_outlined, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final ip = ipCtrl.text.trim();
                if (name.isEmpty || ip.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Please enter both Print Agent Name and Static IP.')),
                  );
                  return;
                }
                try {
                  final result = await AdminApiService.createPrintAgent({
                    'name': name,
                    'department_id': selectedDeptId,
                    'ip_address': ip,
                    'location': descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                  });
                  if (ctx.mounted) Navigator.pop(ctx, result);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger),
                    );
                  }
                }
              },
              child: const Text('Add Agent'),
            ),
          ],
        ),
      ),
    );

    if (createdAgent != null) {
      await _loadData();
      if (mounted) {
        _showAgentCupsPrintersDialog(createdAgent);
      }
    }
  }

  Future<void> _showAgentCupsPrintersDialog(Map<String, dynamic> agent) async {
    final agentId = agent['id'].toString();
    final agentName = agent['name'] ?? agentId;
    final agentIp = agent['ip_address'] ?? '127.0.0.1';
    final deptId = agent['department_id'] as int?;

    List<dynamic> cupsPrinters = [];
    bool isLoadingCups = true;
    String? cupsError;
    Timer? dialogTimer;
    bool fetching = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> refreshPrinters() async {
            if (fetching) return;
            fetching = true;
            await AdminApiService.getAgentCupsPrinters(agentId).then((data) {
              if (ctx.mounted) {
                setDialogState(() {
                  cupsPrinters = data;
                  isLoadingCups = false;
                  cupsError = null;
                });
              }
            }).catchError((err) {
              if (ctx.mounted) {
                setDialogState(() {
                  isLoadingCups = false;
                  cupsError = err.toString().replaceAll('Exception: ', '');
                });
              }
            });
            fetching = false;
          }
          dialogTimer ??= Timer.periodic(const Duration(seconds: 10), (_) {
            if (ctx.mounted) refreshPrinters();
          });
          if (isLoadingCups) refreshPrinters();

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.print_rounded, color: AppTheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$agentName — Available Printers', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      Text('Raspberry Pi Station at $agentIp', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Rescan Pi CUPS',
                  onPressed: () {
                    setDialogState(() {
                      isLoadingCups = true;
                      cupsError = null;
                    });
                  },
                ),
              ],
            ),
            content: SizedBox(
              width: 580,
              height: 380,
              child: isLoadingCups
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            'Connecting to Print Agent at $agentIp...',
                            style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Scanning CUPS queues on Raspberry Pi...',
                            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    )
                  : (cupsError != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.warning_amber_rounded, size: 40, color: AppTheme.danger),
                              const SizedBox(height: 12),
                              Text(cupsError!, style: const TextStyle(color: AppTheme.danger, fontSize: 13), textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Try Again'),
                                onPressed: () => setDialogState(() {
                                  isLoadingCups = true;
                                  cupsError = null;
                                }),
                              ),
                            ],
                          ),
                        )
                      : (cupsPrinters.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.devices_other_outlined, size: 40, color: AppTheme.textMuted),
                                  const SizedBox(height: 12),
                                  const Text('No printers discovered by this station.', style: TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 6),
                                  const Text('Printers configured on this Raspberry Pi will appear here automatically.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                                  const SizedBox(height: 16),
                                  FilledButton.tonalIcon(
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('Manually Add Printer to Agent'),
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      _showRegisterPrinterDialog(prefill: {
                                        'server_id': agentId,
                                        'department_id': deptId,
                                      });
                                    },
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: cupsPrinters.length,
                              separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (ctx, i) {
                                final p = cupsPrinters[i];
                                final cupsName = p['cups_printer_name'] ?? '';
                                final dispName = p['display_name'] ?? cupsName.replaceAll('_', ' ');
                                final isMapped = p['is_mapped'] == true;
                                final stateStr = (p['status'] ?? 'READY').toString().toUpperCase();

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isMapped ? AppTheme.success.withOpacity(0.12) : AppTheme.primarySurface,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.print,
                                      color: isMapped ? AppTheme.success : AppTheme.primary,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(dispName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  subtitle: Text(
                                    '${p['ip_address'] ?? cupsName} · $stateStr',
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                  ),
                                  trailing: isMapped
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppTheme.success.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.check, size: 14, color: AppTheme.success),
                                              SizedBox(width: 4),
                                              Text('Mapped', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 11)),
                                            ],
                                          ),
                                        )
                                      : FilledButton.icon(
                                          style: FilledButton.styleFrom(
                                            backgroundColor: AppTheme.primary,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                          icon: const Icon(Icons.add, size: 14),
                                          label: const Text('Add Printer'),
                                          onPressed: () async {
                                            try {
                                              await AdminApiService.createPrinter({
                                                'cups_printer_name': cupsName,
                                                'display_name': dispName,
                                                'server_id': agentId,
                                                'department_id': deptId,
                                                'is_enabled': true,
                                                'is_active': false,
                                                'device_uri': p['device_uri'],
                                                'ip_address': p['ip_address'],
                                                'protocol': (p['device_uri'] ?? '').toString().startsWith('ipp') ? 'IPP' : 'Socket',
                                              });
                                              setDialogState(() {
                                                p['is_mapped'] = true;
                                              });
                                              await _loadData();
                                              if (ctx.mounted) {
                                                ScaffoldMessenger.of(ctx).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Printer "$dispName" mapped. Waiting for station confirmation.'),
                                                    backgroundColor: AppTheme.success,
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              if (ctx.mounted) {
                                                ScaffoldMessenger.of(ctx).showSnackBar(
                                                  SnackBar(content: Text('Failed to map: $e'), backgroundColor: AppTheme.danger),
                                                );
                                              }
                                            }
                                          },
                                        ),
                                );
                              },
                            ))),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
    dialogTimer?.cancel();
  }

  Future<void> _showEditAgentDialog(Map<String, dynamic> agent) async {
    final nameCtrl = TextEditingController(text: agent['name'] ?? '');
    final ipCtrl = TextEditingController(text: agent['ip_address'] ?? '');
    final locCtrl = TextEditingController(text: agent['location'] ?? '');
    int? selectedDeptId = agent['department_id'] as int?;

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Edit ${agent['name']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int?>(
                    value: selectedDeptId,
                    decoration: InputDecoration(
                      labelText: 'Department',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.school_outlined, size: 20),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('All Campus / General')),
                      ..._departments.map(
                        (d) => DropdownMenuItem<int?>(
                          value: d['id'] as int,
                          child: Text('${d['name']} (${d['code']})'),
                        ),
                      ),
                    ],
                    onChanged: (val) => setDialogState(() => selectedDeptId = val),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ipCtrl,
                    decoration: InputDecoration(
                      labelText: 'Static IP Address',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.lan_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Print Agent Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: locCtrl,
                    decoration: InputDecoration(
                      labelText: 'Location / Notes',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.place_outlined, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
              onPressed: () async {
                try {
                  await AdminApiService.updatePrintAgent(agent['id'].toString(), {
                    'name': nameCtrl.text.trim(),
                    'ip_address': ipCtrl.text.trim().isNotEmpty ? ipCtrl.text.trim() : null,
                    'department_id': selectedDeptId ?? 0,
                    'location': locCtrl.text.trim().isNotEmpty ? locCtrl.text.trim() : null,
                  });
                  if (ctx.mounted) Navigator.pop(ctx, true);
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

    if (updated == true) _loadData();
  }

  Future<void> _deleteAgent(Map<String, dynamic> agent) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Print Agent'),
        content: Text('Are you sure you want to delete "${agent['name']}"?\nAll associated printers will also be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await AdminApiService.deletePrintAgent(agent['id'].toString());
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Print Agent deleted successfully.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete failed: $e'), backgroundColor: AppTheme.danger),
          );
        }
      }
    }
  }
}
