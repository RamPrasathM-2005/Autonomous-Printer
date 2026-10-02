import '../widgets/app_scaffold.dart';
import '../widgets/help_action.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../services/api_service.dart';
import '../services/order_recovery_service.dart';
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

  late AnimationController _animController;
  Timer? _pollTimer;

  String? _errorMessage;
  String _statusMessage = 'Checking print status...';
  bool _isCompleted = false;
  bool _mockPrinting = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _startStatusPolling();
  }

  @override
  void dispose() {
    _animController.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startStatusPolling() {
    _pollTimer?.cancel();
    bool polling = false;
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (polling) return;
      polling = true;
      try {
        final order = await _apiService.getOrder(widget.orderId);
        if (!mounted) return;
        final status = order.status.toUpperCase();
        setState(() {
          _errorMessage = null;
          _statusMessage = order.statusLabel;
          if (status == 'COMPLETED') {
            timer.cancel();
            _animController.stop();
            _isCompleted = true;
            _mockPrinting = order.printSettings.mockPrinting;
            _statusMessage = _mockPrinting
                ? 'Test print complete'
                : 'Print complete';
            OrderRecoveryService().markCompleted(widget.orderId);
          } else if (['FAILED', 'EXPIRED', 'REFUNDED'].contains(status)) {
            timer.cancel();
            _animController.stop();
            _errorMessage = status == 'REFUNDED'
                ? 'Payment refunded.'
                : status == 'EXPIRED'
                ? 'Order expired.'
                : 'Printing needs attention. Contact the station.';
          }
        });
      } catch (_) {
        if (mounted) {
          setState(
            () => _errorMessage = 'Connection lost. Print status unconfirmed.',
          );
        }
      } finally {
        polling = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        actions: const [HelpAction()],
        title: const Text('Print status'),
        elevation: 0,
        backgroundColor: AppTheme.surfaceWhite,
        automaticallyImplyLeading: _isCompleted,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
                              Text(
                                _mockPrinting
                                    ? 'Test print complete'
                                    : 'Print complete',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              if (_mockPrinting) ...[
                                const SizedBox(height: 8),
                                const Text('No paper printed.'),
                              ],
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
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 20),
                            ] else ...[
                              RotationTransition(
                                turns: _animController,
                                child: Container(
                                  width: 84,
                                  height: 84,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primarySurface,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppTheme.primary.withValues(
                                        alpha: 0.3,
                                      ),
                                      width: 2,
                                    ),
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
                                  minHeight: 10,
                                  backgroundColor: AppTheme.surfaceSubtle,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        AppTheme.accent,
                                      ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Order details
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
                            _buildRow('Order', widget.orderId),
                            const Divider(height: 20),
                            _buildRow('Station', widget.printServerId),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      if (!_isCompleted)
                        TextButton.icon(
                          onPressed: _startStatusPolling,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Refresh status'),
                        ),
                      if (_isCompleted)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              OrderRecoveryService().printAgain();
                              try {
                                await _apiService.endSession();
                              } catch (_) {}
                              if (!context.mounted) return;
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (ctx) => const UploadScreen(),
                                ),
                                (route) => false,
                              );
                            },
                            icon: const Icon(Icons.add_circle_outline_rounded),
                            label: const Text('Print Again'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
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
        const SizedBox(width: 12),
        Flexible(
          child: SelectableText(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
