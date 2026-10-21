import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../models/stencil_config.dart';

/// Selectable modes for inverted tracing:
/// - [original]: Preserves the exact original color inversion.
/// - [enhanced]: Controlled sharpening and local contrast enhancement to make
///   faint details, thin lines, and subtle features visible through paper.
/// - [fineOutline]: Thin, crisp, noise-filtered bright outlines against a
///   pure dark background, optimized for physical tracing reference.
enum InvertTracingMode {
  original,
  enhanced,
  fineOutline;

  String get displayName {
    switch (this) {
      case InvertTracingMode.original:
        return 'Original Invert';
      case InvertTracingMode.enhanced:
        return 'Enhanced Invert';
      case InvertTracingMode.fineOutline:
        return 'Fine Outline';
    }
  }

  String get description {
    switch (this) {
      case InvertTracingMode.original:
        return 'Standard color inversion';
      case InvertTracingMode.enhanced:
        return 'Sharpened lines & enhanced contrast';
      case InvertTracingMode.fineOutline:
        return 'Crisp outlines on dark background';
    }
  }
}

/// High-visibility color tints for inverted tracing lines:
/// - [white]: Default clean neutral white illumination.
/// - [neonGreen]: Peak human photopic eye sensitivity, maximum penetration through thick paper.
/// - [cyan]: Vibrant cyan blue, high contrast against warm and dark surfaces.
/// - [amberGold]: Warm amber, high contrast through yellow/ivory sketch paper.
/// - [nightRed]: Night-vision red, reduces eye strain in darkroom environments.
/// - [magenta]: Vibrant magenta, crisp contrast against graphite and dark media.
enum LineColorTint {
  white(
    label: 'White',
    color: Color(0xFFFFFFFF),
    description: 'Clean neutral white lines',
  ),
  neonGreen(
    label: 'Neon Green',
    color: Color(0xFF00FF66),
    description: 'High eye sensitivity through thick paper',
  ),
  cyan(
    label: 'Cyan',
    color: Color(0xFF00E5FF),
    description: 'Vibrant contrast on warm or dark paper',
  ),
  amberGold(
    label: 'Amber Gold',
    color: Color(0xFFFFB300),
    description: 'Warm contrast for textured/yellow paper',
  ),
  nightRed(
    label: 'Night Red',
    color: Color(0xFFFF1744),
    description: 'Prevents eye strain in dark environments',
  ),
  magenta(
    label: 'Magenta',
    color: Color(0xFFFF007F),
    description: 'Punchy high-contrast outline tracing',
  );

  final String label;
  final Color color;
  final String description;

  const LineColorTint({
    required this.label,
    required this.color,
    required this.description,
  });
}

/// Abstract contract for the image processing service.
abstract class ImageProcessingService {
  Future<Uint8List> processImage({
    required Uint8List sourceBytes,
    required InvertTracingMode mode,
    required double detailStrength,
    required double edgeSensitivity,
  });

  Future<Uint8List> processStencil({
    required Uint8List sourceBytes,
    required StencilConfig config,
  });

  double computeOtsuThreshold(Uint8List sourceBytes);
}

/// Parameters passed to the background isolate.
class ProcessingParams {
  final Uint8List sourceBytes;
  final InvertTracingMode mode;
  final double detailStrength;
  final double edgeSensitivity;

  const ProcessingParams({
    required this.sourceBytes,
    required this.mode,
    required this.detailStrength,
    required this.edgeSensitivity,
  });
}

/// Parameters passed to the background isolate for stencil filtering.
class StencilProcessingParams {
  final Uint8List sourceBytes;
  final StencilConfig config;

  const StencilProcessingParams({
    required this.sourceBytes,
    required this.config,
  });
}

