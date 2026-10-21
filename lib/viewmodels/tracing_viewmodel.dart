import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/grid_config.dart';
import '../models/image_model.dart';
import '../models/stencil_config.dart';
import '../services/camera_service.dart';
import '../services/image_picker_service.dart';
import '../services/image_processing_service.dart';
import '../services/screen_service.dart';

/// Available tracing modes in TraceArt.
enum TracingMode {
  lightBox('Light Box', 'Screen tracing for translucent paper'),
  arCamera('AR Camera', 'Surface tracing for opaque canvas & boards');

  final String label;
  final String description;
  const TracingMode(this.label, this.description);
}

/// ViewModel managing TraceArt state:
/// - Selected image persistence
/// - Spatial transformation (pan, zoom, rotate, fit, reset)
/// - Lock / Unlock enforcement
/// - Brightness & Screen Keep-Awake controls
/// - Inverted contrast mode for line tracing
/// - Proportional drawing grid overlay
/// - AR Camera tracing mode for opaque surfaces
/// - Quick stencil & threshold filters (B&W Stencil, Posterize, Edge Sketch)
class TracingViewModel extends ChangeNotifier {
  final ImagePickerService _pickerService;
  final ScreenService _screenService;
  final ImageProcessingService _processingService;
  final CameraService _cameraService;

  ImageModel? _image;
  ImageModel? _processedImage;
  bool _isLocked = false;
  int _quarterTurns = 0;
  final TransformationController _transformationController =
      TransformationController();
  Size? _viewportSize;

  bool _isLoading = false;
  String? _errorMessage;

  double _brightness = 1.0;
  double _savedPreMaxBrightness = 0.8;
  bool _isMaxBrightness = true;
  bool _keepAwake = true;
  bool _isInverted = false;
  bool _hasCalculatedInitialFit = false;

  // AR Camera Tracing Mode state
  TracingMode _tracingMode = TracingMode.lightBox;
  double _overlayOpacity = 0.5;
  bool _isCameraInitializing = false;
  String? _cameraErrorMessage;

  // Drawing Grid Overlay state
  bool _isGridEnabled = false;
  GridConfig _gridConfig = const GridConfig();

  // Fine Detail Mode state
  InvertTracingMode _invertMode = InvertTracingMode.original;
  LineColorTint _lineColorTint = LineColorTint.white;
  double _detailStrength = 0.5;
  double _edgeSensitivity = 0.5;
  bool _isProcessing = false;
  final Map<String, ImageModel> _processedCache = {};
  Timer? _debounceTimer;
  int _processingRequestId = 0;

  // Quick Stencil & Threshold Filters state
  StencilConfig _stencilConfig = const StencilConfig();
  ImageModel? _processedStencilImage;
  final Map<String, ImageModel> _stencilCache = {};
  Timer? _stencilDebounceTimer;
  int _stencilRequestId = 0;

  TracingViewModel({
    ImagePickerService? pickerService,
    ScreenService? screenService,
    ImageProcessingService? processingService,
    CameraService? cameraService,
  })  : _pickerService = pickerService ?? DefaultImagePickerService(),
        _screenService = screenService ?? DefaultScreenService(),
        _processingService = processingService ?? DefaultImageProcessingService(),
        _cameraService = cameraService ?? DefaultCameraService();

  // --- Getters ---

  ImageModel? get image => _image;
  ImageModel? get processedImage => _processedImage;
  ImageModel? get processedStencilImage => _processedStencilImage;
  StencilConfig get stencilConfig => _stencilConfig;
  bool get isStencilActive => _stencilConfig.isEnabled;

  /// The active image to render on the canvas.
  /// When a stencil filter is applied, returns the stencil-processed variant.
  /// When inversion is enabled with Enhanced or Fine Outline mode, returns the
  /// invert-processed variant. Otherwise falls back to original.
  ImageModel? get activeDisplayImage {
    if (_stencilConfig.isEnabled && _processedStencilImage != null) {
      return _processedStencilImage;
    }
    if (_isInverted &&
        _invertMode != InvertTracingMode.original &&
        _processedImage != null) {
      return _processedImage;
    }
    return _image;
  }

