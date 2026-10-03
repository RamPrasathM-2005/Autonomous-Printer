import '../widgets/app_scaffold.dart';
import '../widgets/help_action.dart';
import 'package:flutter/material.dart';

import '../services/api_error.dart';

import '../config/api_config.dart';
import '../config/theme.dart';
import '../models/print_server.dart';
import '../services/api_service.dart';
import '../widgets/station_card.dart';
import '../widgets/ui_state.dart';

class StationsScreen extends StatefulWidget {
  final Function(String stationId)? onStationSelected;

  const StationsScreen({super.key, this.onStationSelected});

  @override
  State<StationsScreen> createState() => _StationsScreenState();
}

class _StationsScreenState extends State<StationsScreen> {
  final ApiService _apiService = ApiService();
  List<PrintServer> _servers = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _selectedStationId;

  @override
  void initState() {
    super.initState();
    _selectedStationId = ApiConfig.selectedStationId;
    _loadServers();
  }

  Future<void> _loadServers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final servers = await _apiService.fetchPrintServers();
      setState(() {
        _servers = servers;
        _isLoading = false;
        if (_servers.isNotEmpty &&
            (_selectedStationId == null ||
                !_servers.any((s) => s.id == _selectedStationId))) {
          _selectedStationId = _servers.first.id;
          ApiConfig.updateSelectedStationId(_selectedStationId!);
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = userError(e);
      });
    }
  }

  void _selectStation(String stationId) {
    setState(() {
      _selectedStationId = stationId;
    });
    ApiConfig.updateSelectedStationId(stationId);
    if (widget.onStationSelected != null) {
      widget.onStationSelected!(stationId);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Station selected'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppTheme.primaryDark,
      ),
    );
  }

  void _manualStationDialog() {
    final controller = TextEditingController(
      text: _selectedStationId ?? 'PRINT-SERVER-001',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Enter Station ID'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Station ID',
                prefixIcon: Icon(Icons.qr_code_scanner),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = controller.text.trim();
              if (val.isNotEmpty) {
                _selectStation(val);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Set Station'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Print Stations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Enter station ID',
            onPressed: _manualStationDialog,
          ),
          const HelpAction(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadServers,
        color: AppTheme.primaryLight,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Active selection banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryDark.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_city_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ACTIVE PRINT STATION',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _selectedStationId ?? 'None Selected',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _manualStationDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primaryDark,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('Change'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Available stations',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            if (_isLoading)
              const UiLoadingView(message: 'Searching print stations...')
            else if (_errorMessage != null)
              UiErrorView(
                message: _errorMessage!,
                onRetry: _loadServers,
              )
            else if (_servers.isEmpty)
              UiEmptyView(
                icon: Icons.print_disabled_rounded,
                title: 'No Print Stations Found',
                message: 'No print stations are currently registered.',
                onAction: _loadServers,
                actionLabel: 'Check Again',
              )
            else
              ..._servers.map(
                (server) => StationCard(
                  server: server,
                  isSelected: server.id == _selectedStationId,
                  onSelect: () => _selectStation(server.id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