/// Default implementation running image enhancement algorithms in a background isolate.
class DefaultImageProcessingService implements ImageProcessingService {
  @override
  Future<Uint8List> processImage({
    required Uint8List sourceBytes,
    required InvertTracingMode mode,
    required double detailStrength,
    required double edgeSensitivity,
  }) async {
    if (mode == InvertTracingMode.original) {
      return sourceBytes;
    }

    final params = ProcessingParams(
      sourceBytes: sourceBytes,
      mode: mode,
      detailStrength: detailStrength.clamp(0.0, 1.0),
      edgeSensitivity: edgeSensitivity.clamp(0.0, 1.0),
    );

    return await Isolate.run(() => ImageProcessor.execute(params));
  }

  @override
  Future<Uint8List> processStencil({
    required Uint8List sourceBytes,
    required StencilConfig config,
  }) async {
    if (config.type == StencilFilterType.none) {
      return sourceBytes;
    }

    final params = StencilProcessingParams(
      sourceBytes: sourceBytes,
      config: config,
    );

    return await Isolate.run(() => ImageProcessor.executeStencil(params));
  }

  @override
  double computeOtsuThreshold(Uint8List sourceBytes) {
    return ImageProcessor.calculateOtsu(sourceBytes);
  }
}

/// Static, isolate-safe image processing routines.
class ImageProcessor {
  /// Entry point called within background isolate.
  static Uint8List execute(ProcessingParams params) {
    final decoded = img.decodeImage(params.sourceBytes);
    if (decoded == null) {
      throw Exception('Failed to decode image bytes for processing');
    }

    img.Image processed;
    switch (params.mode) {
      case InvertTracingMode.original:
        processed = decoded;
        break;
      case InvertTracingMode.enhanced:
        processed = applyEnhancedInvert(
          decoded,
          detailStrength: params.detailStrength,
        );
        break;
      case InvertTracingMode.fineOutline:
        processed = applyFineOutline(
          decoded,
          detailStrength: params.detailStrength,
          edgeSensitivity: params.edgeSensitivity,
        );
        break;
    }

    // Encode to PNG with level 1 for speed while preserving lossless fidelity
    final resultBytes = img.encodePng(processed, level: 1);
    return Uint8List.fromList(resultBytes);
  }

  /// Entry point called within background isolate for stencil filtering.
  static Uint8List executeStencil(StencilProcessingParams params) {
    final decoded = img.decodeImage(params.sourceBytes);
    if (decoded == null) {
      throw Exception('Failed to decode image bytes for stencil processing');
    }

    img.Image processed;
    switch (params.config.type) {
      case StencilFilterType.none:
        processed = decoded;
        break;
      case StencilFilterType.threshold:
        processed = applyThreshold(
          decoded,
          threshold: params.config.thresholdValue,
        );
        break;
      case StencilFilterType.posterize:
        processed = applyPosterize(
          decoded,
          levels: params.config.posterizeLevels,
        );
        break;
      case StencilFilterType.edgeSketch:
        processed = applyEdgeSketch(
          decoded,
          edgeStrength: params.config.edgeStrength,
        );
        break;
    }

    final resultBytes = img.encodePng(processed, level: 1);
    return Uint8List.fromList(resultBytes);
  }

  /// Calculates optimal bimodal threshold using Otsu's method.
  static double calculateOtsu(Uint8List sourceBytes) {
    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null) return 0.5;

    final width = decoded.width;
    final height = decoded.height;
    final totalPixels = width * height;
    if (totalPixels == 0) return 0.5;

