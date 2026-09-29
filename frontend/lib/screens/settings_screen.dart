import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../services/print_agent_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ApiService _apiService = ApiService();
  final PrintAgentService _agentService = PrintAgentService();

  late TextEditingController _backendController;
  late TextEditingController _agentController;

  bool _isTestingBackend = false;
  bool? _backendHealthy;
  bool _isTestingAgent = false;
  bool? _agentHealthy;

  @override
  void initState() {
    super.initState();
    _backendController = TextEditingController(text: ApiConfig.backendUrl);
    _agentController = TextEditingController(text: ApiConfig.agentUrl);
  }

  @override
  void dispose() {
    _backendController.dispose();
    _agentController.dispose();
    super.dispose();
  }

  Future<void> _testBackend() async {
    setState(() {
      _isTestingBackend = true;
      _backendHealthy = null;
    });

    final ok = await _apiService.checkHealth();
    setState(() {
      _isTestingBackend = false;
      _backendHealthy = ok;
    });
  }

  Future<void> _testAgent() async {
    setState(() {
      _isTestingAgent = true;
      _agentHealthy = null;
    });

    final ok = await _agentService.checkAgentHealth();
    setState(() {
      _isTestingAgent = false;
      _agentHealthy = ok;
    });
  }

  Future<void> _saveSettings() async {
    await ApiConfig.setBackendUrl(_backendController.text.trim());
    await ApiConfig.setAgentUrl(_agentController.text.trim());

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Server endpoints saved successfully!'),
        backgroundColor: AppTheme.success,
      ),
    );
    Navigator.pop(context);
  }

  void _applyPreset(String backend, String agent) {
    setState(() {
      _backendController.text = backend;
      _agentController.text = agent;
      _backendHealthy = null;
      _agentHealthy = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Network Configuration'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Quick Environment Presets',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _applyPreset(
                        'http://127.0.0.1:8000', 'http://127.0.0.1:5001'),
                    child: const Text('Localhost (Web/Desktop)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _applyPreset(
                        'http://10.0.2.2:8000', 'http://10.0.2.2:5001'),
                    child: const Text('Emulator (10.0.2.2)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _applyPreset(
                  'http://192.168.31.91:8000', 'http://192.168.31.91:5001'),
              child: const Text('Wi-Fi LAN IP (192.168.31.91)'),
            ),
            const SizedBox(height: 24),

            // Backend URL
            const Text(
              'FastAPI Backend URL',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _backendController,
              decoration: InputDecoration(
                hintText: 'http://127.0.0.1:8000',
                prefixIcon: const Icon(Icons.dns_rounded, size: 20),
                suffixIcon: IconButton(
                  icon: _isTestingBackend
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(
                          _backendHealthy == null
                              ? Icons.bolt_rounded
                              : (_backendHealthy!
                                  ? Icons.check_circle_rounded
                                  : Icons.cancel_rounded),
                          color: _backendHealthy == null
                              ? AppTheme.textMuted
                              : (_backendHealthy!
                                  ? AppTheme.success
                                  : AppTheme.danger),
                        ),
                  onPressed: _testBackend,
                  tooltip: 'Test Ping',
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Print Agent URL
            const Text(
              'Flask Print Agent URL (Station Kiosk)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _agentController,
              decoration: InputDecoration(
                hintText: 'http://127.0.0.1:5001',
                prefixIcon: const Icon(Icons.print_rounded, size: 20),
                suffixIcon: IconButton(
                  icon: _isTestingAgent
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(
                          _agentHealthy == null
                              ? Icons.bolt_rounded
                              : (_agentHealthy!
                                  ? Icons.check_circle_rounded
                                  : Icons.cancel_rounded),
                          color: _agentHealthy == null
                              ? AppTheme.textMuted
                              : (_agentHealthy!
                                  ? AppTheme.success
                                  : AppTheme.danger),
                        ),
                  onPressed: _testAgent,
                  tooltip: 'Test Ping',
                ),
              ),
            ),
            const SizedBox(height: 28),

            ElevatedButton.icon(
              onPressed: _saveSettings,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Save Server Configuration'),
            ),
            const SizedBox(height: 24),

            // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Network Architecture Guide',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Web & Desktop: connects directly to http://127.0.0.1:8000\n'
                    '• Android Emulator: accesses your PC host at http://10.0.2.2:8000\n'
                    '• Physical Android Phone: connects via same Wi-Fi using PC IP (http://192.168.31.91:8000)\n'
                    '• Print Agent: runs locally on port 5001 connected to physical CUPS printers.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
