import 'package:barbeer/core/network/api_client.dart';
import 'package:barbeer/core/theme/app_theme.dart';
import 'package:barbeer/features/auth/data/models/auth_models.dart';
import 'package:barbeer/features/auth/presentation/providers/auth_provider.dart';
import 'package:barbeer/features/caja/data/caja_repository.dart';
import 'package:barbeer/features/caja/presentation/providers/caja_provider.dart';
import 'package:barbeer/features/caja/presentation/screens/caja_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StaticCajaNotifier extends CajaNotifier {
  _StaticCajaNotifier(CajaState value)
    : super(CajaRepository(ApiClient.instance), null, null) {
    state = value;
  }

  @override
  Future<void> load() async {}
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(super.repository, AuthState value) {
    state = value;
  }
}

void main() {
  testWidgets('desktop movement cells match their column headings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const user = UserProfile(
      id: 'user-1',
      username: 'cashier',
      rol: 'CAJERO',
      nivel: 30,
      sedeId: 'branch-1',
      createdAt: '2026-09-01',
      permisos: ['caja:leer'],
    );
    final session = CajaSesion(
      id: 'session-1',
      estado: 'ABIERTA',
      version: 'V2',
      cierreForzado: false,
      sedeId: 'branch-1',
      sede: 'Main branch',
      montoApertura: 100,
      abiertaAt: DateTime(2026, 8, 13, 8),
      usuarioApertura: 'cashier',
      usuarioAperturaId: 'user-1',
      denominaciones: const [],
      resumen: const CajaResumen(
        version: 'V2',
        v2: CajaResumenV2(
          totalVentasBruto: 20,
          totalAnulaciones: 0,
          totalVentasNeto: 20,
          totalDigitalBruto: 0,
          totalReversDigital: 0,
          totalDigitalNeto: 0,
          efectivoEsperado: 120,
          ventasPendientes: 0,
          cantidadVentas: 1,
          cantidadAnuladas: 0,
        ),
      ),
    );
    final movement = CajaMovimiento(
      id: 'movement-1',
      tipo: 'ENTRADA',
      origen: 'MANUAL',
      medioPago: 'EFECTIVO',
      concepto: 'Opening adjustment',
      monto: 20,
      comprobante: 'https://example.com/receipt.png',
      usuario: 'cashier',
      createdAt: DateTime(2026, 8, 13, 10),
    );
    final state = CajaState(
      actual: session,
      movimientos: [movement],
      movimientosTotal: 1,
      sedeId: 'branch-1',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cajaProvider.overrideWith((ref) => _StaticCajaNotifier(state)),
          authProvider.overrideWith(
            (ref) => _TestAuthNotifier(
              ref.read(authRepositoryProvider),
              const AuthState(status: AuthStatus.authenticated, user: user),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const CajaScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final table = tester.widget<DataTable>(find.byType(DataTable));
    final headings = table.columns
        .map((column) => (column.label as Text).data)
        .toList();
    final cells = table.rows.single.cells;

    expect(headings, [
      'Fecha',
      'Tipo',
      'Concepto',
      'Origen/Método',
      'Monto',
      'Comprobante',
      'Usuario',
    ]);
    expect((cells[0].child as Text).data, startsWith('13/08/2026'));
    expect((cells[2].child as Text).data, 'Opening adjustment');
    expect((cells[4].child as Text).data, '+ S/ 20.00');
    expect(cells[5].child, isNot(isA<SizedBox>()));
    expect((cells[6].child as Text).data, 'cashier');
  });
}
