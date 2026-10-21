import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:traceart/models/stencil_config.dart';
import 'package:traceart/services/image_processing_service.dart';

void main() {
  late ImageProcessingService processingService;

  setUp(() {
    processingService = DefaultImageProcessingService();
  });

  /// Helper to generate a bimodal test image:
  /// Left half: dark gray (50, 50, 50)
  /// Right half: light gray (200, 200, 200)
  /// With a solid black line in the middle
  Uint8List createBimodalImageBytes({int width = 40, int height = 40}) {
    final image = img.Image(width: width, height: height);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (x < width ~/ 2) {
          image.setPixelRgba(x, y, 50, 50, 50, 255);
        } else {
          image.setPixelRgba(x, y, 200, 200, 200, 255);
        }
      }
    }
    // Middle vertical edge at x = 20
    for (int y = 0; y < height; y++) {
      image.setPixelRgba(20, y, 0, 0, 0, 255);
    }
    return Uint8List.fromList(img.encodePng(image));
  }

  /// Helper to generate a gradient image from 0 (black) to 255 (white)
  Uint8List createGradientImageBytes({int width = 50, int height = 10}) {
    final image = img.Image(width: width, height: height);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final val = ((x / (width - 1)) * 255).round().clamp(0, 255);
        image.setPixelRgba(x, y, val, val, val, 255);
      }
    }
    return Uint8List.fromList(img.encodePng(image));
  }

  group('StencilConfig Model', () {
    test('default configuration has correct properties', () {
      const config = StencilConfig();
      expect(config.type, equals(StencilFilterType.none));
      expect(config.threshold, equals(0.5));
      expect(config.posterizeLevels, equals(4));
      expect(config.edgeStrength, equals(0.5));
    });

    test('copyWith updates specified fields only', () {
      const config = StencilConfig();
      final updated = config.copyWith(
        type: StencilFilterType.threshold,
        threshold: 0.72,
        posterizeLevels: 6,
        edgeStrength: 0.9,
      );

      expect(updated.type, equals(StencilFilterType.threshold));
      expect(updated.threshold, equals(0.72));
      expect(updated.posterizeLevels, equals(6));
      expect(updated.edgeStrength, equals(0.9));

      final partial = updated.copyWith(type: StencilFilterType.posterize);
      expect(partial.type, equals(StencilFilterType.posterize));
      expect(partial.threshold, equals(0.72));
      expect(partial.posterizeLevels, equals(6));
      expect(partial.edgeStrength, equals(0.9));
    });

    test('value equality and hashCode works as expected', () {
      const config1 = StencilConfig(
        type: StencilFilterType.posterize,
        threshold: 0.4,
        posterizeLevels: 3,
        edgeStrength: 0.5,
      );
      const config2 = StencilConfig(
        type: StencilFilterType.posterize,
        threshold: 0.4,
        posterizeLevels: 3,
        edgeStrength: 0.5,
      );
      const config3 = StencilConfig(
        type: StencilFilterType.edgeSketch,
        threshold: 0.4,
        posterizeLevels: 3,
        edgeStrength: 0.5,
      );

      expect(config1, equals(config2));
      expect(config1.hashCode, equals(config2.hashCode));
      expect(config1, isNot(equals(config3)));
    });
  });

  group('ImageProcessingService - computeOtsuThreshold', () {
    test('computes accurate bimodal threshold', () {
      final bytes = createBimodalImageBytes();
      final otsu = processingService.computeOtsuThreshold(bytes);

      // Partitions dark and bright clusters
      expect(otsu, inInclusiveRange(0.18, 0.60));
    });

    test('handles uniform flat image without crashing or NaN', () {
      final uniform = img.Image(width: 20, height: 20);
      img.fill(uniform, color: img.ColorRgb8(128, 128, 128));
      final bytes = Uint8List.fromList(img.encodePng(uniform));

      final otsu = processingService.computeOtsuThreshold(bytes);
      expect(otsu.isNaN, isFalse);
      expect(otsu.isInfinite, isFalse);
      expect(otsu, inInclusiveRange(0.05, 0.95));
    });
  });

  group('ImageProcessingService - processStencil StencilFilterType.none', () {
    test('returns exact source bytes when type is none', () async {
      final bytes = createBimodalImageBytes();
      const config = StencilConfig(type: StencilFilterType.none);

      final result = await processingService.processStencil(
        sourceBytes: bytes,
        config: config,
      );

      expect(result, equals(bytes));
    });
  });

  group('ImageProcessingService - processStencil StencilFilterType.threshold', () {
    test('produces binary 0 or 255 pixels based on cutoff', () async {
      final bytes = createBimodalImageBytes();
      const config = StencilConfig(
        type: StencilFilterType.threshold,
        threshold: 0.5, // 128 in byte space
      );

      final result = await processingService.processStencil(
        sourceBytes: bytes,
        config: config,
      );

      expect(result.isNotEmpty, isTrue);
      final decoded = img.decodeImage(result);
      expect(decoded, isNotNull);

      // Verify every pixel is strictly binary: 0 or 255
      for (int y = 0; y < decoded!.height; y++) {
        for (int x = 0; x < decoded.width; x++) {
          final p = decoded.getPixel(x, y);
          expect(p.r == 0 || p.r == 255, isTrue,
              reason: 'Pixel ($x, $y) should be 0 or 255, got ${p.r}');
          expect(p.g, equals(p.r));
          expect(p.b, equals(p.r));
          expect(p.a, equals(255));
        }
      }

      // Left region (originally 50) was below 128 -> should be 0 (black)
      final leftPixel = decoded.getPixel(5, 20);
      expect(leftPixel.r, equals(0));

      // Right region (originally 200) was above 128 -> should be 255 (white)
      final rightPixel = decoded.getPixel(35, 20);
      expect(rightPixel.r, equals(255));
    });

    test('higher threshold turns more pixels black', () async {
      final bytes = createGradientImageBytes();

      final lowThreshResult = await processingService.processStencil(
        sourceBytes: bytes,
        config: const StencilConfig(type: StencilFilterType.threshold, threshold: 0.2),
      );
      final highThreshResult = await processingService.processStencil(
        sourceBytes: bytes,
        config: const StencilConfig(type: StencilFilterType.threshold, threshold: 0.8),
      );

      final lowDecoded = img.decodeImage(lowThreshResult)!;
      final highDecoded = img.decodeImage(highThreshResult)!;

      int lowBlackCount = 0;
      int highBlackCount = 0;

      for (int x = 0; x < lowDecoded.width; x++) {
        if (lowDecoded.getPixel(x, 0).r == 0) lowBlackCount++;
        if (highDecoded.getPixel(x, 0).r == 0) highBlackCount++;
      }

      expect(highBlackCount, greaterThan(lowBlackCount));
    });
  });

  group('ImageProcessingService - processStencil StencilFilterType.posterize', () {
    test('quantizes continuous gradient into discrete tonal levels', () async {
      final bytes = createGradientImageBytes(width: 100, height: 10);
      const config = StencilConfig(
        type: StencilFilterType.posterize,
        posterizeLevels: 3,
      );

      final result = await processingService.processStencil(
        sourceBytes: bytes,
        config: config,
      );

      final decoded = img.decodeImage(result);
      expect(decoded, isNotNull);

      // Collect all unique grayscale values in the image
      final uniqueTones = <int>{};
      for (int x = 0; x < decoded!.width; x++) {
        uniqueTones.add(decoded.getPixel(x, 5).r.toInt());
      }

      // 3 levels should yield at most 3 distinct tones
      expect(uniqueTones.length, lessThanOrEqualTo(3));
      expect(uniqueTones.length, greaterThanOrEqualTo(2));
    });

    test('supports different level quantities (e.g. 2, 4, 6)', () async {
      final bytes = createGradientImageBytes(width: 100, height: 10);

      for (final levels in [2, 4, 6]) {
        final result = await processingService.processStencil(
          sourceBytes: bytes,
          config: StencilConfig(
            type: StencilFilterType.posterize,
            posterizeLevels: levels,
          ),
        );
        final decoded = img.decodeImage(result)!;
        final uniqueTones = <int>{};
        for (int x = 0; x < decoded.width; x++) {
          uniqueTones.add(decoded.getPixel(x, 5).r.toInt());
        }
        expect(uniqueTones.length, lessThanOrEqualTo(levels));
      }
    });
  });

  group('ImageProcessingService - processStencil StencilFilterType.edgeSketch', () {
    test('extracts high-contrast line contours on white background', () async {
      final bytes = createBimodalImageBytes(width: 50, height: 50);
      const config = StencilConfig(
        type: StencilFilterType.edgeSketch,
        edgeStrength: 0.7,
      );

      final result = await processingService.processStencil(
        sourceBytes: bytes,
        config: config,
      );

      final decoded = img.decodeImage(result);
      expect(decoded, isNotNull);

      // Flat regions (e.g. far left x=5 or far right x=45) should be light / paper white
      final flatLeft = decoded!.getPixel(5, 25);
      expect(flatLeft.r, greaterThan(200));

      // Middle line / edge boundary at x=20 should be dark sketch line
      final edgePixel = decoded.getPixel(20, 25);
      expect(edgePixel.r, lessThan(120));
      expect(edgePixel.r, lessThan(flatLeft.r));
    });
  });
}
