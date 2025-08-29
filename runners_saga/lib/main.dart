import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'bootstrap.dart';
import 'shared/widgets/navigation/app_router.dart';
import 'shared/providers/app_providers.dart';
import 'shared/widgets/ui/error_screen.dart';
import 'shared/services/app_lifecycle_manager.dart';
import 'shared/services/background_service_manager.dart';
import 'shared/services/background_timer_manager.dart';
import 'shared/services/run/progress_monitor_service.dart';
import 'shared/services/story/scene_trigger_service.dart';
import 'shared/services/audio/audio_manager.dart';

Future<void> main() async {
  try {
    await bootstrap();
    runApp(const ProviderScope(child: RunnersSagaApp()));
  } catch (e, stackTrace) {
    debugPrint('❌ Bootstrap failed: $e');
    debugPrintStack(stackTrace: stackTrace);

    runApp(MaterialApp(
      home: ErrorScreen(
        message: 'Firebase initialization failed.\n\n$e',
        onRetry: () => main(),
        title: 'Startup Error',
      ),
    ));
  }
}

class RunnersSagaApp extends ConsumerStatefulWidget {
  const RunnersSagaApp({super.key});

  @override
  ConsumerState<RunnersSagaApp> createState() => _RunnersSagaAppState();
}

class _RunnersSagaAppState extends ConsumerState<RunnersSagaApp> with WidgetsBindingObserver {
  late AppLifecycleManager _appLifecycleManager;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    
    // Register for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize app lifecycle manager
    _initializeAppLifecycleManager();
  }

  @override
  void dispose() {
    // Unregister from app lifecycle changes
    WidgetsBinding.instance.removeObserver(this);
    
    // Dispose app lifecycle manager
    _appLifecycleManager.dispose();
    
    super.dispose();
  }

  /// Initialize the app lifecycle manager
  Future<void> _initializeAppLifecycleManager() async {
    try {
      // Get service instances from providers
      final backgroundServiceManager = BackgroundServiceManager.instance;
      final backgroundTimerManager = BackgroundTimerManager.instance;
      final progressMonitorService = ProgressMonitorService();
      final sceneTriggerService = SceneTriggerService();
      final audioManager = AudioManager();
      
      // Initialize audio manager
      await audioManager.initialize();
      
      // Initialize background timer manager
      await backgroundTimerManager.initialize();
      
      // Create and initialize app lifecycle manager
      _appLifecycleManager = AppLifecycleManager.instance;
      await _appLifecycleManager.initialize(
        backgroundServiceManager: backgroundServiceManager,
        backgroundTimerManager: backgroundTimerManager,
        progressMonitorService: progressMonitorService,
        sceneTriggerService: sceneTriggerService,
        audioManager: audioManager,
      );
      
      // Request battery optimization exemption (Android only)
      await _appLifecycleManager.requestBatteryOptimizationExemption();
      
      setState(() {
        _isInitialized = true;
      });
      
      debugPrint('✅ App lifecycle manager initialized successfully');
      
    } catch (e) {
      debugPrint('❌ Failed to initialize app lifecycle manager: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (_isInitialized) {
      // Forward lifecycle changes to the app lifecycle manager
      _appLifecycleManager.onAppLifecycleChanged(state);
      
      debugPrint('📱 App lifecycle changed: $state');
    }
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(appThemeProvider);

    return MaterialApp.router(
      title: "The Runner's Saga",
      theme: appTheme.lightTheme,
      darkTheme: appTheme.darkTheme,
      themeMode: appTheme.themeMode,
      routerConfig: AppRouter.router,
      debugShowCheckedModeBanner: false,
    );
  }
}
