import 'dart:typed_data';
import 'package:traceart/models/image_model.dart';
import 'package:traceart/models/stencil_config.dart';
import 'package:traceart/services/image_picker_service.dart';
import 'package:traceart/services/image_processing_service.dart';
import 'package:traceart/services/screen_service.dart';

// Valid 10x10 PNG bytes for testing
final Uint8List testPngBytes = Uint8List.fromList(<int>[
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 10, 0, 0, 0, 10, 8, 2, 0, 0, 0, 2, 80, 88, 234, 0, 0, 0, 60, 73, 68, 65, 84, 120, 156, 99, 249, 255, 255, 63, 3, 110, 192, 130, 71, 14, 33, 205, 200, 200, 136, 213, 24, 168, 244, 255, 255, 255, 177, 170, 64, 24, 142, 85, 5, 138, 221, 152, 42, 208, 157, 134, 166, 2, 139, 203, 145, 85, 96, 247, 24, 92, 5, 78, 127, 67, 116, 3, 0, 135, 15, 45, 17, 100, 159, 251, 103, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130
]);

ImageModel createSampleImage({
  String name = 'anime_character.png',
  int width = 800,
  int height = 1200,
}) {
  return ImageModel(
    name: name,
    path: '/mock/path/$name',
    bytes: testPngBytes,
    width: width,
    height: height,
  );
}

class FakeImagePickerService implements ImagePickerService {
  ImageModel? nextResult;
  bool shouldThrow = false;
  int pickCallCount = 0;

  @override
  Future<ImageModel?> pickImageFromGallery() async {
    pickCallCount++;
    if (shouldThrow) {
      throw Exception('Photo library access failed');
    }
    return nextResult;
  }
}

class FakeScreenService implements ScreenService {
  double current = 0.5;
  double? initial = 0.5;
  bool keepAwakeState = false;
  bool systemUiLockedState = false;
  int restoreCalls = 0;
  int setSystemUiLockedCalls = 0;

  @override
  double get currentBrightness => current;

  @override
  bool get isKeepAwake => keepAwakeState;

  @override
  bool get isSystemUiLocked => systemUiLockedState;

  @override
  bool get isBrightnessSupported => true;

  @override
  Future<void> init() async {
    initial = current;
  }

  @override
  Future<double> getBrightness() async => current;

  @override
  Future<void> setBrightness(double value) async {
    current = value.clamp(0.05, 1.0);
  }

  @override
  Future<void> setMaxBrightness() async {
    current = 1.0;
  }

  @override
  Future<void> restoreBrightness() async {
    restoreCalls++;
    if (initial != null) current = initial!;
  }

  @override
  Future<void> setKeepAwake(bool enable) async {
    keepAwakeState = enable;
  }

  @override
  Future<void> setSystemUiLocked(bool locked) async {
    setSystemUiLockedCalls++;
    systemUiLockedState = locked;
  }
}

class FakeImageProcessingService implements ImageProcessingService {
  int processCallCount = 0;
  InvertTracingMode? lastMode;
  double? lastStrength;
  double? lastSensitivity;
  Uint8List? customResultBytes;

  int stencilCallCount = 0;
  StencilConfig? lastStencilConfig;
  double otsuReturnValue = 0.5;
  int otsuCallCount = 0;

  set nextOtsuThreshold(double val) => otsuReturnValue = val;

  @override
  Future<Uint8List> processImage({
    required Uint8List sourceBytes,
    required InvertTracingMode mode,
    required double detailStrength,
    required double edgeSensitivity,
  }) async {
    processCallCount++;
    lastMode = mode;
    lastStrength = detailStrength;
    lastSensitivity = edgeSensitivity;
    if (mode == InvertTracingMode.original) return sourceBytes;
    return customResultBytes ?? sourceBytes;
  }

  @override
  Future<Uint8List> processStencil({
    required Uint8List sourceBytes,
    required StencilConfig config,
  }) async {
    stencilCallCount++;
    lastStencilConfig = config;
    if (config.type == StencilFilterType.none) return sourceBytes;
    return customResultBytes ?? sourceBytes;
  }

  @override
  double computeOtsuThreshold(Uint8List sourceBytes) {
    otsuCallCount++;
    return otsuReturnValue;
  }
}
