import 'package:flutter/material.dart';

import '../services/api_error.dart';

import '../config/theme.dart';
import '../services/print_agent_service.dart';

class StationTerminalScreen extends StatefulWidget {
  final String? initialOtp;

  const StationTerminalScreen({super.key, this.initialOtp});

  @override
  State<StationTerminalScreen> createState() => _StationTerminalScreenState();
}

class _StationTerminalScreenState extends State<StationTerminalScreen> {
  final PrintAgentService _agentService = PrintAgentService();
  String _enteredPin = '';
  bool _isReleasing = false;
  String? _statusMessage;
  bool _isSuccess = false;
  Map<String, dynamic>? _stationStatus;

  @override
  void initState() {
    super.initState();
    if (widget.initialOtp != null) {
      _enteredPin = widget.initialOtp!;
    }
    _loadStationStatus();
  }

  Future<void> _loadStationStatus() async {
    try {
      final status = await _agentService.getAgentStatus();
      if (mounted) {
        setState(() {
          _stationStatus = status;
        });
      }
    } catch (_) {}
  }

  void _onKeyPressed(String key) {
    if (_enteredPin.length < 6) {
      setState(() {
        _enteredPin += key;
        _statusMessage = null;
      });
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _statusMessage = null;
      });
    }
  }

  void _onClear() {
    setState(() {
      _enteredPin = '';
      _statusMessage = null;
    });
  }

  Future<void> _submitOtp() async {
    if (_enteredPin.length != 6) {
      setState(() {
        _statusMessage = 'Enter the 6-digit release code.';
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _isReleasing = true;
      _statusMessage = null;
    });

    try {
      await _agentService.releaseWithOtp(_enteredPin);
      setState(() {
        _isReleasing = false;
        _isSuccess = true;
        _statusMessage = 'Print released.';
      });
      _loadStationStatus();
    } catch (e) {
      setState(() {
        _isReleasing = false;
        _isSuccess = false;
        _statusMessage = userError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Print station')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            // Kiosk Monitor Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primaryLight.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _stationStatus != null
                          ? AppTheme.success
                          : AppTheme.warning,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _stationStatus?['printer_name'] ?? 'Printer unavailable',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  Text(
                    _stationStatus?['printer_state'] ?? 'Unavailable',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Enter Release Code',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),

            // OTP Display Boxes
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                String char = '';
                if (index < _enteredPin.length) {
                  char = _enteredPin[index];
                }
                return Container(
                  width: 44,
                  height: 52,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: char.isNotEmpty
                          ? AppTheme.secondary
                          : Colors.white24,
                      width: char.isNotEmpty ? 2 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    char,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),

            // Status message
            if (_statusMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: (_isSuccess ? AppTheme.success : AppTheme.danger)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (_isSuccess ? AppTheme.success : AppTheme.danger)
                        .withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isSuccess ? Icons.check_circle : Icons.error_outline,
                      color: _isSuccess ? AppTheme.success : AppTheme.danger,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          color: _isSuccess ? AppTheme.success : Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Keypad Grid
            Column(
              children: [
                _buildKeyRow(['1', '2', '3']),
                const SizedBox(height: 10),
                _buildKeyRow(['4', '5', '6']),
                const SizedBox(height: 10),
                _buildKeyRow(['7', '8', '9']),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _keyButton(label: 'C', isSpecial: true, onTap: _onClear),
                    const SizedBox(width: 12),
                    _keyButton(label: '0', onTap: () => _onKeyPressed('0')),
                    const SizedBox(width: 12),
                    _keyButton(
                      icon: Icons.backspace_outlined,
                      isSpecial: true,
                      onTap: _onBackspace,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isReleasing || _enteredPin.length != 6)
                    ? null
                    : _submitOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isReleasing
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Releasing...'),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.print_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'RELEASE PRINT JOB',
                            style: TextStyle(fontWeight: FontWeight.w800),
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

  Widget _buildKeyRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _keyButton(label: keys[0], onTap: () => _onKeyPressed(keys[0])),
        const SizedBox(width: 12),
        _keyButton(label: keys[1], onTap: () => _onKeyPressed(keys[1])),
        const SizedBox(width: 12),
        _keyButton(label: keys[2], onTap: () => _onKeyPressed(keys[2])),
      ],
    );
  }

  Widget _keyButton({
    String? label,
    IconData? icon,
    bool isSpecial = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 76,
        height: 60,
        decoration: BoxDecoration(
          color: isSpecial ? AppTheme.surfaceLight : AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        alignment: Alignment.center,
        child: icon != null
            ? Icon(icon, color: Colors.white70)
            : Text(
                label ?? '',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isSpecial ? AppTheme.danger : Colors.white,
                ),
              ),
      ),
    );
  }
}
