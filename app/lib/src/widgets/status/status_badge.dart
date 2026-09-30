import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

enum BadgeType { neutral, success, warning, error, primary }

class StatusBadge extends StatelessWidget {
  final String text;
  final BadgeType type;

  const StatusBadge({
    super.key,
    required this.text,
    this.type = BadgeType.neutral,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (type) {
      case BadgeType.success:
        bg = AppColors.successContainer;
        fg = AppColors.onSuccessContainer;
        break;
      case BadgeType.warning:
        bg = AppColors.warningContainer;
        fg = AppColors.onWarningContainer;
        break;
      case BadgeType.error:
        bg = AppColors.errorContainer;
        fg = AppColors.onErrorContainer;
        break;
      case BadgeType.primary:
        bg = AppColors.primaryContainer;
        fg = AppColors.onPrimaryContainer;
        break;
      case BadgeType.neutral:
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade800;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
