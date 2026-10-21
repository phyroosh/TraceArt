/// Units of measurement for physical rulers and dimensions.
enum RulerUnit {
  cm(label: 'Centimeters (cm)', abbreviation: 'cm'),
  inch(label: 'Inches (in)', abbreviation: 'in');

  final String label;
  final String abbreviation;

  const RulerUnit({required this.label, required this.abbreviation});
}

/// Zero-point coordinate origin for on-screen rulers.
enum RulerOrigin {
  /// Ruler zero (0) aligns with the top-left corner of the reference image.
  artwork(
    label: 'Artwork Corner',
    description: '0 aligns with the edge of the reference image',
  ),

  /// Ruler zero (0) aligns with the top-left edge of the physical screen.
  screen(
    label: 'Screen Edge',
    description: '0 aligns with the top-left perimeter of the screen',
  );

  final String label;
  final String description;

  const RulerOrigin({required this.label, required this.description});
}

/// Common standard international paper, photo, and canvas sizes for 1:1 scale tracing.
enum StandardPaperSize {
  a4(label: 'A4', widthCm: 21.0, heightCm: 29.7, description: '21.0 × 29.7 cm'),
  a5(label: 'A5', widthCm: 14.8, heightCm: 21.0, description: '14.8 × 21.0 cm'),
  a6(label: 'A6', widthCm: 10.5, heightCm: 14.8, description: '10.5 × 14.8 cm'),
  postcard4x6(label: '4 × 6" Postcard', widthCm: 10.16, heightCm: 15.24, description: '4.0 × 6.0 in (10.2 × 15.2 cm)'),
  photo5x7(label: '5 × 7" Photo', widthCm: 12.7, heightCm: 17.78, description: '5.0 × 7.0 in (12.7 × 17.8 cm)'),
  canvas8x10(label: '8 × 10" Canvas', widthCm: 20.32, heightCm: 25.4, description: '8.0 × 10.0 in (20.3 × 25.4 cm)'),
  square15cm(label: '15 cm Square', widthCm: 15.0, heightCm: 15.0, description: '15.0 × 15.0 cm (5.9 × 5.9 in)'),
  square20cm(label: '20 cm Square', widthCm: 20.0, heightCm: 20.0, description: '20.0 × 20.0 cm (7.9 × 7.9 in)');

  final String label;
  final double widthCm;
  final double heightCm;
  final String description;

  const StandardPaperSize({
    required this.label,
    required this.widthCm,
    required this.heightCm,
    required this.description,
  });

  double get widthIn => widthCm / 2.54;
  double get heightIn => heightCm / 2.54;
  double get aspectRatio => widthCm / heightCm;
}

/// Immutable configuration for calibrated physical rulers and 1:1 true-scale measurement.
class RulerConfig {
  /// Whether the on-screen rulers and dimension overlays are active.
  final bool isEnabled;

  /// Current measurement unit (`cm` or `inch`).
  final RulerUnit unit;

  /// Measurement coordinate zero-point origin (`artwork` or `screen`).
  final RulerOrigin origin;

  /// Display calibration multiplier factor (default 1.0, range 0.60 to 1.60).
  /// Multiplies the baseline 160 logical-dpi to calibrate for physical screen variations.
  final double calibrationFactor;

  /// Whether to display the floating live artwork dimensions badge.
  final bool showDimensionBadge;

  /// Thickness / depth of the ruler bar along the screen edges in logical pixels.
  final double rulerThickness;

  const RulerConfig({
    this.isEnabled = false,
    this.unit = RulerUnit.cm,
    this.origin = RulerOrigin.artwork,
    this.calibrationFactor = 1.0,
    this.showDimensionBadge = true,
    this.rulerThickness = 28.0,
  });

  /// Baseline standard Android/Flutter logical DPI (1.0x mdpi).
  static const double baselineDpi = 160.0;

  /// Baseline standard logical DPCM (dots per centimeter = 160 / 2.54).
  static const double baselineDpcm = baselineDpi / 2.54; // ~62.992125984

  /// Standard ISO/IEC 7810 ID-1 credit card / driver's license physical dimensions.
  static const double creditCardWidthMm = 85.60;
  static const double creditCardHeightMm = 53.98;
  static const double creditCardWidthCm = creditCardWidthMm / 10.0; // 8.56 cm
  static const double creditCardHeightCm = creditCardHeightMm / 10.0; // 5.398 cm

  /// Calibrated logical pixels per centimeter.
  double get logicalPxPerCm => baselineDpcm * calibrationFactor;

  /// Calibrated logical pixels per millimeter.
  double get logicalPxPerMm => logicalPxPerCm / 10.0;

  /// Calibrated logical pixels per inch.
  double get logicalPxPerInch => baselineDpi * calibrationFactor;

  /// Convert logical pixels to physical centimeters.
  double pxToCm(double logicalPixels) => logicalPixels / logicalPxPerCm;

  /// Convert logical pixels to physical inches.
  double pxToInch(double logicalPixels) => logicalPixels / logicalPxPerInch;

  /// Convert physical centimeters to logical pixels.
  double cmToPx(double cm) => cm * logicalPxPerCm;

  /// Convert physical inches to logical pixels.
  double inchToPx(double inch) => inch * logicalPxPerInch;

  /// Formats a physical dimension value in the currently selected unit.
  String formatDimension(double logicalPixels) {
    if (unit == RulerUnit.cm) {
      final cm = pxToCm(logicalPixels);
      return '${cm.toStringAsFixed(1)} cm';
    } else {
      final inch = pxToInch(logicalPixels);
      return '${inch.toStringAsFixed(2)}"';
    }
  }

  RulerConfig copyWith({
    bool? isEnabled,
    RulerUnit? unit,
    RulerOrigin? origin,
    double? calibrationFactor,
    bool? showDimensionBadge,
    double? rulerThickness,
  }) {
    return RulerConfig(
      isEnabled: isEnabled ?? this.isEnabled,
      unit: unit ?? this.unit,
      origin: origin ?? this.origin,
      calibrationFactor: (calibrationFactor ?? this.calibrationFactor).clamp(0.60, 1.60),
      showDimensionBadge: showDimensionBadge ?? this.showDimensionBadge,
      rulerThickness: rulerThickness ?? this.rulerThickness,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RulerConfig &&
          runtimeType == other.runtimeType &&
          isEnabled == other.isEnabled &&
          unit == other.unit &&
          origin == other.origin &&
          (calibrationFactor - other.calibrationFactor).abs() < 0.0001 &&
          showDimensionBadge == other.showDimensionBadge &&
          rulerThickness == other.rulerThickness;

  @override
  int get hashCode => Object.hash(
        isEnabled,
        unit,
        origin,
        calibrationFactor,
        showDimensionBadge,
        rulerThickness,
      );

  @override
  String toString() =>
      'RulerConfig(enabled: $isEnabled, unit: ${unit.abbreviation}, origin: ${origin.name}, cal: ${calibrationFactor.toStringAsFixed(3)})';
}
