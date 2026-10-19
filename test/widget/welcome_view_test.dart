import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traceart/theme/app_theme.dart';
import 'package:traceart/ui/views/welcome_view.dart';
import 'package:traceart/viewmodels/tracing_viewmodel.dart';
import '../mocks/fake_services.dart';

void main() {
  late FakeImagePickerService pickerService;
  late FakeScreenService screenService;
  late TracingViewModel viewModel;

  setUp(() {
    pickerService = FakeImagePickerService();
    screenService = FakeScreenService();
    viewModel = TracingViewModel(
      pickerService: pickerService,
      screenService: screenService,
    );
  });

  tearDown(() {
    viewModel.dispose();
  });

  Widget buildSubject() {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: WelcomeView(viewModel: viewModel),
    );
  }

  testWidgets('renders TraceArt branding, tagline, and Choose an Image button',
      (tester) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('TraceArt'), findsOneWidget);
    expect(find.text('Turn your screen into a tracing board'), findsOneWidget);
    expect(find.text('Choose an Image'), findsOneWidget);
    expect(find.text('Pick Photo'), findsOneWidget);
    expect(find.text('Align & Scale'), findsOneWidget);
    expect(find.text('Lock & Trace'), findsOneWidget);
  });

  testWidgets('tapping Choose an Image triggers image picker', (tester) async {
    final testImg = createSampleImage();
    pickerService.nextResult = testImg;

    await tester.pumpWidget(buildSubject());

    final buttonFinder = find.widgetWithText(ElevatedButton, 'Choose an Image');
    expect(buttonFinder, findsOneWidget);

    await tester.tap(buttonFinder);
    await tester.pumpAndSettle();

    expect(pickerService.pickCallCount, equals(1));
    expect(viewModel.hasImage, isTrue);
  });

  testWidgets('displays error notification when errorMessage is present',
      (tester) async {
    pickerService.shouldThrow = true;

    await tester.pumpWidget(buildSubject());
    await tester.tap(find.widgetWithText(ElevatedButton, 'Choose an Image'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(find.textContaining('Photo library access failed'), findsOneWidget);
  });
}
