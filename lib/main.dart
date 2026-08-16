import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/providers/branding_provider.dart';
import 'core/providers/theme_mode_provider.dart';
import 'core/routes/app_router.dart';
import 'core/theme/app_scroll_behavior.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final isMobilePlatform =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  if (isMobilePlatform) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
  final preferences = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: const BarBeerApp(),
    ),
  );
}

class BarBeerApp extends ConsumerWidget {
  const BarBeerApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Carga branding remoto (endpoint público) al arrancar la app
    ref.listen<AuthState>(authProvider, (_, __) {
      router.refresh();
    });
    // Precarga el branding fuera del ciclo de build para evitar
    // modificar el árbol durante su construcción.
    Future.microtask(() => ref.read(brandingProvider.notifier).load());

    return MaterialApp.router(
      title: 'BarBeer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.systemUiOverlayStyle(context),
        child: child ?? const SizedBox.shrink(),
      ),
      scrollBehavior: const AppScrollBehavior(),
      routerConfig: router,
    );
  }
}
