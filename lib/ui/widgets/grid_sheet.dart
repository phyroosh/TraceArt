import 'package:flutter/material.dart';
import '../../models/grid_config.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/tracing_viewmodel.dart';

/// Modal bottom sheet for customizing the Proportional Drawing Grid Overlay:
/// divisions, opacity, line color, center crosshairs, diagonals, and cell labels.
class GridSheet extends StatelessWidget {
  final TracingViewModel viewModel;

  const GridSheet({super.key, required this.viewModel});

  static Future<void> show(BuildContext context, TracingViewModel viewModel) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => GridSheet(viewModel: viewModel),
    );
  }

  static const List<int> _divisionPresets = [3, 4, 5, 6, 8, 10, 12];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final config = viewModel.gridConfig;
        final opacityPct = (config.opacity * 100).round();

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
                              Icons.grid_4x4_rounded,
                              color: AppTheme.primary,
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Drawing Grid Overlay',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        FilledButton.tonalIcon(
                          key: const Key('grid_toggle_button'),
                          onPressed: viewModel.toggleGrid,
                          icon: Icon(
                            viewModel.isGridEnabled
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                            size: 18,
                          ),
                          label: Text(
                            viewModel.isGridEnabled ? 'Active' : 'Off',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: viewModel.isGridEnabled
                                ? AppTheme.primary
                                : AppTheme.surfaceHighlight,
                            foregroundColor: viewModel.isGridEnabled
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
                    const SizedBox(height: 16),

                    // Master Grid Enable Toggle
                    SwitchListTile(
                      key: const Key('grid_enable_tile'),
                      contentPadding: EdgeInsets.zero,
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceHighlight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.grid_on_rounded,
                          color: viewModel.isGridEnabled
                              ? AppTheme.primary
                              : AppTheme.textTertiary,
                          size: 20,
                        ),
                      ),
                      title: const Text(
                        'Show Proportional Grid',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      subtitle: const Text(
                        'Scale proportions square-by-square directly on physical paper',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      value: viewModel.isGridEnabled,
                      activeThumbColor: AppTheme.primary,
                      onChanged: (_) => viewModel.toggleGrid(),
                    ),

                    if (viewModel.isGridEnabled) ...[
                      const SizedBox(height: 12),
                      const Divider(color: AppTheme.borderLight, height: 1),
                      const SizedBox(height: 16),

                      // Section 1: Grid Divisions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'GRID DIVISIONS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${config.divisions} × ${config.divisions}'
                              '${config.divisions == 3 ? " (Thirds)" : ""}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Preset Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _divisionPresets.map((count) {
                            final isSelected = config.divisions == count;
                            final label = count == 3 ? '3×3 Thirds' : '$count×$count';

                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                key: Key('grid_division_chip_$count'),
                                label: Text(label),
                                selected: isSelected,
                                selectedColor: AppTheme.primary,
                                backgroundColor: AppTheme.surfaceHighlight,
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? Colors.black
                                      : AppTheme.textPrimary,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  fontSize: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(
                                    color: isSelected
                                        ? AppTheme.primary
                                        : AppTheme.borderMedium,
                                  ),
                                ),
                                showCheckmark: false,
                                onSelected: (_) =>
                                    viewModel.setGridDivisions(count),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Continuous Divisions Slider
                      Row(
                        children: [
                          const Text(
                            '2×2',
                            style: TextStyle(
                              color: AppTheme.textTertiary,
                              fontSize: 12,
                            ),
                          ),
                          Expanded(
                            child: Slider(
                              key: const Key('grid_divisions_slider'),
                              value: config.divisions.toDouble(),
                              min: 2,
                              max: 16,
                              divisions: 14,
                              label: '${config.divisions}×${config.divisions}',
                              onChanged: (val) =>
                                  viewModel.setGridDivisions(val.round()),
                            ),
                          ),
                          const Text(
                            '16×16',
                            style: TextStyle(
                              color: AppTheme.textTertiary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Section 2: Opacity Slider
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'LINE OPACITY',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          Text(
                            '$opacityPct%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.opacity_rounded,
                            color: AppTheme.textTertiary,
                            size: 18,
                          ),
                          Expanded(
                            child: Slider(
                              key: const Key('grid_opacity_slider'),
                              value: config.opacity,
                              min: 0.15,
                              max: 1.0,
                              divisions: 17,
                              label: '$opacityPct%',
                              onChanged: (val) =>
                                  viewModel.setGridOpacity(val),
                            ),
                          ),
                          const Icon(
                            Icons.line_weight_rounded,
                            color: AppTheme.primary,
                            size: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Section 3: Line Color Presets
                      const Text(
                        'LINE COLOR',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: GridColor.values.map((preset) {
                            final isSelected = config.colorPreset == preset;

                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: InkWell(
                                key: Key('grid_color_${preset.name}'),
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => viewModel.setGridColor(preset),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppTheme.surfaceHighlight
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? preset.color
                                          : AppTheme.borderMedium,
                                      width: isSelected ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 14,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          color: preset.color,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.black.withValues(alpha: 0.5),
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        preset.label,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: isSelected
                                              ? AppTheme.textPrimary
                                              : AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Section 4: Auxiliary Drawing Guides
                      Material(
                        color: AppTheme.surfaceHighlight.withValues(alpha: 0.6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: AppTheme.borderLight),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          child: Column(
                            children: [
                              SwitchListTile(
                                key: const Key('grid_crosshair_tile'),
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Center Crosshairs',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                subtitle: const Text(
                                  'Accented horizontal and vertical center axes',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                value: config.showCenterCrosshair,
                                activeThumbColor: AppTheme.primary,
                                onChanged: (_) =>
                                    viewModel.toggleGridCenterCrosshair(),
                              ),
                              const Divider(color: AppTheme.borderLight, height: 1),
                              SwitchListTile(
                                key: const Key('grid_diagonals_tile'),
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Diagonal Guides',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                subtitle: const Text(
                                  'Corner-to-corner diagonal armature lines',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                value: config.showDiagonals,
                                activeThumbColor: AppTheme.primary,
                                onChanged: (_) =>
                                    viewModel.toggleGridDiagonals(),
                              ),
                              const Divider(color: AppTheme.borderLight, height: 1),
                              SwitchListTile(
                                key: const Key('grid_labels_tile'),
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Square Labels (Coordinates)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                subtitle: const Text(
                                  'Alphanumeric cell labels (A1, B2...) to track squares',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                value: config.showLabels,
                                activeThumbColor: AppTheme.primary,
                                onChanged: (_) => viewModel.toggleGridLabels(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
