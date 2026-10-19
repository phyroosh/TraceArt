import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/tracing_viewmodel.dart';

/// Modal bottom sheet for fine-tuning tracing illumination,
/// toggling maximum brightness, keeping screen awake, and inverting colors.
class BrightnessSheet extends StatelessWidget {
  final TracingViewModel viewModel;

  const BrightnessSheet({super.key, required this.viewModel});

  static Future<void> show(BuildContext context, TracingViewModel viewModel) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => BrightnessSheet(viewModel: viewModel),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final brightnessPct = (viewModel.brightness * 100).round();

        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppTheme.borderLight),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.borderMedium,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title and Max Brightness Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.wb_sunny_rounded,
                        color: AppTheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Tracing Illumination',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  FilledButton.tonalIcon(
                    onPressed: viewModel.toggleMaxBrightness,
                    icon: Icon(
                      viewModel.isMaxBrightness
                          ? Icons.check_circle_rounded
                          : Icons.bolt_rounded,
                      size: 18,
                    ),
                    label: Text(
                      viewModel.isMaxBrightness ? '100% Boost' : 'Max Brightness',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: viewModel.isMaxBrightness
                          ? AppTheme.primary
                          : AppTheme.surfaceHighlight,
                      foregroundColor: viewModel.isMaxBrightness
                          ? Colors.black
                          : AppTheme.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Brightness Slider
              Row(
                children: [
                  const Icon(
                    Icons.brightness_low_rounded,
                    color: AppTheme.textTertiary,
                    size: 20,
                  ),
                  Expanded(
                    child: Slider(
                      value: viewModel.brightness,
                      min: 0.05,
                      max: 1.0,
                      divisions: 95,
                      label: '$brightnessPct%',
                      onChanged: (val) => viewModel.setBrightness(val),
                    ),
                  ),
                  const Icon(
                    Icons.brightness_high_rounded,
                    color: AppTheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 44,
                    child: Text(
                      '$brightnessPct%',
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Keep Screen Awake Tile
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceHighlight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.screen_lock_portrait_rounded,
                    color: AppTheme.primaryLight,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Keep Screen Awake',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                ),
                subtitle: const Text(
                  'Prevents display from sleeping while tracing',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                value: viewModel.keepAwake,
                activeThumbColor: AppTheme.primary,
                onChanged: (_) => viewModel.toggleKeepAwake(),
              ),

              // Invert Lines Tile (High Contrast Mode)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceHighlight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.invert_colors_rounded,
                    color: AppTheme.primaryLight,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Invert Line Colors',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                ),
                subtitle: const Text(
                  'High contrast lines for easier tracing on paper',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                value: viewModel.isInverted,
                activeThumbColor: AppTheme.primary,
                onChanged: (_) => viewModel.toggleInverted(),
              ),

              const SizedBox(height: 12),

              // Info Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceHighlight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: AppTheme.textSecondary,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your device brightness will automatically return to normal when exiting or leaving TraceArt.',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
