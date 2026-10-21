import 'package:flutter/material.dart';
import '../../services/image_processing_service.dart';
import '../../viewmodels/tracing_viewmodel.dart';

/// The core canvas component rendering the reference image.
/// When [viewModel.isLocked] is true:
/// - Pointer events are completely ignored via [IgnorePointer].
/// - InteractiveViewer pan & scale are explicitly disabled.
/// - The transformation matrix remains 100% frozen and stationary.
class TracingCanvas extends StatelessWidget {
  final TracingViewModel viewModel;

  const TracingCanvas({super.key, required this.viewModel});

  // Color inversion matrix for high-contrast line tracing
  static const List<double> _invertMatrix = <double>[
    -1.0, 0.0, 0.0, 0.0, 255.0,
    0.0, -1.0, 0.0, 0.0, 255.0,
    0.0, 0.0, -1.0, 0.0, 255.0,
    0.0, 0.0, 0.0, 1.0, 0.0,
  ];

  // Inverted grayscale luminance matrix (used when a color tint is selected in Original mode)
  static const List<double> _invertGrayscaleMatrix = <double>[
    -0.299, -0.587, -0.114, 0.0, 255.0,
    -0.299, -0.587, -0.114, 0.0, 255.0,
    -0.299, -0.587, -0.114, 0.0, 255.0,
    0.0, 0.0, 0.0, 1.0, 0.0,
  ];

  @override
  Widget build(BuildContext context) {
    final image = viewModel.image;
    if (image == null) {
      return const SizedBox.shrink();
    }

    final effectiveSize = viewModel.effectiveImageSize;
    final displayImage = viewModel.activeDisplayImage ?? image;

    Widget imageContent = Image.memory(
      displayImage.bytes,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      filterQuality: FilterQuality.high,
    );

    // Apply GPU inversion matrix for Original Invert mode,
    // or as a smooth fallback while Enhanced/Outline is computing
    final isOriginalInvert = viewModel.invertMode == InvertTracingMode.original;
    final isFallback = viewModel.activeDisplayImage == null;
    final hasTint = viewModel.lineColorTint != LineColorTint.white;

    if (viewModel.isInverted) {
      if (isOriginalInvert || isFallback) {
        final matrix = hasTint ? _invertGrayscaleMatrix : _invertMatrix;
        imageContent = ColorFiltered(
          colorFilter: ColorFilter.matrix(matrix),
          child: imageContent,
        );
      }

      if (hasTint) {
        imageContent = ColorFiltered(
          colorFilter: ColorFilter.mode(
            viewModel.lineColorTint.color,
            BlendMode.modulate,
          ),
          child: imageContent,
        );
      }
    }

    final childWidget = SizedBox(
      width: effectiveSize.width,
      height: effectiveSize.height,
      child: RotatedBox(
        quarterTurns: viewModel.quarterTurns,
        child: imageContent,
      ),
    );

    return IgnorePointer(
      ignoring: viewModel.isLocked,
      child: InteractiveViewer(
        transformationController: viewModel.transformationController,
        panEnabled: !viewModel.isLocked,
        scaleEnabled: !viewModel.isLocked,
        minScale: 0.05,
        maxScale: 35.0,
        boundaryMargin: const EdgeInsets.all(double.infinity),
        child: childWidget,
      ),
    );
  }
}
