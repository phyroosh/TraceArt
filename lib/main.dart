import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'ui/views/welcome_view.dart';
import 'ui/views/workspace_view.dart';
import 'viewmodels/tracing_viewmodel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set immersive dark system UI styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(const TraceArtApp());
}

class TraceArtApp extends StatefulWidget {
  const TraceArtApp({super.key});

  @override
  State<TraceArtApp> createState() => _TraceArtAppState();
}

class _TraceArtAppState extends State<TraceArtApp>
    with WidgetsBindingObserver {
  late final TracingViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _viewModel = TracingViewModel();
    _viewModel.init();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _viewModel.handleAppLifecycle(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TraceArt',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _viewModel.hasImage
                ? WorkspaceView(
                    key: const ValueKey('workspace_view'),
                    viewModel: _viewModel,
                  )
                : WelcomeView(
                    key: const ValueKey('welcome_view'),
                    viewModel: _viewModel,
                  ),
          );
        },
      ),
    );
  }
}
