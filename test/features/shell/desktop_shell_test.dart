import 'package:barbeer/core/navigation/app_destinations.dart';
import 'package:barbeer/features/auth/data/models/auth_models.dart';
import 'package:barbeer/features/auth/presentation/providers/auth_provider.dart';
import 'package:barbeer/features/shell/presentation/screens/desktop_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders and collapses the desktop shell', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);

    final auth = AuthState(
      status: AuthStatus.authenticated,
      user: const UserProfile(
        id: 'user-id',
        username: 'admin',
        rol: 'ADMIN',
        nivel: 10,
        createdAt: '2026-01-01',
        permisos: ['productos:leer', 'etiquetas:leer'],
      ),
    );
    final visible = appDestinations
        .where((destination) => destination.canAccess(auth.hasPermission))
        .toList();

    await tester.pumpWidget(
      MaterialApp(
        home: DesktopShell(
          currentPath: '/productos',
          destinations: visible,
          auth: auth,
          onNavigate: (_) {},
          onLogout: () {},
          child: const ColoredBox(color: Colors.white),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(const Key('desktop-sidebar'))).width, 272);
    expect(tester.getSize(find.byKey(const Key('desktop-header'))).height, 56);
    expect(find.text('Productos'), findsWidgets);
    expect(find.text('Billeteras'), findsOneWidget);
    expect(find.text('Ventas'), findsNothing);
    expect(find.byTooltip('Cerrar sesion'), findsOneWidget);

    await tester.tap(find.byKey(const Key('desktop-sidebar-toggle')));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byKey(const Key('desktop-sidebar'))).width, 68);
    expect(tester.takeException(), isNull);
  });
}
