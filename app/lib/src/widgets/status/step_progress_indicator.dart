import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_spacing.dart';

class StepProgressIndicator extends StatelessWidget {
  final int currentStep; // 1: Upload, 2: Configure, 3: Order/Pay, 4: OTP/Print
  final int totalSteps;

  const StepProgressIndicator({
    super.key,
    required this.currentStep,
    this.totalSteps = 4,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: List.generate(totalSteps, (index) {
        final stepNumber = index + 1;
        final isPassed = stepNumber < currentStep;
        final isCurrent = stepNumber == currentStep;

        Color stepColor;
        if (isPassed || isCurrent) {
          stepColor = isDark ? AppColors.primaryDark : AppColors.primary;
        } else {
          stepColor = isDark ? AppColors.surfaceVariantDark : AppColors.outlineVariantLight;
        }

        return Expanded(
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: isPassed ? stepColor : (isCurrent ? stepColor : Colors.transparent),
                  shape: BoxShape.circle,
                  border: Border.all(color: stepColor, width: 2),
                ),
                child: Center(
                  child: isPassed
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : Text(
                          '$stepNumber',
                          style: TextStyle(
                            color: isCurrent ? Colors.white : stepColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                ),
              ),
              if (index < totalSteps - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                    color: isPassed ? stepColor : (isDark ? AppColors.surfaceVariantDark : AppColors.outlineVariantLight),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}
