import 'package:flutter/material.dart';
import '../../models/stencil_config.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/tracing_viewmodel.dart';

/// Modal bottom sheet for configuring Quick Stencil & Threshold Filters:
/// - B&W Binary Stencil with threshold adjustment and Auto-Otsu detection
/// - Posterize tonal stepping for progressive layer shading
/// - Edge Sketch line art and contour extraction
class StencilSheet extends StatelessWidget {
  final TracingViewModel viewModel;

  const StencilSheet({super.key, required this.viewModel});

  static Future<void> show(BuildContext context, TracingViewModel viewModel) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StencilSheet(viewModel: viewModel),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final config = viewModel.stencilConfig;

        return Material(
          color: AppTheme.surfaceElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Container(
            decoration: BoxDecoration(
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
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
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

                    // Sheet Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.brush_rounded,
                              color: AppTheme.primary,
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Quick Stencil Filters',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        if (viewModel.isProcessing)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.primary,
                            ),
                          )
                        else if (config.isEnabled)
                          TextButton(
                            onPressed: () =>
                                viewModel.setStencilType(StencilFilterType.none),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.textSecondary,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Reset',
                                style: TextStyle(fontSize: 12)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Filter Type Selector
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<StencilFilterType>(
                        showSelectedIcon: false,
                        style: SegmentedButton.styleFrom(
                          backgroundColor: AppTheme.surfaceHighlight,
                          selectedBackgroundColor: AppTheme.primary,
                          selectedForegroundColor: Colors.black,
                          foregroundColor: AppTheme.textPrimary,
                          side: const BorderSide(color: AppTheme.borderLight),
                          visualDensity: VisualDensity.compact,
                        ),
                        segments: const [
                          ButtonSegment(
                            value: StencilFilterType.none,
                            label: Text('Original',
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w600)),
                          ),
                          ButtonSegment(
                            value: StencilFilterType.threshold,
                            label: Text('B&W Stencil',
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w600)),
                          ),
                          ButtonSegment(
                            value: StencilFilterType.posterize,
                            label: Text('Posterize',
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w600)),
                          ),
                          ButtonSegment(
                            value: StencilFilterType.edgeSketch,
                            label: Text('Edge Sketch',
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w600)),
                          ),
                        ],
                        selected: {config.type},
                        onSelectionChanged: (selected) {
                          if (selected.isNotEmpty) {
                            viewModel.setStencilType(selected.first);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Contextual Controls for Selected Stencil Type
                    if (config.type == StencilFilterType.threshold) ...[
                      _buildThresholdControls(context, config),
                    ] else if (config.type == StencilFilterType.posterize) ...[
                      _buildPosterizeControls(context, config),
                    ] else if (config.type == StencilFilterType.edgeSketch) ...[
                      _buildEdgeSketchControls(context, config),
                    ] else ...[
                      _buildNoneInfoCard(),
                    ],

                    const SizedBox(height: 16),

                    // Synergy Info Callout
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
                            Icons.auto_awesome_rounded,
                            color: AppTheme.primaryLight,
                            size: 18,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Stencil filters automatically compose with Invert Lines, Neon/Amber Color Tints, and AR Camera mode.',
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
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildThresholdControls(BuildContext context, StencilConfig config) {
    final thresholdPct = (config.thresholdValue * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Threshold Cutoff',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppTheme.textPrimary,
              ),
            ),
            Row(
              children: [
                Text(
                  '$thresholdPct%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  key: const Key('stencil_auto_otsu_button'),
                  onPressed: viewModel.applyAutoOtsuThreshold,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 14),
                  label: const Text('Auto Otsu', style: TextStyle(fontSize: 11)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.surfaceHighlight,
                    foregroundColor: AppTheme.primaryLight,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ),
        Slider(
          key: const Key('stencil_threshold_slider'),
          value: config.thresholdValue,
          min: 0.05,
          max: 0.95,
          divisions: 90,
          label: '$thresholdPct%',
          onChanged: (val) => viewModel.setStencilThreshold(val),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _buildPresetChip(
              key: const Key('stencil_preset_light'),
              label: 'Light (30%)',
              isSelected: (config.thresholdValue - 0.30).abs() < 0.03,
              onTap: () => viewModel.setStencilThreshold(0.30),
            ),
            const SizedBox(width: 8),
            _buildPresetChip(
              key: const Key('stencil_preset_balanced'),
              label: 'Balanced (50%)',
              isSelected: (config.thresholdValue - 0.50).abs() < 0.03,
              onTap: () => viewModel.setStencilThreshold(0.50),
            ),
            const SizedBox(width: 8),
            _buildPresetChip(
              key: const Key('stencil_preset_heavy'),
              label: 'Heavy Shadow (70%)',
              isSelected: (config.thresholdValue - 0.70).abs() < 0.03,
              onTap: () => viewModel.setStencilThreshold(0.70),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPosterizeControls(BuildContext context, StencilConfig config) {
    const levels = [2, 3, 4, 6, 8];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Tonal Shading Steps',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              '${config.posterizeLevels} Levels',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: levels.map((n) {
            final isSelected = config.posterizeLevels == n;
            return ChoiceChip(
              key: Key('stencil_posterize_chip_$n'),
              label: Text('$n Steps'),
              selected: isSelected,
              showCheckmark: false,
              selectedColor: AppTheme.primary,
              backgroundColor: AppTheme.surfaceHighlight,
              labelStyle: TextStyle(
                color: isSelected ? Colors.black : AppTheme.textPrimary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
              side: BorderSide(
                color: isSelected ? AppTheme.primary : AppTheme.borderLight,
              ),
              onSelected: (_) => viewModel.setStencilPosterizeLevels(n),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildEdgeSketchControls(BuildContext context, StencilConfig config) {
    final edgePct = (config.edgeStrength * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Line Weight & Sensitivity',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              '$edgePct%',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
                fontSize: 13,
              ),
            ),
          ],
        ),
        Slider(
          key: const Key('stencil_edge_slider'),
          value: config.edgeStrength,
          min: 0.1,
          max: 1.0,
          divisions: 90,
          label: '$edgePct%',
          onChanged: (val) => viewModel.setStencilEdgeStrength(val),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _buildPresetChip(
              key: const Key('stencil_sketch_delicate'),
              label: 'Delicate (30%)',
              isSelected: (config.edgeStrength - 0.30).abs() < 0.03,
              onTap: () => viewModel.setStencilEdgeStrength(0.30),
            ),
            const SizedBox(width: 8),
            _buildPresetChip(
              key: const Key('stencil_sketch_normal'),
              label: 'Normal (50%)',
              isSelected: (config.edgeStrength - 0.50).abs() < 0.03,
              onTap: () => viewModel.setStencilEdgeStrength(0.50),
            ),
            const SizedBox(width: 8),
            _buildPresetChip(
              key: const Key('stencil_sketch_bold'),
              label: 'Bold Lines (80%)',
              isSelected: (config.edgeStrength - 0.80).abs() < 0.03,
              onTap: () => viewModel.setStencilEdgeStrength(0.80),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPresetChip({
    required Key key,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: isSelected
            ? AppTheme.primary.withValues(alpha: 0.25)
            : AppTheme.surfaceHighlight,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          key: key,
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppTheme.primary : AppTheme.borderLight,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppTheme.primaryLight : AppTheme.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoneInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHighlight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.image_outlined,
            color: AppTheme.textSecondary,
            size: 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Original Reference View',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Choose B&W Stencil, Posterize, or Edge Sketch above to convert complex photos into easy tracing stencils.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
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
