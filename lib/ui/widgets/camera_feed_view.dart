import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/tracing_viewmodel.dart';

/// Full-screen live camera view serving as the backdrop for AR Tracing Mode.
class CameraFeedView extends StatelessWidget {
  final TracingViewModel viewModel;

  const CameraFeedView({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    if (viewModel.isCameraInitializing) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppTheme.primary,
              ),
              SizedBox(height: 16),
              Text(
                'Starting Camera Feed...',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (viewModel.cameraErrorMessage != null) {
      return Container(
        color: const Color(0xFF0D0F12),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.videocam_off_rounded,
                  color: Colors.redAccent,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                viewModel.cameraErrorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.tonal(
                    onPressed: () => viewModel.setTracingMode(TracingMode.lightBox),
                    child: const Text('Light Box Mode'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () => viewModel.setTracingMode(TracingMode.arCamera),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final controller = viewModel.cameraService.controller;

    // Real device with active controller
    if (controller != null && controller.value.isInitialized) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final previewSize = controller.value.previewSize;

          if (previewSize == null) {
            return CameraPreview(controller);
          }

          // Camera sensor width and height are typically in landscape
          final sensorWidth = previewSize.height;
          final sensorHeight = previewSize.width;

          return ClipRect(
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: sensorWidth,
                  height: sensorHeight,
                  child: CameraPreview(controller),
                ),
              ),
            ),
          );
        },
      );
    }

    // Fallback simulated feed for tests or mock services
    return Container(
      key: const Key('simulated_camera_feed'),
      color: const Color(0xFF161920),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Subtle visual texture representing paper surface
          CustomPaint(
            painter: _SimulatedSurfacePainter(),
          ),
          const Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.videocam_rounded,
                  color: AppTheme.textTertiary,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'AR Surface View Active',
                  style: TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SimulatedSurfacePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1.0;

    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
