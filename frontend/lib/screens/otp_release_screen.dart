import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_error.dart';

import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../models/order.dart';
import '../services/api_service.dart';
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
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            const Text('Code copied'),
          ],
        ),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _releaseOrder() async {
    if (_otpData == null || _order == null) return;
    try {
      await _apiService.releaseOrder(widget.orderId, _otpData!.otpCode);
      if (mounted) _goToProgressScreen();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = userError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final otpStr = _otpData?.otpCode ?? '------';

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Release print'),
        elevation: 0,
        backgroundColor: AppTheme.surfaceWhite,
      ),
      body: Column(
        children: [
          // WorkflowStepper removed — no top flow bar
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    children: [
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
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
                      ],

                      if (_order?.printSettings.unpaidTestPrint == true)
                        const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: Text('Test print - No payment'),
                        ),
                      const SizedBox(height: 24),

                      // Large OTP Digits Display Card
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 28,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceWhite,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.3),
                            width: 2,
                          ),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Release code',
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
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                : LayoutBuilder(
                                    builder: (context, constraints) {
                                      final width =
                                          ((constraints.maxWidth - 36) / 6)
                                              .clamp(20.0, 44.0);
                                      return Semantics(
                                        label: 'Release code: $otpStr',
                                        excludeSemantics: true,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: List.generate(
                                            6,
                                            (i) => Container(
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 3,
                                                  ),
                                              width: width,
                                              height: width + 12,
                                              decoration: BoxDecoration(
                                                color: AppTheme.primarySurface,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: AppTheme.primary,
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  i < otpStr.length
                                                      ? otpStr[i]
                                                      : '-',
                                                  style: TextStyle(
                                                    fontSize: width * 0.55,
                                                    fontWeight: FontWeight.w900,
                                                    color: AppTheme.primary,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                            const SizedBox(height: 20),

                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _otpData == null
                                      ? null
                                      : _copyToClipboard,
                                  icon: const Icon(
                                    Icons.copy_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('Copy code'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.warningSurface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppTheme.warning.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.timer_outlined,
                                        size: 16,
                                        color: AppTheme.warning,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _secondsLeft <= 0
                                            ? 'Code expired'
                                            : 'Expires in ${_formatTimer(_secondsLeft)}',
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
                  color: Colors.black.withValues(alpha: 0.06),
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
                          onPressed:
                              _isLoading ||
                                  _otpData == null ||
                                  _secondsLeft <= 0
                              ? null
                              : _releaseOrder,
                          icon: const Icon(Icons.print_rounded, size: 20),
                          label: const Text(
                            'Release print',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
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
}
