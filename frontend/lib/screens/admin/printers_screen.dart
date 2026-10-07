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
  String? _error;

  List<dynamic> _printers = [];
  List<dynamic> _agents = [];
  List<dynamic> _discovered = [];
  List<dynamic> _departments = [];

  String _searchQuery = '';
  String _statusFilter = 'ALL';
  final Set<String> _testingPrinterIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        AdminApiService.getPrinters(),
        AdminApiService.getPrintAgents(),
        AdminApiService.getDiscoveredPrinters(),
        AdminApiService.getDepartments(),
      ]);

      if (mounted) {
        setState(() {
          _printers = results[0];
          _agents = results[1];
          _discovered = results[2];
          _departments = results[3];
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
      final ip = (p['ip_address'] ?? '').toString().toLowerCase();
      final location = (p['location'] ?? p['server_location'] ?? '').toString().toLowerCase();
      final dept = (p['department_name'] ?? '').toString().toLowerCase();
      final serverId = (p['server_id'] ?? '').toString().toLowerCase();

      final matchesSearch = _searchQuery.isEmpty ||
          name.contains(_searchQuery) ||
          cupsName.contains(_searchQuery) ||
          ip.contains(_searchQuery) ||
          location.contains(_searchQuery) ||
          dept.contains(_searchQuery) ||
          serverId.contains(_searchQuery);

      final isActive = p['is_active'] == true;
      final hasMismatch = p['has_mismatch'] == true;

      bool matchesStatus = true;
      if (_statusFilter == 'ACTIVE') {
        matchesStatus = isActive;
      } else if (_statusFilter == 'INACTIVE') {
        matchesStatus = !isActive;
      } else if (_statusFilter == 'MISMATCH') {
        matchesStatus = hasMismatch;
      }

      return matchesSearch && matchesStatus;
    }).toList();
  }

  Future<void> _runTestConnection(String printerId, String displayName) async {
    setState(() => _testingPrinterIds.add(printerId));
    try {
      final res = await AdminApiService.testPrinterConnection(printerId);
      final bool success = res['success'] == true;
      final String msg = res['message'] ?? (success ? 'Connection verified successfully.' : 'Connection test failed.');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(success ? Icons.check_circle : Icons.warning_amber_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text('[$displayName] $msg')),
              ],
            ),
            backgroundColor: success ? AppTheme.success : AppTheme.danger,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test Connection Error: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _testingPrinterIds.remove(printerId));
      }
    }
  }

  Future<void> _showRegisterPrinterDialog({Map<String, dynamic>? prefill}) async {
    if (_agents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please register at least one Print Agent before adding printers.'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    final cupsCtrl = TextEditingController(text: prefill?['cups_printer_name'] ?? '');
    final nameCtrl = TextEditingController(text: prefill?['cups_printer_name']?.toString().replaceAll('_', ' ') ?? '');
    final ipCtrl = TextEditingController(text: prefill?['ip_address'] ?? '');
    final uriCtrl = TextEditingController(text: prefill?['device_uri'] ?? '');
    final locationCtrl = TextEditingController(text: prefill?['location'] ?? '');
    final modelCtrl = TextEditingController(text: prefill?['model'] ?? '');

    String selectedProtocol = prefill?['protocol'] ?? 'Socket';
    String selectedServerId = prefill?['server_id'] ?? _agents.first['id'].toString();
    int? selectedDeptId = prefill?['department_id'] as int?;
    bool isEnabled = true;
    bool supportsColor = true;
    bool supportsDuplex = true;

    void updateDeviceUri(StateSetter setDialogState) {
      final ip = ipCtrl.text.trim();
      if (ip.isNotEmpty) {
        if (selectedProtocol == 'Socket') {
          uriCtrl.text = 'socket://$ip:9100';
        } else if (selectedProtocol == 'IPP') {
          uriCtrl.text = 'ipp://$ip:631/ipp/print';
        } else if (selectedProtocol == 'LPD') {
          uriCtrl.text = 'lpd://$ip/queue';
        }
        setDialogState(() {});
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
                child: const Icon(Icons.add_to_photos_outlined, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Register Printer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: nameCtrl,
                          decoration: InputDecoration(
                            labelText: 'Display Name *',
                            hintText: 'e.g. Lab HP LaserJet',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: cupsCtrl,
                          decoration: InputDecoration(
                            labelText: 'CUPS Printer Name *',
                            hintText: 'e.g. HP_LaserJet_400',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: ipCtrl,
                          decoration: InputDecoration(
                            labelText: 'Static IP Address *',
                            hintText: '192.168.1.100',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onChanged: (_) => updateDeviceUri(setDialogState),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedProtocol,
                          decoration: InputDecoration(
                            labelText: 'Protocol',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Socket', child: Text('Socket (Port 9100)')),
                            DropdownMenuItem(value: 'IPP', child: Text('IPP (Port 631)')),
                            DropdownMenuItem(value: 'LPD', child: Text('LPD (Port 515)')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedProtocol = val);
                              updateDeviceUri(setDialogState);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: uriCtrl,
                    decoration: InputDecoration(
                      labelText: 'Device URI',
                      hintText: 'socket://192.168.1.100:9100',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedServerId,
                          decoration: InputDecoration(
                            labelText: 'Assigned Print Agent *',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          value: selectedDeptId,
                          decoration: InputDecoration(
                            labelText: 'Department',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: locationCtrl,
                          decoration: InputDecoration(
                            labelText: 'Location',
                            hintText: 'e.g. Ground Floor Lab',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: modelCtrl,
                          decoration: InputDecoration(
                            labelText: 'Model',
                            hintText: 'e.g. LaserJet M401dn',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: SwitchListTile(
                          dense: true,
                          title: const Text('Enabled', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          value: isEnabled,
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppTheme.primary,
                          onChanged: (v) => setDialogState(() => isEnabled = v),
                        ),
                      ),
                      Expanded(
                        child: SwitchListTile(
                          dense: true,
                          title: const Text('Color', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          value: supportsColor,
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppTheme.primary,
                          onChanged: (v) => setDialogState(() => supportsColor = v),
                        ),
                      ),
                      Expanded(
                        child: SwitchListTile(
                          dense: true,
                          title: const Text('Duplex', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          value: supportsDuplex,
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppTheme.primary,
                          onChanged: (v) => setDialogState(() => supportsDuplex = v),
                        ),
                      ),
                    ],
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
                final ip = ipCtrl.text.trim();

                if (cupsName.isEmpty || dispName.isEmpty || ip.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Please complete required fields.')),
                  );
                  return;
                }

                try {
                  await AdminApiService.createPrinter({
                    'cups_printer_name': cupsName,
                    'display_name': dispName,
                    'ip_address': ip,
                    'protocol': selectedProtocol,
                    'device_uri': uriCtrl.text.trim().isNotEmpty ? uriCtrl.text.trim() : null,
                    'server_id': selectedServerId,
                    'department_id': selectedDeptId,
                    'location': locationCtrl.text.trim().isNotEmpty ? locationCtrl.text.trim() : null,
                    'model': modelCtrl.text.trim().isNotEmpty ? modelCtrl.text.trim() : null,
                    'is_enabled': isEnabled,
                    'supports_color': supportsColor,
                    'supports_duplex': supportsDuplex,
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
              child: const Text('Register Printer'),
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
            content: Text('Printer registered and activated successfully.'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    }
  }

  Future<void> _showEditPrinterDialog(Map<String, dynamic> printer) async {
    final nameCtrl = TextEditingController(text: printer['display_name'] ?? '');
    final ipCtrl = TextEditingController(text: printer['ip_address'] ?? '');
    final uriCtrl = TextEditingController(text: printer['device_uri'] ?? '');
    final locationCtrl = TextEditingController(text: printer['location'] ?? '');
    int? selectedDeptId = printer['department_id'] as int?;
    String selectedServerId = printer['server_id'] ?? (_agents.isNotEmpty ? _agents.first['id'] : '');
    bool isEnabled = printer['is_enabled'] != false;

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
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ipCtrl,
                    decoration: InputDecoration(
                      labelText: 'Static IP Address',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: uriCtrl,
                    decoration: InputDecoration(
                      labelText: 'Device URI',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedServerId,
                    decoration: InputDecoration(
                      labelText: 'Assigned Print Agent',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                      labelText: 'Location',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Printer Enabled', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    value: isEnabled,
                    activeColor: AppTheme.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setDialogState(() => isEnabled = val),
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
                    'ip_address': ipCtrl.text.trim().isNotEmpty ? ipCtrl.text.trim() : null,
                    'device_uri': uriCtrl.text.trim().isNotEmpty ? uriCtrl.text.trim() : null,
                    'location': locationCtrl.text.trim().isNotEmpty ? locationCtrl.text.trim() : null,
                    'server_id': selectedServerId,
                    'department_id': selectedDeptId ?? 0,
                    'is_enabled': isEnabled,
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
        title: const Text('Delete Printer'),
        content: Text('Are you sure you want to delete "${printer['display_name']}"?'),
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
        await AdminApiService.deletePrinter(printer['id'].toString());
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Printer deleted successfully.')),
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

    final mismatchCount = _printers.where((p) => p['has_mismatch'] == true).length;

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
                          if (mismatchCount > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: AppTheme.danger.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                              child: Text('$mismatchCount Mismatch', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.danger)),
                            ),
                          ],
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
                    Tab(
                      child: Row(
                        children: [
                          const Text('Discovered Printers'),
                          if (_discovered.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: AppTheme.warning.withOpacity(0.18), borderRadius: BorderRadius.circular(10)),
                              child: Text('${_discovered.length} New', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.warning)),
                            ),
                          ],
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
              _buildDiscoveredTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrintersTab() {
    final mismatches = _printers.where((p) => p['has_mismatch'] == true).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Prominent Mismatch Alert Banner
            if (mismatches.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Configuration Mismatch Flagged During Heartbeat Sync',
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.danger, fontSize: 14),
                          ),
                          const SizedBox(width: 4),
                          ...mismatches.map((m) => Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '• ${m['display_name']} (${m['cups_printer_name']}): ${m['mismatch_details']}',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                                ),
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

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
                      title: 'Verified & Active',
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
                      title: 'Heartbeat Mismatches',
                      value: '${mismatches.length}',
                      icon: Icons.sync_problem_outlined,
                      iconColor: mismatches.isNotEmpty ? AppTheme.danger : AppTheme.success,
                      iconBgColor: (mismatches.isNotEmpty ? AppTheme.danger : AppTheme.success).withOpacity(0.12),
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
                          hintText: 'Search by printer name, static IP, CUPS queue, or agent...',
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
                        DropdownMenuItem(value: 'MISMATCH', child: Text('Flagged Mismatches')),
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
          DataColumn(label: Text('Static IP & URI', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Assigned Agent', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Department', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Routing Status', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Connection Test', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Heartbeat Mismatch', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w700))),
        ],
        rows: printers.map((p) {
          final String pid = p['id'].toString();
          final isTesting = _testingPrinterIds.contains(pid);
          final bool isActive = p['is_active'] == true;
          final bool isEnabled = p['is_enabled'] != false;
          final String testStatus = (p['test_status'] ?? 'PENDING').toString().toUpperCase();
          final bool hasMismatch = p['has_mismatch'] == true;

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
                    Text(p['ip_address'] ?? 'DHCP/None', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    if (p['protocol'] != null)
                      Text('${p['protocol']}', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                  ],
                ),
              ),
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
                Tooltip(
                  message: p['test_message'] ?? 'Click Test Connection to probe CUPS and network.',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (testStatus == 'SUCCESS')
                          ? AppTheme.success.withOpacity(0.12)
                          : (testStatus == 'FAILED' ? AppTheme.danger.withOpacity(0.12) : AppTheme.warning.withOpacity(0.12)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      testStatus == 'SUCCESS' ? 'VERIFIED' : (testStatus == 'FAILED' ? 'UNREACHABLE' : 'PENDING'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: (testStatus == 'SUCCESS') ? AppTheme.success : (testStatus == 'FAILED' ? AppTheme.danger : AppTheme.warning),
                      ),
                    ),
                  ),
                ),
              ),
              DataCell(
                hasMismatch
                    ? Tooltip(
                        message: p['mismatch_details'] ?? 'Configuration mismatch detected.',
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppTheme.danger.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.sync_problem, size: 14, color: AppTheme.danger),
                              SizedBox(width: 4),
                              Text('MISMATCH', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.danger)),
                            ],
                          ),
                        ),
                      )
                    : const Icon(Icons.check, size: 16, color: AppTheme.success),
              ),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    isTesting
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                        : IconButton(
                            icon: const Icon(Icons.network_check_outlined, size: 18),
                            tooltip: 'Test Connection',
                            onPressed: () => _runTestConnection(pid, p['display_name'] ?? 'Printer'),
                          ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Edit Configuration',
                      onPressed: () => _showEditPrinterDialog(p),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                      tooltip: 'Delete',
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
                            label: const Text('Open CUPS'),
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

  Widget _buildDiscoveredTab() {
    if (_discovered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.check_circle_outline, size: 48, color: AppTheme.success),
            SizedBox(height: 12),
            Text('No unregistered printers detected.', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('All printers reported by Print Agents match registered configurations.', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Unregistered CUPS Printers Reported in Heartbeats',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'The system does not automatically create printer records. Click "Register" to add them to your fleet.',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
            color: Theme.of(context).cardColor,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppTheme.surfaceSubtle),
              columns: const [
                DataColumn(label: Text('CUPS Queue', style: TextStyle(fontWeight: FontWeight.w700))),
                DataColumn(label: Text('Reporting Agent', style: TextStyle(fontWeight: FontWeight.w700))),
                DataColumn(label: Text('Detected IP / URI', style: TextStyle(fontWeight: FontWeight.w700))),
                DataColumn(label: Text('Engine State', style: TextStyle(fontWeight: FontWeight.w700))),
                DataColumn(label: Text('Last Seen', style: TextStyle(fontWeight: FontWeight.w700))),
                DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w700))),
              ],
              rows: _discovered.map((d) {
                return DataRow(
                  cells: [
                    DataCell(Text(d['cups_printer_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(d['server_name'] ?? d['server_id'] ?? '')),
                    DataCell(Text(d['ip_address'] ?? d['device_uri'] ?? 'Local USB / Socket', style: const TextStyle(fontSize: 12))),
                    DataCell(Text(d['reported_status'] ?? 'READY', style: const TextStyle(fontSize: 12))),
                    DataCell(Text(d['last_seen'] ?? '', style: const TextStyle(fontSize: 12))),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FilledButton.tonal(
                            onPressed: () => _showRegisterPrinterDialog(prefill: d),
                            child: const Text('Register'),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            tooltip: 'Dismiss',
                            onPressed: () async {
                              await AdminApiService.dismissDiscoveredPrinter(d['id'].toString());
                              _loadData();
                            },
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
            width: 420,
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
                      labelText: 'Static IP Address *',
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
        // Automatically open the CUPS dialog for the newly created agent to add printers!
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

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (isLoadingCups) {
            AdminApiService.getAgentCupsPrinters(agentId).then((data) {
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
          }

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
                      Text('$agentName — CUPS Printers', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
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
                                  const Text('No CUPS printers reported by this Print Agent yet.', style: TextStyle(fontWeight: FontWeight.w600)),
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
                                        'ip_address': agentIp,
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
                                final uri = p['device_uri'] ?? '';
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
                                    'Queue: $cupsName • State: $stateStr\nURI: $uri',
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
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            _showRegisterPrinterDialog(prefill: {
                                              'cups_printer_name': cupsName,
                                              'display_name': dispName,
                                              'server_id': agentId,
                                              'department_id': deptId,
                                              'ip_address': agentIp,
                                              'device_uri': uri,
                                            });
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
              FilledButton.tonalIcon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Custom Printer'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showRegisterPrinterDialog(prefill: {
                    'server_id': agentId,
                    'department_id': deptId,
                    'ip_address': agentIp,
                  });
                },
              ),
            ],
          );
        },
      ),
    );
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
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Print Agent Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: locCtrl,
                    decoration: InputDecoration(
                      labelText: 'Location / Notes',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
