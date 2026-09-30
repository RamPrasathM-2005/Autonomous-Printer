import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_spacing.dart';
import '../../constants/app_typography.dart';
import '../../models/printer_status_model.dart';

class PrinterStatusBanner extends StatelessWidget {
  final PrinterStatusModel status;

  const PrinterStatusBanner({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final bool isReady = status.isReady;
    final Color bgColor = isReady ? AppColors.successContainer : AppColors.warningContainer;
    final Color contentColor = isReady ? AppColors.onSuccessContainer : AppColors.onWarningContainer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Icon(
            isReady ? Icons.check_circle_outline : Icons.info_outline,
            color: contentColor,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              isReady
                  ? '${status.printerName} • Ready to Print'
                  : 'Printer Alert: ${status.alertMessage ?? "Paper/Queue delay"}',
              style: AppTypography.bodySmall.copyWith(
                color: contentColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: contentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Queue: ${status.queueLength}',
              style: TextStyle(color: contentColor, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
