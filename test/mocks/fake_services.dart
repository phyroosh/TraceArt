import 'dart:typed_data';
import 'package:traceart/models/image_model.dart';
import 'package:traceart/services/image_picker_service.dart';
import 'package:traceart/services/screen_service.dart';

// Valid 10x10 PNG bytes for testing
final Uint8List testPngBytes = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x0A, 0x00, 0x00, 0x00, 0x0A,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x8D, 0x32, 0xCF,
  0xBD, 0x00, 0x00, 0x00, 0x19, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x60, 0x18, 0x05, 0xA3,
  0x60, 0x14, 0x8C, 0x82, 0x51, 0x30, 0x28, 0x18,
  0x28, 0x00, 0x00, 0x27, 0x10, 0x02, 0x71, 0x3C,
  0x87, 0x3B, 0xC3, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
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
  int restoreCalls = 0;

  @override
  double get currentBrightness => current;

  @override
  bool get isKeepAwake => keepAwakeState;

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
}
