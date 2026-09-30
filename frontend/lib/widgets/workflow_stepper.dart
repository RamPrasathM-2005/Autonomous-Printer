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
    return LayoutBuilder(
      builder: (context, constraints) {
        // On very narrow screens (< 340px), hide labels entirely and shrink circles.
        // On compact screens (< 420px), show label only for active step.
        // On wide screens, show all labels.
        final w = constraints.maxWidth;
        final hideAllLabels = w < 330;
        final hideInactiveLabels = w < 420;

        // Sizes scale down on narrow screens
        final double circleSize = w < 330 ? 28 : (w < 420 ? 30 : 34);
        final double activeCircleSize = w < 330 ? 34 : (w < 420 ? 36 : 42);
        final double iconSize = w < 330 ? 14 : (w < 420 ? 15 : 18);
        final double activeIconSize = w < 330 ? 16 : (w < 420 ? 17 : 20);
        final double fontSize = w < 330 ? 9.5 : (w < 420 ? 10.5 : 12.0);
        final double activeFontSize = w < 330 ? 10.5 : (w < 420 ? 11.5 : 13.0);
        final double horizontalPad = w < 330 ? 8 : (w < 420 ? 10 : 16);

        return Container(
          margin: EdgeInsets.fromLTRB(horizontalPad, 10, horizontalPad, 8),
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPad,
            vertical: w < 420 ? 10 : 13,
          ),
          decoration: BoxDecoration(
            color: AppTheme.surfaceWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border.withValues(alpha: 0.8), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(_steps.length * 2 - 1, (i) {
              // Odd indices = connector lines between steps
              if (i.isOdd) {
                final stepBefore = (i ~/ 2) + 1;
                final isPassed = currentStep > stepBefore;
                return Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 3,
                    margin: EdgeInsets.symmetric(horizontal: w < 330 ? 1 : 2),
                    decoration: BoxDecoration(
                      color: isPassed ? AppTheme.primary : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }

              final stepIndex = (i ~/ 2) + 1;
              final stepData = _steps[stepIndex - 1];
              final isCompleted = currentStep > stepIndex;
              final isCurrent = currentStep == stepIndex;
              final showLabel = hideAllLabels
                  ? false
                  : hideInactiveLabels
                      ? isCurrent
                      : true;

              Color bgColor;
              Color iconColor;
              Border? border;
              List<BoxShadow>? shadow;

              if (isCompleted) {
                bgColor = AppTheme.primary;
                iconColor = Colors.white;
                border = null;
                shadow = null;
              } else if (isCurrent) {
                bgColor = AppTheme.primary;
                iconColor = Colors.white;
                border = Border.all(
                  color: AppTheme.primaryLight.withValues(alpha: 0.3),
                  width: 3,
                );
                shadow = [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ];
              } else {
                bgColor = const Color(0xFFF1F5F9);
                iconColor = const Color(0xFF64748B);
                border = Border.all(color: const Color(0xFFCBD5E1), width: 1.2);
                shadow = null;
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: isCurrent ? activeCircleSize : circleSize,
                    height: isCurrent ? activeCircleSize : circleSize,
                    decoration: BoxDecoration(
                      color: bgColor,
                      shape: BoxShape.circle,
                      border: border,
                      boxShadow: shadow,
                    ),
                    child: Center(
                      child: isCompleted
                          ? Icon(Icons.check_rounded,
                              size: isCurrent ? activeIconSize : iconSize,
                              color: Colors.white)
                          : Icon(
                              stepData['icon'] as IconData,
                              size: isCurrent ? activeIconSize : iconSize,
                              color: iconColor,
                            ),
                    ),
                  ),
                  if (showLabel) ...[
                    const SizedBox(height: 4),
                    Text(
                      stepData['label'] as String,
                      style: TextStyle(
                        fontSize: isCurrent ? activeFontSize : fontSize,
                        fontWeight: isCurrent
                            ? FontWeight.w800
                            : (isCompleted ? FontWeight.w700 : FontWeight.w600),
                        color: isCurrent
                            ? AppTheme.primary
                            : (isCompleted
                                ? AppTheme.textPrimary
                                : const Color(0xFF64748B)),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              );
            }),
          ),
        );
      },
    );
  }
}
