import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/tracing_viewmodel.dart';

/// Floating bottom toolbar shown in Unlocked (Editing) Mode.
/// Provides Zoom, Rotate, Fit, Reset, and the primary Lock Canvas action.
class AlignmentToolbar extends StatelessWidget {
  final TracingViewModel viewModel;
  final VoidCallback onOpenBrightness;
  final VoidCallback onOpenGrid;

  const AlignmentToolbar({
    super.key,
    required this.viewModel,
    required this.onOpenBrightness,
    required this.onOpenGrid,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderMedium, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Zoom controls
          _buildIconButton(
            icon: Icons.remove_rounded,
            tooltip: 'Zoom Out',
            onPressed: viewModel.zoomOut,
          ),
          _buildIconButton(
            icon: Icons.add_rounded,
            tooltip: 'Zoom In',
            onPressed: viewModel.zoomIn,
          ),
          _buildDivider(),

          // Rotation controls (90 degree increments)
          _buildIconButton(
            icon: Icons.rotate_90_degrees_ccw_rounded,
            tooltip: 'Rotate 90° CCW',
            onPressed: viewModel.rotateCounterClockwise,
          ),
          _buildIconButton(
            icon: Icons.rotate_90_degrees_cw_rounded,
            tooltip: 'Rotate 90° CW',
            onPressed: viewModel.rotateClockwise,
          ),
          _buildDivider(),

          // Fit and Reset
          _buildIconButton(
            icon: Icons.aspect_ratio_rounded,
            tooltip: 'Fit Image to Screen',
            onPressed: viewModel.fitToScreen,
          ),
          _buildIconButton(
            icon: Icons.restart_alt_rounded,
            tooltip: 'Reset Alignment',
            onPressed: viewModel.resetAlignment,
          ),
          _buildDivider(),

          // Brightness quick toggle
          _buildIconButton(
            icon: Icons.wb_sunny_outlined,
            tooltip: 'Display & Brightness',
            onPressed: onOpenBrightness,
          ),

          // Drawing Grid toggle / configure
          _buildIconButton(
            key: const Key('grid_toolbar_button'),
            icon: viewModel.isGridEnabled
                ? Icons.grid_on_rounded
                : Icons.grid_4x4_rounded,
            tooltip: 'Drawing Grid Overlay',
            color: viewModel.isGridEnabled
                ? AppTheme.primary
                : AppTheme.textPrimary,
            onPressed: onOpenGrid,
          ),
          const SizedBox(width: 6),

          // Primary Action: Lock Canvas
          FilledButton.icon(
            key: const Key('lock_canvas_button'),
            onPressed: viewModel.toggleLock,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 3,
              shadowColor: AppTheme.primary.withValues(alpha: 0.4),
            ),
            icon: const Icon(Icons.lock_open_rounded, size: 20),
            label: const Text(
              'Lock Canvas',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    Key? key,
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: key,
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              icon,
              size: 22,
              color: color ?? AppTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: AppTheme.borderLight,
    );
  }
}
