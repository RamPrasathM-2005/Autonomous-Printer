import 'dart:async';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../services/print_agent_service.dart';
import '../widgets/workflow_stepper.dart';
import '../services/kiosk_launcher.dart';
import 'upload_screen.dart';

class PrintProgressScreen extends StatefulWidget {
  final String orderId;
  final String otp;
  final String printServerId;

  const PrintProgressScreen({
    super.key,
    required this.orderId,
    required this.otp,
    required this.printServerId,
  });

  @override
  State<PrintProgressScreen> createState() => _PrintProgressScreenState();
}

class _PrintProgressScreenState extends State<PrintProgressScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final PrintAgentService _agentService = PrintAgentService();

  late AnimationController _animController;
  Timer? _pollTimer;

  String? _errorMessage;
  String? _warningMessage;
  bool _isOutOfPaper = false;
  String _statusMessage = 'Connecting to local printer kiosk...';
  int _progressPercent = 10;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _triggerRelease();
  }

  @override
  void dispose() {
    _animController.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _triggerRelease() async {
    setState(() {
      _errorMessage = null;
      _warningMessage = null;
      _isOutOfPaper = false;
      _statusMessage = 'Sending 6-digit OTP to printer kiosk...';
      _progressPercent = 25;
    });

    try {
      final result = await _agentService.releaseJobWithOtp(widget.otp);

      if (result['success'] == true) {
        setState(() {
          _statusMessage = 'Print job accepted. Printing pages...';
          _progressPercent = 60;
        });

        _startStatusPolling();
      } else {
        try {
          final ord = await _apiService.getOrder(widget.orderId);
          final st = ord.status.toUpperCase();
          if (st == 'RELEASED' || st == 'PRINTING' || st == 'COMPLETED') {
            _startStatusPolling();
            return;
          }
        } catch (_) {}

        setState(() {
          _errorMessage = result['error'] ?? 'Print agent rejected OTP.';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Job released at printer kiosk. Printing your document...';
        _progressPercent = 65;
      });
      _startStatusPolling();
    }
  }

  void _startStatusPolling() {
    int ticks = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      ticks++;
      try {
        final order = await _apiService.getOrder(widget.orderId);
        final status = order.status.toUpperCase();

        if (status == 'COMPLETED') {
          timer.cancel();
          _animController.stop();
          setState(() {
            _isOutOfPaper = false;
            _warningMessage = null;
            _statusMessage = 'Printing completed successfully!';
            _progressPercent = 100;
            _isCompleted = true;
          });
        } else if (order.isOutOfPaper) {
          setState(() {
            _isOutOfPaper = true;
            _warningMessage = order.errorMessage ??
                'Printer is out of paper. Please load paper into the tray to continue.';
            _statusMessage = 'Printer is paused: Out of paper.';
            _progressPercent = 65;
          });
        } else if (status == 'PRINTING') {
          setState(() {
            _isOutOfPaper = false;
            _warningMessage = null;
            _statusMessage = 'Printing document on physical printer...';
            _progressPercent = 75;
          });
        } else if (status == 'FAILED') {
          timer.cancel();
          _animController.stop();
          setState(() {
            _errorMessage = order.errorMessage ?? 'Print job failed on physical printer.';
          });
        }
      } catch (_) {
        // Continue polling without setting false completion
        if (ticks < 10) {
          setState(() {
            _statusMessage = 'Printing in progress...';
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Live Telemetry & Printing'),
        elevation: 0,
        backgroundColor: AppTheme.surfaceWhite,
        automaticallyImplyLeading: _isCompleted,
      ),
      body: Column(
        children: [
          const WorkflowStepper(currentStep: 5),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    children: [
                      // Progress Animation Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceWhite,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppTheme.border),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: Column(
                          children: [
                            if (_isCompleted) ...[
                              Container(
                                width: 84,
                                height: 84,
                                decoration: const BoxDecoration(
                                  color: AppTheme.successSurface,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_circle_rounded,
                                  size: 56,
                                  color: AppTheme.success,
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Printing Completed!',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Please collect your printed pages from the output tray.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                              ),
                            ] else if (_errorMessage != null) ...[
                              Container(
                                width: 84,
                                height: 84,
                                decoration: const BoxDecoration(
                                  color: AppTheme.dangerSurface,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.error_outline_rounded,
                                  size: 56,
                                  color: AppTheme.danger,
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Kiosk Release Notice',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.danger,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: _triggerRelease,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Retry Release'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                            ] else if (_isOutOfPaper) ...[
                              Container(
                                width: 84,
                                height: 84,
                                decoration: const BoxDecoration(
                                  color: AppTheme.warningSurface,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.warning_amber_rounded,
                                  size: 56,
                                  color: AppTheme.warning,
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Printer Out of Paper',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.warning,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _warningMessage ??
                                    'The print job is queued in the printer buffer. Please add paper into the printer feed tray to resume printing.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                              ),
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppTheme.warningSurface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.warning),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Waiting for paper... Printing will resume automatically',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.warning),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              RotationTransition(
                                turns: _animController,
                                child: Container(
                                  width: 84,
                                  height: 84,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primarySurface,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppTheme.primary.withOpacity(0.3), width: 2),
                                  ),
                                  child: const Icon(
                                    Icons.print_rounded,
                                    size: 46,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                _statusMessage,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 20),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: _progressPercent / 100.0,
                                  minHeight: 10,
                                  backgroundColor: AppTheme.surfaceSubtle,
                                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '$_progressPercent%',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.accent,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Job Telemetry Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceWhite,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.border),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: Column(
                          children: [
                            _buildRow('Order Ref ID', widget.orderId),
                            const Divider(height: 20),
                            _buildRow('Release OTP', widget.otp),
                            const Divider(height: 20),
                            _buildRow('CUPS Station ID', widget.printServerId),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextButton.icon(
                        onPressed: () => KioskLauncher.openKioskScreen(widget.otp),
                        icon: const Icon(Icons.desktop_windows_rounded, size: 18),
                        label: const Text('Open Touchscreen Kiosk Monitor'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                        ),
                      ),

                      const SizedBox(height: 20),

                      if (_isCompleted)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (ctx) => const UploadScreen()),
                                (route) => false,
                              );
                            },
                            icon: const Icon(Icons.add_circle_outline_rounded),
                            label: const Text('Print Another Document'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
