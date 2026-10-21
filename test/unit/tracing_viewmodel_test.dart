import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traceart/models/grid_config.dart';
import 'package:traceart/models/stencil_config.dart';
import 'package:traceart/services/image_processing_service.dart';
import 'package:traceart/viewmodels/tracing_viewmodel.dart';
import '../mocks/fake_camera_service.dart';
import '../mocks/fake_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeImagePickerService pickerService;
  late FakeScreenService screenService;
  late FakeImageProcessingService processingService;
  late FakeCameraService cameraService;
  late TracingViewModel viewModel;

  setUp(() {
    pickerService = FakeImagePickerService();
    screenService = FakeScreenService();
    processingService = FakeImageProcessingService();
    cameraService = FakeCameraService();
    viewModel = TracingViewModel(
      pickerService: pickerService,
      screenService: screenService,
      processingService: processingService,
      cameraService: cameraService,
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
      expect(viewModel.lineColorTint, equals(LineColorTint.white));
      expect(viewModel.detailStrength, closeTo(0.5, 0.001));
      expect(viewModel.edgeSensitivity, closeTo(0.5, 0.001));
      expect(viewModel.isProcessing, isFalse);
      expect(viewModel.processedImage, isNull);
      expect(viewModel.activeDisplayImage, isNull);
    });

    test('setLineColorTint updates tint and clearImage resets it', () async {
      viewModel.setImage(createSampleImage());
      viewModel.setLineColorTint(LineColorTint.neonGreen);
      expect(viewModel.lineColorTint, equals(LineColorTint.neonGreen));

      viewModel.setLineColorTint(LineColorTint.cyan);
      expect(viewModel.lineColorTint, equals(LineColorTint.cyan));

      await viewModel.clearImage();
      expect(viewModel.lineColorTint, equals(LineColorTint.white));
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

  group('Proportional Drawing Grid Overlay Tests', () {
    test('initial state has grid disabled and default GridConfig', () {
      expect(viewModel.isGridEnabled, isFalse);
      expect(viewModel.gridConfig.divisions, equals(4));
      expect(viewModel.gridConfig.opacity, equals(0.6));
      expect(viewModel.gridConfig.colorPreset, equals(GridColor.white));
      expect(viewModel.gridConfig.showCenterCrosshair, isFalse);
      expect(viewModel.gridConfig.showDiagonals, isFalse);
      expect(viewModel.gridConfig.showLabels, isFalse);
    });

    test('toggleGrid flips isGridEnabled', () {
      bool notified = false;
      viewModel.addListener(() => notified = true);

      viewModel.toggleGrid();
      expect(viewModel.isGridEnabled, isTrue);
      expect(notified, isTrue);

      notified = false;
      viewModel.toggleGrid();
      expect(viewModel.isGridEnabled, isFalse);
      expect(notified, isTrue);
    });

    test('setGridEnabled sets state and notifies only when changed', () {
      int notifyCount = 0;
      viewModel.addListener(() => notifyCount++);

      viewModel.setGridEnabled(true);
      expect(viewModel.isGridEnabled, isTrue);
      expect(notifyCount, equals(1));

      viewModel.setGridEnabled(true);
      expect(notifyCount, equals(1)); // no duplicate notification

      viewModel.setGridEnabled(false);
      expect(viewModel.isGridEnabled, isFalse);
      expect(notifyCount, equals(2));
    });

    test('setGridDivisions clamps divisions within 2..16', () {
      viewModel.setGridDivisions(8);
      expect(viewModel.gridConfig.divisions, equals(8));

      viewModel.setGridDivisions(1);
      expect(viewModel.gridConfig.divisions, equals(2));

      viewModel.setGridDivisions(25);
      expect(viewModel.gridConfig.divisions, equals(16));
    });

    test('setGridOpacity clamps opacity within 0.15..1.0', () {
      viewModel.setGridOpacity(0.8);
      expect(viewModel.gridConfig.opacity, closeTo(0.8, 0.01));

      viewModel.setGridOpacity(0.05);
      expect(viewModel.gridConfig.opacity, closeTo(0.15, 0.01));

      viewModel.setGridOpacity(1.5);
      expect(viewModel.gridConfig.opacity, closeTo(1.0, 0.01));
    });

    test('setGridColor updates color preset', () {
      viewModel.setGridColor(GridColor.cyan);
      expect(viewModel.gridConfig.colorPreset, equals(GridColor.cyan));
      expect(viewModel.gridConfig.activeColor.toARGB32(), isNotNull);

      viewModel.setGridColor(GridColor.amber);
      expect(viewModel.gridConfig.colorPreset, equals(GridColor.amber));
    });

    test('auxiliary guides toggle functions work correctly', () {
      expect(viewModel.gridConfig.showCenterCrosshair, isFalse);
      viewModel.toggleGridCenterCrosshair();
      expect(viewModel.gridConfig.showCenterCrosshair, isTrue);
      viewModel.toggleGridCenterCrosshair();
      expect(viewModel.gridConfig.showCenterCrosshair, isFalse);

      expect(viewModel.gridConfig.showDiagonals, isFalse);
      viewModel.toggleGridDiagonals();
      expect(viewModel.gridConfig.showDiagonals, isTrue);
      viewModel.toggleGridDiagonals();
      expect(viewModel.gridConfig.showDiagonals, isFalse);

      expect(viewModel.gridConfig.showLabels, isFalse);
      viewModel.toggleGridLabels();
      expect(viewModel.gridConfig.showLabels, isTrue);
      viewModel.toggleGridLabels();
      expect(viewModel.gridConfig.showLabels, isFalse);
    });

    test('updateGridConfig sets complete config', () {
      const customConfig = GridConfig(
        divisions: 6,
        opacity: 0.9,
        strokeWidth: 2.0,
        colorPreset: GridColor.neonGreen,
        showCenterCrosshair: true,
        showDiagonals: true,
        showLabels: true,
      );

      viewModel.updateGridConfig(customConfig);
      expect(viewModel.gridConfig, equals(customConfig));
      expect(viewModel.gridConfig.divisions, equals(6));
      expect(viewModel.gridConfig.colorPreset, equals(GridColor.neonGreen));
    });

    test('GridConfig copyWith and equality', () {
      const c1 = GridConfig(divisions: 4, opacity: 0.5);
      final c2 = c1.copyWith(divisions: 8);
      expect(c2.divisions, equals(8));
      expect(c2.opacity, equals(0.5));
      expect(c1 == c2, isFalse);

      final c3 = c1.copyWith();
      expect(c1 == c3, isTrue);
      expect(c1.hashCode, equals(c3.hashCode));
    });

    test('GridColor presets have valid labels and colors', () {
      for (final color in GridColor.values) {
        expect(color.label.isNotEmpty, isTrue);
        expect(color.color.a, equals(1.0));
      }
    });
  });

  group('AR Camera Tracing Mode', () {
    test('default state is lightBox with 50% opacity and torch off', () {
      expect(viewModel.tracingMode, equals(TracingMode.lightBox));
      expect(viewModel.isArMode, isFalse);
      expect(viewModel.overlayOpacity, equals(0.5));
      expect(viewModel.isTorchOn, isFalse);
      expect(viewModel.isCameraInitializing, isFalse);
      expect(viewModel.cameraErrorMessage, isNull);
    });

    test('setTracingMode to arCamera initializes camera and sets isArMode', () async {
      await viewModel.setTracingMode(TracingMode.arCamera);

      expect(viewModel.tracingMode, equals(TracingMode.arCamera));
      expect(viewModel.isArMode, isTrue);
      expect(cameraService.initializeCalls, equals(1));
      expect(cameraService.isInitialized, isTrue);
      expect(viewModel.cameraErrorMessage, isNull);
    });

    test('switching back to lightBox disposes camera', () async {
      await viewModel.setTracingMode(TracingMode.arCamera);
      expect(viewModel.isArMode, isTrue);

      await viewModel.setTracingMode(TracingMode.lightBox);
      expect(viewModel.isArMode, isFalse);
      expect(cameraService.disposeCalls, equals(1));
    });

    test('toggleTracingMode alternates between lightBox and arCamera', () async {
      expect(viewModel.isArMode, isFalse);

      await viewModel.toggleTracingMode();
      expect(viewModel.isArMode, isTrue);
      expect(cameraService.initializeCalls, equals(1));

      await viewModel.toggleTracingMode();
      expect(viewModel.isArMode, isFalse);
      expect(cameraService.disposeCalls, equals(1));
    });

    test('camera initialization failure sets cameraErrorMessage', () async {
      cameraService.shouldSucceed = false;

      await viewModel.setTracingMode(TracingMode.arCamera);

      expect(viewModel.isArMode, isTrue);
      expect(viewModel.cameraErrorMessage, contains('Camera permission or device not available'));
    });

    test('setOverlayOpacity clamps between 0.1 and 0.95', () {
      viewModel.setOverlayOpacity(0.75);
      expect(viewModel.overlayOpacity, closeTo(0.75, 0.005));

      // Test lower clamp
      viewModel.setOverlayOpacity(0.02);
      expect(viewModel.overlayOpacity, closeTo(0.1, 0.005));

      // Test upper clamp
      viewModel.setOverlayOpacity(1.5);
      expect(viewModel.overlayOpacity, closeTo(0.95, 0.005));
    });

    test('toggleTorch toggles camera torch state', () async {
      await viewModel.setTracingMode(TracingMode.arCamera);
      expect(viewModel.isTorchOn, isFalse);

      await viewModel.toggleTorch();
      expect(cameraService.toggleTorchCalls, equals(1));
      expect(viewModel.isTorchOn, isTrue);

      await viewModel.toggleTorch();
      expect(cameraService.toggleTorchCalls, equals(2));
      expect(viewModel.isTorchOn, isFalse);
    });

    test('switchCamera switches camera lens direction', () async {
      await viewModel.setTracingMode(TracingMode.arCamera);
      expect(cameraService.currentLensDirection, equals(CameraLensDirection.back));

      await viewModel.switchCamera();
      expect(cameraService.switchCameraCalls, equals(1));
      expect(cameraService.currentLensDirection, equals(CameraLensDirection.front));
    });

    test('clearImage resets tracing mode to lightBox and disposes camera', () async {
      viewModel.setImage(createSampleImage());
      await viewModel.setTracingMode(TracingMode.arCamera);
      expect(viewModel.isArMode, isTrue);

      await viewModel.clearImage();

      expect(viewModel.tracingMode, equals(TracingMode.lightBox));
      expect(viewModel.isArMode, isFalse);
      expect(cameraService.disposeCalls, greaterThan(0));
    });
  });

  group('Quick Stencil & Threshold Filters', () {
    test('initial stencil state is inactive with none type', () {
      expect(viewModel.isStencilActive, isFalse);
      expect(viewModel.stencilConfig.type, equals(StencilFilterType.none));
      expect(viewModel.stencilConfig.threshold, equals(0.5));
      expect(viewModel.stencilConfig.posterizeLevels, equals(4));
      expect(viewModel.stencilConfig.edgeStrength, equals(0.5));
      expect(viewModel.processedStencilImage, isNull);
    });

    test('setting stencil type updates config and triggers background processing', () async {
      viewModel.setImage(createSampleImage());
      expect(viewModel.isStencilActive, isFalse);

      viewModel.setStencilType(StencilFilterType.threshold);
      expect(viewModel.stencilConfig.type, equals(StencilFilterType.threshold));
      expect(viewModel.isStencilActive, isTrue);

      // Wait for debounce timer (150ms) + fake processing
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(processingService.stencilCallCount, greaterThan(0));
      expect(viewModel.processedStencilImage, isNotNull);
      expect(viewModel.activeDisplayImage, equals(viewModel.processedStencilImage));
    });

    test('setStencilThreshold clamps value within 0.05 - 0.95 and debounces processing', () async {
      viewModel.setImage(createSampleImage());
      viewModel.setStencilType(StencilFilterType.threshold);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final initialCalls = processingService.stencilCallCount;

      // Lower clamp
      viewModel.setStencilThreshold(0.01);
      expect(viewModel.stencilConfig.threshold, equals(0.05));

      // Upper clamp
      viewModel.setStencilThreshold(0.99);
      expect(viewModel.stencilConfig.threshold, equals(0.95));

      // Normal value
      viewModel.setStencilThreshold(0.7);
      expect(viewModel.stencilConfig.threshold, equals(0.7));

      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(processingService.stencilCallCount, greaterThan(initialCalls));
    });

    test('setStencilPosterizeLevels updates levels and triggers processing', () async {
      viewModel.setImage(createSampleImage());
      viewModel.setStencilType(StencilFilterType.posterize);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      viewModel.setStencilPosterizeLevels(6);
      expect(viewModel.stencilConfig.posterizeLevels, equals(6));

      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(viewModel.processedStencilImage, isNotNull);
    });

    test('setStencilEdgeStrength clamps within 0.1 - 1.0 and triggers processing', () async {
      viewModel.setImage(createSampleImage());
      viewModel.setStencilType(StencilFilterType.edgeSketch);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      viewModel.setStencilEdgeStrength(0.05); // clamped to 0.1
      expect(viewModel.stencilConfig.edgeStrength, equals(0.1));

      viewModel.setStencilEdgeStrength(1.5); // clamped to 1.0
      expect(viewModel.stencilConfig.edgeStrength, equals(1.0));

      viewModel.setStencilEdgeStrength(0.8);
      expect(viewModel.stencilConfig.edgeStrength, equals(0.8));

      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(viewModel.processedStencilImage, isNotNull);
    });

    test('applyAutoOtsuThreshold computes optimal bimodal cutoff and updates config', () async {
      viewModel.setImage(createSampleImage());
      processingService.nextOtsuThreshold = 0.42;

      viewModel.applyAutoOtsuThreshold();

      expect(processingService.otsuCallCount, equals(1));
      expect(viewModel.stencilConfig.threshold, closeTo(0.42, 0.001));
    });

    test('switching back to StencilFilterType.none clears processedStencilImage', () async {
      viewModel.setImage(createSampleImage());
      viewModel.setStencilType(StencilFilterType.threshold);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(viewModel.isStencilActive, isTrue);
      expect(viewModel.processedStencilImage, isNotNull);

      viewModel.setStencilType(StencilFilterType.none);
      expect(viewModel.isStencilActive, isFalse);
      expect(viewModel.processedStencilImage, isNull);
      expect(viewModel.activeDisplayImage, equals(viewModel.image));
    });

    test('clearImage resets stencil configuration to defaults and evicts cache', () async {
      viewModel.setImage(createSampleImage());
      viewModel.setStencilConfig(const StencilConfig(
        type: StencilFilterType.posterize,
        threshold: 0.7,
        posterizeLevels: 8,
        edgeStrength: 0.9,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 200));

      await viewModel.clearImage();

      expect(viewModel.isStencilActive, isFalse);
      expect(viewModel.stencilConfig.type, equals(StencilFilterType.none));
      expect(viewModel.stencilConfig.threshold, equals(0.5));
      expect(viewModel.stencilConfig.posterizeLevels, equals(4));
      expect(viewModel.stencilConfig.edgeStrength, equals(0.5));
      expect(viewModel.processedStencilImage, isNull);
    });
  });
}
