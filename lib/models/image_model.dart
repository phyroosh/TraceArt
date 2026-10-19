import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Represents a loaded reference image in memory.
/// Stores byte buffer, file path (if available), dimensions, and metadata.
class ImageModel {
  final String? path;
  final Uint8List bytes;
  final int width;
  final int height;
  final String name;

  const ImageModel({
    this.path,
    required this.bytes,
    required this.width,
    required this.height,
    required this.name,
  });

  /// The aspect ratio of the image (width / height).
  double get aspectRatio =>
      (width > 0 && height > 0) ? width / height : 1.0;

  /// The intrinsic size of the image.
  Size get size => Size(width.toDouble(), height.toDouble());

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageModel &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          name == other.name &&
          width == other.width &&
          height == other.height &&
          bytes.length == other.bytes.length;

  @override
  int get hashCode => Object.hash(path, name, width, height, bytes.length);

  @override
  String toString() =>
      'ImageModel(name: $name, dimensions: ${width}x$height, bytes: ${bytes.length})';
}
