import 'package:flutter_test/flutter_test.dart';
import 'package:traceart/models/ruler_config.dart';

void main() {
  group('RulerConfig & Conversions', () {
    test('default configuration has expected defaults', () {
      const config = RulerConfig();
      expect(config.isEnabled, isFalse);
      expect(config.unit, equals(RulerUnit.cm));
      expect(config.origin, equals(RulerOrigin.artwork));
      expect(config.calibrationFactor, equals(1.0));
      expect(config.rulerThickness, equals(28.0));
    });

    test('logicalPxPerCm and logicalPxPerInch respect calibration factor', () {
      const standardConfig = RulerConfig(calibrationFactor: 1.0);
      expect(standardConfig.logicalPxPerCm, closeTo(62.9921, 0.001));
      expect(standardConfig.logicalPxPerInch, closeTo(160.0, 0.001));

      const scaledConfig = RulerConfig(calibrationFactor: 1.2);
      expect(scaledConfig.logicalPxPerCm, closeTo(62.9921 * 1.2, 0.001));
      expect(scaledConfig.logicalPxPerInch, closeTo(160.0 * 1.2, 0.001));
    });

    test('pxToCm and cmToPx conversions are inverse operations', () {
      const config = RulerConfig(calibrationFactor: 1.15);
      const testCm = 15.0;
      final px = config.cmToPx(testCm);
      final cm = config.pxToCm(px);
      expect(cm, closeTo(testCm, 0.0001));
    });

    test('pxToInch and inchToPx conversions are inverse operations', () {
      const config = RulerConfig(calibrationFactor: 0.95);
      const testIn = 6.5;
      final px = config.inchToPx(testIn);
      final inch = config.pxToInch(px);
      expect(inch, closeTo(testIn, 0.0001));
    });

    test('formatDimension outputs correct formatted strings', () {
      const metricConfig = RulerConfig(unit: RulerUnit.cm);
      expect(metricConfig.formatDimension(100.0), equals('1.6 cm'));

      const imperialConfig = RulerConfig(unit: RulerUnit.inch);
      expect(imperialConfig.formatDimension(160.0), equals('1.00"'));
    });

    test('calibration factor is clamped between 0.60 and 1.60 in copyWith', () {
      final configMin = const RulerConfig().copyWith(calibrationFactor: 0.2);
      expect(configMin.calibrationFactor, equals(0.60));

      final configMax = const RulerConfig().copyWith(calibrationFactor: 2.5);
      expect(configMax.calibrationFactor, equals(1.60));
    });

    test('copyWith and value equality work correctly', () {
      const initial = RulerConfig();
      final updated = initial.copyWith(
        isEnabled: true,
        unit: RulerUnit.inch,
        origin: RulerOrigin.screen,
        calibrationFactor: 1.1,
      );

      expect(updated.isEnabled, isTrue);
      expect(updated.unit, equals(RulerUnit.inch));
      expect(updated.origin, equals(RulerOrigin.screen));
      expect(updated.calibrationFactor, equals(1.1));

      final identicalCopy = updated.copyWith();
      expect(identicalCopy, equals(updated));
      expect(identicalCopy.hashCode, equals(updated.hashCode));
    });
  });

  group('StandardPaperSize Presets', () {
    test('A4 dimensions are 21.0 x 29.7 cm', () {
      expect(StandardPaperSize.a4.widthCm, closeTo(21.0, 0.01));
      expect(StandardPaperSize.a4.heightCm, closeTo(29.7, 0.01));
      expect(StandardPaperSize.a4.widthIn, closeTo(21.0 / 2.54, 0.01));
      expect(StandardPaperSize.a4.heightIn, closeTo(29.7 / 2.54, 0.01));
    });

    test('A5 dimensions are 14.8 x 21.0 cm', () {
      expect(StandardPaperSize.a5.widthCm, closeTo(14.8, 0.01));
      expect(StandardPaperSize.a5.heightCm, closeTo(21.0, 0.01));
    });

    test('Postcard 4x6" dimensions match imperial standards', () {
      expect(StandardPaperSize.postcard4x6.widthIn, closeTo(4.0, 0.01));
      expect(StandardPaperSize.postcard4x6.heightIn, closeTo(6.0, 0.01));
      expect(StandardPaperSize.postcard4x6.widthCm, closeTo(4.0 * 2.54, 0.01));
      expect(StandardPaperSize.postcard4x6.heightCm, closeTo(6.0 * 2.54, 0.01));
    });

    test('Square presets have 1:1 aspect ratio', () {
      expect(StandardPaperSize.square15cm.widthCm, equals(StandardPaperSize.square15cm.heightCm));
      expect(StandardPaperSize.square20cm.widthCm, equals(StandardPaperSize.square20cm.heightCm));
      expect(StandardPaperSize.square15cm.aspectRatio, closeTo(1.0, 0.001));
    });
  });
}
