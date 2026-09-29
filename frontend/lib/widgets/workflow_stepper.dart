import 'package:flutter/material.dart';
import '../config/theme.dart';

class WorkflowStepper extends StatelessWidget {
  final int currentStep; // 1 to 5

  const WorkflowStepper({
    super.key,
    required this.currentStep,
  });

  static const List<Map<String, dynamic>> _steps = [
    {'index': 1, 'label': 'Upload', 'icon': Icons.cloud_upload_outlined},
    {'index': 2, 'label': 'Options', 'icon': Icons.tune_outlined},
    {'index': 3, 'label': 'Payment', 'icon': Icons.credit_card_outlined},
    {'index': 4, 'label': 'OTP Code', 'icon': Icons.pin_outlined},
    {'index': 5, 'label': 'Printing', 'icon': Icons.print_outlined},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surfaceWhite,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            children: List.generate(_steps.length * 2 - 1, (i) {
              if (i.isOdd) {
                final stepBefore = (i ~/ 2) + 1;
                final isPassed = currentStep > stepBefore;
                return Expanded(
                  child: Container(
                    height: 2,
                    color: isPassed ? AppTheme.primary : AppTheme.border,
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
                bgColor = AppTheme.primarySurface;
                iconColor = AppTheme.primary;
                border = Border.all(color: AppTheme.primary, width: 2);
              } else {
                bgColor = AppTheme.surfaceSubtle;
                iconColor = AppTheme.textMuted;
                border = Border.all(color: AppTheme.border, width: 1);
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: bgColor,
                      shape: BoxShape.circle,
                      border: border,
                    ),
                    child: Center(
                      child: isCompleted
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : Icon(stepData['icon'] as IconData,
                              size: 15, color: iconColor),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stepData['label'] as String,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          isCurrent ? FontWeight.w700 : FontWeight.w500,
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
        ],
      ),
    );
  }
}
