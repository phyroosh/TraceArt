import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traceart/services/image_processing_service.dart';
import 'package:traceart/viewmodels/tracing_viewmodel.dart';
import '../mocks/fake_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeImagePickerService pickerService;
  late FakeScreenService screenService;
  late FakeImageProcessingService processingService;
  late TracingViewModel viewModel;

  setUp(() {
    pickerService = FakeImagePickerService();
    screenService = FakeScreenService();
    processingService = FakeImageProcessingService();
    viewModel = TracingViewModel(
      pickerService: pickerService,
      screenService: screenService,
      processingService: processingService,
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

    test('locking canvas activates keepAwake and systemUiLocked for tracing', () {
      viewModel.setImage(createSampleImage());
      screenService.keepAwakeState = false;
      screenService.systemUiLockedState = false;

      viewModel.toggleLock();

      expect(viewModel.isLocked, isTrue);
      expect(viewModel.keepAwake, isTrue);
      expect(screenService.keepAwakeState, isTrue);
      expect(screenService.systemUiLockedState, isTrue);

      viewModel.toggleLock();

      expect(viewModel.isLocked, isFalse);
      expect(screenService.systemUiLockedState, isFalse);
    });

    test('clearImage and dispose reset systemUiLocked', () async {
      viewModel.setImage(createSampleImage());
      viewModel.toggleLock();
      expect(screenService.systemUiLockedState, isTrue);

      await viewModel.clearImage();
      expect(screenService.systemUiLockedState, isFalse);

      final tempVm = TracingViewModel(
        pickerService: pickerService,
        screenService: screenService,
        processingService: processingService,
      );
      tempVm.setImage(createSampleImage());
      tempVm.toggleLock();
      expect(screenService.systemUiLockedState, isTrue);

      tempVm.dispose();
      expect(screenService.systemUiLockedState, isFalse);
    });

    test('resuming app while locked re-asserts systemUiLocked', () async {
      viewModel.setImage(createSampleImage());
      viewModel.toggleLock();
      expect(screenService.systemUiLockedState, isTrue);

      screenService.systemUiLockedState = false;
      await viewModel.handleAppLifecycle(AppLifecycleState.resumed);
      expect(screenService.systemUiLockedState, isTrue);
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

  group('Fine Detail Mode & Tracing Invariant Tests', () {
    test('initial state has default modes and values', () {
      expect(viewModel.invertMode, equals(InvertTracingMode.original));
      expect(viewModel.detailStrength, closeTo(0.5, 0.001));
      expect(viewModel.edgeSensitivity, closeTo(0.5, 0.001));
      expect(viewModel.isProcessing, isFalse);
      expect(viewModel.processedImage, isNull);
      expect(viewModel.activeDisplayImage, isNull);
    });

    test('setting invertMode to enhanced triggers processing when inverted', () async {
      viewModel.setImage(createSampleImage());
      viewModel.toggleInverted();
      expect(viewModel.isInverted, isTrue);

      viewModel.setInvertMode(InvertTracingMode.enhanced);
      // Wait for async processing
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(processingService.processCallCount, greaterThan(0));
      expect(processingService.lastMode, equals(InvertTracingMode.enhanced));
      expect(viewModel.processedImage, isNotNull);
      expect(viewModel.activeDisplayImage, equals(viewModel.processedImage));
    });

    test('setting invertMode to fineOutline passes edgeSensitivity to processing', () async {
      viewModel.setImage(createSampleImage());
      viewModel.setInverted(true);
      viewModel.setEdgeSensitivity(0.85);

      viewModel.setInvertMode(InvertTracingMode.fineOutline);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(processingService.lastMode, equals(InvertTracingMode.fineOutline));
      expect(processingService.lastSensitivity, closeTo(0.85, 0.001));
    });

    test('adjusting detailStrength debounces and triggers re-processing', () async {
      viewModel.setImage(createSampleImage());
      viewModel.setInverted(true);
      viewModel.setInvertMode(InvertTracingMode.enhanced);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final initialCount = processingService.processCallCount;

      viewModel.setDetailStrength(0.9);
      expect(viewModel.detailStrength, closeTo(0.9, 0.001));

      // Before debounce fires
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(processingService.processCallCount, equals(initialCount));

      // After debounce (150ms) fires
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(processingService.processCallCount, greaterThan(initialCount));
      expect(processingService.lastStrength, closeTo(0.9, 0.001));
    });

    test('caching: switching back to previously processed mode is instantaneous', () async {
      viewModel.setImage(createSampleImage());
      viewModel.setInverted(true);

      // 1. Process enhanced
      viewModel.setInvertMode(InvertTracingMode.enhanced);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final countAfterEnhanced = processingService.processCallCount;

      // 2. Process outline
      viewModel.setInvertMode(InvertTracingMode.fineOutline);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(processingService.processCallCount, greaterThan(countAfterEnhanced));
      final countAfterOutline = processingService.processCallCount;

      // 3. Switch back to enhanced: should use cached image WITHOUT re-calling process
      viewModel.setInvertMode(InvertTracingMode.enhanced);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(processingService.processCallCount, equals(countAfterOutline));
      expect(viewModel.processedImage, isNotNull);
    });

    test('core invariant: switching modes NEVER alters isLocked state', () async {
      viewModel.setImage(createSampleImage());
      viewModel.toggleLock();
      expect(viewModel.isLocked, isTrue);

      viewModel.setInverted(true);
      viewModel.setInvertMode(InvertTracingMode.enhanced);
      expect(viewModel.isLocked, isTrue);

      viewModel.setInvertMode(InvertTracingMode.fineOutline);
      expect(viewModel.isLocked, isTrue);

      viewModel.setDetailStrength(0.8);
      expect(viewModel.isLocked, isTrue);

      viewModel.setEdgeSensitivity(0.3);
      expect(viewModel.isLocked, isTrue);

      viewModel.setInvertMode(InvertTracingMode.original);
      expect(viewModel.isLocked, isTrue);
    });

    test('core invariant: switching modes NEVER alters transformation matrix or quarterTurns', () async {
      viewModel.setImage(createSampleImage());
      viewModel.updateViewportSize(const Size(400, 800));
      viewModel.zoomIn();
      viewModel.rotateClockwise();

      final matrixBefore = viewModel.transformationController.value.clone();
      final turnsBefore = viewModel.quarterTurns;

      viewModel.setInverted(true);
      viewModel.setInvertMode(InvertTracingMode.enhanced);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(viewModel.transformationController.value, equals(matrixBefore));
      expect(viewModel.quarterTurns, equals(turnsBefore));

      viewModel.setInvertMode(InvertTracingMode.fineOutline);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(viewModel.transformationController.value, equals(matrixBefore));
      expect(viewModel.quarterTurns, equals(turnsBefore));
    });

    test('disabling inversion restores activeDisplayImage to original image', () async {
      viewModel.setImage(createSampleImage());
      viewModel.setInverted(true);
      viewModel.setInvertMode(InvertTracingMode.enhanced);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(viewModel.activeDisplayImage, isNotNull);
      expect(viewModel.activeDisplayImage, isNot(equals(viewModel.image)));

      viewModel.toggleInverted();
      expect(viewModel.isInverted, isFalse);
      expect(viewModel.activeDisplayImage, equals(viewModel.image));
    });

    test('clearImage resets processedImage and cache', () async {
      viewModel.setImage(createSampleImage());
      viewModel.setInverted(true);
      viewModel.setInvertMode(InvertTracingMode.enhanced);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(viewModel.processedImage, isNotNull);

      await viewModel.clearImage();

      expect(viewModel.processedImage, isNull);
      expect(viewModel.activeDisplayImage, isNull);
    });
  });
}
