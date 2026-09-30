import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_spacing.dart';
import '../../constants/app_typography.dart';

class SegmentedToggleOption<T> {
  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;

  const SegmentedToggleOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
  });
}

class SegmentedToggle<T> extends StatelessWidget {
  final T selectedValue;
  final List<SegmentedToggleOption<T>> options;
  final ValueChanged<T> onSelected;

  const SegmentedToggle({
    super.key,
    required this.selectedValue,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: options.map((opt) {
        final isSelected = opt.value == selectedValue;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: InkWell(
              onTap: () => onSelected(opt.value),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? AppColors.primaryDark.withValues(alpha: 0.2) : AppColors.primaryContainer)
                      : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
                  border: Border.all(
                    color: isSelected
                        ? (isDark ? AppColors.primaryDark : AppColors.primary)
                        : (isDark ? AppColors.surfaceVariantDark : AppColors.outlineVariantLight),
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (opt.icon != null) ...[
                      Icon(
                        opt.icon,
                        size: 22,
                        color: isSelected
                            ? (isDark ? AppColors.primaryDark : AppColors.primary)
                            : (isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      opt.label,
                      style: AppTypography.titleMedium.copyWith(
                        color: isSelected
                            ? (isDark ? AppColors.primaryDark : AppColors.primary)
                            : (isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (opt.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        opt.subtitle!,
                        style: AppTypography.labelSmall.copyWith(
                          color: isSelected
                              ? (isDark ? AppColors.primaryDark : AppColors.primary)
                              : AppColors.outlineLight,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
