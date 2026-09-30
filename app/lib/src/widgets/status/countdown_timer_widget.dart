import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_spacing.dart';
import '../../constants/app_typography.dart';
import '../../utils/formatters.dart';

class CountdownTimerWidget extends StatelessWidget {
  final Duration remainingDuration;
  final bool isExpired;

  const CountdownTimerWidget({
    super.key,
    required this.remainingDuration,
    this.isExpired = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isLow = remainingDuration.inMinutes < 2 && !isExpired;
    final Color color = isExpired
        ? AppColors.error
        : (isLow ? AppColors.warning : AppColors.primary);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isExpired ? Icons.timer_off_outlined : Icons.timer_outlined,
            color: color,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            isExpired ? 'OTP Expired' : 'Expires in: ${AppFormatters.formatDuration(remainingDuration)}',
            style: AppTypography.titleMedium.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
