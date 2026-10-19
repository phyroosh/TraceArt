import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/image_model.dart';

abstract class ImagePickerService {
  Future<ImageModel?> pickImageFromGallery();
}

class DefaultImagePickerService implements ImagePickerService {
  final ImagePicker _picker;

  DefaultImagePickerService({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  @override
  Future<ImageModel?> pickImageFromGallery() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
      );

      if (file == null) {
        // User cancelled selection
        return null;
      }

      final Uint8List bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw Exception('The selected file is empty.');
      }

      // Decode image dimensions to accurately position and fit the image
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final int width = frameInfo.image.width;
      final int height = frameInfo.image.height;

      final String name = file.name.isNotEmpty
          ? file.name
          : (file.path.split('/').isNotEmpty ? file.path.split('/').last : 'image.png');

      return ImageModel(
        path: file.path,
        bytes: bytes,
        width: width,
        height: height,
        name: name,
      );
    } catch (e, stack) {
      debugPrint('Error picking image: $e\n$stack');
      rethrow;
    }
  }
}
