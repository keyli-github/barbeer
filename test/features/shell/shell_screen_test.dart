import 'package:barbeer/core/navigation/app_destinations.dart';
import 'package:barbeer/core/providers/branding_provider.dart';
import 'package:barbeer/core/providers/sede_scope_provider.dart';
import 'package:barbeer/features/auth/data/models/auth_models.dart';
import 'package:barbeer/features/auth/data/repositories/auth_repository.dart';
import 'package:barbeer/features/auth/presentation/providers/auth_provider.dart';
import 'package:barbeer/features/perfil/presentation/screens/perfil_screen.dart';
import 'package:barbeer/features/shell/presentation/screens/shell_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(super.repository, AuthState value) {
    state = value;
  }
}

void main() {
  Future<void> pumpShell(
    WidgetTester tester, {
    required UserProfile user,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    final router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
        ShellRoute(
          builder: (_, state, child) =>
              ShellScreen(currentPath: state.matchedLocation, child: child),
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (_, _) =>
                  const Scaffold(body: Center(child: Text('DASH'))),
            ),
            GoRoute(path: '/perfil', builder: (_, _) => const PerfilScreen()),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(
            (ref) => _TestAuthNotifier(
              ref.read(authRepositoryProvider),
              AuthState(status: AuthStatus.authenticated, user: user),
            ),
          ),
          brandingProvider.overrideWith((_) => BrandingNotifier.noop()),
          sedeScopeOptionsProvider.overrideWith(
            (ref) async => const <SedeScopeOption>[],
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('móvil: el usuario del panel Ver más navega al perfil', (
    tester,
  ) async {
    await pumpShell(
      tester,
      user: const UserProfile(
        id: 'admin-1',
        username: 'admin',
        rol: 'ADMIN',
        nivel: 50,
        sedeId: 's1',
        sede: 'Centro',
        createdAt: '2026-01-01',
        permisos: ['productos:leer', 'usuarios:leer'],
      ),
    );

    expect(find.text('DASH'), findsOneWidget);

    await tester.tap(find.text('Ver más'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('header-profile-button')), findsOneWidget);

    await tester.tap(find.text('admin'));
    await tester.pumpAndSettle();

    expect(find.text('INFORMACION DE CUENTA'), findsOneWidget);
    expect(find.text('Cambiar\ncontrasena'), findsOneWidget);
    expect(find.text('Cerrar\nsesion'), findsOneWidget);
  });

  testWidgets('móvil: el botón del header navega al perfil (admin)', (
    tester,
  ) async {
    await pumpShell(
      tester,
      user: const UserProfile(
        id: 'admin-1',
        username: 'admin',
        rol: 'ADMIN',
        nivel: 50,
        sedeId: 's1',
        sede: 'Centro',
        createdAt: '2026-01-01',
        permisos: ['productos:leer', 'usuarios:leer'],
      ),
    );

    await tester.tap(find.byKey(const Key('header-profile-button')));
    await tester.pumpAndSettle();

    expect(find.text('INFORMACION DE CUENTA'), findsOneWidget);
    expect(find.text('Administrador'), findsOneWidget);
  });

  testWidgets('móvil: el superadmin ve sus opciones especiales en el perfil', (
    tester,
  ) async {
    await pumpShell(
      tester,
      user: const UserProfile(
        id: 'sa-1',
        username: 'superadmin',
        rol: 'SUPERADMIN',
        nivel: 100,
        createdAt: '2026-01-01',
        permisos: ['productos:leer', 'usuarios:leer', 'establecimientos:leer'],
      ),
    );

    await tester.tap(find.byKey(const Key('header-profile-button')));
    await tester.pumpAndSettle();

    expect(find.text('INFORMACION DE CUENTA'), findsOneWidget);
    expect(find.text('Super Admin'), findsOneWidget);
    expect(find.text('Todas las sedes'), findsNWidgets(2));
    expect(find.text('PERSONALIZACIÓN DEL SISTEMA'), findsOneWidget);
    expect(find.text('Logo del sistema'), findsOneWidget);
    expect(find.text('Portada del login'), findsOneWidget);
    final assets = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => image.image)
        .whereType<AssetImage>()
        .map((image) => image.assetName);
    expect(assets, contains('assets/images/yacare.png'));
    expect(assets, contains('assets/images/login.webp'));
  });

  test('branding identifica la imagen que se está guardando', () {
    const logo = BrandingState(mutation: BrandingMutation.logo);
    const cover = BrandingState(mutation: BrandingMutation.cover);

    expect(logo.mutation, BrandingMutation.logo);
    expect(cover.mutation, BrandingMutation.cover);
    expect(logo.mutation == BrandingMutation.cover, isFalse);
  });
}
