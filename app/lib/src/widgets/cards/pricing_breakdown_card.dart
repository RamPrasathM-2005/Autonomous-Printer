import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_spacing.dart';
import '../../constants/app_typography.dart';
import '../../utils/price_calculator.dart';
import '../../utils/formatters.dart';

class PricingBreakdownCard extends StatelessWidget {
  final PricingBreakdown breakdown;

  const PricingBreakdownCard({
    super.key,
    required this.breakdown,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Price Summary', style: AppTypography.headlineMedium),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.primaryDark : AppColors.primary).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Text(
                    '${breakdown.totalSheets} Sheets / ${breakdown.totalPrintPages} Pages',
                    style: AppTypography.labelSmall.copyWith(
                      color: isDark ? AppColors.primaryDark : AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _buildRow('Printing Subtotal', AppFormatters.formatCurrency(breakdown.subtotal)),
            const SizedBox(height: AppSpacing.xs),
            _buildRow('Kiosk Platform Fee', AppFormatters.formatCurrency(breakdown.serviceFee)),
            const SizedBox(height: AppSpacing.xs),
            _buildRow('GST (18%)', AppFormatters.formatCurrency(breakdown.gstTax)),
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Payable',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                Text(
                  AppFormatters.formatCurrency(breakdown.grandTotal),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.primaryDark : AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.bodyMedium),
        Text(value, style: AppTypography.titleMedium),
      ],
    );
  }
}
