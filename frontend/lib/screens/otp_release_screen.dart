import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';
import '../models/order.dart';
import '../services/api_service.dart';
import '../widgets/workflow_stepper.dart';
import '../services/print_agent_service.dart';
import '../widgets/server_config_dialog.dart';
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
  Timer? _countdownTimer;
  int _secondsLeft = 86400;
  String? _selectedPrinterName;

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
      final diff = expiry != null ? expiry.difference(DateTime.now()).inSeconds : 86400;

      final existingPrinter = order.printSettings.toJson()['printer_name'] ??
          order.printSettings.toJson()['cups_printer_name'];

      setState(() {
        _order = order;
        _otpData = otp;
        if (existingPrinter != null && existingPrinter.toString().isNotEmpty) {
          _selectedPrinterName = existingPrinter.toString();
        }
        _secondsLeft = diff > 0 ? diff : 86400;
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

  Widget _buildPrinterSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.print_outlined, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Select Destination Printer',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Two printers are connected to this station. Choose which printer will print your pages:',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildPrinterCard(
                  name: 'HP_LaserJet_400_M401dn_F36EC0',
                  title: 'HP LaserJet 400',
                  subtitle: 'Duplex • B&W • Fast',
                  icon: Icons.print_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildPrinterCard(
                  name: 'Printer_2',
                  title: 'Secondary Printer',
                  subtitle: 'Color / Tray 2 • High Res',
                  icon: Icons.color_lens_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrinterCard({
    required String name,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedPrinterName == name;
    return InkWell(
      onTap: () async {
        setState(() {
          _selectedPrinterName = name;
        });
        await _apiService.selectOrderPrinter(
          orderId: widget.orderId,
          cupsPrinterName: name,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Target printer assigned to $title'),
              duration: const Duration(seconds: 1),
              backgroundColor: AppTheme.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primarySurface : AppTheme.surfaceSubtle,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: AppTheme.primary,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? AppTheme.primary.withOpacity(0.8) : AppTheme.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
    final h = totalSecs ~/ 3600;
    final m = (totalSecs % 3600) ~/ 60;
    final s = totalSecs % 60;
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}m ${s.toString().padLeft(2, '0')}s';
    }
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
    if (_selectedPrinterName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a destination printer first!'),
          backgroundColor: AppTheme.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
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
        titleSpacing: 16,
        elevation: 0,
        backgroundColor: AppTheme.surfaceWhite,
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
                errorBuilder: (ctx, err, stack) => const Icon(Icons.pin_rounded, size: 22, color: AppTheme.primary),
              ),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'Release OTP Code',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
            child: ElevatedButton.icon(
              onPressed: () => showServerConfigModal(context),
              icon: const Icon(Icons.dns_rounded, size: 15, color: Colors.white),
              label: const Text(
                'Server',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const WorkflowStepper(currentStep: 4),
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
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.dangerSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: AppTheme.danger, fontSize: 13),
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Two-Printer Selection Card
                      _buildPrinterSelector(),

                      const SizedBox(height: 16),

                      // Large OTP Digits Display Card - Revealed after printer selection
                      if (_selectedPrinterName == null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceWhite,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppTheme.primary.withOpacity(0.3), width: 1.5),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: AppTheme.primarySurface,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                                ),
                                child: const Center(
                                  child: Icon(Icons.touch_app_rounded, size: 28, color: AppTheme.primary),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Select a Printer Above',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Tap either HP LaserJet 400 or Secondary Printer above to route your print job and reveal your 6-digit release OTP code.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceWhite,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppTheme.primary.withOpacity(0.4), width: 2),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.successSurface,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: AppTheme.success.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.check_circle_rounded, size: 14, color: AppTheme.success),
                                        const SizedBox(width: 5),
                                        Text(
                                          _selectedPrinterName == 'Printer_2'
                                              ? 'Routed to: Secondary Printer'
                                              : 'Routed to: HP LaserJet 400',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.success,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
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
                    ],

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
