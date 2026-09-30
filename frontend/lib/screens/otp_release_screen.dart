import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';
import '../models/order.dart';
import '../services/api_service.dart';
import '../widgets/workflow_stepper.dart';
import '../services/kiosk_launcher.dart';
import '../services/print_agent_service.dart';
import 'print_progress_screen.dart';

class OtpReleaseScreen extends StatefulWidget {
  final String orderId;

  const OtpReleaseScreen({super.key, required this.orderId});

  @override
  State<OtpReleaseScreen> createState() => _OtpReleaseScreenState();
}

class _OtpReleaseScreenState extends State<OtpReleaseScreen> {
  final ApiService _apiService = ApiService();
  OrderOtp? _otpData;
  PrintOrder? _order;
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _pollingTimer;

  int _secondsLeft = 900; // 15 mins
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _fetchOtpAndOrder();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      _pollOrderStatus();
    });
  }

  Future<void> _fetchOtpAndOrder() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final order = await _apiService.getOrder(widget.orderId);
      final otp = await _apiService.getOrderOtp(widget.orderId);

      DateTime? expiry;
      if (otp.expiresAt.isNotEmpty) {
        try {
          expiry = DateTime.tryParse(otp.expiresAt.replaceAll(' ', 'T'));
        } catch (_) {}
      }
      final diff = expiry != null ? expiry.difference(DateTime.now()).inSeconds : 900;

      setState(() {
        _order = order;
        _otpData = otp;
        _secondsLeft = diff > 0 ? diff : 900;
        _isLoading = false;
      });

      _startCountdown();
      _startPolling();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft > 0) {
        setState(() {
          _secondsLeft--;
        });
      } else {
        t.cancel();
      }
    });
  }

  Future<void> _pollOrderStatus() async {
    try {
      final updated = await _apiService.getOrder(widget.orderId);
      final status = updated.status.toUpperCase();

      if (status == 'PRINTING' || status == 'COMPLETED' || status == 'RELEASED') {
        _pollingTimer?.cancel();
        _countdownTimer?.cancel();

        if (!mounted) return;
        _goToProgressScreen();
      }
    } catch (_) {}
  }

  void _goToProgressScreen() {
    if (_otpData == null || _order == null) return;
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (ctx) => PrintProgressScreen(
          orderId: widget.orderId,
          otp: _otpData!.otpCode,
          printServerId: _order!.printServerId,
        ),
      ),
    );
  }

  String _formatTimer(int totalSecs) {
    final m = totalSecs ~/ 60;
    final s = totalSecs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _copyToClipboard() {
    if (_otpData == null) return;
    Clipboard.setData(ClipboardData(text: _otpData!.otpCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text('OTP Code ${_otpData!.otpCode} copied to clipboard!'),
          ],
        ),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _simulateRelease() async {
    if (_otpData == null || _order == null) return;
    try {
      final agentService = PrintAgentService();
      await agentService.releasePrintJob(
        stationId: _order!.printServerId,
        otp: _otpData!.otpCode,
      );
      _goToProgressScreen();
    } catch (_) {
      _goToProgressScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final otpStr = _otpData?.otpCode ?? '------';

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Release OTP Code'),
        elevation: 0,
        backgroundColor: AppTheme.surfaceWhite,
      ),
      body: Column(
        children: [
          const WorkflowStepper(currentStep: 4),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    children: [
                      const Text(
                        'Your Kiosk Release Code',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Enter this code on the kiosk touchscreen or click Auto Release below.',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 24),

                      // Large OTP Digits Display Card
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceWhite,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppTheme.primary.withOpacity(0.3), width: 2),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: Column(
                          children: [
                            const Text(
                              '6-DIGIT RELEASE CODE',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textMuted,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _isLoading
                                ? const SizedBox(
                                    height: 50,
                                    child: Center(child: CircularProgressIndicator()),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(6, (i) {
                                      final digit = i < otpStr.length ? otpStr[i] : '-';
                                      return Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 4),
                                        width: 44,
                                        height: 54,
                                        decoration: BoxDecoration(
                                          color: AppTheme.primarySurface,
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: AppTheme.primary, width: 1.5),
                                        ),
                                        child: Center(
                                          child: Text(
                                            digit,
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.w900,
                                              color: AppTheme.primary,
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                            const SizedBox(height: 20),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _copyToClipboard,
                                  icon: const Icon(Icons.copy_rounded, size: 16),
                                  label: const Text('Copy Code'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.warningSurface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.timer_outlined, size: 16, color: AppTheme.warning),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Expires in ${_formatTimer(_secondsLeft)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFFB45309),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Instructions & Trigger Actions Container
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceWhite,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.border),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'How to Release Your Print Job',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _buildInstructionStep(
                              step: '1',
                              title: 'Walk to the Kiosk Terminal',
                              subtitle: 'Locate your selected station touchscreen/keypad.',
                            ),
                            const SizedBox(height: 12),
                            _buildInstructionStep(
                              step: '2',
                              title: 'Enter 6-Digit OTP',
                              subtitle: 'Type the code on the screen and tap Release Document.',
                            ),
                            const SizedBox(height: 12),
                            _buildInstructionStep(
                              step: '3',
                              title: 'Collect Printed Document',
                              subtitle: 'Your physical pages will output from the printer tray.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceWhite,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _simulateRelease,
                          icon: const Icon(Icons.print_rounded, size: 20),
                          label: const Text(
                            'Auto-Release Print Job Now',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
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

  Widget _buildInstructionStep({
    required String step,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.primarySurface,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
          ),
          child: Center(
            child: Text(
              step,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
