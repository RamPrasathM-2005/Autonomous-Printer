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
    await ApiConfig.updateBackendUrl(_backendController.text);
    await ApiConfig.updateAgentUrl(_agentController.text);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Server URLs saved successfully!'),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  void _applyPreset(String backend, String agent) {
    setState(() {
      _backendController.text = backend;
      _agentController.text = agent;
    });
    _saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network & Server Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Connection Presets',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _applyPreset('http://10.0.2.2:8000', 'http://10.0.2.2:5001'),
                    child: const Text('Emulator', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _applyPreset('http://127.0.0.1:8000', 'http://127.0.0.1:5001'),
                    child: const Text('Localhost', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Backend URL
            const Text(
              'FastAPI Backend URL',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _backendController,
              decoration: InputDecoration(
                hintText: 'http://10.0.2.2:8000',
                prefixIcon: const Icon(Icons.dns_rounded),
                suffixIcon: IconButton(
                  icon: _isTestingBackend
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(
                          _backendHealthy == null
                              ? Icons.bolt_rounded
                              : (_backendHealthy! ? Icons.check_circle_rounded : Icons.cancel_rounded),
                          color: _backendHealthy == null
                              ? Colors.white54
                              : (_backendHealthy! ? AppTheme.success : AppTheme.danger),
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
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _agentController,
              decoration: InputDecoration(
                hintText: 'http://10.0.2.2:5001',
                prefixIcon: const Icon(Icons.print_rounded),
                suffixIcon: IconButton(
                  icon: _isTestingAgent
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(
                          _agentHealthy == null
                              ? Icons.bolt_rounded
                              : (_agentHealthy! ? Icons.check_circle_rounded : Icons.cancel_rounded),
                          color: _agentHealthy == null
                              ? Colors.white54
                              : (_agentHealthy! ? AppTheme.success : AppTheme.danger),
                        ),
                  onPressed: _testAgent,
                  tooltip: 'Test Ping',
                ),
              ),
            ),
            const SizedBox(height: 28),

            ElevatedButton.icon(
              onPressed: _saveSettings,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Save Server Configuration'),
            ),
            const SizedBox(height: 24),

            // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Network Architecture Note',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryLight, fontSize: 13),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '• Android Emulator accesses your PC host at 10.0.2.2\n'
                    '• Real Android device requires your PC\'s Wi-Fi LAN IP (e.g., http://192.168.1.x:8000)\n'
                    '• FastAPI runs on port 8000\n'
                    '• Flask Print Agent runs on port 5001\n'
                    '• All documents remain stored on the local Linux/PC filesystem without cloud dependency.',
                    style: TextStyle(fontSize: 12, height: 1.5, color: Colors.white60),
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
