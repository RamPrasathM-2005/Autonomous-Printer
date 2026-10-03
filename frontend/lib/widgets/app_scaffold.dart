import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/theme.dart';

/// A shared, quiet backdrop for every step of the print flow.
class AppScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? bottomNavigationBar;

  const AppScaffold({
    super.key,
    this.appBar,
    this.body,
    this.bottomNavigationBar,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF3F7FE),
    resizeToAvoidBottomInset: true,
    appBar: appBar,
    bottomNavigationBar: bottomNavigationBar,
    body: Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(painter: _BlueTilePainter()),
            ),
          ),
        ),
        if (body != null) SafeArea(top: false, bottom: false, child: body!),
      ],
    ),
  );
}

class _BlueTilePainter extends CustomPainter {
  const _BlueTilePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final fadeHeight = math.min(420.0, size.height);
    final rect = Rect.fromLTWH(0, 0, size.width, fadeHeight);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE0ECFF), Color(0xFFF3F7FE)],
        ).createShader(rect),
    );
    const tile = 32.0;
    for (var row = 0; row * tile < fadeHeight; row++) {
      final fade = math.pow(1 - row * tile / fadeHeight, 2).toDouble();
      for (var col = 0; col * tile < size.width; col++) {
        final cell = Rect.fromLTWH(col * tile, row * tile, tile, tile);
        if ((col * 7 + row * 11) % 9 < 2) {
          canvas.drawRect(
            cell,
            Paint()..color = AppTheme.primary.withValues(alpha: 0.035 * fade),
          );
        }
        canvas.drawRect(
          cell,
          Paint()
            ..color = AppTheme.primary.withValues(alpha: 0.055 * fade)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BlueTilePainter oldDelegate) => false;
}
