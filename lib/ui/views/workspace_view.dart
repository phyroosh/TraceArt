import 'package:flutter/material.dart';
import '../../services/image_processing_service.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/tracing_viewmodel.dart';
import '../widgets/alignment_toolbar.dart';
import '../widgets/brightness_sheet.dart';
import '../widgets/camera_feed_view.dart';
import '../widgets/grid_sheet.dart';
import '../widgets/locked_toolbar.dart';
import '../widgets/stencil_sheet.dart';
import '../widgets/tracing_canvas.dart';

/// The main tracing workspace where the reference image is aligned,
/// illuminated, and locked for physical paper tracing.
class WorkspaceView extends StatefulWidget {
  final TracingViewModel viewModel;

  const WorkspaceView({super.key, required this.viewModel});

  @override
  State<WorkspaceView> createState() => _WorkspaceViewState();
}

class _WorkspaceViewState extends State<WorkspaceView> {
  // When locked, controls are hidden by default to keep the screen
  // 100% unobstructed and touch non-responsive. The 3-dot menu toggles them.
  bool _showLockedOptions = false;

  void _confirmExit(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.borderMedium),
        ),
        title: const Text(
          'Exit Tracing Session?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Exiting will restore your normal screen brightness and return to the image picker.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop(true);
              widget.viewModel.clearImage();
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Exit Session'),
          ),
        ],
      ),
    );
  }

  void _openBrightness(BuildContext context) {
    BrightnessSheet.show(context, widget.viewModel);
  }

  void _openGrid(BuildContext context) {
    GridSheet.show(context, widget.viewModel);
  }

  void _openStencil(BuildContext context) {
    StencilSheet.show(context, widget.viewModel);
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;

    return LayoutBuilder(
      builder: (context, constraints) {
        vm.updateViewportSize(constraints.biggest);

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (vm.isLocked) {
              if (_showLockedOptions) {
                setState(() => _showLockedOptions = false);
              }
              // Completely block and ignore back navigation while tracing is locked
              return;
            }
            _confirmExit(context);
          },
          child: Scaffold(
            backgroundColor: Colors.black, // Pure black backdrop for contrast
            body: Stack(
              fit: StackFit.expand,
              children: [
                // 0. AR Camera Live Stream (when in AR mode)
                if (vm.isArMode)
                  CameraFeedView(viewModel: vm),

                // 1. Core Tracing Canvas (Image layer)
                // When locked, AbsorbPointer makes the canvas completely touch non-responsive
                AbsorbPointer(
                  absorbing: vm.isLocked,
                  child: TracingCanvas(viewModel: vm),
                ),

                // 2. Unlocked Mode: Top Navigation & Status Bar
                if (!vm.isLocked)
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.surface.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.borderLight),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Back / Change Image
                            IconButton(
                              icon: const Icon(Icons.arrow_back_rounded,
                                  size: 20),
                              tooltip: 'Exit to Welcome',
                              color: AppTheme.textPrimary,
                              onPressed: () => _confirmExit(context),
                            ),
                            const SizedBox(width: 4),

                            // Image Name
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 160),
                              child: Text(
                                vm.image?.name ?? 'TraceArt',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Editing Status Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'EDITING',
                                style: TextStyle(
                                  color: AppTheme.primaryLight,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Mode Switcher: Light Box vs AR Mode
                            FilledButton.tonalIcon(
                              key: const Key('mode_switch_button'),
                              onPressed: vm.toggleTracingMode,
                              style: FilledButton.styleFrom(
                                backgroundColor: vm.isArMode
                                    ? AppTheme.primary.withValues(alpha: 0.25)
                                    : AppTheme.surfaceHighlight,
                                foregroundColor: vm.isArMode
                                    ? AppTheme.primaryLight
                                    : AppTheme.textPrimary,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: Icon(
                                vm.isArMode
                                    ? Icons.camera_alt_rounded
                                    : Icons.lightbulb_rounded,
                                size: 14,
                              ),
                              label: Text(
                                vm.isArMode ? 'AR Mode' : 'Light Box',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),

                            // Quick Invert Button
                            IconButton(
                              icon: Icon(
                                vm.isInverted
                                    ? (vm.invertMode ==
                                            InvertTracingMode.fineOutline
                                        ? Icons.polyline_rounded
                                        : vm.invertMode ==
                                                InvertTracingMode.enhanced
                                            ? Icons.auto_fix_high_rounded
                                            : Icons.invert_colors_off_rounded)
                                    : Icons.invert_colors_rounded,
                                size: 20,
                              ),
                              tooltip: vm.isInverted
                                  ? '${vm.invertMode.displayName} • ${vm.lineColorTint.label} (Tap to turn off)'
                                  : 'Invert Lines',
                              color: vm.isInverted
                                  ? (vm.lineColorTint == LineColorTint.white
                                      ? AppTheme.primary
                                      : vm.lineColorTint.color)
                                  : AppTheme.textSecondary,
                              onPressed: vm.toggleInverted,
                            ),

                            // Replace Image Button
                            IconButton(
                              icon: const Icon(Icons.photo_library_outlined,
                                  size: 20),
                              tooltip: 'Choose Different Image',
                              color: AppTheme.textSecondary,
                              onPressed: vm.pickImage,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // 3. Unlocked Mode: Bottom Alignment Toolbar
                if (!vm.isLocked)
                  SafeArea(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: AlignmentToolbar(
                          viewModel: vm,
                          onOpenBrightness: () => _openBrightness(context),
                          onOpenGrid: () => _openGrid(context),
                          onOpenStencil: () => _openStencil(context),
                        ),
                      ),
                    ),
                  ),

                // 4. Locked Mode: Small 3-dot button on the top-right corner
                if (vm.isLocked)
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            key: const Key('locked_menu_button'),
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              setState(() {
                                _showLockedOptions = !_showLockedOptions;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.surface.withValues(alpha: 0.85),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _showLockedOptions
                                      ? AppTheme.lockedEmerald
                                      : AppTheme.borderMedium,
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Icon(
                                _showLockedOptions
                                    ? Icons.close_rounded
                                    : Icons.more_vert_rounded,
                                size: 20,
                                color: _showLockedOptions
                                    ? AppTheme.lockedEmeraldLight
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // 5. Locked Mode: Options Overlay (shown only when 3-dot is tapped)
                if (vm.isLocked && _showLockedOptions) ...[
                  // Top bar in locked options
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.surface.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                AppTheme.lockedEmerald.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_rounded,
                                  size: 20),
                              tooltip: 'Exit Session',
                              color: AppTheme.textPrimary,
                              onPressed: () => _confirmExit(context),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Screen Locked',
                              style: TextStyle(
                                color: AppTheme.lockedEmeraldLight,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(
                                vm.isInverted
                                    ? (vm.invertMode ==
                                            InvertTracingMode.fineOutline
                                        ? Icons.polyline_rounded
                                        : vm.invertMode ==
                                                InvertTracingMode.enhanced
                                            ? Icons.auto_fix_high_rounded
                                            : Icons.invert_colors_off_rounded)
                                    : Icons.invert_colors_rounded,
                                size: 20,
                              ),
                              tooltip: vm.isInverted
                                  ? '${vm.invertMode.displayName} • ${vm.lineColorTint.label} (Tap to turn off)'
                                  : 'Invert Lines',
                              color: vm.isInverted
                                  ? (vm.lineColorTint == LineColorTint.white
                                      ? AppTheme.primary
                                      : vm.lineColorTint.color)
                                  : AppTheme.textSecondary,
                              onPressed: vm.toggleInverted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Bottom bar with Unlock button and Brightness
                  SafeArea(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: LockedToolbar(
                          viewModel: vm,
                          onOpenBrightness: () => _openBrightness(context),
                          onOpenGrid: () => _openGrid(context),
                          onOpenStencil: () => _openStencil(context),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
