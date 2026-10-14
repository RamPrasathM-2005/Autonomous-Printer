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
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.border.withValues(alpha: 0.8),
          width: 1.2,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 450;
          return Row(
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
                      color: isPassed
                          ? AppTheme.primary
                          : const Color(0xFFE2E8F0),
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

              if (isCompleted) {
                bgColor = AppTheme.primary;
                iconColor = Colors.white;
              } else if (isCurrent) {
                bgColor = AppTheme.primary;
                iconColor = Colors.white;
              } else {
                bgColor = const Color(0xFFF1F5F9);
                iconColor = const Color(0xFF64748B);
                border = Border.all(color: const Color(0xFFCBD5E1), width: 1.2);
              }

              final circleSize = isCurrent
                  ? (isNarrow ? 34.0 : 38.0)
                  : (isNarrow ? 28.0 : 32.0);

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: circleSize,
                    height: circleSize,
                    decoration: BoxDecoration(
                      color: bgColor,
                      shape: BoxShape.circle,
                      border: border,
                    ),
                    child: Center(
                      child: isCompleted
                          ? Icon(
                              Icons.check_rounded,
                              size: isNarrow ? 16 : 18,
                              color: Colors.white,
                            )
                          : Icon(
                              stepData['icon'] as IconData,
                              size: isCurrent
                                  ? (isNarrow ? 17 : 19)
                                  : (isNarrow ? 14 : 16),
                              color: iconColor,
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stepData['label'] as String,
                    style: TextStyle(
                      fontSize: isNarrow ? 10 : 11,
                      fontWeight: isCurrent || isCompleted
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isCurrent
                          ? AppTheme.primary
                          : (isCompleted
                                ? AppTheme.textPrimary
                                : const Color(0xFF64748B)),
                    ),
                  ),
                ],
              );
            }),
          );
        },
      ),
    );
  }
}
