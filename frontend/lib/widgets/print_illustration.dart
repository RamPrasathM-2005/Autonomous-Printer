import 'package:flutter/material.dart';

import '../config/theme.dart';

/// A small code-native illustration; no network assets or font downloads.
class PrintIllustration extends StatelessWidget {
  const PrintIllustration({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: 320,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 230,
            height: 145,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0xFFD0DFFF), Color(0x00D0DFFF)],
              ),
            ),
          ),
          Positioned(
            top: 10,
            child: Container(
              width: 100,
              height: 102,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primaryBorder),
              ),
              child: Column(
                children: List.generate(
                  3,
                  (index) => Container(
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9E3F7),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 64,
            child: Container(
              width: 170,
              height: 88,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF3265E9), Color(0xFF12329E)],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.18),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Align(
                alignment: Alignment(0.75, -0.65),
                child: Icon(Icons.circle, color: Color(0xFF9BF3C6), size: 7),
              ),
            ),
          ),
          Positioned(
            top: 103,
            child: Container(
              width: 124,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFF0C2569),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          Positioned(
            top: 110,
            child: Container(
              width: 104,
              height: 59,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.primaryBorder),
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: AppTheme.primary,
                size: 26,
              ),
            ),
          ),
          _file('PDF', const Color(0xFFE95468), 21, 28, -0.15),
          _file('JPG', const Color(0xFF249E80), 253, 43, 0.15),
          _file('PNG', const Color(0xFF8960D5), 242, 117, -0.1),
        ],
      ),
    ),
  );

  Widget _file(
    String label,
    Color color,
    double left,
    double top,
    double angle,
  ) => Positioned(
    left: left,
    top: top,
    child: Transform.rotate(
      angle: angle,
      child: Container(
        width: 49,
        height: 59,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.primaryBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
