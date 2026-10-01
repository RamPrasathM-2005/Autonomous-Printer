import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../models/order.dart';
import '../services/api_error.dart';
import '../services/api_service.dart';
import '../services/print_agent_service.dart';
import '../widgets/workflow_stepper.dart';
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

  int _secondsLeft = 900; // 15 mins

  String? _selectedPrinterName;
  bool _isPrinterLocked = false;
  bool _isSubmittingPrinter = false;
  bool _isReleasing = false;

  static const String _kPrinter1Id = 'HP_LaserJet_400_M401dn_F36EC0';
  static const String _kPrinter2Id = 'Printer_2';

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
          expiry = DateTime.tryParse(
            otp.expiresAt.endsWith('Z') ? otp.expiresAt : '${otp.expiresAt}Z',
          );
        } catch (_) {}
      }
      final diff = expiry != null
          ? expiry.difference(DateTime.now()).inSeconds
          : 900;

      final existingPrinter = order.printSettings.toJson()['printer_name'] ??
          order.printSettings.toJson()['cups_printer_name'] ??
          otp.selectedPrinter;

      final isLocked = otp.printerSelectionLocked ||
          (order.printSettings.toJson()['printer_selection_locked'] == true);

      setState(() {
        _order = order;
        _otpData = otp;
        _secondsLeft = diff > 0 ? diff : 0;
        if (existingPrinter != null && existingPrinter.toString().isNotEmpty) {
          _selectedPrinterName = existingPrinter.toString();
        }
        _isPrinterLocked = isLocked && _selectedPrinterName != null;
        _isLoading = false;
      });

      _startCountdown();
      _startPolling();
    } catch (e) {
      setState(() {
        _errorMessage = userError(e);
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

      if (status == 'PRINTING' ||
          status == 'COMPLETED' ||
          status == 'RELEASED') {
        _pollingTimer?.cancel();
        _countdownTimer?.cancel();

        if (!mounted) return;
        _goToProgressScreen();
      }
    } catch (_) {}
  }

  void _goToProgressScreen() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();

    final activeOtp = _otpData?.otpCode ?? '------';

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (ctx) => PrintProgressScreen(
          orderId: widget.orderId,
          otp: activeOtp,
          printServerId: _order?.printServerId ?? 'PRINT-SERVER-001',
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
    final otpStr = _otpData?.otpCode ?? '';
    if (otpStr.isEmpty) return;
    Clipboard.setData(ClipboardData(text: otpStr));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text('OTP Code $otpStr copied to clipboard!'),
          ],
        ),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _selectAndLockPrinter(String printerName) async {
    if (_isPrinterLocked) return;

    setState(() {
      _selectedPrinterName = printerName;
      _isSubmittingPrinter = true;
    });

    try {
      final success = await _apiService.selectOrderPrinter(
        orderId: widget.orderId,
        cupsPrinterName: printerName,
      );

      if (success) {
        setState(() {
          _isPrinterLocked = true;
          _isSubmittingPrinter = false;
        });

        final printerTitle = printerName == _kPrinter1Id
            ? 'HP LaserJet 400'
            : 'Secondary Station Printer';

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Target printer locked to $printerTitle! Release OTP is ready.'),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        setState(() {
          _isSubmittingPrinter = false;
          _isPrinterLocked = true;
        });
      }
    } catch (e) {
      setState(() => _isSubmittingPrinter = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _releaseOrder() async {
    if (_otpData == null || _order == null || _isReleasing) return;
    if (!_isPrinterLocked || _selectedPrinterName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select and confirm a printer first.'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    setState(() => _isReleasing = true);

    try {
      final agentService = PrintAgentService();
      await agentService.releasePrintJob(
        stationId: _order!.printServerId,
        otp: _otpData!.otpCode,
      );
      if (mounted) _goToProgressScreen();
    } catch (_) {
      try {
        await _apiService.releaseOrder(widget.orderId, _otpData!.otpCode);
      } catch (_) {}
      if (mounted) _goToProgressScreen();
    } finally {
      if (mounted) setState(() => _isReleasing = false);
    }
  }

  Widget _buildPrinterSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isPrinterLocked ? const Color(0xFF86EFAC) : AppTheme.border,
          width: _isPrinterLocked ? 1.5 : 1,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.print_rounded, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Destination Printer',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      _isPrinterLocked
                          ? 'Printer assigned and locked for this job'
                          : 'Step 1: Choose which printer will output your pages',
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              if (_isPrinterLocked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_rounded, size: 12, color: Color(0xFF166534)),
                      SizedBox(width: 4),
                      Text(
                        'LOCKED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF166534),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Two Printer Cards Side-by-Side
          Row(
            children: [
              Expanded(
                child: _buildPrinterCard(
                  name: _kPrinter1Id,
                  title: 'HP LaserJet 400',
                  subtitle: 'Duplex • B&W • Fast',
                  trayLabel: 'Tray 1 • Standard',
                  icon: Icons.print_rounded,
                  accentColor: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPrinterCard(
                  name: _kPrinter2Id,
                  title: 'Secondary Printer',
                  subtitle: 'Color / Media • High Res',
                  trayLabel: 'Tray 2 • Special',
                  icon: Icons.color_lens_outlined,
                  accentColor: const Color(0xFF059669),
                ),
              ),
            ],
          ),

          // Confirm & Lock Button if selected but not yet locked
          if (!_isPrinterLocked && _selectedPrinterName != null) ...[
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _isSubmittingPrinter
                  ? null
                  : () => _selectAndLockPrinter(_selectedPrinterName!),
              icon: _isSubmittingPrinter
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.lock_outline_rounded, size: 16),
              label: Text(
                _isSubmittingPrinter
                    ? 'Locking Selection...'
                    : 'Confirm & Lock ${_selectedPrinterName == _kPrinter1Id ? 'HP LaserJet 400' : 'Secondary Printer'}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 6),
            const Center(
              child: Text(
                'Selection locks permanently. Switching is not allowed after confirmation.',
                style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrinterCard({
    required String name,
    required String title,
    required String subtitle,
    required String trayLabel,
    required IconData icon,
    required Color accentColor,
  }) {
    final isSelected = _selectedPrinterName == name;
    final isLocked = _isPrinterLocked;

    return InkWell(
      onTap: isLocked
          ? null
          : () {
              setState(() {
                _selectedPrinterName = name;
              });
            },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? (isLocked ? const Color(0xFFF0FDF4) : accentColor.withValues(alpha: 0.06))
              : (isLocked ? const Color(0xFFF8FAFC) : AppTheme.surfaceSubtle),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? (isLocked ? const Color(0xFF16A34A) : accentColor)
                : (isLocked ? const Color(0xFFE2E8F0) : AppTheme.border),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: isSelected ? accentColor : (isLocked ? const Color(0xFF94A3B8) : AppTheme.textSecondary),
                ),
                if (isSelected && isLocked)
                  const Icon(Icons.check_circle_rounded, size: 20, color: Color(0xFF16A34A))
                else if (isSelected)
                  Icon(Icons.radio_button_checked_rounded, size: 20, color: accentColor)
                else if (!isLocked)
                  const Icon(Icons.radio_button_off_rounded, size: 20, color: Color(0xFFCBD5E1))
                else
                  const Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFFCBD5E1)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: isSelected
                    ? (isLocked ? const Color(0xFF166534) : AppTheme.textPrimary)
                    : (isLocked ? const Color(0xFF94A3B8) : AppTheme.textPrimary),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? AppTheme.textSecondary
                    : (isLocked ? const Color(0xFF94A3B8) : AppTheme.textMuted),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isLocked ? const Color(0xFFDCFCE7) : accentColor.withValues(alpha: 0.12))
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                trayLabel,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? (isLocked ? const Color(0xFF166534) : accentColor)
                      : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpSection() {
    if (!_isPrinterLocked) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primarySurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.touch_app_rounded, size: 28, color: AppTheme.primary),
            ),
            const SizedBox(height: 12),
            const Text(
              'Select Destination Printer First',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose either HP LaserJet 400 or Secondary Printer above to lock your destination and generate your 6-digit release OTP.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
            ),
          ],
        ),
      );
    }

    final otpStr = _otpData?.otpCode ?? '------';
    final targetPrinterTitle = _selectedPrinterName == _kPrinter1Id
        ? 'HP LaserJet 400 M401dn'
        : 'Secondary Station Printer';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF16A34A)),
                const SizedBox(width: 6),
                Text(
                  'Assigned to $targetPrinterTitle (Locked)',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF166534),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          const Text(
            'YOUR 6-DIGIT RELEASE OTP',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 14),

          // Stylized individual digit boxes
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              6,
              (i) {
                final char = i < otpStr.length ? otpStr[i] : '-';
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 44,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      char,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Action Buttons: Copy Code & Timer
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _copyToClipboard,
                icon: const Icon(Icons.copy_rounded, size: 15),
                label: const Text('Copy Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.warningSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 15, color: AppTheme.warning),
                    const SizedBox(width: 6),
                    Text(
                      _secondsLeft <= 0 ? 'Expired' : 'Expires in ${_formatTimer(_secondsLeft)}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
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
    );
  }

  Widget _buildInstructions() {
    final targetPrinterTitle = _selectedPrinterName == _kPrinter1Id
        ? 'HP LaserJet 400'
        : 'Secondary Printer';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How to Release Your Print Job',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildInstructionStep(
            step: '1',
            title: 'Walk to the Kiosk Terminal',
            subtitle: 'Locate Station 1 touchscreen terminal.',
          ),
          const SizedBox(height: 10),
          _buildInstructionStep(
            step: '2',
            title: 'Enter 6-Digit OTP',
            subtitle: 'Type the code on the screen and tap Release Document.',
          ),
          const SizedBox(height: 10),
          _buildInstructionStep(
            step: '3',
            title: 'Collect Pages from $targetPrinterTitle',
            subtitle: 'Your physical pages output immediately from the locked printer tray.',
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
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppTheme.primarySurface,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
          ),
          child: Center(
            child: Text(
              step,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Printer Selection & Release'),
        elevation: 0,
        backgroundColor: AppTheme.surfaceWhite,
      ),
      body: Column(
        children: [
          const WorkflowStepper(currentStep: 4),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_errorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.dangerSurface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppTheme.danger.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: AppTheme.danger,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],

                            // Step 1: Printer Selector First!
                            _buildPrinterSelector(),

                            const SizedBox(height: 16),

                            // Step 2: OTP Section (Displayed once printer is confirmed/locked)
                            _buildOtpSection(),

                            const SizedBox(height: 16),

                            // Instructions Step Guide
                            _buildInstructions(),

                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceWhite,
              border: const Border(top: BorderSide(color: AppTheme.border)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ElevatedButton.icon(
                    onPressed: (!_isPrinterLocked || _secondsLeft <= 0 || _isReleasing)
                        ? null
                        : _releaseOrder,
                    icon: _isReleasing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.print_rounded, size: 20),
                    label: Text(
                      !_isPrinterLocked
                          ? 'Select & Confirm Printer Above'
                          : (_isReleasing
                              ? 'Starting Print...'
                              : 'Auto-Release Print Job Now'),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
