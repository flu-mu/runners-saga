import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'bootstrap.dart';
import 'shared/widgets/navigation/app_router.dart';
import 'shared/providers/app_providers.dart';
import 'shared/widgets/ui/error_screen.dart';

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

class RunnersSagaApp extends ConsumerWidget {
  const RunnersSagaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
