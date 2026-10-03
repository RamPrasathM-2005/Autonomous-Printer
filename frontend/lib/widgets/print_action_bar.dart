import 'package:flutter/material.dart';

import '../config/theme.dart';

class PrintActionBar extends StatelessWidget {
  final String details;
  final String amount;
  final String action;
  final VoidCallback onPressed;
  const PrintActionBar({
    super.key,
    required this.details,
    required this.amount,
    required this.action,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: AppTheme.surfaceWhite,
      border: Border(top: BorderSide(color: AppTheme.border)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final summary = Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      details,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      amount,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                );
                final button = FilledButton(
                  onPressed: onPressed,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(140, 48),
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(action),
                );
                if (constraints.maxWidth < 480 ||
                    MediaQuery.textScalerOf(context).scale(14) > 18) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [summary, const SizedBox(height: 12), button],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: summary),
                    const SizedBox(width: 16),
                    button,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}
