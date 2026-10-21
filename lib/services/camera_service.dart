import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// Abstract service managing device camera access for AR Tracing Mode.
abstract class CameraService {
  bool get isAvailable;
  bool get isInitialized;
  bool get isTorchOn;
  CameraLensDirection get currentLensDirection;
  CameraController? get controller;

  /// Initializes the camera with the given lens direction (defaults to back camera).
  /// Returns `true` if initialization succeeded, `false` otherwise.
  Future<bool> initializeCamera({CameraLensDirection direction = CameraLensDirection.back});

  /// Toggles the hardware camera flash / torch mode to illuminate physical drawing paper.
  Future<void> toggleTorch();

  /// Toggles between the rear and front facing cameras.
  Future<void> switchCamera();

  /// Releases the camera hardware and resources.
  Future<void> dispose();
}

/// Default implementation using Flutter's official `package:camera`.
class DefaultCameraService implements CameraService {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  bool _isTorchOn = false;
  CameraLensDirection _currentLensDirection = CameraLensDirection.back;
  bool _isInitialized = false;

  @override
  bool get isAvailable => _cameras.isNotEmpty;

  @override
  bool get isInitialized => _isInitialized && _controller != null && _controller!.value.isInitialized;

  @override
  bool get isTorchOn => _isTorchOn;

  @override
  CameraLensDirection get currentLensDirection => _currentLensDirection;

  @override
  CameraController? get controller => _controller;

  @override
  Future<bool> initializeCamera({CameraLensDirection direction = CameraLensDirection.back}) async {
    try {
      if (_cameras.isEmpty) {
        _cameras = await availableCameras();
      }

      if (_cameras.isEmpty) {
        _isInitialized = false;
        return false;
      }

      _currentLensDirection = direction;

      // Find matching camera or fallback to first available
      final camera = _cameras.firstWhere(
        (cam) => cam.lensDirection == direction,
        orElse: () => _cameras.first,
      );

      // Dispose existing controller before creating a new one
      await _controller?.dispose();
      _controller = null;
      _isTorchOn = false;

      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      _controller = controller;
      await controller.initialize();
      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('CameraService initialization error: $e');
      _isInitialized = false;
      await _controller?.dispose();
      _controller = null;
      return false;
    }
  }

  @override
  Future<void> toggleTorch() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;

    try {
      if (_isTorchOn) {
        await ctrl.setFlashMode(FlashMode.off);
        _isTorchOn = false;
      } else {
        await ctrl.setFlashMode(FlashMode.torch);
        _isTorchOn = true;
      }
    } catch (e) {
      debugPrint('Failed to toggle torch: $e');
    }
  }

  @override
  Future<void> switchCamera() async {
    if (_cameras.length < 2) return;

    final targetDirection = _currentLensDirection == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;

    await initializeCamera(direction: targetDirection);
  }

  @override
  Future<void> dispose() async {
    _isTorchOn = false;
    _isInitialized = false;
    final ctrl = _controller;
    _controller = null;
    await ctrl?.dispose();
  }
}
