import 'package:flutter/material.dart';

import '../config/theme.dart';

class WorkflowStepper extends StatelessWidget {
  final int currentStep; // 1 to 5

  const WorkflowStepper({super.key, required this.currentStep});

  static const List<Map<String, dynamic>> _steps = [
    {'index': 1, 'label': 'Upload', 'icon': Icons.cloud_upload_rounded},
    {'index': 2, 'label': 'Options', 'icon': Icons.tune_rounded},
    {'index': 3, 'label': 'Payment', 'icon': Icons.credit_card_rounded},
    {'index': 4, 'label': 'Release', 'icon': Icons.pin_rounded},
    {'index': 5, 'label': 'Print', 'icon': Icons.print_rounded},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surfaceWhite,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: List.generate(_steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            final stepBefore = (i ~/ 2) + 1;
            final isPassed = currentStep > stepBefore;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: isPassed ? AppTheme.primary : AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }

          final stepIndex = (i ~/ 2) + 1;
          final stepData = _steps[stepIndex - 1];
          final isCompleted = currentStep > stepIndex;
          final isCurrent = currentStep == stepIndex;

          Color bgColor;
          Color iconColor;
          Border? border;
          List<BoxShadow>? shadow;

          if (isCompleted) {
            bgColor = AppTheme.primary;
            iconColor = Colors.white;
          } else if (isCurrent) {
            bgColor = AppTheme.primarySurface;
            iconColor = AppTheme.primary;
            border = Border.all(color: AppTheme.primary, width: 2);
            shadow = [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ];
          } else {
            bgColor = AppTheme.surfaceSubtle;
            iconColor = AppTheme.textMuted;
            border = Border.all(color: AppTheme.border, width: 1);
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: isCurrent ? 36 : 30,
                height: isCurrent ? 36 : 30,
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                  border: border,
                  boxShadow: shadow,
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Colors.white,
                        )
                      : Icon(
                          stepData['icon'] as IconData,
                          size: isCurrent ? 17 : 14,
                          color: iconColor,
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                stepData['label'] as String,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isCurrent
                      ? FontWeight.w700
                      : (isCompleted ? FontWeight.w600 : FontWeight.w500),
                  color: isCurrent
                      ? AppTheme.primary
                      : (isCompleted
                            ? AppTheme.textPrimary
                            : AppTheme.textMuted),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
