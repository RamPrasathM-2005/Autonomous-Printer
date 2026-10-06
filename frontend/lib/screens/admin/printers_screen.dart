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

class _PrintersScreenState extends State<PrintersScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _printers = [];
  List<dynamic> _departments = [];

  String _searchQuery = '';
  String _statusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final printers = await AdminApiService.getPrinters();
      final departments = await AdminApiService.getDepartments();

      if (mounted) {
        setState(() {
          _printers = printers;
          _departments = departments;
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

  List<dynamic> get _filteredPrinters {
    return _printers.where((p) {
      final name = (p['display_name'] ?? '').toString().toLowerCase();
      final cupsName = (p['cups_printer_name'] ?? '').toString().toLowerCase();
      final location = (p['server_location'] ?? '').toString().toLowerCase();
      final dept = (p['department_name'] ?? '').toString().toLowerCase();
      final serverId = (p['server_id'] ?? '').toString().toLowerCase();

      final matchesSearch = _searchQuery.isEmpty ||
          name.contains(_searchQuery) ||
          cupsName.contains(_searchQuery) ||
          location.contains(_searchQuery) ||
          dept.contains(_searchQuery) ||
          serverId.contains(_searchQuery);

      final status = (p['server_status'] ?? '').toString().toUpperCase();
      final matchesStatus = _statusFilter == 'ALL' || status == _statusFilter;

      return matchesSearch && matchesStatus;
    }).toList();
  }

  Future<void> _showEditPrinterDialog(Map<String, dynamic> printer) async {
    final nameCtrl = TextEditingController(text: printer['display_name'] ?? '');
    int? selectedDeptId = printer['department_id'] as int?;
    bool isActive = printer['is_active'] == true;

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
                child: const Icon(Icons.print_outlined, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Configure Printer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hardware Station ID', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  const SizedBox(height: 4),
                  Text('${printer['id']} (${printer['server_id']})',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Display Name',
                      hintText: 'e.g. Library HP LaserJet Pro',
                      prefixIcon: const Icon(Icons.label_outline, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int?>(
                    value: selectedDeptId,
                    decoration: InputDecoration(
                      labelText: 'Assigned Department',
                      prefixIcon: const Icon(Icons.business_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('General / All Campus'),
                      ),
                      ..._departments.map((d) => DropdownMenuItem<int?>(
                            value: d['id'] as int,
                            child: Text('${d['name']} (${d['code']})'),
                          )),
                    ],
                    onChanged: (val) {
                      setDialogState(() => selectedDeptId = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Printer Enabled', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Allow new print orders to be routed here', style: TextStyle(fontSize: 12)),
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
                  await AdminApiService.updatePrinter(printer['id'].toString(), {
                    'display_name': nameCtrl.text.trim(),
                    'department_id': selectedDeptId ?? 0,
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
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      currentSection: AdminNavSection.printers,
      title: 'Printers & Hardware',
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

    final totalCount = _printers.length;
    final onlineCount = _printers.where((p) => (p['server_status'] ?? '').toString().toUpperCase() == 'ONLINE').length;
    final warningCount = _printers.where((p) {
      final paper = (p['paper_state'] ?? '').toString().toUpperCase();
      return paper == 'LOW' || paper == 'EMPTY';
    }).length;
    final activeCount = _printers.where((p) => p['is_active'] == true).length;

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
                return GridView.count(
                  crossAxisCount: isNarrow ? 2 : 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableCardImpossiblePhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: isNarrow ? 1.6 : 1.45,
                  children: [
                    StatCard(
                      title: 'Total Printers',
                      value: '$totalCount',
                      icon: Icons.print_rounded,
                      iconColor: AppTheme.primary,
                      subtitle: 'Registered Fleet',
                    ),
                    StatCard(
                      title: 'Online Stations',
                      value: '$onlineCount',
                      icon: Icons.cloud_done_rounded,
                      iconColor: AppTheme.success,
                      subtitle: '$onlineCount / $totalCount Live',
                    ),
                    StatCard(
                      title: 'Active & Enabled',
                      value: '$activeCount',
                      icon: Icons.check_circle_outline_rounded,
                      iconColor: const Color(0xFF0284C7),
                      subtitle: 'Accepting Orders',
                    ),
                    StatCard(
                      title: 'Paper Warnings',
                      value: '$warningCount',
                      icon: Icons.warning_amber_rounded,
                      iconColor: warningCount > 0 ? AppTheme.warning : AppTheme.textMuted,
                      subtitle: warningCount > 0 ? 'Tray low/empty' : 'All Trays OK',
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Filter & Search Toolbar
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
                          setState(() => _searchQuery = val.trim().toLowerCase());
                        },
                        decoration: InputDecoration(
                          hintText: 'Search printer, location, CUPS...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),

                    // Status Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _statusFilter,
                          isDense: true,
                          style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                          items: const [
                            DropdownMenuItem(value: 'ALL', child: Text('Status: All Stations')),
                            DropdownMenuItem(value: 'ONLINE', child: Text('Status: Online')),
                            DropdownMenuItem(value: 'OFFLINE', child: Text('Status: Offline')),
                            DropdownMenuItem(value: 'MAINTENANCE', child: Text('Status: Maintenance')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _statusFilter = val);
                          },
                        ),
                      ),
                    ),

                    // Refresh Button
                    OutlinedButton.icon(
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Refresh', style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Printer Fleet Table Card
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
                        Text(
                          'Printer Fleet (${_filteredPrinters.length})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Real-time CUPS Queues & Paper Trays',
                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildPrintersTable(_filteredPrinters),
                  ],
                ),
              ),
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
        child: Column(
          children: [
            const Icon(Icons.print_disabled_outlined, size: 40, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            const Text('No printers found matching criteria.', style: TextStyle(color: AppTheme.textMuted)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppTheme.surfaceSubtle),
        columns: const [
          DataColumn(label: Text('Printer Name', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('CUPS Queue', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Station / Location', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Department', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Network Status', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Engine State', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Paper Tray', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Jobs Printed', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w700))),
        ],
        rows: printers.map((p) {
          final serverStatus = (p['server_status'] ?? '').toString().toUpperCase();
          final isOnline = serverStatus == 'ONLINE';
          final paperState = (p['paper_state'] ?? '').toString().toUpperCase();
          final printerState = (p['printer_state'] ?? '').toString().toUpperCase();

          return DataRow(
            cells: [
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      p['supports_color'] == true ? Icons.color_lens_outlined : Icons.print_outlined,
                      size: 18,
                      color: p['is_active'] == true ? AppTheme.primary : AppTheme.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(p['display_name'] ?? 'Unnamed', style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (p['is_active'] != true)
                          const Text('Disabled', style: TextStyle(fontSize: 10, color: AppTheme.danger)),
                      ],
                    ),
                  ],
                ),
              ),
              DataCell(Text(p['cups_printer_name'] ?? '-')),
              DataCell(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(p['server_location'] ?? 'Station', style: const TextStyle(fontSize: 13)),
                    Text(p['server_id'] ?? '', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
              ),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySurface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    p['department_name'] ?? 'All Campus',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primary),
                  ),
                ),
              ),
              DataCell(_buildStatusBadge(serverStatus, isOnline)),
              DataCell(_buildStateBadge(printerState)),
              DataCell(_buildPaperBadge(paperState)),
              DataCell(Text('${p['total_jobs_count'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(
                IconButton(
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  tooltip: 'Configure Printer',
                  onPressed: () => _showEditPrinterDialog(p),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusBadge(String status, bool isOnline) {
    Color bg;
    Color fg;
    if (isOnline) {
      bg = AppTheme.success.withOpacity(0.12);
      fg = AppTheme.success;
    } else if (status == 'MAINTENANCE') {
      bg = AppTheme.warning.withOpacity(0.12);
      fg = AppTheme.warning;
    } else {
      bg = AppTheme.danger.withOpacity(0.12);
      fg = AppTheme.danger;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(status.isEmpty ? 'UNKNOWN' : status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  Widget _buildStateBadge(String state) {
    Color color = AppTheme.textMuted;
    if (state == 'IDLE' || state == 'READY') {
      color = AppTheme.success;
    } else if (state == 'PRINTING' || state == 'BUSY') {
      color = AppTheme.primary;
    } else if (state == 'ERROR') {
      color = AppTheme.danger;
    }

    return Text(state.isEmpty ? 'UNKNOWN' : state, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color));
  }

  Widget _buildPaperBadge(String state) {
    Color color = AppTheme.success;
    if (state == 'LOW') color = AppTheme.warning;
    if (state == 'EMPTY' || state == 'OUT') color = AppTheme.danger;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.layers_outlined, size: 14, color: color),
        const SizedBox(width: 4),
        Text(state.isEmpty ? 'OK' : state, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
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
