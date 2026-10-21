import 'package:camera/camera.dart';
import 'package:traceart/services/camera_service.dart';

/// Test double implementing [CameraService] for headless unit and widget testing.
class FakeCameraService implements CameraService {
  bool shouldSucceed = true;
  bool available = true;
  bool _isInitialized = false;
  bool _isTorchOn = false;
  CameraLensDirection _currentLensDirection = CameraLensDirection.back;

  int initializeCalls = 0;
  int toggleTorchCalls = 0;
  int switchCameraCalls = 0;
  int disposeCalls = 0;

  @override
  bool get isAvailable => available;

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get isTorchOn => _isTorchOn;

  @override
  CameraLensDirection get currentLensDirection => _currentLensDirection;

  @override
  CameraController? get controller => null;

  @override
  Future<bool> initializeCamera({CameraLensDirection direction = CameraLensDirection.back}) async {
    initializeCalls++;
    if (!shouldSucceed || !available) {
      _isInitialized = false;
      return false;
    }
    _currentLensDirection = direction;
    _isInitialized = true;
    return true;
  }

  @override
  Future<void> toggleTorch() async {
    toggleTorchCalls++;
    if (_isInitialized) {
      _isTorchOn = !_isTorchOn;
    }
  }

  @override
  Future<void> switchCamera() async {
    switchCameraCalls++;
    _currentLensDirection = _currentLensDirection == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    _isInitialized = false;
    _isTorchOn = false;
  }
}
