import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../models/order.dart';
import '../services/api_error.dart';
import '../services/api_service.dart';
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

  int _secondsLeft = 900; // 15 mins
  Timer? _countdownTimer;

  String _selectedPrinterName = 'HP_LaserJet_400_M401dn_F36EC0';
  bool _isPrinterLocked = false;
  bool _isSwitching = false;
  bool _isReleasing = false;

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

      setState(() {
        _order = order;
        _otpData = otp;
        _secondsLeft = diff > 0 ? diff : 0;
        _selectedPrinterName = otp.selectedPrinter ??
            'HP_LaserJet_400_M401dn_F36EC0';
        _isPrinterLocked = otp.printerSelectionLocked;
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

    final activeOtp = _getOtpForPrinter(_selectedPrinterName);

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

  String _getOtpForPrinter(String cupsPrinterName) {
    if (_otpData?.printerOtps != null &&
        _otpData!.printerOtps!.containsKey(cupsPrinterName)) {
      final entry = _otpData!.printerOtps![cupsPrinterName];
      if (entry is Map && entry['otp'] != null) {
        return entry['otp'].toString();
      }
    }
    return _otpData?.otpCode ?? '------';
  }

  void _copyToClipboard(String otpCode, String printerTitle) {
    Clipboard.setData(ClipboardData(text: otpCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text('OTP for $printerTitle copied to clipboard'),
          ],
        ),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _switchPrinter(String targetPrinterName, String printerTitle) async {
    if (_isPrinterLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Printer switching was already used. Switching is allowed only once.'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Switch Printer?'),
        content: Text(
          'Switch target printer to $printerTitle? Switching is allowed only once and will lock printer selection for this print job.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('Confirm Switch', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSwitching = true);
    try {
      final success = await _apiService.selectOrderPrinter(
        orderId: widget.orderId,
        cupsPrinterName: targetPrinterName,
      );
      if (success) {
        setState(() {
          _selectedPrinterName = targetPrinterName;
          _isPrinterLocked = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Printer switched to $printerTitle and locked.'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Printer switching is already locked on server.'),
              backgroundColor: AppTheme.danger,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSwitching = false);
    }
  }

  Future<void> _releaseOrder() async {
    if (_otpData == null || _order == null || _isReleasing) return;
    setState(() => _isReleasing = true);

    try {
      final releaseOtp = _getOtpForPrinter(_selectedPrinterName);
      await _apiService.releaseOrder(widget.orderId, releaseOtp);
      if (mounted) _goToProgressScreen();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = userError(e));
    } finally {
      if (mounted) setState(() => _isReleasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p1Otp = _getOtpForPrinter('HP_LaserJet_400_M401dn_F36EC0');
    final p2Otp = _getOtpForPrinter('Printer_2');

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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Error banner
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

                      // Top Instructions & Security Info
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceWhite,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.shield_outlined,
                                    size: 18,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'Dual-Printer Authentication',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.warningSurface,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppTheme.warning.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.timer_outlined, size: 14, color: AppTheme.warning),
                                      const SizedBox(width: 4),
                                      Text(
                                        _secondsLeft <= 0 ? 'Expired' : _formatTimer(_secondsLeft),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFB45309),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Enter the OTP of your chosen printer at the station touchscreen. '
                              'Using one OTP immediately invalidates both codes to block duplicate printing.',
                              style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary, height: 1.4),
                            ),
                            if (_isPrinterLocked) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.lock_rounded, size: 13, color: Color(0xFF92400E)),
                                    SizedBox(width: 6),
                                    Text(
                                      'Printer switching locked (1-time switch used)',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // PRINTER 1 CARD
                      _buildDualPrinterCard(
                        printerCupsName: 'HP_LaserJet_400_M401dn_F36EC0',
                        printerTitle: 'HP LaserJet 400 M401dn',
                        printerBadge: 'Primary Printer · Tray 1',
                        printerSpecs: 'Duplex B&W · High-Speed Laser',
                        printerIcon: Icons.print_rounded,
                        accentColor: const Color(0xFF2563EB),
                        otpCode: p1Otp,
                        isSelected: _selectedPrinterName == 'HP_LaserJet_400_M401dn_F36EC0',
                      ),

                      const SizedBox(height: 14),

                      // PRINTER 2 CARD
                      _buildDualPrinterCard(
                        printerCupsName: 'Printer_2',
                        printerTitle: 'Secondary Station Printer',
                        printerBadge: 'Color Printer · Tray 2',
                        printerSpecs: 'High-Resolution · Color Supported',
                        printerIcon: Icons.color_lens_outlined,
                        accentColor: const Color(0xFF059669),
                        otpCode: p2Otp,
                        isSelected: _selectedPrinterName == 'Printer_2',
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom Action Bar: Single Release Button
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
                    onPressed: (_isLoading || _secondsLeft <= 0 || _isReleasing)
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
                      _isReleasing
                          ? 'Starting Print...'
                          : 'Release Print on ${_selectedPrinterName == 'HP_LaserJet_400_M401dn_F36EC0' ? 'HP LaserJet 400' : 'Secondary Printer'}',
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

  Widget _buildDualPrinterCard({
    required String printerCupsName,
    required String printerTitle,
    required String printerBadge,
    required String printerSpecs,
    required IconData printerIcon,
    required Color accentColor,
    required String otpCode,
    required bool isSelected,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? accentColor : AppTheme.border,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? accentColor.withValues(alpha: 0.07)
                  : AppTheme.surfaceSubtle,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(printerIcon, size: 20, color: accentColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        printerTitle,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        printerSpecs,
                        style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: isSelected ? accentColor : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected ? accentColor : AppTheme.border,
                    ),
                  ),
                  child: Text(
                    isSelected ? 'SELECTED' : 'AVAILABLE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                // OTP Code Display Block
                Text(
                  'DEDICATED RELEASE CODE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 10),

                // Monospace Digits
                _isLoading
                    ? const SizedBox(
                        height: 44,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          6,
                          (i) {
                            final char = i < otpCode.length ? otpCode[i] : '-';
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: 38,
                              height: 46,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? accentColor.withValues(alpha: 0.08)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? accentColor.withValues(alpha: 0.6)
                                      : const Color(0xFFCBD5E1),
                                  width: 1.2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  char,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: isSelected ? accentColor : AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                const SizedBox(height: 12),

                // Action Row: Copy OTP & Switch Printer
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : () => _copyToClipboard(otpCode, printerTitle),
                        icon: const Icon(Icons.copy_rounded, size: 14),
                        label: const Text('Copy OTP', style: TextStyle(fontSize: 11)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: isSelected
                          ? Container(
                              height: 36,
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle_rounded, size: 14, color: accentColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Active Printer',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: accentColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ElevatedButton.icon(
                              onPressed: (_isPrinterLocked || _isSwitching)
                                  ? null
                                  : () => _switchPrinter(printerCupsName, printerTitle),
                              icon: const Icon(Icons.swap_horiz_rounded, size: 14),
                              label: Text(
                                _isPrinterLocked ? 'Switch Locked' : 'Select Printer',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
