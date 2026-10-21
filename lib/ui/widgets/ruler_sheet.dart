import 'package:flutter/material.dart';
import '../../models/ruler_config.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/tracing_viewmodel.dart';
import 'screen_calibration_dialog.dart';

/// Modal bottom sheet for configuring physical rulers, 1:1 scale presets,
/// measurement units, and screen calibration.
class RulerSheet extends StatelessWidget {
  final TracingViewModel viewModel;

  const RulerSheet({super.key, required this.viewModel});

  static Future<void> show(BuildContext context, TracingViewModel viewModel) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => RulerSheet(viewModel: viewModel),
    );
  }

  void _showCustomDimensionDialog(BuildContext context) {
    final unit = viewModel.rulerConfig.unit;
    final isCm = unit == RulerUnit.cm;
    final controller = TextEditingController(
      text: isCm
          ? viewModel.physicalArtworkWidthCm.toStringAsFixed(1)
          : viewModel.physicalArtworkWidthIn.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.borderMedium),
        ),
        title: Text(
          'Target Physical Width (${unit.abbreviation})',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the desired physical width for your drawing paper or canvas. The height will adjust proportionally.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('custom_dimension_input'),
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                suffixText: unit.abbreviation,
                hintText: isCm ? 'e.g. 15.0' : 'e.g. 6.0',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('custom_dimension_apply_button'),
            onPressed: () {
              final val = double.tryParse(controller.text.trim());
              if (val != null && val > 0) {
                if (isCm) {
                  viewModel.scaleToPhysicalSize(widthCm: val);
                } else {
                  viewModel.scaleToPhysicalSize(widthIn: val);
                }
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Apply Scale'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final config = viewModel.rulerConfig;
        final hasImage = viewModel.hasImage;

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

                    // Sheet Header & Master Toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.straighten_rounded,
                                color: AppTheme.primary,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Calibrated Rulers & Scale',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          key: const Key('ruler_master_switch'),
                          value: config.isEnabled,
                          activeThumbColor: Colors.black,
                          activeTrackColor: AppTheme.primary,
                          onChanged: (_) => viewModel.toggleRuler(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Live Physical Dimensions Card
                    if (hasImage) ...[
                      _buildLiveDimensionCard(context),
                      const SizedBox(height: 16),
                    ],

                    // Section: Measurement Unit & Coordinate Origin
                    Row(
                      children: [
                        // Unit Switcher
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Unit',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: double.infinity,
                                child: SegmentedButton<RulerUnit>(
                                  showSelectedIcon: false,
                                  style: SegmentedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: AppTheme.surfaceHighlight,
                                    selectedBackgroundColor: AppTheme.primary,
                                    selectedForegroundColor: Colors.black,
                                    foregroundColor: AppTheme.textPrimary,
                                  ),
                                  segments: const [
                                    ButtonSegment(
                                      value: RulerUnit.cm,
                                      label: Text('cm / mm', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                    ),
                                    ButtonSegment(
                                      value: RulerUnit.inch,
                                      label: Text('Inches (")', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                    ),
                                  ],
                                  selected: {config.unit},
                                  onSelectionChanged: (set) {
                                    if (set.isNotEmpty) viewModel.setRulerUnit(set.first);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Origin Switcher
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Zero Origin',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: double.infinity,
                                child: SegmentedButton<RulerOrigin>(
                                  showSelectedIcon: false,
                                  style: SegmentedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: AppTheme.surfaceHighlight,
                                    selectedBackgroundColor: AppTheme.primary,
                                    selectedForegroundColor: Colors.black,
                                    foregroundColor: AppTheme.textPrimary,
                                  ),
                                  segments: const [
                                    ButtonSegment(
                                      value: RulerOrigin.artwork,
                                      label: Text('Artwork', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                    ),
                                    ButtonSegment(
                                      value: RulerOrigin.screen,
                                      label: Text('Screen', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                    ),
                                  ],
                                  selected: {config.origin},
                                  onSelectionChanged: (set) {
                                    if (set.isNotEmpty) viewModel.setRulerOrigin(set.first);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Section: 1:1 True Physical Scale (Standard Paper Presets)
                    if (hasImage) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '1:1 True Physical Scale Presets',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          TextButton.icon(
                            key: const Key('custom_size_button'),
                            onPressed: () => _showCustomDimensionDialog(context),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.primaryLight,
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.tune_rounded, size: 14),
                            label: const Text('Custom Size', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: StandardPaperSize.values.map((size) {
                          return ActionChip(
                            key: Key('paper_size_${size.name}'),
                            label: Text(size.label),
                            avatar: const Icon(Icons.aspect_ratio_rounded, size: 14, color: AppTheme.primary),
                            backgroundColor: AppTheme.surfaceHighlight,
                            labelStyle: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                            side: const BorderSide(color: AppTheme.borderLight),
                            onPressed: () => viewModel.scaleToStandardPaperSize(size),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Section: Screen Calibration Tile
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceHighlight.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.tune_rounded, color: AppTheme.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Screen Calibration',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Density: ${(RulerConfig.baselineDpi * config.calibrationFactor).round()} dpi (${config.calibrationFactor.toStringAsFixed(3)}x)',
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.tonal(
                            key: const Key('open_calibration_button'),
                            onPressed: () => ScreenCalibrationDialog.show(context, viewModel),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.surfaceElevated,
                              foregroundColor: AppTheme.primaryLight,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            child: const Text('Calibrate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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

  Widget _buildLiveDimensionCard(BuildContext context) {
    final widthCm = viewModel.physicalArtworkWidthCm.toStringAsFixed(1);
    final heightCm = viewModel.physicalArtworkHeightCm.toStringAsFixed(1);
    final widthIn = viewModel.physicalArtworkWidthIn.toStringAsFixed(2);
    final heightIn = viewModel.physicalArtworkHeightIn.toStringAsFixed(2);
    final ratio = viewModel.artworkAspectRatio.toStringAsFixed(2);
    final scalePct = (viewModel.currentScaleFactor * 100).round();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHighlight.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Current Physical Size on Screen',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: AppTheme.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Scale: $scalePct%',
                  style: const TextStyle(
                    color: AppTheme.primaryLight,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildDimensionStat('Metric Width × Height', '$widthCm × $heightCm cm'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDimensionStat('Imperial Width × Height', '$widthIn" × $heightIn"'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.aspect_ratio_rounded, size: 14, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text(
                'Native Aspect Ratio: $ratio (${viewModel.effectiveImageSize.width.round()} × ${viewModel.effectiveImageSize.height.round()} px)',
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDimensionStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppTheme.textTertiary, fontSize: 10),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