  bool get hasImage => _image != null;
  bool get isLocked => _isLocked;
  int get quarterTurns => _quarterTurns;
  TransformationController get transformationController =>
      _transformationController;
  Size? get viewportSize => _viewportSize;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  double get brightness => _brightness;
  bool get isMaxBrightness => _isMaxBrightness;
  bool get keepAwake => _keepAwake;
  bool get isInverted => _isInverted;
  bool get isBrightnessSupported => _screenService.isBrightnessSupported;

  InvertTracingMode get invertMode => _invertMode;
  LineColorTint get lineColorTint => _lineColorTint;
  double get detailStrength => _detailStrength;
  double get edgeSensitivity => _edgeSensitivity;
  bool get isProcessing => _isProcessing;

  bool get isGridEnabled => _isGridEnabled;
  GridConfig get gridConfig => _gridConfig;

  // AR Camera Mode Getters
  TracingMode get tracingMode => _tracingMode;
  bool get isArMode => _tracingMode == TracingMode.arCamera;
  double get overlayOpacity => _overlayOpacity;
  bool get isCameraInitializing => _isCameraInitializing;
  String? get cameraErrorMessage => _cameraErrorMessage;
  CameraService get cameraService => _cameraService;
  bool get isTorchOn => _cameraService.isTorchOn;

  /// Effective size of the image accounting for 90-degree rotations
  Size get effectiveImageSize {
    if (_image == null) return Size.zero;
    return (_quarterTurns % 2 == 1)
        ? Size(_image!.height.toDouble(), _image!.width.toDouble())
        : Size(_image!.width.toDouble(), _image!.height.toDouble());
  }

  // --- Initialization ---

  Future<void> init() async {
    await _screenService.init();
    _brightness = _screenService.currentBrightness;
  }

  // --- Image Selection & Lifecycle ---

