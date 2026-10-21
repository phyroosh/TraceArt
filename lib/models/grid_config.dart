import 'package:flutter/material.dart';

/// Available high-contrast color presets for the drawing grid lines.
enum GridColor {
  white('Crisp White', Color(0xFFFFFFFF)),
  black('Obsidian Black', Color(0xFF000000)),
  cyan('Electric Cyan', Color(0xFF00E5FF)),
  neonGreen('Neon Green', Color(0xFF00FF66)),
  amber('Radiant Amber', Color(0xFFFFB300)),
  red('Crimson Red', Color(0xFFFF3366));

  final String label;
  final Color color;

  const GridColor(this.label, this.color);
}

/// Immutable configuration defining the visual properties of the proportional drawing grid.
class GridConfig {
  /// Number of subdivisions along each axis (e.g. 3 for 3x3, 4 for 4x4, etc.)
  final int divisions;

  /// Line opacity between 0.15 and 1.0
  final double opacity;

  /// Line thickness in pixels
  final double strokeWidth;

  /// High-contrast line color preset
  final GridColor colorPreset;

  /// Whether to render accented center crosshairs (horizontal and vertical center axes)
  final bool showCenterCrosshair;

  /// Whether to render corner-to-corner diagonal armature lines
  final bool showDiagonals;

  /// Whether to render alphanumeric cell labels (A-Z along columns, 1-N along rows)
  final bool showLabels;

  const GridConfig({
    this.divisions = 4,
    this.opacity = 0.6,
    this.strokeWidth = 1.2,
    this.colorPreset = GridColor.white,
    this.showCenterCrosshair = false,
    this.showDiagonals = false,
    this.showLabels = false,
  });

  /// The active color with configured opacity applied
  Color get activeColor => colorPreset.color.withValues(alpha: opacity.clamp(0.0, 1.0));

  GridConfig copyWith({
    int? divisions,
    double? opacity,
    double? strokeWidth,
    GridColor? colorPreset,
    bool? showCenterCrosshair,
    bool? showDiagonals,
    bool? showLabels,
  }) {
    return GridConfig(
      divisions: divisions ?? this.divisions,
      opacity: opacity ?? this.opacity,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      colorPreset: colorPreset ?? this.colorPreset,
      showCenterCrosshair: showCenterCrosshair ?? this.showCenterCrosshair,
      showDiagonals: showDiagonals ?? this.showDiagonals,
      showLabels: showLabels ?? this.showLabels,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GridConfig &&
          runtimeType == other.runtimeType &&
          divisions == other.divisions &&
          opacity == other.opacity &&
          strokeWidth == other.strokeWidth &&
          colorPreset == other.colorPreset &&
          showCenterCrosshair == other.showCenterCrosshair &&
          showDiagonals == other.showDiagonals &&
          showLabels == other.showLabels;

  @override
  int get hashCode => Object.hash(
        divisions,
        opacity,
        strokeWidth,
        colorPreset,
        showCenterCrosshair,
        showDiagonals,
        showLabels,
      );
}
