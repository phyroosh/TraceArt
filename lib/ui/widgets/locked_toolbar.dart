import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/tracing_viewmodel.dart';

/// Minimal, high-contrast toolbar displayed when the image is LOCKED.
/// Positioned at the screen edge to remain accessible even when physical paper
/// is placed on the screen.
class LockedToolbar extends StatelessWidget {
  final TracingViewModel viewModel;
  final VoidCallback onOpenBrightness;
  final VoidCallback onOpenGrid;
  final VoidCallback onOpenStencil;
  final VoidCallback onOpenRuler;

  const LockedToolbar({
    super.key,
    required this.viewModel,
    required this.onOpenBrightness,
    required this.onOpenGrid,
    required this.onOpenStencil,
    required this.onOpenRuler,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF101217).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.lockedEmerald.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Locked Status Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.lockedEmerald.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.lockedEmerald.withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_rounded,
                  color: AppTheme.lockedEmeraldLight,
                  size: 16,
                ),
                SizedBox(width: 6),
                Text(
                  'FROZEN',
                  style: TextStyle(
                    color: AppTheme.lockedEmeraldLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Quick Brightness Button
          Tooltip(
            message: 'Screen Brightness',
            child: IconButton(
              icon: Icon(
                viewModel.isMaxBrightness
                    ? Icons.brightness_high_rounded
                    : Icons.brightness_6_rounded,
                color: AppTheme.primary,
                size: 22,
              ),
              onPressed: onOpenBrightness,
            ),
          ),
          const SizedBox(width: 4),

          // Quick Grid Button
          Tooltip(
            message: 'Drawing Grid Overlay',
            child: IconButton(
              key: const Key('locked_grid_button'),
              icon: Icon(
                viewModel.isGridEnabled
                    ? Icons.grid_on_rounded
                    : Icons.grid_4x4_rounded,
                color: viewModel.isGridEnabled
                    ? AppTheme.primary
                    : AppTheme.textSecondary,
                size: 22,
              ),
              onPressed: onOpenGrid,
            ),
          ),
          const SizedBox(width: 4),

          // Quick Stencil Button
          Tooltip(
            message: 'Quick Stencil Filters',
            child: IconButton(
              key: const Key('locked_stencil_button'),
              icon: Icon(
                viewModel.isStencilActive
                    ? Icons.auto_fix_high_rounded
                    : Icons.auto_fix_normal_rounded,
                color: viewModel.isStencilActive
                    ? AppTheme.primary
                    : AppTheme.textSecondary,
                size: 22,
              ),
              onPressed: onOpenStencil,
            ),
          ),
          const SizedBox(width: 4),

          // Quick Ruler Button
          Tooltip(
            message: 'Calibrated Rulers & True Scale',
            child: IconButton(
              key: const Key('locked_ruler_button'),
              icon: Icon(
                viewModel.isRulerEnabled
                    ? Icons.straighten_rounded
                    : Icons.square_foot_rounded,
                color: viewModel.isRulerEnabled
                    ? AppTheme.primary
                    : AppTheme.textSecondary,
                size: 22,
              ),
              onPressed: onOpenRuler,
            ),
          ),
          const SizedBox(width: 4),

          // Quick Torch Button (AR Mode)
          if (viewModel.isArMode) ...[
            Tooltip(
              message: viewModel.isTorchOn ? 'Torch On' : 'Torch Off',
              child: IconButton(
                key: const Key('locked_torch_button'),
                icon: Icon(
                  viewModel.isTorchOn
                      ? Icons.flashlight_on_rounded
                      : Icons.flashlight_off_rounded,
                  color: viewModel.isTorchOn
                      ? AppTheme.primary
                      : AppTheme.textSecondary,
                  size: 22,
                ),
                onPressed: viewModel.toggleTorch,
              ),
            ),
            const SizedBox(width: 4),
          ],
          const SizedBox(width: 2),

          // Primary Action: UNLOCK BUTTON
          FilledButton.icon(
            key: const Key('unlock_canvas_button'),
            onPressed: viewModel.toggleLock,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.lockedEmerald,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              shadowColor: AppTheme.lockedEmerald.withValues(alpha: 0.5),
            ),
            icon: const Icon(Icons.lock_open_rounded, size: 20),
            label: const Text(
              'Unlock to Edit',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
