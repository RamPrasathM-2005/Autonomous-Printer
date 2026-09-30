import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_spacing.dart';
import '../../constants/app_typography.dart';

class KioskInfoCard extends StatelessWidget {
  final String stationName;
  final String stationId;

  const KioskInfoCard({
    super.key,
    required this.stationName,
    required this.stationId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF2D1B69), const Color(0xFF1E1035)]
              : [AppColors.primaryContainer, AppColors.primaryContainer.withValues(alpha: 0.5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.primaryDark.withValues(alpha: 0.2) : AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.print,
              color: isDark ? AppColors.primaryDark : AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connected Kiosk',
                  style: AppTypography.labelSmall.copyWith(
                    color: isDark ? AppColors.onPrimaryContainerDark : AppColors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  stationName,
                  style: AppTypography.titleMedium.copyWith(
                    color: isDark ? AppColors.onPrimaryContainerDark : AppColors.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'ID: $stationId',
                  style: AppTypography.bodySmall.copyWith(
                    color: isDark ? AppColors.onPrimaryContainerDark.withValues(alpha: 0.8) : AppColors.onPrimaryContainer.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
