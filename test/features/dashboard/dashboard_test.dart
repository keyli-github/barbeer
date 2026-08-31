import 'package:barbeer/features/auth/data/models/auth_models.dart';
import 'package:barbeer/features/auth/presentation/providers/auth_provider.dart';
import 'package:barbeer/features/caja/data/caja_repository.dart';
import 'package:barbeer/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:barbeer/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  final auth = AuthState(
    status: AuthStatus.authenticated,
    user: const UserProfile(
      id: 'u1',
      username: 'root',
      rol: 'SUPERADMIN',
      nivel: 100,
      createdAt: '2026-01-01',
      permisos: ['caja:leer'],
    ),
  );
  final session = CajaSesion.fromJson({
    'id': 'c1',
    'estado': 'ABIERTA',
    'version': 'V2',
    'sedeId': 's1',
    'sede': {'nombre': 'Centro'},
    'montoApertura': 100,
    'abiertaAt': '2026-08-29T10:00:00Z',
    'usuarioApertura': {'id': 'u1', 'username': 'root'},
    'resumen': {
      'version': 'V2',
      'totalVentasNeto': 150.5,
      'costoProductosVendidos': 60,
      'utilidadBruta': 90.5,
      'unidadesVendidas': 12,
      'otrosGastos': 10,
      'utilidadNeta': 80.5,
      'margenNeto': 53.49,
    },
  });

  Future<void> pumpKpis(WidgetTester tester, {required bool loading}) =>
      tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DashboardKpis(
            data: DashboardData(
              selectedSedeId: 's1',
              cajaActual: session,
              loading: loading,
            ),
            auth: auth,
          ),
        ),
      ));

  testWidgets('SUPERADMIN keeps seven financial labels while values load', (
    tester,
  ) async {
    await pumpKpis(tester, loading: true);

    for (final label in const [
      'VENTAS TOTALES',
      'COSTO DE PRODUCTOS VENDIDOS',
      'UTILIDAD BRUTA',
      'UNIDADES VENDIDAS',
      'OTROS GASTOS',
      'UTILIDAD NETA',
      'MARGEN NETO',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byKey(const Key('dashboard-kpi-value-skeleton')), findsNWidgets(7));
    expect(find.text('PRODUCTOS'), findsNothing);
  });

  testWidgets('SUPERADMIN renders authoritative financial response values', (
    tester,
  ) async {
    await pumpKpis(tester, loading: false);

    expect(find.textContaining('150.50'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('53.5%'), findsOneWidget);
    expect(find.byKey(const Key('dashboard-kpi-value-skeleton')), findsNothing);
  });

  group('Blocker 8: Dashboard recent activity', () {
    List<Map<String, dynamic>> makeAudit(int count) => List.generate(
          count,
          (i) => {
            'id': 'a$i',
            'accion': 'CREAR_VENTA',
            'usuario': {'username': 'user$i'},
            'createdAt': '2026-08-29T1$i:00:00Z',
          },
        );

    testWidgets('Ver todo link is visible with 6 audit items', (
      tester,
    ) async {
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, __) => const SizedBox()),
          GoRoute(path: '/auditoria', builder: (_, __) => const SizedBox()),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(
        routerConfig: router,
      ));
      // Now test the DashboardRecentActivity widget directly
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DashboardRecentActivity(audit: makeAudit(6)),
        ),
      ));
      expect(find.text('Ver todo'), findsOneWidget);
    });

    testWidgets('Ver todo link is visible with exactly 1 audit item', (
      tester,
    ) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DashboardRecentActivity(audit: makeAudit(1)),
        ),
      ));
      expect(find.text('Ver todo'), findsOneWidget);
    });

    test('audit fetch limit constant matches web parity (8)', () {
      expect(dashboardAuditLimit, 8);
    });
  });
}
