import 'package:flutter/material.dart';
import '../config/theme.dart';

class WorkflowStepper extends StatelessWidget {
  final int currentStep; // 1 to 5

  const WorkflowStepper({
    super.key,
    required this.currentStep,
  });

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
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.8), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: List.generate(_steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            final stepBefore = (i ~/ 2) + 1;
            final isPassed = currentStep > stepBefore;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: isPassed ? AppTheme.primary : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(3),
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
            bgColor = AppTheme.primary;
            iconColor = Colors.white;
            border = Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3), width: 4);
            shadow = [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ];
          } else {
            bgColor = const Color(0xFFF1F5F9);
            iconColor = const Color(0xFF64748B);
            border = Border.all(color: const Color(0xFFCBD5E1), width: 1.5);
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: isCurrent ? 42 : 36,
                height: isCurrent ? 42 : 36,
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                  border: border,
                  boxShadow: shadow,
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check_rounded, size: 20, color: Colors.white)
                      : Icon(
                          stepData['icon'] as IconData,
                          size: isCurrent ? 20 : 18,
                          color: iconColor,
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                stepData['label'] as String,
                style: TextStyle(
                  fontSize: isCurrent ? 13 : 12,
                  fontWeight: isCurrent
                      ? FontWeight.w800
                      : (isCompleted ? FontWeight.w700 : FontWeight.w600),
                  color: isCurrent
                      ? AppTheme.primary
                      : (isCompleted ? AppTheme.textPrimary : const Color(0xFF64748B)),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
