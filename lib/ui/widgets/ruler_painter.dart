import 'package:flutter/material.dart';
import '../../models/ruler_config.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/tracing_viewmodel.dart';

/// Interactive widget overlay that renders calibrated metric (cm/mm) or imperial (in)
/// measuring rulers along the top and left perimeter of the tracing viewport.
class RulerOverlay extends StatelessWidget {
  final TracingViewModel viewModel;

  const RulerOverlay({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([viewModel, viewModel.transformationController]),
      builder: (context, _) {
        if (!viewModel.isRulerEnabled) {
          return const SizedBox.shrink();
        }

        final config = viewModel.rulerConfig;
        final bounds = viewModel.hasImage ? viewModel.artworkViewportBounds : null;

        return IgnorePointer(
          ignoring: false, // Corner box can be tapped to toggle unit
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Ruler Painter (passes gestures through to canvas)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: RulerPainter(
                      config: config,
                      artworkBounds: bounds,
                    ),
                  ),
                ),
              ),

              // Interactive Corner Unit Badge
              Positioned(
                top: 0,
                left: 0,
                width: config.rulerThickness,
                height: config.rulerThickness,
                child: Tooltip(
                  message: 'Tap to switch unit (${config.unit.abbreviation})',
                  child: InkWell(
                    key: const Key('ruler_corner_unit_toggle'),
                    onTap: () {
                      final next = config.unit == RulerUnit.cm
                          ? RulerUnit.inch
                          : RulerUnit.cm;
                      viewModel.setRulerUnit(next);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElevated.withValues(alpha: 0.95),
                        border: Border(
                          right: BorderSide(color: AppTheme.borderMedium, width: 1),
                          bottom: BorderSide(color: AppTheme.borderMedium, width: 1),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        config.unit.abbreviation,
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// CustomPainter drawing calibrated ruler ticks and numbers along the top & left edges.
class RulerPainter extends CustomPainter {
  final RulerConfig config;
  final Rect? artworkBounds;

  RulerPainter({
    required this.config,
    this.artworkBounds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final thickness = config.rulerThickness;

    final bgPaint = Paint()
      ..color = const Color(0xEB0E1015)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = AppTheme.borderMedium
      ..strokeWidth = 1.0;

    // 1. Draw top horizontal ruler background & bottom edge
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, thickness), bgPaint);
    canvas.drawLine(
      Offset(0, thickness),
      Offset(size.width, thickness),
      borderPaint,
    );

    // 2. Draw left vertical ruler background & right edge
    canvas.drawRect(Rect.fromLTWH(0, 0, thickness, size.height), bgPaint);
    canvas.drawLine(
      Offset(thickness, 0),
      Offset(thickness, size.height),
      borderPaint,
    );

    // Highlight artwork interval on rulers if artwork is active
    if (artworkBounds != null) {
      _paintArtworkHighlight(canvas, size, thickness, artworkBounds!);
    }

    // 3. Draw tick marks & numerical labels
    if (config.unit == RulerUnit.cm) {
      _paintMetricRulers(canvas, size, thickness);
    } else {
      _paintImperialRulers(canvas, size, thickness);
    }
  }

  void _paintArtworkHighlight(Canvas canvas, Size size, double thickness, Rect bounds) {
    final highlightPaint = Paint()
      ..color = AppTheme.primary.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    final boundMarkerPaint = Paint()
      ..color = AppTheme.primary
      ..strokeWidth = 1.5;

    // Horizontal artwork span (clamped to screen)
    final xStart = bounds.left.clamp(thickness, size.width);
    final xEnd = bounds.right.clamp(thickness, size.width);
    if (xEnd > xStart) {
      canvas.drawRect(
        Rect.fromLTRB(xStart, 0, xEnd, thickness),
        highlightPaint,
      );
      // Artwork start / end indicator tick
      canvas.drawLine(Offset(bounds.left, 0), Offset(bounds.left, thickness), boundMarkerPaint);
      canvas.drawLine(Offset(bounds.right, 0), Offset(bounds.right, thickness), boundMarkerPaint);
    }

    // Vertical artwork span (clamped to screen)
    final yStart = bounds.top.clamp(thickness, size.height);
    final yEnd = bounds.bottom.clamp(thickness, size.height);
    if (yEnd > yStart) {
      canvas.drawRect(
        Rect.fromLTRB(0, yStart, thickness, yEnd),
        highlightPaint,
      );
      // Artwork start / end indicator tick
      canvas.drawLine(Offset(0, bounds.top), Offset(thickness, bounds.top), boundMarkerPaint);
      canvas.drawLine(Offset(0, bounds.bottom), Offset(thickness, bounds.bottom), boundMarkerPaint);
    }
  }

  void _paintMetricRulers(Canvas canvas, Size size, double thickness) {
    final pxPerMm = config.logicalPxPerMm;
    final pxPerCm = config.logicalPxPerCm;

    final majorTickPaint = Paint()
      ..color = AppTheme.textPrimary
      ..strokeWidth = 1.2;

    final mediumTickPaint = Paint()
      ..color = AppTheme.textSecondary
      ..strokeWidth = 1.0;

    final minorTickPaint = Paint()
      ..color = AppTheme.textTertiary.withValues(alpha: 0.6)
      ..strokeWidth = 0.8;

    // Origin offset
    final originX = (config.origin == RulerOrigin.artwork && artworkBounds != null)
        ? artworkBounds!.left
        : 0.0;
    final originY = (config.origin == RulerOrigin.artwork && artworkBounds != null)
        ? artworkBounds!.top
        : 0.0;

    // --- Horizontal Ruler (Top) ---
    final minCmH = ((thickness - originX) / pxPerCm).floor() - 1;
    final maxCmH = ((size.width - originX) / pxPerCm).ceil() + 1;

    for (int cm = minCmH; cm <= maxCmH; cm++) {
      final cmX = originX + cm * pxPerCm;

      // Draw 1mm sub-ticks within this cm
      for (int mm = 0; mm < 10; mm++) {
        final x = cmX + mm * pxPerMm;
        if (x < thickness || x > size.width) continue;

        if (mm == 0) {
          // 1cm Major Tick (full length)
          canvas.drawLine(Offset(x, thickness - 14), Offset(x, thickness), majorTickPaint);
          _drawLabel(canvas, '$cm', Offset(x + 2, 2));
        } else if (mm == 5) {
          // 5mm Medium Tick
          canvas.drawLine(Offset(x, thickness - 9), Offset(x, thickness), mediumTickPaint);
        } else {
          // 1mm Minor Tick
          canvas.drawLine(Offset(x, thickness - 5), Offset(x, thickness), minorTickPaint);
        }
      }
    }

    // --- Vertical Ruler (Left) ---
    final minCmV = ((thickness - originY) / pxPerCm).floor() - 1;
    final maxCmV = ((size.height - originY) / pxPerCm).ceil() + 1;

    for (int cm = minCmV; cm <= maxCmV; cm++) {
      final cmY = originY + cm * pxPerCm;

      for (int mm = 0; mm < 10; mm++) {
        final y = cmY + mm * pxPerMm;
        if (y < thickness || y > size.height) continue;

        if (mm == 0) {
          // 1cm Major Tick
          canvas.drawLine(Offset(thickness - 14, y), Offset(thickness, y), majorTickPaint);
          _drawLabel(canvas, '$cm', Offset(2, y + 2));
        } else if (mm == 5) {
          // 5mm Medium Tick
          canvas.drawLine(Offset(thickness - 9, y), Offset(thickness, y), mediumTickPaint);
        } else {
          // 1mm Minor Tick
          canvas.drawLine(Offset(thickness - 5, y), Offset(thickness, y), minorTickPaint);
        }
      }
    }
  }

  void _paintImperialRulers(Canvas canvas, Size size, double thickness) {
    final pxPerInch = config.logicalPxPerInch;
    final pxPerSixteenth = pxPerInch / 16.0;

    final majorTickPaint = Paint()
      ..color = AppTheme.textPrimary
      ..strokeWidth = 1.2;

    final halfTickPaint = Paint()
      ..color = AppTheme.textSecondary
      ..strokeWidth = 1.0;

    final quarterTickPaint = Paint()
      ..color = AppTheme.textSecondary.withValues(alpha: 0.8)
      ..strokeWidth = 0.8;

    final minorTickPaint = Paint()
      ..color = AppTheme.textTertiary.withValues(alpha: 0.5)
      ..strokeWidth = 0.7;

    final originX = (config.origin == RulerOrigin.artwork && artworkBounds != null)
        ? artworkBounds!.left
        : 0.0;
    final originY = (config.origin == RulerOrigin.artwork && artworkBounds != null)
        ? artworkBounds!.top
        : 0.0;

    // --- Horizontal Ruler (Top) ---
    final minInH = ((thickness - originX) / pxPerInch).floor() - 1;
    final maxInH = ((size.width - originX) / pxPerInch).ceil() + 1;

    for (int inch = minInH; inch <= maxInH; inch++) {
      final inchX = originX + inch * pxPerInch;

      for (int sixteenth = 0; sixteenth < 16; sixteenth++) {
        final x = inchX + sixteenth * pxPerSixteenth;
        if (x < thickness || x > size.width) continue;

        if (sixteenth == 0) {
          // Major Inch Tick
          canvas.drawLine(Offset(x, thickness - 15), Offset(x, thickness), majorTickPaint);
          _drawLabel(canvas, '$inch"', Offset(x + 2, 2));
        } else if (sixteenth == 8) {
          // 1/2 Inch Tick
          canvas.drawLine(Offset(x, thickness - 11), Offset(x, thickness), halfTickPaint);
        } else if (sixteenth % 4 == 0) {
          // 1/4 Inch Tick
          canvas.drawLine(Offset(x, thickness - 8), Offset(x, thickness), quarterTickPaint);
        } else if (sixteenth % 2 == 0) {
          // 1/8 Inch Tick
          canvas.drawLine(Offset(x, thickness - 5), Offset(x, thickness), minorTickPaint);
        }
      }
    }

    // --- Vertical Ruler (Left) ---
    final minInV = ((thickness - originY) / pxPerInch).floor() - 1;
    final maxInV = ((size.height - originY) / pxPerInch).ceil() + 1;

    for (int inch = minInV; inch <= maxInV; inch++) {
      final inchY = originY + inch * pxPerInch;

      for (int sixteenth = 0; sixteenth < 16; sixteenth++) {
        final y = inchY + sixteenth * pxPerSixteenth;
        if (y < thickness || y > size.height) continue;

        if (sixteenth == 0) {
          // Major Inch Tick
          canvas.drawLine(Offset(thickness - 15, y), Offset(thickness, y), majorTickPaint);
          _drawLabel(canvas, '$inch"', Offset(2, y + 2));
        } else if (sixteenth == 8) {
          // 1/2 Inch Tick
          canvas.drawLine(Offset(thickness - 11, y), Offset(thickness, y), halfTickPaint);
        } else if (sixteenth % 4 == 0) {
          // 1/4 Inch Tick
          canvas.drawLine(Offset(thickness - 8, y), Offset(thickness, y), quarterTickPaint);
        } else if (sixteenth % 2 == 0) {
          // 1/8 Inch Tick
          canvas.drawLine(Offset(thickness - 5, y), Offset(thickness, y), minorTickPaint);
        }
      }
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset position) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, position);
  }

  @override
  bool shouldRepaint(covariant RulerPainter oldDelegate) {
    return oldDelegate.config != config ||
        oldDelegate.artworkBounds != artworkBounds;
  }
}
