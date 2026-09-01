import 'package:barbeer/core/navigation/route_access_policy.dart';
import 'package:barbeer/core/routes/route_paths.dart';
import 'package:barbeer/core/routes/router_refresh_notifier.dart';
import 'package:barbeer/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _adminPermissions = {'productos:leer', 'cuentas:leer'};
const _pages = {
  RoutePaths.splash: 'SPLASH',
  RoutePaths.login: 'LOGIN',
  RoutePaths.changePassword: 'CHANGE PASSWORD',
  RoutePaths.noAutorizado: 'UNAUTHORIZED',
  RoutePaths.dashboard: 'DASHBOARD',
  RoutePaths.productos: 'PROTECTED PRODUCTS',
  '/unknown-protected': 'PROTECTED UNKNOWN',
};

bool _can(
  String path, {
  String role = 'ADMIN',
  Set<String> permissions = const {},
}) => RouteAccessPolicy.canAccess(path, role: role, permissions: permissions);

typedef _Scenario = (AuthGateState, String, Set<String>, String);

GoRouter _router(_Scenario scenario, RouterRefreshNotifier refresh) => GoRouter(
  initialLocation: scenario.$2,
  refreshListenable: refresh,
  redirect: (_, state) => routeGuardRedirect(
    gate: scenario.$1,
    currentPath: state.matchedLocation,
    role: 'ADMIN',
    permissions: scenario.$3,
  ),
  routes: [
    for (final page in _pages.entries)
      GoRoute(
        path: page.key,
        builder: (_, __) => Scaffold(body: Text(page.value)),
      ),
  ],
);

void main() {
  test('role, permissions, known paths, and unknown defaults share policy', () {
    const action = RouteAccessRule.both({'SUPERADMIN'}, {'usuarios:editar'});
    bool accounts(String role) =>
        _can(RoutePaths.cuentas, role: role, permissions: _adminPermissions);
    bool actionAllowed(Set<String> permissions) =>
        action.allows(role: 'SUPERADMIN', permissions: permissions);

    expect(accounts('ADMIN'), isTrue);
    expect(accounts('VENDEDORA'), isFalse);
    expect(actionAllowed({'usuarios:editar'}), isTrue);
    expect(actionAllowed({}), isFalse);
    expect(_can(RoutePaths.productos, permissions: _adminPermissions), isTrue);
    expect(_can(RoutePaths.productos), isFalse);
    expect(
      _can(
        RoutePaths.importaciones,
        permissions: const {'importaciones:ejecutar'},
      ),
      isTrue,
    );
    expect(_can(RoutePaths.importaciones), isFalse);
    expect(_can('/unknown-protected', role: 'SUPERADMIN'), isFalse);
    expect(
      routeGuardRedirect(
        gate: AuthGateState.authenticated,
        currentPath: RoutePaths.splash,
        pendingLocation: RoutePaths.productos,
        role: 'ADMIN',
        permissions: _adminPermissions,
      ),
      RoutePaths.productos,
    );
  });

  testWidgets('widget deep-link matrix blocks unauthorized content flashes', (
    tester,
  ) async {
    final product = RoutePaths.productos;
    final authenticated = AuthGateState.authenticated;
    final scenarios = <_Scenario>[
      (AuthGateState.unresolved, product, {}, 'SPLASH'),
      (AuthGateState.unauthenticated, product, {}, 'LOGIN'),
      (authenticated, product, {'productos:leer'}, 'PROTECTED PRODUCTS'),
      (authenticated, product, {}, 'UNAUTHORIZED'),
      (authenticated, '/unknown-protected', {}, 'UNAUTHORIZED'),
    ];

    for (final scenario in scenarios) {
      final refresh = RouterRefreshNotifier();
      final router = _router(scenario, refresh);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      final expected = scenario.$4;
      if (!expected.startsWith('PROTECTED')) {
        expect(find.textContaining('PROTECTED'), findsNothing);
      }
      await tester.pumpAndSettle();
      expect(find.text(expected), findsOneWidget);
      router.dispose();
    }
  });

  test('403 refresh replaces auth metadata or preserves prior state', () async {
    const initial = AuthState(status: AuthStatus.authenticated);
    const refreshed = AuthState(status: AuthStatus.authenticated);
    final success = await preserveAuthorizationRefresh(
      initial,
      () async => refreshed,
    );
    final failure = await preserveAuthorizationRefresh(
      initial,
      () async => throw Exception('authorization refresh failed'),
    );

    expect(success, same(refreshed));
    expect(failure, same(initial));
  });
}
