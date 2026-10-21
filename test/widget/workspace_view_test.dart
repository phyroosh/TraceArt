import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traceart/models/grid_config.dart';
import 'package:traceart/models/stencil_config.dart';
import 'package:traceart/services/image_processing_service.dart';
import 'package:traceart/theme/app_theme.dart';
import 'package:traceart/ui/views/workspace_view.dart';
import 'package:traceart/ui/widgets/alignment_toolbar.dart';
import 'package:traceart/ui/widgets/camera_feed_view.dart';
import 'package:traceart/ui/widgets/grid_painter.dart';
import 'package:traceart/ui/widgets/locked_toolbar.dart';
import 'package:traceart/ui/widgets/stencil_sheet.dart';
import 'package:traceart/ui/widgets/tracing_canvas.dart';
import 'package:traceart/viewmodels/tracing_viewmodel.dart';
import '../mocks/fake_camera_service.dart';
import '../mocks/fake_services.dart';

void main() {
  late FakeImagePickerService pickerService;
  late FakeScreenService screenService;
  late FakeImageProcessingService processingService;
  late FakeCameraService cameraService;
  late TracingViewModel viewModel;

  setUp(() {
    pickerService = FakeImagePickerService();
    screenService = FakeScreenService();
    processingService = FakeImageProcessingService();
    cameraService = FakeCameraService();
    viewModel = TracingViewModel(
      pickerService: pickerService,
      screenService: screenService,
      processingService: processingService,
      cameraService: cameraService,
    );
    viewModel.setImage(createSampleImage(name: 'sketch.png'));
  });

  tearDown(() {
    viewModel.dispose();
  });

  Widget buildSubject() {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) => WorkspaceView(viewModel: viewModel),
      ),
    );
  }

  testWidgets('renders TracingCanvas and AlignmentToolbar in Unlocked Mode',
      (tester) async {
    await tester.pumpWidget(buildSubject());

    expect(find.byType(TracingCanvas), findsOneWidget);
    expect(find.byType(AlignmentToolbar), findsOneWidget);
    expect(find.byType(LockedToolbar), findsNothing);
    expect(find.text('Lock Canvas'), findsOneWidget);
    expect(find.text('EDITING'), findsOneWidget);
    expect(find.text('sketch.png'), findsOneWidget);

    // Verify canvas is NOT absorbing touches when unlocked
    final absorbPointerFinder = find.descendant(
      of: find.byType(WorkspaceView),
      matching: find.byType(AbsorbPointer),
    );
    expect(absorbPointerFinder, findsOneWidget);
    final absorbPointer = tester.widget<AbsorbPointer>(absorbPointerFinder);
    expect(absorbPointer.absorbing, isFalse);
  });

  testWidgets(
      'tapping Lock Canvas hides all options, freezes touches, and 3-dot brings back unlock',
      (tester) async {
    await tester.pumpWidget(buildSubject());

    final lockButton = find.byKey(const Key('lock_canvas_button'));
    expect(lockButton, findsOneWidget);

    final matrixBefore = viewModel.transformationController.value.clone();

    // 1. Tap Lock Canvas
    await tester.tap(lockButton);
    await tester.pumpAndSettle();

    expect(viewModel.isLocked, isTrue);

    // ALL options must be HIDDEN
    expect(find.byType(AlignmentToolbar), findsNothing);
    expect(find.byType(LockedToolbar), findsNothing);
    expect(find.text('EDITING'), findsNothing);

    // Canvas AbsorbPointer must be absorbing: true (completely touch non-responsive)
    final absorbPointerFinder = find.descendant(
      of: find.byType(WorkspaceView),
      matching: find.byType(AbsorbPointer),
    );
    final absorbPointer = tester.widget<AbsorbPointer>(absorbPointerFinder);
    expect(absorbPointer.absorbing, isTrue);

    // ONLY the small 3-dot menu button in top right corner must be visible
    final menuButton = find.byKey(const Key('locked_menu_button'));
    expect(menuButton, findsOneWidget);

    // Matrix must be completely preserved
    expect(viewModel.transformationController.value, equals(matrixBefore));

    // 2. Tap 3-dot button to bring back Lock/Unlock options
    await tester.tap(menuButton);
    await tester.pumpAndSettle();

    expect(find.byType(LockedToolbar), findsOneWidget);
    expect(find.text('Screen Locked'), findsOneWidget);
    expect(find.text('Unlock to Edit'), findsOneWidget);

    // 3. Tap Unlock to Edit button
    final unlockButton = find.byKey(const Key('unlock_canvas_button'));
    expect(unlockButton, findsOneWidget);
    await tester.tap(unlockButton);
    await tester.pumpAndSettle();

    // Must be unlocked and restore all editing tools
    expect(viewModel.isLocked, isFalse);
    expect(find.byType(AlignmentToolbar), findsOneWidget);
    expect(find.byType(LockedToolbar), findsNothing);
    expect(find.byKey(const Key('locked_menu_button')), findsNothing);

    // Alignment preserved
    expect(viewModel.transformationController.value, equals(matrixBefore));
  });

  testWidgets('zoom in and rotate buttons in unlocked mode work',
      (tester) async {
    await tester.pumpWidget(buildSubject());

    final initialTurns = viewModel.quarterTurns;
    final rotateButton = find.byTooltip('Rotate 90° CW');
    expect(rotateButton, findsOneWidget);

    await tester.tap(rotateButton);
    await tester.pumpAndSettle();

    expect(viewModel.quarterTurns, equals((initialTurns + 1) % 4));

    final zoomInButton = find.byTooltip('Zoom In');
    expect(zoomInButton, findsOneWidget);
    final scaleBefore =
        viewModel.transformationController.value.getMaxScaleOnAxis();

    await tester.tap(zoomInButton);
    await tester.pumpAndSettle();

    final scaleAfter =
        viewModel.transformationController.value.getMaxScaleOnAxis();
    expect(scaleAfter, greaterThan(scaleBefore));
  });

  testWidgets('quick invert button toggles inversion state', (tester) async {
    await tester.pumpWidget(buildSubject());

    expect(viewModel.isInverted, isFalse);

    // Find the quick invert button by tooltip
    final invertButton = find.byTooltip('Invert Lines');
    expect(invertButton, findsOneWidget);

    await tester.tap(invertButton);
    await tester.pumpAndSettle();

    expect(viewModel.isInverted, isTrue);
  });

  testWidgets('BrightnessSheet displays three modes when inverted', (tester) async {
    viewModel.setInverted(true);
    await tester.pumpWidget(buildSubject());

    // Open Display & Brightness sheet
    final brightnessButton = find.byTooltip('Display & Brightness');
    expect(brightnessButton, findsOneWidget);

    await tester.tap(brightnessButton);
    await tester.pumpAndSettle();

    // Verify Invert Tracing Mode header is visible
    expect(find.text('Invert Tracing Mode'), findsOneWidget);

    // Verify all 3 modes are visible in the segmented button
    expect(find.text('Original'), findsOneWidget);
    expect(find.text('Enhanced'), findsOneWidget);
    expect(find.text('Outline'), findsOneWidget);

    // Initially in Original mode
    expect(viewModel.invertMode, equals(InvertTracingMode.original));

    // Tap Enhanced
    await tester.tap(find.text('Enhanced'));
    await tester.pumpAndSettle();

    expect(viewModel.invertMode, equals(InvertTracingMode.enhanced));
    expect(find.text('Detail Strength'), findsOneWidget);
    expect(find.text('Sharpens small lines and enhances subtle contrast'), findsOneWidget);

    // Tap Outline
    await tester.tap(find.text('Outline'));
    await tester.pumpAndSettle();

    expect(viewModel.invertMode, equals(InvertTracingMode.fineOutline));
    expect(find.text('Detail Strength'), findsOneWidget);
    expect(find.text('Edge Sensitivity'), findsOneWidget);

    // Verify Line Color Tint section is visible
    expect(find.text('Line Color Tint'), findsOneWidget);
    expect(find.byKey(const Key('tint_white')), findsOneWidget);
    expect(find.byKey(const Key('tint_neonGreen')), findsOneWidget);
    expect(find.byKey(const Key('tint_cyan')), findsOneWidget);
    expect(find.byKey(const Key('tint_amberGold')), findsOneWidget);
    expect(find.byKey(const Key('tint_nightRed')), findsOneWidget);
    expect(find.byKey(const Key('tint_magenta')), findsOneWidget);

    // Initially in White tint
    expect(viewModel.lineColorTint, equals(LineColorTint.white));

    // Scroll into view & tap Neon Green
    await tester.ensureVisible(find.byKey(const Key('tint_neonGreen')));
    await tester.tap(find.byKey(const Key('tint_neonGreen')));
    await tester.pumpAndSettle();
    expect(viewModel.lineColorTint, equals(LineColorTint.neonGreen));

    // Tap Cyan
    await tester.ensureVisible(find.byKey(const Key('tint_cyan')));
    await tester.tap(find.byKey(const Key('tint_cyan')));
    await tester.pumpAndSettle();
    expect(viewModel.lineColorTint, equals(LineColorTint.cyan));
  });

  testWidgets('back navigation shows exit dialog when unlocked but is swallowed when locked',
      (tester) async {
    await tester.pumpWidget(buildSubject());

    // 1. Unlocked mode: trigger back pop
    final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
    await widgetsAppState.didPopRoute();
    await tester.pumpAndSettle();

    // Must show exit dialog
    expect(find.text('Exit Tracing Session?'), findsOneWidget);

    // Dismiss dialog with 'Stay'
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.text('Exit Tracing Session?'), findsNothing);

    // 2. Lock the canvas
    final lockButton = find.byKey(const Key('lock_canvas_button'));
    await tester.tap(lockButton);
    await tester.pumpAndSettle();
    expect(viewModel.isLocked, isTrue);

    // Trigger back pop while locked
    await widgetsAppState.didPopRoute();
    await tester.pumpAndSettle();

    // MUST NOT show exit dialog!
    expect(find.text('Exit Tracing Session?'), findsNothing);

    // 3. Open 3-dot menu while locked
    final menuButton = find.byKey(const Key('locked_menu_button'));
    await tester.tap(menuButton);
    await tester.pumpAndSettle();
    expect(find.text('Screen Locked'), findsOneWidget);

    // Trigger back pop while 3-dot options are open
    await widgetsAppState.didPopRoute();
    await tester.pumpAndSettle();

    // 3-dot menu must close, but still NO exit dialog!
    expect(find.text('Screen Locked'), findsNothing);
    expect(find.text('Exit Tracing Session?'), findsNothing);
    expect(viewModel.isLocked, isTrue);
  });

  testWidgets('tapping Grid button in AlignmentToolbar opens GridSheet and configures overlay',
      (tester) async {
    await tester.pumpWidget(buildSubject());

    // Initially no GridPainter rendered because grid is disabled
    expect(find.byType(CustomPaint), findsWidgets);
    expect(
      find.byWidgetPredicate((w) => w is CustomPaint && w.painter is GridPainter),
      findsNothing,
    );

    // Tap Grid button in AlignmentToolbar
    final gridBtn = find.byKey(const Key('grid_toolbar_button'));
    expect(gridBtn, findsOneWidget);
    await tester.tap(gridBtn);
    await tester.pumpAndSettle();

    // Verify GridSheet is displayed
    expect(find.text('Drawing Grid Overlay'), findsOneWidget);
    expect(find.text('Show Proportional Grid'), findsOneWidget);

    // Tap Enable Grid tile
    await tester.tap(find.byKey(const Key('grid_enable_tile')));
    await tester.pumpAndSettle();

    expect(viewModel.isGridEnabled, isTrue);

    // GridPainter must now be rendered on the canvas
    expect(
      find.byWidgetPredicate((w) => w is CustomPaint && w.painter is GridPainter),
      findsOneWidget,
    );

    // Select 8x8 divisions preset chip
    final chip8 = find.byKey(const Key('grid_division_chip_8'));
    expect(chip8, findsOneWidget);
    await tester.tap(chip8);
    await tester.pumpAndSettle();

    expect(viewModel.gridConfig.divisions, equals(8));

    // Select Cyan color preset
    final cyanChip = find.byKey(const Key('grid_color_cyan'));
    expect(cyanChip, findsOneWidget);
    await tester.tap(cyanChip);
    await tester.pumpAndSettle();

    expect(viewModel.gridConfig.colorPreset, equals(GridColor.cyan));
  });

  testWidgets('locked toolbar provides Grid button allowing grid adjustment while tracing',
      (tester) async {
    await tester.pumpWidget(buildSubject());

    // Lock canvas
    await tester.tap(find.byKey(const Key('lock_canvas_button')));
    await tester.pumpAndSettle();

    expect(viewModel.isLocked, isTrue);

    // Open locked options menu via 3-dot
    await tester.tap(find.byKey(const Key('locked_menu_button')));
    await tester.pumpAndSettle();

    // Verify locked grid button exists in LockedToolbar
    final lockedGridBtn = find.byKey(const Key('locked_grid_button'));
    expect(lockedGridBtn, findsOneWidget);

    // Tap locked grid button to open GridSheet
    await tester.tap(lockedGridBtn);
    await tester.pumpAndSettle();

    expect(find.text('Drawing Grid Overlay'), findsOneWidget);
  });

  testWidgets(
      'tapping mode switch button toggles AR Camera Tracing mode and reveals AR toolbar controls',
      (tester) async {
    await tester.pumpWidget(buildSubject());

    // Initially in Light Box mode, no camera feed
    expect(find.text('Light Box'), findsOneWidget);
    expect(find.byType(CameraFeedView), findsNothing);
    expect(find.byKey(const Key('torch_toolbar_button')), findsNothing);
    expect(find.byKey(const Key('camera_switch_button')), findsNothing);

    // Tap mode switch button
    final modeButton = find.byKey(const Key('mode_switch_button'));
    await tester.tap(modeButton);
    await tester.pumpAndSettle();

    expect(viewModel.isArMode, isTrue);
    expect(find.text('AR Mode'), findsOneWidget);
    expect(find.byType(CameraFeedView), findsOneWidget);
    expect(find.byKey(const Key('torch_toolbar_button')), findsOneWidget);
    expect(find.byKey(const Key('camera_switch_button')), findsOneWidget);

    // Tap Torch button in AlignmentToolbar
    await tester.tap(find.byKey(const Key('torch_toolbar_button')));
    await tester.pumpAndSettle();

    expect(viewModel.isTorchOn, isTrue);
    expect(cameraService.toggleTorchCalls, equals(1));

    // Tap Camera Switch button
    await tester.tap(find.byKey(const Key('camera_switch_button')));
    await tester.pumpAndSettle();

    expect(cameraService.switchCameraCalls, equals(1));
  });

  testWidgets(
      'opening BrightnessSheet in AR mode displays AR overlay opacity slider and desk flashlight',
      (tester) async {
    await viewModel.setTracingMode(TracingMode.arCamera);
    await tester.pumpWidget(buildSubject());

    // Open Brightness & Tracing Illumination sheet
    final brightnessBtn = find.byKey(const Key('brightness_toolbar_button'));
    expect(brightnessBtn, findsOneWidget);
    await tester.tap(brightnessBtn);
    await tester.pumpAndSettle();

    // Verify AR Overlay controls are present
    expect(find.text('AR Tracing Overlay'), findsOneWidget);
    expect(find.text('Artwork Opacity'), findsOneWidget);
    expect(find.byKey(const Key('ar_overlay_opacity_slider')), findsOneWidget);
    expect(find.byKey(const Key('ar_torch_tile')), findsOneWidget);

    // Toggle desk flashlight tile
    await tester.tap(find.byKey(const Key('ar_torch_tile')));
    await tester.pumpAndSettle();

    expect(viewModel.isTorchOn, isTrue);
    expect(cameraService.toggleTorchCalls, equals(1));
  });

  testWidgets(
      'locking canvas in AR mode retains camera feed and provides desk torch button in locked menu',
      (tester) async {
    await viewModel.setTracingMode(TracingMode.arCamera);
    await tester.pumpWidget(buildSubject());

    // Lock canvas
    await tester.tap(find.byKey(const Key('lock_canvas_button')));
    await tester.pumpAndSettle();

    expect(viewModel.isLocked, isTrue);
    // Camera feed remains active behind locked artwork
    expect(find.byType(CameraFeedView), findsOneWidget);

    // Open locked options menu via 3-dot
    await tester.tap(find.byKey(const Key('locked_menu_button')));
    await tester.pumpAndSettle();

    // Verify locked torch button is available
    final lockedTorchBtn = find.byKey(const Key('locked_torch_button'));
    expect(lockedTorchBtn, findsOneWidget);

    // Tap locked torch button
    await tester.tap(lockedTorchBtn);
    await tester.pumpAndSettle();

    expect(viewModel.isTorchOn, isTrue);
    expect(cameraService.toggleTorchCalls, equals(1));
  });

  testWidgets(
      'tapping stencil button in AlignmentToolbar opens StencilSheet and configures modes',
      (tester) async {
    await tester.pumpWidget(buildSubject());

    // 1. Verify stencil button is visible on toolbar and tap it
    final stencilBtn = find.byKey(const Key('stencil_toolbar_button'));
    expect(stencilBtn, findsOneWidget);
    await tester.tap(stencilBtn);
    await tester.pumpAndSettle();

    // 2. Verify StencilSheet opened
    expect(find.byType(StencilSheet), findsOneWidget);
    expect(find.text('Quick Stencil Filters'), findsOneWidget);
    expect(find.text('Original'), findsOneWidget);
    expect(find.text('B&W Stencil'), findsOneWidget);
    expect(find.text('Posterize'), findsOneWidget);
    expect(find.text('Edge Sketch'), findsOneWidget);

    // 3. Select B&W Stencil
    await tester.tap(find.text('B&W Stencil'));
    await tester.pumpAndSettle();

    expect(viewModel.stencilConfig.type, equals(StencilFilterType.threshold));
    expect(find.text('Threshold Cutoff'), findsOneWidget);
    expect(find.byKey(const Key('stencil_threshold_slider')), findsOneWidget);
    expect(find.byKey(const Key('stencil_auto_otsu_button')), findsOneWidget);

    // 4. Tap Auto Otsu button
    processingService.nextOtsuThreshold = 0.45;
    await tester.tap(find.byKey(const Key('stencil_auto_otsu_button')));
    await tester.pumpAndSettle();

    expect(processingService.otsuCallCount, equals(1));
    expect(viewModel.stencilConfig.threshold, closeTo(0.45, 0.01));

    // 5. Select Posterize
    await tester.tap(find.text('Posterize'));
    await tester.pumpAndSettle();

    expect(viewModel.stencilConfig.type, equals(StencilFilterType.posterize));
    expect(find.text('Tonal Shading Steps'), findsOneWidget);
    expect(find.byKey(const Key('stencil_posterize_chip_6')), findsOneWidget);

    // Tap 6 Steps
    await tester.tap(find.byKey(const Key('stencil_posterize_chip_6')));
    await tester.pumpAndSettle();
    expect(viewModel.stencilConfig.posterizeLevels, equals(6));

    // 6. Select Edge Sketch
    await tester.tap(find.text('Edge Sketch'));
    await tester.pumpAndSettle();

    expect(viewModel.stencilConfig.type, equals(StencilFilterType.edgeSketch));
    expect(find.text('Line Weight & Sensitivity'), findsOneWidget);
    expect(find.byKey(const Key('stencil_edge_slider')), findsOneWidget);
  });

  testWidgets(
      'in locked mode 3-dot options provides locked stencil button that opens StencilSheet',
      (tester) async {
    await tester.pumpWidget(buildSubject());

    // Lock canvas
    await tester.tap(find.byKey(const Key('lock_canvas_button')));
    await tester.pumpAndSettle();
    expect(viewModel.isLocked, isTrue);

    // Open locked options menu via 3-dot
    await tester.tap(find.byKey(const Key('locked_menu_button')));
    await tester.pumpAndSettle();

    // Verify locked stencil button is present
    final lockedStencilBtn = find.byKey(const Key('locked_stencil_button'));
    expect(lockedStencilBtn, findsOneWidget);

    // Tap locked stencil button
    await tester.tap(lockedStencilBtn);
    await tester.pumpAndSettle();

    // Verify StencilSheet opens even while canvas is locked
    expect(find.byType(StencilSheet), findsOneWidget);
    expect(find.text('Quick Stencil Filters'), findsOneWidget);
  });
}

