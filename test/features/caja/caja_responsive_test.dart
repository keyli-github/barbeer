import 'package:barbeer/core/network/api_client.dart';
import 'package:barbeer/core/theme/app_theme.dart';
import 'package:barbeer/features/auth/data/models/auth_models.dart';
import 'package:barbeer/features/auth/presentation/providers/auth_provider.dart';
import 'package:barbeer/features/caja/data/caja_repository.dart';
import 'package:barbeer/features/caja/presentation/providers/caja_provider.dart';
import 'package:barbeer/features/caja/presentation/screens/caja_screen.dart';
import 'package:barbeer/features/caja/presentation/widgets/caja_arqueo_sheets.dart';
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

const _cashViewports = <({String name, TargetPlatform platform, Size size})>[
  (
    name: 'Android mobile',
    platform: TargetPlatform.android,
    size: Size(390, 844),
  ),
  (
    name: 'Windows desktop',
    platform: TargetPlatform.windows,
    size: Size(1440, 1000),
  ),
];

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
}

void _expectNineDenominationFields(
  WidgetTester tester, {
  required String keyPrefix,
  required String reason,
}) {
  final fields = find.byWidgetPredicate((widget) {
    if (widget is! TextFormField || widget.key is! ValueKey<String>) {
      return false;
    }
    return (widget.key! as ValueKey<String>).value.startsWith(keyPrefix);
  });

  expect(fields, findsNWidgets(9), reason: reason);
  expect(find.byKey(ValueKey('${keyPrefix}0.2')), findsNothing, reason: reason);
  expect(find.byKey(ValueKey('${keyPrefix}0.1')), findsNothing, reason: reason);
}

Widget _openingScreenHarness(TargetPlatform platform) {
  const user = UserProfile(
    id: 'cashier-1',
    username: 'cashier',
    rol: 'CAJERO',
    nivel: 30,
    sedeId: 'branch-1',
    createdAt: '2026-09-01',
    permisos: ['caja:aperturar'],
  );

  return ProviderScope(
    overrides: [
      cajaProvider.overrideWith(
        (ref) => _StaticCajaNotifier(CajaState(sedeId: 'branch-1')),
      ),
      authProvider.overrideWith(
        (ref) => _TestAuthNotifier(
          ref.read(authRepositoryProvider),
          const AuthState(status: AuthStatus.authenticated, user: user),
        ),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme.copyWith(platform: platform),
      home: const CajaScreen(),
    ),
  );
}

CajaSesion _openCashSession() => CajaSesion(
  id: 'session-1',
  estado: 'ABIERTA',
  version: 'V2',
  cierreForzado: false,
  sedeId: 'branch-1',
  sede: 'Main branch',
  montoApertura: 100,
  abiertaAt: DateTime(2026, 8, 13, 8),
  usuarioApertura: 'cashier',
  usuarioAperturaId: 'cashier-1',
  denominaciones: const [],
);

Widget _cashSheetHarness(TargetPlatform platform, {required bool close}) =>
    ProviderScope(
      overrides: [
        cajaProvider.overrideWith(
          (ref) => _StaticCajaNotifier(
            CajaState(actual: _openCashSession(), sedeId: 'branch-1'),
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme.copyWith(platform: platform),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                key: const ValueKey('launch-cash-sheet'),
                onPressed: () {
                  if (close) {
                    showCierreSheet(
                      context,
                      canForzar: false,
                      onSuccess: () {},
                    );
                  } else {
                    showPrecuadreSheet(context, onSuccess: () {});
                  }
                },
                child: const Text('Launch cash sheet'),
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets(
    'opening cash controls show nine denominations on mobile and desktop',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final viewport in _cashViewports) {
        _setViewport(tester, viewport.size);
        await tester.pumpWidget(_openingScreenHarness(viewport.platform));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Abrir caja'));
        await tester.pumpAndSettle();

        expect(
          find.text('Conteo obligatorio de las 9 denominaciones PEN'),
          findsOneWidget,
          reason: viewport.name,
        );
        _expectNineDenominationFields(
          tester,
          keyPrefix: 'apertura-denominacion-',
          reason: viewport.name,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'precuadre and close controls show nine denominations on mobile and desktop',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final viewport in _cashViewports) {
        for (final close in [false, true]) {
          _setViewport(tester, viewport.size);
          await tester.pumpWidget(
            _cashSheetHarness(viewport.platform, close: close),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(const ValueKey('launch-cash-sheet')));
          await tester.pumpAndSettle();

          _expectNineDenominationFields(
            tester,
            keyPrefix: 'caja-denominacion-',
            reason: '${viewport.name}, ${close ? 'close' : 'precuadre'}',
          );

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        }
      }
    },
  );

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
      'Acción',
    ]);
    expect((cells[0].child as Text).data, startsWith('13/08/2026'));
    expect((cells[2].child as Text).data, 'Opening adjustment');
    expect((cells[4].child as Text).data, '+ S/ 20.00');
    expect(cells[5].child, isNot(isA<SizedBox>()));
    expect((cells[6].child as Text).data, 'cashier');
    expect(
      find.byKey(const ValueKey('cash-movement-annul-movement-1')),
      findsOneWidget,
    );
  });
}
