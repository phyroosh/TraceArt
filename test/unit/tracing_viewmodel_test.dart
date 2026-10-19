import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traceart/viewmodels/tracing_viewmodel.dart';
import '../mocks/fake_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeImagePickerService pickerService;
  late FakeScreenService screenService;
  late TracingViewModel viewModel;

  setUp(() {
    pickerService = FakeImagePickerService();
    screenService = FakeScreenService();
    viewModel = TracingViewModel(
      pickerService: pickerService,
      screenService: screenService,
    );
  });

  tearDown(() {
    viewModel.dispose();
  });

  group('Image Selection & Persistence', () {
    test('initially has no image and is unlocked', () {
      expect(viewModel.hasImage, isFalse);
      expect(viewModel.image, isNull);
      expect(viewModel.isLocked, isFalse);
      expect(viewModel.quarterTurns, equals(0));
    });

    test('pickImage updates image, enables keepAwake and boosts brightness', () async {
      final testImg = createSampleImage();
      pickerService.nextResult = testImg;

      await viewModel.pickImage();

      expect(viewModel.hasImage, isTrue);
      expect(viewModel.image, equals(testImg));
      expect(viewModel.isLocked, isFalse);
      expect(viewModel.keepAwake, isTrue);
      expect(screenService.keepAwakeState, isTrue);
      expect(viewModel.brightness, equals(1.0));
      expect(viewModel.errorMessage, isNull);
    });

    test('pickImage handles user cancellation gracefully', () async {
      pickerService.nextResult = null; // cancelled

      await viewModel.pickImage();

      expect(viewModel.hasImage, isFalse);
      expect(viewModel.errorMessage, isNull);
    });

    test('pickImage handles error and sets errorMessage', () async {
      pickerService.shouldThrow = true;

      await viewModel.pickImage();

      expect(viewModel.hasImage, isFalse);
      expect(viewModel.errorMessage, contains('Photo library access failed'));
    });

    test('clearImage resets state and restores brightness and wakelock', () async {
      viewModel.setImage(createSampleImage());
      expect(viewModel.hasImage, isTrue);

      await viewModel.clearImage();

      expect(viewModel.hasImage, isFalse);
      expect(viewModel.isLocked, isFalse);
      expect(viewModel.quarterTurns, equals(0));
      expect(screenService.restoreCalls, greaterThan(0));
      expect(screenService.keepAwakeState, isFalse);
    });
  });

  group('Lock & Unlock — Core Invariant Tests', () {
    test('toggleLock freezes and unfreezes canvas while preserving exact matrix', () {
      viewModel.setImage(createSampleImage());
      viewModel.updateViewportSize(const Size(400, 800));

      // Apply initial zoom
      viewModel.zoomIn();
      final matrixBeforeLock = viewModel.transformationController.value.clone();

      // Lock the canvas
      viewModel.toggleLock();
      expect(viewModel.isLocked, isTrue);
      expect(viewModel.transformationController.value, equals(matrixBeforeLock));

      // Attempt to modify while locked — MUST NOT CHANGE
      viewModel.zoomIn();
      viewModel.zoomOut();
      viewModel.rotateClockwise();
      viewModel.rotateCounterClockwise();
      viewModel.resetAlignment();
      viewModel.fitToScreen();

      expect(viewModel.transformationController.value, equals(matrixBeforeLock));
      expect(viewModel.quarterTurns, equals(0));

      // Unlock the canvas
      viewModel.toggleLock();
      expect(viewModel.isLocked, isFalse);

      // Alignment must remain 100% identical after unlock
      expect(viewModel.transformationController.value, equals(matrixBeforeLock));

      // Now modification works again
      viewModel.zoomIn();
      expect(viewModel.transformationController.value, isNot(equals(matrixBeforeLock)));
    });

    test('locking canvas activates keepAwake for tracing', () {
      viewModel.setImage(createSampleImage());
      screenService.keepAwakeState = false;

      viewModel.toggleLock();

      expect(viewModel.isLocked, isTrue);
      expect(viewModel.keepAwake, isTrue);
      expect(screenService.keepAwakeState, isTrue);
    });
  });

  group('Alignment, Rotation & Transformations', () {
    test('calculateFitMatrix centers and scales content without cropping', () {
      final matrix = viewModel.calculateFitMatrix(
        const Size(400, 800),
        const Size(200, 600),
      );

      // Scale must fit available height (768 / 600 = 1.28)
      // Translation must be positive and centered
      final scaleX = matrix.getMaxScaleOnAxis();
      expect(scaleX, closeTo(1.28, 0.05));
    });

    test('rotateClockwise increments quarterTurns and updates effective dimensions', () {
      viewModel.setImage(createSampleImage(width: 800, height: 1200));
      viewModel.updateViewportSize(const Size(400, 800));

      expect(viewModel.effectiveImageSize, equals(const Size(800, 1200)));

      viewModel.rotateClockwise();
      expect(viewModel.quarterTurns, equals(1));
      expect(viewModel.effectiveImageSize, equals(const Size(1200, 800)));

      viewModel.rotateClockwise();
      expect(viewModel.quarterTurns, equals(2));
      expect(viewModel.effectiveImageSize, equals(const Size(800, 1200)));

      viewModel.rotateClockwise();
      expect(viewModel.quarterTurns, equals(3));
      expect(viewModel.effectiveImageSize, equals(const Size(1200, 800)));

      viewModel.rotateClockwise();
      expect(viewModel.quarterTurns, equals(0));
      expect(viewModel.effectiveImageSize, equals(const Size(800, 1200)));
    });

    test('rotateCounterClockwise decrements quarterTurns', () {
      viewModel.setImage(createSampleImage());
      viewModel.updateViewportSize(const Size(400, 800));

      viewModel.rotateCounterClockwise();
      expect(viewModel.quarterTurns, equals(3));

      viewModel.rotateCounterClockwise();
      expect(viewModel.quarterTurns, equals(2));
    });

    test('resetAlignment restores 0 rotation and initial fit', () {
      viewModel.setImage(createSampleImage());
      viewModel.updateViewportSize(const Size(400, 800));

      viewModel.rotateClockwise();
      viewModel.zoomIn();
      viewModel.zoomIn();

      expect(viewModel.quarterTurns, equals(1));

      viewModel.resetAlignment();

      expect(viewModel.quarterTurns, equals(0));
      final matrix = viewModel.transformationController.value;
      final expectedFit = viewModel.calculateFitMatrix(
        const Size(400, 800),
        viewModel.effectiveImageSize,
      );
      expect(matrix, equals(expectedFit));
    });

    test('zoomIn increases scale and zoomOut decreases scale', () {
      viewModel.setImage(createSampleImage());
      viewModel.updateViewportSize(const Size(400, 800));

      final initialScale =
          viewModel.transformationController.value.getMaxScaleOnAxis();

      viewModel.zoomIn();
      final zoomedInScale =
          viewModel.transformationController.value.getMaxScaleOnAxis();
      expect(zoomedInScale, greaterThan(initialScale));

      viewModel.zoomOut();
      final zoomedOutScale =
          viewModel.transformationController.value.getMaxScaleOnAxis();
      expect(zoomedOutScale, lessThan(zoomedInScale));
    });
  });

  group('Brightness & Lifecycle', () {
    test('setBrightness updates brightness level', () async {
      await viewModel.setBrightness(0.65);
      expect(viewModel.brightness, closeTo(0.65, 0.01));
      expect(screenService.current, closeTo(0.65, 0.01));
    });

    test('toggleMaxBrightness toggles between 1.0 and previous level', () async {
      await viewModel.setBrightness(0.7);
      expect(viewModel.isMaxBrightness, isFalse);

      await viewModel.toggleMaxBrightness();
      expect(viewModel.isMaxBrightness, isTrue);
      expect(viewModel.brightness, equals(1.0));

      await viewModel.toggleMaxBrightness();
      expect(viewModel.isMaxBrightness, isFalse);
      expect(viewModel.brightness, closeTo(0.7, 0.01));
    });

    test('lifecycle paused restores brightness and resumed reapplies it', () async {
      viewModel.setImage(createSampleImage());
      await viewModel.setBrightness(0.9);

      await viewModel.handleAppLifecycle(AppLifecycleState.paused);
      expect(screenService.restoreCalls, greaterThan(0));

      await viewModel.handleAppLifecycle(AppLifecycleState.resumed);
      expect(screenService.current, closeTo(0.9, 0.01));
    });
  });
}
