import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../config/theme.dart';
import '../models/print_server.dart';
import '../services/api_service.dart';
import '../widgets/station_card.dart';

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
        if (_servers.isNotEmpty && (_selectedStationId == null || !_servers.any((s) => s.id == _selectedStationId))) {
          _selectedStationId = _servers.first.id;
          ApiConfig.updateSelectedStationId(_selectedStationId!);
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
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
        content: Text('Selected Station: $stationId'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppTheme.primaryDark,
      ),
    );
  }

  void _manualStationDialog() {
    final controller = TextEditingController(text: _selectedStationId ?? 'PRINT-SERVER-001');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Enter Station ID'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the station or kiosk identifier (or scan QR code from the printer station).',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
            const SizedBox(height: 16),
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
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/app_logo.jpg',
                width: 28,
                height: 28,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => const Icon(Icons.print_rounded, size: 22, color: AppTheme.primary),
              ),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'Print Stations',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Enter Station / QR',
            onPressed: _manualStationDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadServers,
          ),
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
                gradient: const LinearGradient(
                  colors: [Color(0xFF3730A3), Color(0xFF4F46E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
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
                    child: const Icon(Icons.location_city_rounded, color: Colors.white, size: 24),
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('Change'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Available Printing Kiosks',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 36),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _loadServers,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry Connection'),
                    ),
                  ],
                ),
              )
            else if (_servers.isEmpty)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.print_disabled_rounded, size: 48, color: Colors.white38),
                    const SizedBox(height: 12),
                    const Text(
                      'No Print Stations Found',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Ensure the FastAPI backend and print-agent are started.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.white60),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: _loadServers,
                      child: const Text('Check Again'),
                    ),
                  ],
                ),
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
