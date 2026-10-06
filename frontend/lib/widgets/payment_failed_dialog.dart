import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Modal dialog presented when a payment attempt fails or is closed.
/// Mirrors the standard payment failure interface with Retry and Cancel actions.
class PaymentFailedDialog extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onCancel;
  final String? message;
  final VoidCallback? onCheckStatus;

  const PaymentFailedDialog({
    super.key,
    required this.onRetry,
    required this.onCancel,
    this.message,
    this.onCheckStatus,
  });

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onRetry,
    required VoidCallback onCancel,
    String? message,
    VoidCallback? onCheckStatus,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PaymentFailedDialog(
        message: message,
        onCheckStatus: onCheckStatus == null
            ? null
            : () {
                Navigator.of(ctx).pop();
                onCheckStatus();
              },
        onRetry: () {
          Navigator.of(ctx).pop();
          onRetry();
        },
        onCancel: () {
          Navigator.of(ctx).pop();
          onCancel();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      backgroundColor: AppTheme.surfaceWhite,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Red circular icon with subtle halo
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFEE2E2), // soft red halo
                ),
                child: Center(
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFEF4444), // red-500
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Title
              const Text(
                'Payment Failed',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.2,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // Subtitle
              Text(
                message ?? 'Your transaction couldn’t be completed. Please try again or use a different payment method.',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textSecondary,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // Retry Payment Button (Green)
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF15803D), // solid green
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Retry Payment',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              if (onCheckStatus != null)
                TextButton(
                  onPressed: onCheckStatus,
                  child: const Text('Check payment status'),
                ),

              // Cancel Button (Outlined/Neutral)
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppTheme.surfaceSubtle,
                    foregroundColor: AppTheme.textPrimary,
                    side: const BorderSide(color: AppTheme.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
