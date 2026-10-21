import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traceart/services/image_processing_service.dart';
import 'package:traceart/theme/app_theme.dart';
import 'package:traceart/ui/views/workspace_view.dart';
import 'package:traceart/ui/widgets/alignment_toolbar.dart';
import 'package:traceart/ui/widgets/locked_toolbar.dart';
import 'package:traceart/ui/widgets/tracing_canvas.dart';
import 'package:traceart/viewmodels/tracing_viewmodel.dart';
import '../mocks/fake_services.dart';

void main() {
  late FakeImagePickerService pickerService;
  late FakeScreenService screenService;
  late FakeImageProcessingService processingService;
  late TracingViewModel viewModel;

  setUp(() {
    pickerService = FakeImagePickerService();
    screenService = FakeScreenService();
    processingService = FakeImageProcessingService();
    viewModel = TracingViewModel(
      pickerService: pickerService,
      screenService: screenService,
      processingService: processingService,
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
}