    final histogram = Int32List(256);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final p = decoded.getPixel(x, y);
        final lum = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).round().clamp(0, 255);
        histogram[lum]++;
      }
    }

    double sumTotal = 0;
    for (int i = 0; i < 256; i++) {
      sumTotal += i * histogram[i];
    }

    double sumB = 0;
    int wB = 0;
    double maxVariance = 0.0;
    int bestThreshold = 128;

    for (int t = 0; t < 256; t++) {
      wB += histogram[t];
      if (wB == 0) continue;
      final wF = totalPixels - wB;
      if (wF == 0) break;

      sumB += t * histogram[t];
      final mB = sumB / wB;
      final mF = (sumTotal - sumB) / wF;

      final varianceBetween = wB.toDouble() * wF.toDouble() * (mB - mF) * (mB - mF);
      if (varianceBetween > maxVariance) {
        maxVariance = varianceBetween;
        bestThreshold = t;
      }
    }

    return (bestThreshold / 255.0).clamp(0.05, 0.95);
  }

  /// Binary thresholding: values >= threshold become pure white (255),
  /// values < threshold become pure black ink/stencil (0).
  static img.Image applyThreshold(
    img.Image source, {
    required double threshold,
  }) {
    final width = source.width;
    final height = source.height;
    final pixelCount = width * height;

    final gray = Float32List(pixelCount);
    for (int y = 0; y < height; y++) {
      final row = y * width;
      for (int x = 0; x < width; x++) {
        final p = source.getPixel(x, y);
        gray[row + x] = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
      }
    }

    final smoothed = _applySeparableBlur(gray, width, height);
    final cutoff = (threshold.clamp(0.05, 0.95) * 255.0);
    final output = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      final row = y * width;
      for (int x = 0; x < width; x++) {
        final lum = smoothed[row + x];
        final val = lum >= cutoff ? 255 : 0;
        output.setPixelRgba(x, y, val, val, val, 255);
      }
    }

    return output;
  }

  /// Posterization: quantizes continuous tones into [levels] discrete tonal bands.
  static img.Image applyPosterize(
    img.Image source, {
    required int levels,
  }) {
    final width = source.width;
    final height = source.height;
    final output = img.Image(width: width, height: height);

    final numLevels = levels.clamp(2, 8);
    final step = 255.0 / (numLevels - 1);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final p = source.getPixel(x, y);
        final lum = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
        final bucket = (lum / 255.0 * (numLevels - 1)).round();
        final quantized = (bucket * step).clamp(0.0, 255.0).round();
        output.setPixelRgba(x, y, quantized, quantized, quantized, 255);
      }
    }

    return output;
  }

  /// Edge sketch: extracts clean line art contours (pencil/ink outline style).
  static img.Image applyEdgeSketch(
    img.Image source, {
    required double edgeStrength,
  }) {
    final width = source.width;
    final height = source.height;
    final pixelCount = width * height;

    final gray = Float32List(pixelCount);
    for (int y = 0; y < height; y++) {
      final row = y * width;
      for (int x = 0; x < width; x++) {
        final p = source.getPixel(x, y);
        gray[row + x] = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
      }
    }

    final blur1 = _applySeparableBlur(gray, width, height);
    final blur2 = _applySeparableBlur(_applySeparableBlur(blur1, width, height), width, height);

    final mag = Float32List(pixelCount);
    for (int y = 1; y < height - 1; y++) {
      final prevRow = (y - 1) * width;
      final row = y * width;
      final nextRow = (y + 1) * width;

      for (int x = 1; x < width - 1; x++) {
        final gx = (3.0 * (blur1[prevRow + x + 1] - blur1[prevRow + x - 1]) +
                10.0 * (blur1[row + x + 1] - blur1[row + x - 1]) +
                3.0 * (blur1[nextRow + x + 1] - blur1[nextRow + x - 1])) /
            32.0;

        final gy = (3.0 * (blur1[nextRow + x - 1] - blur1[prevRow + x - 1]) +
                10.0 * (blur1[nextRow + x] - blur1[prevRow + x]) +
                3.0 * (blur1[nextRow + x + 1] - blur1[prevRow + x + 1])) /
            32.0;

        mag[row + x] = math.sqrt(gx * gx + gy * gy);
      }
    }

    final output = img.Image(width: width, height: height);
    final strength = edgeStrength.clamp(0.1, 1.0);

    for (int y = 0; y < height; y++) {
      final row = y * width;
      for (int x = 0; x < width; x++) {
        final i = row + x;
        final dog = (blur2[i] - blur1[i]).abs() * 3.0;
        final edge = mag[i] * 1.5;
        final signal = math.max(dog, edge) * (0.8 + strength * 1.8);

        final ink = (255.0 - signal * 4.0).clamp(0.0, 255.0).round();
        output.setPixelRgba(x, y, ink, ink, ink, 255);
      }
    }

    return output;
  }

  /// Applies unsharp-masking edge sharpening, subtle line contrast enhancement,
  /// and color inversion.
  static img.Image applyEnhancedInvert(
    img.Image source, {
    required double detailStrength,
  }) {
    final width = source.width;
    final height = source.height;

    // 1. Create a blurred copy to isolate high-frequency spatial details (edges & fine lines)
    final blurred = img.gaussianBlur(source.clone(), radius: 2);

    final output = img.Image(width: width, height: height);

    // Boost factor for high frequency detail (0.6 at strength 0.0 to 2.4 at strength 1.0)
    final k = 0.6 + (detailStrength * 1.8);

    // Line density factor to pull faint lines up from background
    final contrastBoost = 1.0 + (detailStrength * 0.75);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final p = source.getPixel(x, y);
        final pb = blurred.getPixel(x, y);

        // High frequency detail delta
        final dR = p.r - pb.r;
        final dG = p.g - pb.g;
        final dB = p.b - pb.b;

        // Apply controlled sharpening with halo limiting
        // Clamp excessive delta to avoid wide halos around extreme contrast transitions
        final clampedDR = dR.clamp(-60, 60);
        final clampedDG = dG.clamp(-60, 60);
        final clampedDB = dB.clamp(-60, 60);

        // Sharpened channel values
        double rSharp = (p.r + (clampedDR * k)).clamp(0.0, 255.0);
        double gSharp = (p.g + (clampedDG * k)).clamp(0.0, 255.0);
        double bSharp = (p.b + (clampedDB * k)).clamp(0.0, 255.0);

        // Local contrast enhancement for dark line details:
        // In the original, lines are darker than the surrounding paper/canvas.
        // We amplify the darkness of faint details so when inverted they become
        // bright and clearly visible through paper.
        final lum = 0.299 * rSharp + 0.587 * gSharp + 0.114 * bSharp;
        final darkness = (255.0 - lum).clamp(0.0, 255.0);
        final enhancedDarkness = (darkness * contrastBoost).clamp(0.0, 255.0);
        final lumRatio = darkness > 0.0 ? (enhancedDarkness / darkness) : 1.0;

        // Invert channels while applying enhanced line contrast
        final rOut = ((255.0 - rSharp) * lumRatio).clamp(0.0, 255.0).round();
        final gOut = ((255.0 - gSharp) * lumRatio).clamp(0.0, 255.0).round();
        final bOut = ((255.0 - bSharp) * lumRatio).clamp(0.0, 255.0).round();

        output.setPixelRgba(x, y, rOut, gOut, bOut, p.a.round());
      }
    }

    return output;
  }

  /// Extracts clean, thin outlines using pre-smoothing, Scharr edge gradients,
  /// non-maximum suppression (ridge thinning), and adjustable sensitivity thresholding.
  static img.Image applyFineOutline(
    img.Image source, {
    required double detailStrength,
    required double edgeSensitivity,
  }) {
    final width = source.width;
    final height = source.height;
    final pixelCount = width * height;

    // 1. Grayscale luminance
    final gray = Float32List(pixelCount);
    for (int y = 0; y < height; y++) {
      final rowOffset = y * width;
      for (int x = 0; x < width; x++) {
        final p = source.getPixel(x, y);
        gray[rowOffset + x] =
            0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
      }
    }

    // 2. Multi-scale smoothing for Difference of Gaussians (DoG) line extraction
    // Narrow blur (suppresses single-pixel noise while preserving thin lines & hair)
    final blur1 = _applySeparableBlur(gray, width, height);
    // Wider blur (averages line strokes with background to extract line ridges)
    final blur2 = _applySeparableBlur(_applySeparableBlur(blur1, width, height), width, height);

    // 3. Compute Scharr Gradients and Magnitudes for step edges
    final mag = Float32List(pixelCount);
    for (int y = 1; y < height - 1; y++) {
      final prevRow = (y - 1) * width;
      final row = y * width;
      final nextRow = (y + 1) * width;

      for (int x = 1; x < width - 1; x++) {
        final gx = (3.0 * (blur1[prevRow + x + 1] - blur1[prevRow + x - 1]) +
                10.0 * (blur1[row + x + 1] - blur1[row + x - 1]) +
                3.0 * (blur1[nextRow + x + 1] - blur1[nextRow + x - 1])) /
            32.0;

        final gy = (3.0 * (blur1[nextRow + x - 1] - blur1[prevRow + x - 1]) +
                10.0 * (blur1[nextRow + x] - blur1[prevRow + x]) +
                3.0 * (blur1[nextRow + x + 1] - blur1[prevRow + x + 1])) /
            32.0;

        mag[row + x] = math.sqrt(gx * gx + gy * gy);
      }
    }

    // 4. Combine Difference of Gaussians (for true line strokes & hair)
    // with Gradient Magnitude (for color boundaries)
    final combined = Float32List(pixelCount);
    for (int i = 0; i < pixelCount; i++) {
      // DoG positive for dark lines on light paper (typical line art)
      final dogLines = (blur2[i] - blur1[i]) * 3.5;
      // DoG for bright lines on dark background
      final dogBright = (blur1[i] - blur2[i]) * 2.5;
      final strokeSignal = math.max(dogLines, dogBright);
      final edgeSignal = mag[i] * 1.5;

      combined[i] = math.max(strokeSignal, edgeSignal);
    }

    // 5. Sensitivity thresholding & Detail Strength scaling
    // Sensitivity: 0.0 (high threshold = only prominent outlines) to 1.0 (low threshold = delicate details)
    final minThreshold = 24.0 - (edgeSensitivity * 20.0); // ranges from ~4.0 to 24.0
    final maxThreshold = minThreshold + 30.0;

    final output = img.Image(width: width, height: height);

    // Detail strength controls outline brightness and intensity
    final brightnessScale = 1.0 + (detailStrength * 2.0);

    for (int y = 0; y < height; y++) {
      final row = y * width;
      for (int x = 0; x < width; x++) {
        final val = combined[row + x];
        if (val < minThreshold) {
          // Pure black background for high physical contrast through paper
          output.setPixelRgba(x, y, 0, 0, 0, 255);
        } else {
          // Normalized edge intensity with crisp white output for physical tracing
          final norm = ((val - minThreshold) / (maxThreshold - minThreshold))
              .clamp(0.0, 1.0);
          final intensity =
              (norm * 255.0 * brightnessScale).clamp(160.0, 255.0).round();

          output.setPixelRgba(x, y, intensity, intensity, intensity, 255);
        }
      }
    }

    return output;
  }

  /// Fast separable 3x3 Gaussian blur with [1, 2, 1] / 4 kernel.
  static Float32List _applySeparableBlur(
    Float32List src,
    int width,
    int height,
  ) {
    final count = width * height;
    final temp = Float32List(count);
    final dst = Float32List(count);

    // Horizontal
    for (int y = 0; y < height; y++) {
      final row = y * width;
      temp[row] = src[row];
      temp[row + width - 1] = src[row + width - 1];
      for (int x = 1; x < width - 1; x++) {
        temp[row + x] =
            (src[row + x - 1] + 2.0 * src[row + x] + src[row + x + 1]) * 0.25;
      }
    }

    // Vertical
    for (int x = 0; x < width; x++) {
      dst[x] = temp[x];
      dst[(height - 1) * width + x] = temp[(height - 1) * width + x];
    }
    for (int y = 1; y < height - 1; y++) {
      final prevRow = (y - 1) * width;
      final row = y * width;
      final nextRow = (y + 1) * width;
      for (int x = 0; x < width; x++) {
        dst[row + x] =
            (temp[prevRow + x] + 2.0 * temp[row + x] + temp[nextRow + x]) * 0.25;
      }
    }

    return dst;
  }
}
