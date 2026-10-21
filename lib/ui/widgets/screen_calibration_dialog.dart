import 'package:flutter/material.dart';
import '../../models/ruler_config.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/tracing_viewmodel.dart';

/// Modal dialog allowing the artist to calibrate their device screen to true physical dimensions
/// by placing a standard physical Credit Card / ID card (ISO/IEC 7810 ID-1, 85.60 x 53.98 mm)
/// or desk ruler directly against the glass.
class ScreenCalibrationDialog extends StatefulWidget {
  final TracingViewModel viewModel;

  const ScreenCalibrationDialog({super.key, required this.viewModel});

  static Future<void> show(BuildContext context, TracingViewModel viewModel) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => ScreenCalibrationDialog(viewModel: viewModel),
    );
  }

  @override
  State<ScreenCalibrationDialog> createState() => _ScreenCalibrationDialogState();
}

class _ScreenCalibrationDialogState extends State<ScreenCalibrationDialog> {
  late double _currentFactor;
  int _calibrationMode = 0; // 0 = Credit Card, 1 = 5cm Ruler

  @override
  void initState() {
    super.initState();
    _currentFactor = widget.viewModel.rulerConfig.calibrationFactor;
  }

  void _applyFactor(double factor) {
    final clamped = factor.clamp(0.60, 1.60);
    setState(() => _currentFactor = clamped);
    widget.viewModel.setCalibrationFactor(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveDpi = (RulerConfig.baselineDpi * _currentFactor).round();
    final percentDiff = ((_currentFactor - 1.0) * 100).round();
    final diffSign = percentDiff > 0 ? '+$percentDiff%' : '$percentDiff%';

    return Dialog(
      backgroundColor: AppTheme.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppTheme.borderMedium, width: 1.2),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.straighten_rounded,
                          color: AppTheme.primary,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Screen Size Calibration',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              Text(
                'Place a real standard card or ruler on your screen and adjust the slider until the outline matches exactly.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),

              // Calibration Mode Switcher
              SegmentedButton<int>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  backgroundColor: AppTheme.surfaceHighlight,
                  selectedBackgroundColor: AppTheme.primary,
                  selectedForegroundColor: Colors.black,
                  foregroundColor: AppTheme.textPrimary,
                  visualDensity: VisualDensity.compact,
                ),
                segments: const [
                  ButtonSegment(
                    value: 0,
                    label: Text('Credit / ID Card', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    icon: Icon(Icons.credit_card_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: 1,
                    label: Text('5 cm Ruler', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    icon: Icon(Icons.square_foot_rounded, size: 16),
                  ),
                ],
                selected: {_calibrationMode},
                onSelectionChanged: (set) {
                  if (set.isNotEmpty) {
                    setState(() => _calibrationMode = set.first);
                  }
                },
              ),
              const SizedBox(height: 12),

              // Physical Target Visual Area
              Center(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 110),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: Center(
                    child: _calibrationMode == 0
                        ? _buildCreditCardOutline()
                        : _buildRulerBarOutline(),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Calibration Factor Slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Size Multiplier',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    '${_currentFactor.toStringAsFixed(3)}x ($effectiveDpi dpi)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
              Slider(
                key: const Key('calibration_slider'),
                value: _currentFactor,
                min: 0.70,
                max: 1.40,
                divisions: 140,
                onChanged: _applyFactor,
              ),

              // Nudge Buttons & Reset
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const Key('calibration_reset_button'),
                    onPressed: () => _applyFactor(1.0),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.restart_alt_rounded, size: 14),
                    label: const Text('Default', style: TextStyle(fontSize: 11)),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton.filledTonal(
                        key: const Key('calibration_nudge_down'),
                        icon: const Icon(Icons.remove_rounded, size: 16),
                        onPressed: () => _applyFactor(_currentFactor - 0.005),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Decrease by 0.5%',
                      ),
                      const SizedBox(width: 6),
                      IconButton.filledTonal(
                        key: const Key('calibration_nudge_up'),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        onPressed: () => _applyFactor(_currentFactor + 0.005),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Increase by 0.5%',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Calibration Status Callout
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceHighlight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Row(
                  children: [
                    Icon(
                      _currentFactor == 1.0
                          ? Icons.info_outline_rounded
                          : Icons.check_circle_rounded,
                      color: _currentFactor == 1.0
                          ? AppTheme.textSecondary
                          : AppTheme.lockedEmeraldLight,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _currentFactor == 1.0
                            ? 'Using baseline standard display density (160 dpi).'
                            : 'Screen calibrated: $diffSign adjustment applied for physical precision.',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Save Button
              FilledButton(
                key: const Key('calibration_done_button'),
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Done & Save Calibration',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreditCardOutline() {
    // Standard ISO/IEC 7810 ID-1: 85.60 mm x 53.98 mm (8.56 cm x 5.398 cm)
    final pxPerCm = RulerConfig.baselineDpcm * _currentFactor;
    final cardWidth = 8.56 * pxPerCm;
    final cardHeight = 5.398 * pxPerCm;

    return Container(
      width: cardWidth,
      height: cardHeight,
      decoration: BoxDecoration(
        color: AppTheme.surfaceHighlight.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(cardHeight * 0.06), // ~3.18mm standard radius
        border: Border.all(
          color: AppTheme.primary,
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.2),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        children: [
          // EMV Chip graphic
          Positioned(
            left: cardWidth * 0.12,
            top: cardHeight * 0.35,
            width: cardWidth * 0.16,
            height: cardHeight * 0.28,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFD4AF37), width: 1),
              ),
              child: const Icon(Icons.memory_rounded, size: 14, color: Colors.white70),
            ),
          ),
          // Contactless symbol
          Positioned(
            right: cardWidth * 0.10,
            top: cardHeight * 0.12,
            child: const Icon(Icons.contactless_rounded, size: 16, color: Colors.white38),
          ),
          // Dimensions label
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'STANDARD CARD\n85.60 × 53.98 mm',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.primaryLight,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRulerBarOutline() {
    // 5.0 cm test bar
    final pxPerCm = RulerConfig.baselineDpcm * _currentFactor;
    final barWidth = 5.0 * pxPerCm;
    const barHeight = 44.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: barWidth,
          height: barHeight,
          decoration: BoxDecoration(
            color: AppTheme.surfaceHighlight.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.primary, width: 2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(width: 1.5, height: 10, color: AppTheme.primary),
                  Text('$i cm', style: const TextStyle(fontSize: 8, color: AppTheme.primary, fontWeight: FontWeight.w700)),
                  Container(width: 1.5, height: 10, color: AppTheme.primary),
                ],
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Exact 5.0 cm Test Bar (Match with real ruler)',
          style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}
