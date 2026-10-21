/// Selectable quick stencil filter types:
/// - [none]: Original reference photo without filter.
/// - [threshold]: High-contrast binary black & white threshold (stencil / screenprint style).
/// - [posterize]: Multi-level discrete tonal stepping for progressive layer shading.
/// - [edgeSketch]: Line art and contour extraction (pencil/ink outline style).
enum StencilFilterType {
  none(
    label: 'None',
    description: 'Original reference photo',
  ),
  threshold(
    label: 'B&W Stencil',
    description: 'Binary threshold for high-contrast stencil silhouettes',
  ),
  posterize(
    label: 'Posterize',
    description: 'Tonal layer stepping for progressive shading',
  ),
  edgeSketch(
    label: 'Edge Sketch',
    description: 'Clean line art and contour extraction',
  );

  final String label;
  final String description;

  const StencilFilterType({
    required this.label,
    required this.description,
  });
}

/// Immutable configuration for quick stencil and threshold filters.
class StencilConfig {
  final StencilFilterType type;
  final double thresholdValue; // 0.05 to 0.95 (default 0.50)
  final int posterizeLevels; // 2 to 8 (default 4)
  final double edgeStrength; // 0.1 to 1.0 (default 0.5)

  const StencilConfig({
    this.type = StencilFilterType.none,
    double? threshold,
    double? thresholdValue,
    this.posterizeLevels = 4,
    this.edgeStrength = 0.5,
  }) : thresholdValue = threshold ?? thresholdValue ?? 0.5;

  double get threshold => thresholdValue;

  /// True when an active stencil filter is applied to the image.
  bool get isEnabled => type != StencilFilterType.none;

  StencilConfig copyWith({
    StencilFilterType? type,
    double? threshold,
    double? thresholdValue,
    int? posterizeLevels,
    double? edgeStrength,
  }) {
    return StencilConfig(
      type: type ?? this.type,
      thresholdValue: threshold ?? thresholdValue ?? this.thresholdValue,
      posterizeLevels: posterizeLevels ?? this.posterizeLevels,
      edgeStrength: edgeStrength ?? this.edgeStrength,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StencilConfig &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          thresholdValue == other.thresholdValue &&
          posterizeLevels == other.posterizeLevels &&
          edgeStrength == other.edgeStrength;

  @override
  int get hashCode =>
      Object.hash(type, thresholdValue, posterizeLevels, edgeStrength);

  @override
  String toString() =>
      'StencilConfig(type: ${type.name}, threshold: $thresholdValue, levels: $posterizeLevels, edge: $edgeStrength)';
}
