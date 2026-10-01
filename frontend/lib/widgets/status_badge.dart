import 'package:flutter/material.dart';

import '../config/theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const StatusBadge({
    super.key,
    required this.status,
    this.fontSize = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  });

  Color _getColor() {
    final s = status.toUpperCase();
    if (s == 'ONLINE' ||
        s == 'COMPLETED' ||
        s == 'SUCCESS' ||
        s == 'NORMAL' ||
        s == 'IDLE' ||
        s == 'RELEASED') {
      return AppTheme.success;
    }
    if (s == 'WAITING_FOR_OTP' ||
        s == 'WAITING_FOR_PAYMENT' ||
        s == 'LOW' ||
        s == 'PRINTING') {
      return AppTheme.warning;
    }
    if (s == 'OFFLINE' ||
        s == 'FAILED' ||
        s == 'ERROR' ||
        s == 'EMPTY' ||
        s == 'CANCELLED') {
      return AppTheme.danger;
    }
    return AppTheme.info;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status.replaceAll('_', ' '),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }
}
