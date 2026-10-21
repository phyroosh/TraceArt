import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/image_model.dart';
import '../services/image_picker_service.dart';
import '../services/image_processing_service.dart';
import '../services/screen_service.dart';

/// ViewModel managing TraceArt state:
/// - Selected image persistence
/// - Spatial transformation (pan, zoom, rotate, fit, reset)
/// - Lock / Unlock enforcement
/// - Brightness & Screen Keep-Awake controls
/// - Inverted contrast mode for line tracing
class TracingViewModel extends ChangeNotifier {
  final ImagePickerService _pickerService;
  final ScreenService _screenService;
  final ImageProcessingService _processingService;

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

  // Fine Detail Mode state
  InvertTracingMode _invertMode = InvertTracingMode.original;
  double _detailStrength = 0.5;
  double _edgeSensitivity = 0.5;
  bool _isProcessing = false;
  final Map<String, ImageModel> _processedCache = {};
  Timer? _debounceTimer;
  int _processingRequestId = 0;

  TracingViewModel({
    ImagePickerService? pickerService,
    ScreenService? screenService,
    ImageProcessingService? processingService,
  })  : _pickerService = pickerService ?? DefaultImagePickerService(),
        _screenService = screenService ?? DefaultScreenService(),
        _processingService = processingService ?? DefaultImageProcessingService();

  // --- Getters ---

  ImageModel? get image => _image;
  ImageModel? get processedImage => _processedImage;

  /// The active image to render on the canvas.
  /// When inversion is enabled with Enhanced or Fine Outline mode, returns the
  /// processed variant (or falls back to original if processing is underway).
  ImageModel? get activeDisplayImage {
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
  double get detailStrength => _detailStrength;
  double get edgeSensitivity => _edgeSensitivity;
  bool get isProcessing => _isProcessing;

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
        _processedCache.clear();
        _processedImage = null;
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
    _processedCache.clear();
    _processedImage = null;
    _image = model;
    _quarterTurns = 0;
    _isLocked = false;
    _hasCalculatedInitialFit = false;
    _errorMessage = null;
    if (_viewportSize != null) {
      fitToScreen();
    }
    if (_isInverted && _invertMode != InvertTracingMode.original) {
      _scheduleImageProcessing(immediate: true);
    }
    notifyListeners();
  }

  Future<void> clearImage() async {
    _debounceTimer?.cancel();
    _processedCache.clear();
    _processedImage = null;
    _image = null;
    _isLocked = false;
    _quarterTurns = 0;
    _hasCalculatedInitialFit = false;
    _transformationController.value = Matrix4.identity();
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

  // --- App Lifecycle ---

  Future<void> handleAppLifecycle(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Restore system brightness when user backgrounds the app
      await _screenService.restoreBrightness();
    } else if (state == AppLifecycleState.resumed && _image != null) {
      // Re-apply tracing brightness when returning to active tracing session
      await _screenService.setBrightness(_brightness);
      if (_keepAwake) {
        await _screenService.setKeepAwake(true);
      }
      if (_isLocked) {
        await _screenService.setSystemUiLocked(true);
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _transformationController.dispose();
    _screenService.setSystemUiLocked(false);
    _screenService.restoreBrightness();
    _screenService.setKeepAwake(false);
    super.dispose();
  }
}
