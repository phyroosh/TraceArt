import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:traceart/models/grid_config.dart';
import 'package:traceart/ui/widgets/grid_painter.dart';

void main() {
  group('GridPainter Tests', () {
    test('paints without error on non-empty size with default config', () {
      const config = GridConfig(divisions: 4, opacity: 0.6);
      const painter = GridPainter(config: config);

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(400, 400);

      expect(() => painter.paint(canvas, size), returnsNormally);
      recorder.endRecording();
    });

    test('paints without error with crosshairs, diagonals, and labels enabled', () {
      const config = GridConfig(
        divisions: 6,
        opacity: 0.8,
        showCenterCrosshair: true,
        showDiagonals: true,
        showLabels: true,
      );
      const painter = GridPainter(config: config);

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(800, 600);

      expect(() => painter.paint(canvas, size), returnsNormally);
      recorder.endRecording();
    });

    test('handles empty size and invalid divisions gracefully', () {
      const config = GridConfig(divisions: 0);
      const painter = GridPainter(config: config);

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      expect(() => painter.paint(canvas, Size.zero), returnsNormally);
      expect(() => painter.paint(canvas, const Size(100, 100)), returnsNormally);
      recorder.endRecording();
    });

    test('shouldRepaint returns true when config changes, false when identical', () {
      const config1 = GridConfig(divisions: 4, opacity: 0.5);
      const config2 = GridConfig(divisions: 8, opacity: 0.5);
      const config3 = GridConfig(divisions: 4, opacity: 0.5);

      const painter1 = GridPainter(config: config1);
      const painter2 = GridPainter(config: config2);
      const painter3 = GridPainter(config: config3);

      expect(painter1.shouldRepaint(painter2), isTrue);
      expect(painter1.shouldRepaint(painter3), isFalse);
    });
  });
}
