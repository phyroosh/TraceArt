import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/grid_config.dart';

/// High-performance [CustomPainter] rendering the proportional drawing grid
/// directly on the reference image canvas.
class GridPainter extends CustomPainter {
  final GridConfig config;

  const GridPainter({required this.config});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || config.divisions < 1) return;

    final paint = Paint()
      ..color = config.activeColor
      ..strokeWidth = config.strokeWidth
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    final stepX = size.width / config.divisions;
    final stepY = size.height / config.divisions;

    // 1. Draw outer boundary frame
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // 2. Draw vertical grid lines
    for (int i = 1; i < config.divisions; i++) {
      final x = stepX * i;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // 3. Draw horizontal grid lines
    for (int i = 1; i < config.divisions; i++) {
      final y = stepY * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // 4. Draw optional center crosshair
    if (config.showCenterCrosshair) {
      final crosshairPaint = Paint()
        ..color = config.activeColor
        ..strokeWidth = config.strokeWidth * 1.8
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;

      final centerX = size.width / 2.0;
      final centerY = size.height / 2.0;

      canvas.drawLine(Offset(centerX, 0), Offset(centerX, size.height), crosshairPaint);
      canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), crosshairPaint);
    }

    // 5. Draw optional corner-to-corner diagonal armature lines
    if (config.showDiagonals) {
      final diagPaint = Paint()
        ..color = config.activeColor.withValues(
          alpha: (config.opacity * 0.75).clamp(0.0, 1.0),
        )
        ..strokeWidth = config.strokeWidth
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;

      canvas.drawLine(Offset.zero, Offset(size.width, size.height), diagPaint);
      canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), diagPaint);
    }

    // 6. Draw optional alphanumeric square labels (A1, B1, etc.)
    if (config.showLabels) {
      final fontSize = (math.min(stepX, stepY) * 0.16).clamp(9.0, 22.0);
      final textStyle = TextStyle(
        color: config.activeColor,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 3,
            offset: const Offset(1, 1),
          ),
        ],
      );

      for (int row = 0; row < config.divisions; row++) {
        for (int col = 0; col < config.divisions; col++) {
          final colLabel = _getColumnLabel(col);
          final label = '$colLabel${row + 1}';

          final textPainter = TextPainter(
            text: TextSpan(text: label, style: textStyle),
            textDirection: TextDirection.ltr,
          )..layout();

          final offset = Offset(
            col * stepX + 4.0,
            row * stepY + 4.0,
          );
          textPainter.paint(canvas, offset);
        }
      }
    }
  }

  String _getColumnLabel(int index) {
    if (index < 26) {
      return String.fromCharCode(65 + index);
    }
    final first = String.fromCharCode(65 + (index ~/ 26) - 1);
    final second = String.fromCharCode(65 + (index % 26));
    return '$first$second';
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) {
    return oldDelegate.config != config;
  }
}
