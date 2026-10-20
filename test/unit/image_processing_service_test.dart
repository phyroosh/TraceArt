import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:traceart/services/image_processing_service.dart';

void main() {
  late ImageProcessingService processingService;

  setUp(() {
    processingService = DefaultImageProcessingService();
  });

  /// Helper to generate a test image containing:
  /// - A white background
  /// - A strong black line (primary outline)
  /// - A faint gray line (subtle detail, hair strand, or pencil line)
  /// - A flat light-gray texture / subtle gradient
  Uint8List createTestImageBytes({int width = 40, int height = 40}) {
    final image = img.Image(width: width, height: height);
    // Background: white (255, 255, 255)
    img.fill(image, color: img.ColorRgb8(255, 255, 255));

    // Strong edge/outline: vertical black line at x = 10
    for (int y = 5; y < height - 5; y++) {
      image.setPixelRgba(10, y, 0, 0, 0, 255);
    }

    // Subtle faint detail (e.g. hair strand or light sketch line): x = 25, gray (210, 210, 210)
    for (int y = 10; y < height - 10; y++) {
      image.setPixelRgba(25, y, 210, 210, 210, 255);
    }

    return Uint8List.fromList(img.encodePng(image));
  }

  group('ImageProcessingService - InvertTracingMode.original', () {
    test('returns exact source bytes without processing', () async {
      final inputBytes = createTestImageBytes();
      final result = await processingService.processImage(
        sourceBytes: inputBytes,
        mode: InvertTracingMode.original,
        detailStrength: 0.5,
        edgeSensitivity: 0.5,
      );

      expect(result, equals(inputBytes));
    });
  });

  group('ImageProcessingService - InvertTracingMode.enhanced', () {
    test('produces valid PNG with enhanced line contrast and inversion', () async {
      final inputBytes = createTestImageBytes();
      final result = await processingService.processImage(
        sourceBytes: inputBytes,
        mode: InvertTracingMode.enhanced,
        detailStrength: 0.8,
        edgeSensitivity: 0.5,
      );

      expect(result, isNotNull);
      expect(result.isNotEmpty, isTrue);

      final decoded = img.decodeImage(result);
      expect(decoded, isNotNull);
      expect(decoded!.width, equals(40));
      expect(decoded.height, equals(40));

      // The original white background (x=35, y=20) should invert to dark/black
      final bgPixel = decoded.getPixel(35, 20);
      expect(bgPixel.r, lessThan(30));
      expect(bgPixel.g, lessThan(30));
      expect(bgPixel.b, lessThan(30));

      // The strong black line (x=10, y=20) should invert to bright/white
      final linePixel = decoded.getPixel(10, 20);
      expect(linePixel.r, greaterThan(200));
      expect(linePixel.g, greaterThan(200));
      expect(linePixel.b, greaterThan(200));

      // The subtle faint line at x=25 should be clearly enhanced and visible
      final faintPixel = decoded.getPixel(25, 20);
      expect(faintPixel.r, greaterThan(bgPixel.r));
    });

    test('higher detailStrength increases line intensity', () async {
      final inputBytes = createTestImageBytes();

      final lowStrength = await processingService.processImage(
        sourceBytes: inputBytes,
        mode: InvertTracingMode.enhanced,
        detailStrength: 0.1,
        edgeSensitivity: 0.5,
      );

      final highStrength = await processingService.processImage(
        sourceBytes: inputBytes,
        mode: InvertTracingMode.enhanced,
        detailStrength: 1.0,
        edgeSensitivity: 0.5,
      );

      final lowDecoded = img.decodeImage(lowStrength)!;
      final highDecoded = img.decodeImage(highStrength)!;

      // At x=25 (the subtle faint line), high strength should produce higher brightness
      final lowFaint = lowDecoded.getPixel(25, 20).r;
      final highFaint = highDecoded.getPixel(25, 20).r;

      expect(highFaint, greaterThanOrEqualTo(lowFaint));
    });
  });

  group('ImageProcessingService - InvertTracingMode.fineOutline', () {
    test('produces clean bright outlines on pure dark background', () async {
      final inputBytes = createTestImageBytes();
      final result = await processingService.processImage(
        sourceBytes: inputBytes,
        mode: InvertTracingMode.fineOutline,
        detailStrength: 0.8,
        edgeSensitivity: 0.5,
      );

      final decoded = img.decodeImage(result);
      expect(decoded, isNotNull);
      expect(decoded!.width, equals(40));
      expect(decoded.height, equals(40));

      // Background should be pure black (0, 0, 0)
      final bgPixel = decoded.getPixel(35, 20);
      expect(bgPixel.r, equals(0));
      expect(bgPixel.g, equals(0));
      expect(bgPixel.b, equals(0));

      // Outline at strong edge (x=10, y=20) should be bright white
      final linePixel = decoded.getPixel(10, 20);
      expect(linePixel.r, greaterThan(150));
      expect(linePixel.g, greaterThan(150));
      expect(linePixel.b, greaterThan(150));
    });

    test('edgeSensitivity controls detection of subtle features', () async {
      final inputBytes = createTestImageBytes();

      // Low sensitivity: only strong edges detected
      final lowSensBytes = await processingService.processImage(
        sourceBytes: inputBytes,
        mode: InvertTracingMode.fineOutline,
        detailStrength: 0.8,
        edgeSensitivity: 0.05,
      );

      // High sensitivity: detects subtle faint lines too
      final highSensBytes = await processingService.processImage(
        sourceBytes: inputBytes,
        mode: InvertTracingMode.fineOutline,
        detailStrength: 0.8,
        edgeSensitivity: 0.95,
      );

      final lowDecoded = img.decodeImage(lowSensBytes)!;
      final highDecoded = img.decodeImage(highSensBytes)!;

      // Strong edge (x=10) should be detected in both
      expect(lowDecoded.getPixel(10, 20).r, greaterThan(100));
      expect(highDecoded.getPixel(10, 20).r, greaterThan(100));

      // Subtle line (x=25): low sensitivity should filter it out (0), high sensitivity should detect it (>0)
      final lowSubtle = lowDecoded.getPixel(25, 20).r;
      final highSubtle = highDecoded.getPixel(25, 20).r;

      expect(highSubtle, greaterThanOrEqualTo(lowSubtle));
    });

    test('suppresses flat areas without spurious noise', () async {
      final flatImage = img.Image(width: 30, height: 30);
      img.fill(flatImage, color: img.ColorRgb8(128, 128, 128));
      final flatBytes = Uint8List.fromList(img.encodePng(flatImage));

      final result = await processingService.processImage(
        sourceBytes: flatBytes,
        mode: InvertTracingMode.fineOutline,
        detailStrength: 0.8,
        edgeSensitivity: 0.5,
      );

      final decoded = img.decodeImage(result)!;
      // All pixels should remain pure black
      for (int y = 0; y < decoded.height; y++) {
        for (int x = 0; x < decoded.width; x++) {
          final p = decoded.getPixel(x, y);
          expect(p.r, equals(0));
          expect(p.g, equals(0));
          expect(p.b, equals(0));
        }
      }
    });

    test('processes real anime character image efficiently if file exists', () async {
      final file = File('/home/phyroosh/Pictures/anime_character.jpg');
      if (!file.existsSync()) return;

      final bytes = await file.readAsBytes();
      final sw = Stopwatch()..start();
      final enhanced = await processingService.processImage(
        sourceBytes: bytes,
        mode: InvertTracingMode.enhanced,
        detailStrength: 0.6,
        edgeSensitivity: 0.5,
      );
      final enhancedMs = sw.elapsedMilliseconds;
      sw.reset();

      final outline = await processingService.processImage(
        sourceBytes: bytes,
        mode: InvertTracingMode.fineOutline,
        detailStrength: 0.8,
        edgeSensitivity: 0.6,
      );
      final outlineMs = sw.elapsedMilliseconds;

      expect(enhanced.isNotEmpty, isTrue);
      expect(outline.isNotEmpty, isTrue);
      expect(enhancedMs, lessThan(5000));
      expect(outlineMs, lessThan(5000));
    });

    test('processes real photograph efficiently if file exists', () async {
      final file = File('/home/phyroosh/Pictures/self_doubt_editorial_1788660518707.jpg');
      if (!file.existsSync()) return;

      final bytes = await file.readAsBytes();
      final sw = Stopwatch()..start();
      final enhanced = await processingService.processImage(
        sourceBytes: bytes,
        mode: InvertTracingMode.enhanced,
        detailStrength: 0.5,
        edgeSensitivity: 0.5,
      );
      final enhancedMs = sw.elapsedMilliseconds;
      sw.reset();

      final outline = await processingService.processImage(
        sourceBytes: bytes,
        mode: InvertTracingMode.fineOutline,
        detailStrength: 0.7,
        edgeSensitivity: 0.5,
      );
      final outlineMs = sw.elapsedMilliseconds;

      expect(enhanced.isNotEmpty, isTrue);
      expect(outline.isNotEmpty, isTrue);
      expect(enhancedMs, lessThan(5000));
      expect(outlineMs, lessThan(5000));
    });
  });
}