  Future<void> pickImage() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final selected = await _pickerService.pickImageFromGallery();
      if (selected != null) {
        _debounceTimer?.cancel();
        _stencilDebounceTimer?.cancel();
        _processedCache.clear();
        _stencilCache.clear();
        _processedImage = null;
        _processedStencilImage = null;
        _image = selected;
        _quarterTurns = 0;
        _isLocked = false;
        _hasCalculatedInitialFit = false;
        _errorMessage = null;

        // Apply tracing defaults: keep screen awake & boost brightness
        await _screenService.setKeepAwake(true);
        _keepAwake = true;
        await setBrightness(1.0);

        if (_viewportSize != null) {
          fitToScreen();
        }

        if (_stencilConfig.isEnabled) {
          _scheduleStencilProcessing(immediate: true);
        }
        if (_isInverted && _invertMode != InvertTracingMode.original) {
          _scheduleImageProcessing(immediate: true);
        }
      }
    } catch (e) {
      _errorMessage = 'Could not load selected image: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sets an image directly (useful for tests or preloading)
  void setImage(ImageModel model) {
    _debounceTimer?.cancel();
    _stencilDebounceTimer?.cancel();
    _processedCache.clear();
    _stencilCache.clear();
    _processedImage = null;
    _processedStencilImage = null;
    _image = model;
    _quarterTurns = 0;
    _isLocked = false;
    _hasCalculatedInitialFit = false;
    _errorMessage = null;
    if (_viewportSize != null) {
      fitToScreen();
    }
    if (_stencilConfig.isEnabled) {
      _scheduleStencilProcessing(immediate: true);
    }
    if (_isInverted && _invertMode != InvertTracingMode.original) {
      _scheduleImageProcessing(immediate: true);
    }
    notifyListeners();
  }

  Future<void> clearImage() async {
    _debounceTimer?.cancel();
    _stencilDebounceTimer?.cancel();
    _processedCache.clear();
    _stencilCache.clear();
    _processedImage = null;
    _processedStencilImage = null;
    _stencilConfig = const StencilConfig();
    _image = null;
    _isLocked = false;
    _quarterTurns = 0;
    _hasCalculatedInitialFit = false;
    _lineColorTint = LineColorTint.white;
    _transformationController.value = Matrix4.identity();
    await _cameraService.dispose();
    _tracingMode = TracingMode.lightBox;
    _cameraErrorMessage = null;
    _isCameraInitializing = false;
    await _screenService.setSystemUiLocked(false);
    await _screenService.restoreBrightness();
    await _screenService.setKeepAwake(false);
    notifyListeners();
  }

  void updateViewportSize(Size size) {
    if (size == _viewportSize) return;
    final firstTime = _viewportSize == null || !_hasCalculatedInitialFit;
    _viewportSize = size;
    if (firstTime && _image != null && !_isLocked) {
      _transformationController.value =
          calculateFitMatrix(size, effectiveImageSize);
      _hasCalculatedInitialFit = true;
    }
  }

  // --- Alignment & Transformations ---

  Matrix4 calculateFitMatrix(Size viewportSize, Size contentSize) {
    if (viewportSize.isEmpty || contentSize.isEmpty) {
      return Matrix4.identity();
    }

    // Maintain 16px safety padding around edges
    final availableWidth = math.max(10.0, viewportSize.width - 32.0);
    final availableHeight = math.max(10.0, viewportSize.height - 32.0);

    final scaleX = availableWidth / contentSize.width;
    final scaleY = availableHeight / contentSize.height;
    final scale = math.min(scaleX, scaleY);

    final renderedWidth = contentSize.width * scale;
    final renderedHeight = contentSize.height * scale;

    final dx = (viewportSize.width - renderedWidth) / 2.0;
    final dy = (viewportSize.height - renderedHeight) / 2.0;

    return Matrix4.translationValues(dx, dy, 0.0) *
        Matrix4.diagonal3Values(scale, scale, scale);
  }

  /// Fits the complete image within the available tracing workspace without cropping.
  void fitToScreen() {
    if (_isLocked || _image == null || _viewportSize == null) return;
    _transformationController.value =
        calculateFitMatrix(_viewportSize!, effectiveImageSize);
    _hasCalculatedInitialFit = true;
    notifyListeners();
  }

  /// Resets position, scale, and rotation to initial fit.
  void resetAlignment() {
    if (_isLocked || _image == null) return;
    _quarterTurns = 0;
    if (_viewportSize != null) {
      _transformationController.value =
          calculateFitMatrix(_viewportSize!, effectiveImageSize);
    }
    notifyListeners();
  }

  /// Rotates the image 90 degrees clockwise and adjusts fit.
  void rotateClockwise() {
    if (_isLocked || _image == null) return;
    _quarterTurns = (_quarterTurns + 1) % 4;
    if (_viewportSize != null) {
      _transformationController.value =
          calculateFitMatrix(_viewportSize!, effectiveImageSize);
    }
    notifyListeners();
  }

  /// Rotates the image 90 degrees counterclockwise and adjusts fit.
  void rotateCounterClockwise() {
    if (_isLocked || _image == null) return;
    _quarterTurns = (_quarterTurns + 3) % 4;
    if (_viewportSize != null) {
      _transformationController.value =
          calculateFitMatrix(_viewportSize!, effectiveImageSize);
    }
    notifyListeners();
  }

  /// Zooms in or out relative to the center of the viewport.
  void zoomBy(double factor) {
    if (_isLocked || _image == null) return;
    final vSize = _viewportSize ?? const Size(400, 800);
    final center = Offset(vSize.width / 2, vSize.height / 2);

    final currentMatrix = _transformationController.value;
    final currentScale = currentMatrix.getMaxScaleOnAxis();
    final targetScale = (currentScale * factor).clamp(0.08, 30.0);
    final effectiveFactor = targetScale / currentScale;

    final translation = Matrix4.translationValues(center.dx, center.dy, 0);
    final scaleMatrix = Matrix4.diagonal3Values(
        effectiveFactor, effectiveFactor, effectiveFactor);
    final invTranslation =
        Matrix4.translationValues(-center.dx, -center.dy, 0);

    _transformationController.value =
        translation * scaleMatrix * invTranslation * currentMatrix;
    notifyListeners();
  }

  void zoomIn() => zoomBy(1.25);
  void zoomOut() => zoomBy(0.8);

  // --- Lock / Unlock ---

  /// Toggles the lock state. When locked, the image's current matrix is frozen
  /// and all canvas touch events are ignored. Alignment is 100% preserved.
  void toggleLock() {
    _isLocked = !_isLocked;
    if (_isLocked) {
      // Ensure keep-awake is active during tracing
      _screenService.setKeepAwake(true);
      _screenService.setSystemUiLocked(true);
      _keepAwake = true;
    } else {
      _screenService.setSystemUiLocked(false);
    }
    notifyListeners();
  }

  void setLocked(bool locked) {
    if (_isLocked == locked) return;
    _isLocked = locked;
    if (_isLocked) {
      _screenService.setKeepAwake(true);
      _screenService.setSystemUiLocked(true);
      _keepAwake = true;
    } else {
      _screenService.setSystemUiLocked(false);
    }
    notifyListeners();
  }

  // --- Brightness & Display Settings ---

  Future<void> setBrightness(double value) async {
    _brightness = value.clamp(0.05, 1.0);
    _isMaxBrightness = (_brightness >= 0.98);
    await _screenService.setBrightness(_brightness);
    notifyListeners();
  }

  Future<void> toggleMaxBrightness() async {
    if (_isMaxBrightness) {
      _isMaxBrightness = false;
      await setBrightness(_savedPreMaxBrightness);
    } else {
      _savedPreMaxBrightness = _brightness;
      _isMaxBrightness = true;
      await setBrightness(1.0);
    }
  }

  Future<void> toggleKeepAwake() async {
    _keepAwake = !_keepAwake;
    await _screenService.setKeepAwake(_keepAwake);
    notifyListeners();
  }

  void toggleInverted() {
    _isInverted = !_isInverted;
    notifyListeners();
    if (_isInverted && _invertMode != InvertTracingMode.original) {
      _scheduleImageProcessing(immediate: true);
    }
  }

  void setInverted(bool value) {
    if (_isInverted == value) return;
    _isInverted = value;
    notifyListeners();
    if (_isInverted && _invertMode != InvertTracingMode.original) {
      _scheduleImageProcessing(immediate: true);
    }
  }

  void setInvertMode(InvertTracingMode mode) {
    if (_invertMode == mode) return;
    _invertMode = mode;
    notifyListeners();
    if (_isInverted && mode != InvertTracingMode.original) {
      _scheduleImageProcessing(immediate: true);
    }
  }

  void setDetailStrength(double value) {
    final clamped = value.clamp(0.0, 1.0);
    if ((_detailStrength - clamped).abs() < 0.001) return;
    _detailStrength = clamped;
    notifyListeners();
    if (_isInverted && _invertMode != InvertTracingMode.original) {
      _scheduleImageProcessing(immediate: false);
    }
  }

  void setEdgeSensitivity(double value) {
    final clamped = value.clamp(0.0, 1.0);
    if ((_edgeSensitivity - clamped).abs() < 0.001) return;
    _edgeSensitivity = clamped;
    notifyListeners();
    if (_isInverted && _invertMode == InvertTracingMode.fineOutline) {
      _scheduleImageProcessing(immediate: false);
    }
  }

  void setLineColorTint(LineColorTint tint) {
    if (_lineColorTint == tint) return;
    _lineColorTint = tint;
    notifyListeners();
  }

  // --- Drawing Grid Overlay Controls ---

  void toggleGrid() {
    _isGridEnabled = !_isGridEnabled;
    notifyListeners();
  }

  void setGridEnabled(bool enabled) {
    if (_isGridEnabled == enabled) return;
    _isGridEnabled = enabled;
    notifyListeners();
  }

  void updateGridConfig(GridConfig config) {
    if (_gridConfig == config) return;
    _gridConfig = config;
    notifyListeners();
  }

  void setGridDivisions(int divisions) {
    final clamped = divisions.clamp(2, 16);
    if (_gridConfig.divisions == clamped) return;
    _gridConfig = _gridConfig.copyWith(divisions: clamped);
    notifyListeners();
  }

  void setGridOpacity(double opacity) {
    final clamped = opacity.clamp(0.15, 1.0);
    if ((_gridConfig.opacity - clamped).abs() < 0.005) return;
    _gridConfig = _gridConfig.copyWith(opacity: clamped);
    notifyListeners();
  }

  void setGridStrokeWidth(double strokeWidth) {
    final clamped = strokeWidth.clamp(0.5, 4.0);
    if ((_gridConfig.strokeWidth - clamped).abs() < 0.05) return;
    _gridConfig = _gridConfig.copyWith(strokeWidth: clamped);
    notifyListeners();
  }

  void setGridColor(GridColor colorPreset) {
    if (_gridConfig.colorPreset == colorPreset) return;
    _gridConfig = _gridConfig.copyWith(colorPreset: colorPreset);
    notifyListeners();
  }

  void toggleGridCenterCrosshair() {
    _gridConfig = _gridConfig.copyWith(
      showCenterCrosshair: !_gridConfig.showCenterCrosshair,
    );
    notifyListeners();
  }

  void toggleGridDiagonals() {
    _gridConfig = _gridConfig.copyWith(
      showDiagonals: !_gridConfig.showDiagonals,
    );
    notifyListeners();
  }

  void toggleGridLabels() {
    _gridConfig = _gridConfig.copyWith(
      showLabels: !_gridConfig.showLabels,
    );
    notifyListeners();
  }

  // --- Quick Stencil & Threshold Filters Controls ---

  void setStencilConfig(StencilConfig config) {
    if (_stencilConfig == config) return;
    _stencilConfig = config;
    notifyListeners();
    if (config.isEnabled) {
      _scheduleStencilProcessing(immediate: true);
    } else {
      _processedStencilImage = null;
      notifyListeners();
    }
  }

  void setStencilType(StencilFilterType type) {
    if (_stencilConfig.type == type) return;
    setStencilConfig(_stencilConfig.copyWith(type: type));
  }

  void setStencilThreshold(double threshold) {
    final clamped = threshold.clamp(0.05, 0.95);
    if ((_stencilConfig.thresholdValue - clamped).abs() < 0.005) return;
    _stencilConfig = _stencilConfig.copyWith(thresholdValue: clamped);
    notifyListeners();
    if (_stencilConfig.type == StencilFilterType.threshold) {
      _scheduleStencilProcessing(immediate: false);
    }
  }

  void setStencilPosterizeLevels(int levels) {
    final clamped = levels.clamp(2, 8);
    if (_stencilConfig.posterizeLevels == clamped) return;
    _stencilConfig = _stencilConfig.copyWith(posterizeLevels: clamped);
    notifyListeners();
    if (_stencilConfig.type == StencilFilterType.posterize) {
      _scheduleStencilProcessing(immediate: true);
    }
  }

  void setStencilEdgeStrength(double strength) {
    final clamped = strength.clamp(0.1, 1.0);
    if ((_stencilConfig.edgeStrength - clamped).abs() < 0.005) return;
    _stencilConfig = _stencilConfig.copyWith(edgeStrength: clamped);
    notifyListeners();
    if (_stencilConfig.type == StencilFilterType.edgeSketch) {
      _scheduleStencilProcessing(immediate: false);
    }
  }

  void applyAutoOtsuThreshold() {
    if (_image == null) return;
    final otsu = _processingService.computeOtsuThreshold(_image!.bytes);
    setStencilThreshold(otsu);
  }

  // --- AR Camera Tracing Controls ---

  Future<void> setTracingMode(TracingMode mode) async {
    if (_tracingMode == mode) return;
    _tracingMode = mode;
    _cameraErrorMessage = null;
    notifyListeners();

    if (mode == TracingMode.arCamera) {
      _isCameraInitializing = true;
      notifyListeners();

      final success = await _cameraService.initializeCamera();
      _isCameraInitializing = false;
      if (!success) {
        _cameraErrorMessage = 'Camera permission or device not available';
      }
      notifyListeners();
    } else {
      await _cameraService.dispose();
      notifyListeners();
    }
  }

  Future<void> toggleTracingMode() async {
    final next = _tracingMode == TracingMode.lightBox
        ? TracingMode.arCamera
        : TracingMode.lightBox;
    await setTracingMode(next);
  }

  void setOverlayOpacity(double opacity) {
    final clamped = opacity.clamp(0.1, 0.95);
    if ((_overlayOpacity - clamped).abs() < 0.005) return;
    _overlayOpacity = clamped;
    notifyListeners();
  }

  Future<void> toggleTorch() async {
    await _cameraService.toggleTorch();
    notifyListeners();
  }

  Future<void> switchCamera() async {
    _isCameraInitializing = true;
    notifyListeners();
    await _cameraService.switchCamera();
    _isCameraInitializing = false;
    notifyListeners();
  }

  void _scheduleImageProcessing({bool immediate = false}) {
    if (_image == null || !_isInverted || _invertMode == InvertTracingMode.original) {
      _debounceTimer?.cancel();
      _isProcessing = false;
      return;
    }

    final cacheKey =
        '${_image!.name}_${_invertMode.name}_${(_detailStrength * 20).round()}_${(_edgeSensitivity * 20).round()}';
    if (_processedCache.containsKey(cacheKey)) {
      _debounceTimer?.cancel();
      _processedImage = _processedCache[cacheKey];
      _isProcessing = false;
      notifyListeners();
      return;
    }

    _debounceTimer?.cancel();

    if (immediate) {
      _executeImageProcessing(cacheKey);
    } else {
      _isProcessing = true;
      notifyListeners();
      _debounceTimer = Timer(const Duration(milliseconds: 150), () {
        _executeImageProcessing(cacheKey);
      });
    }
  }

  Future<void> _executeImageProcessing(String cacheKey) async {
    if (_image == null) return;
    final requestId = ++_processingRequestId;
    _isProcessing = true;
    notifyListeners();

    try {
      final processedBytes = await _processingService.processImage(
        sourceBytes: _image!.bytes,
        mode: _invertMode,
        detailStrength: _detailStrength,
        edgeSensitivity: _edgeSensitivity,
      );

      if (requestId == _processingRequestId && _image != null) {
        final resultModel = ImageModel(
          bytes: processedBytes,
          width: _image!.width,
          height: _image!.height,
          name: '${_image!.name}_${_invertMode.name}',
          path: _image!.path,
        );

        _processedCache[cacheKey] = resultModel;
        _processedImage = resultModel;
        _isProcessing = false;
        notifyListeners();
      }
    } catch (e) {
      if (requestId == _processingRequestId) {
        _isProcessing = false;
        notifyListeners();
      }
    }
  }

  void _scheduleStencilProcessing({bool immediate = false}) {
    if (_image == null || !_stencilConfig.isEnabled) {
      _stencilDebounceTimer?.cancel();
      _processedStencilImage = null;
      return;
    }

    final cacheKey =
        '${_image!.name}_stencil_${_stencilConfig.type.name}_${(_stencilConfig.thresholdValue * 100).round()}_${_stencilConfig.posterizeLevels}_${(_stencilConfig.edgeStrength * 100).round()}';

    if (_stencilCache.containsKey(cacheKey)) {
      _processedStencilImage = _stencilCache[cacheKey];
      notifyListeners();
      return;
    }

    _stencilDebounceTimer?.cancel();
    if (immediate) {
      _runStencilProcessing(cacheKey);
    } else {
      _stencilDebounceTimer = Timer(const Duration(milliseconds: 150), () {
        _runStencilProcessing(cacheKey);
      });
    }
  }

  Future<void> _runStencilProcessing(String cacheKey) async {
    if (_image == null) return;
    final requestId = ++_stencilRequestId;
    _isProcessing = true;
    notifyListeners();

    try {
      final processedBytes = await _processingService.processStencil(
        sourceBytes: _image!.bytes,
        config: _stencilConfig,
      );

      if (requestId == _stencilRequestId && _image != null) {
        final resultModel = ImageModel(
          bytes: processedBytes,
          width: _image!.width,
          height: _image!.height,
          name: '${_image!.name}_${_stencilConfig.type.name}',
          path: _image!.path,
        );

        _stencilCache[cacheKey] = resultModel;
        _processedStencilImage = resultModel;
        _isProcessing = false;
        notifyListeners();
      }
    } catch (_) {
      if (requestId == _stencilRequestId) {
        _isProcessing = false;
        notifyListeners();
      }
    }
  }

  // --- App Lifecycle ---

  Future<void> handleAppLifecycle(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Restore system brightness when user backgrounds the app
      await _screenService.restoreBrightness();
      if (_tracingMode == TracingMode.arCamera) {
        await _cameraService.dispose();
      }
    } else if (state == AppLifecycleState.resumed && _image != null) {
      // Re-apply tracing brightness when returning to active tracing session
      await _screenService.setBrightness(_brightness);
      if (_keepAwake) {
        await _screenService.setKeepAwake(true);
      }
      if (_isLocked) {
        await _screenService.setSystemUiLocked(true);
      }
      if (_tracingMode == TracingMode.arCamera) {
        await _cameraService.initializeCamera(direction: _cameraService.currentLensDirection);
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _stencilDebounceTimer?.cancel();
    _transformationController.dispose();
    _cameraService.dispose();
    _screenService.setSystemUiLocked(false);
    _screenService.restoreBrightness();
    _screenService.setKeepAwake(false);
    super.dispose();
  }
}
