import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// A custom illustration depicting a luminous tracing light table / screen
/// with a reference character outline and a stylus.
class TracingBoardIllustration extends StatelessWidget {
  final double size;

  const TracingBoardIllustration({super.key, this.size = 200});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.15),
            AppTheme.primary.withValues(alpha: 0.03),
            Colors.transparent,
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
      child: Center(
        child: SizedBox(
          width: size * 0.8,
          height: size * 0.8,
          child: CustomPaint(
            painter: _BoardPainter(),
          ),
        ),
      ),
    );
  }
}

class _BoardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Device body / base light table
    final deviceRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.52),
        width: w * 0.82,
        height: h * 0.72,
      ),
      const Radius.circular(20),
    );

    final devicePaint = Paint()
      ..color = const Color(0xFF1E2129)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(deviceRect, devicePaint);

    final deviceBorder = Paint()
      ..color = const Color(0xFF333846)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(deviceRect, deviceBorder);

    // 2. Glowing bright screen area (light table surface)
    final screenRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.52),
        width: w * 0.72,
        height: h * 0.62,
      ),
      const Radius.circular(14),
    );

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFFBEB),
          const Color(0xFFFEF3C7),
          AppTheme.primary.withValues(alpha: 0.6),
        ],
        stops: const [0.0, 0.7, 1.0],
      ).createShader(screenRect.outerRect);
    canvas.drawRRect(screenRect, glowPaint);

    // 3. Tracing paper sheet rotated slightly
    canvas.save();
    canvas.translate(w * 0.5, h * 0.52);
    canvas.rotate(-0.06);

    final paperRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset.zero,
        width: w * 0.62,
        height: h * 0.52,
      ),
      const Radius.circular(8),
    );

    final paperPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.82)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(paperRect, paperPaint);

    // Reference artwork lines on the paper
    final linePaint = Paint()
      ..color = const Color(0xFF0F172A).withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    // Anime eye / face sketch curve
    final path = Path()
      ..moveTo(-w * 0.16, -h * 0.05)
      ..quadraticBezierTo(-w * 0.08, -h * 0.14, 0, -h * 0.06)
      ..quadraticBezierTo(w * 0.08, -h * 0.14, w * 0.16, -h * 0.05);
    canvas.drawPath(path, linePaint);

    // Second arc (chin / smile)
    final path2 = Path()
      ..moveTo(-w * 0.12, h * 0.05)
      ..quadraticBezierTo(0, h * 0.14, w * 0.12, h * 0.05);
    canvas.drawPath(path2, linePaint);

    // Pencil / Stylus drawing on the sheet
    final penBodyPaint = Paint()
      ..color = AppTheme.primary
      ..style = PaintingStyle.fill;
    final penTipPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(w * 0.12, h * 0.05);
    canvas.rotate(0.5);

    // Pen tip
    final tipPath = Path()
      ..moveTo(0, 0)
      ..lineTo(-5, -12)
      ..lineTo(5, -12)
      ..close();
    canvas.drawPath(tipPath, penTipPaint);

    // Pen barrel
    final barrelRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(-5, -45, 10, 33),
      const Radius.circular(3),
    );
    canvas.drawRRect(barrelRect, penBodyPaint);

    canvas.restore();
    canvas.restore();

    // 4. Corner light rays / brightness bursts
    final rayPaint = Paint()
      ..color = AppTheme.primary.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
        Offset(w * 0.12, h * 0.22), Offset(w * 0.05, h * 0.15), rayPaint);
    canvas.drawLine(
        Offset(w * 0.88, h * 0.22), Offset(w * 0.95, h * 0.15), rayPaint);
    canvas.drawLine(
        Offset(w * 0.5, h * 0.12), Offset(w * 0.5, h * 0.03), rayPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
