import 'package:barbeer/core/network/api_client.dart';
import 'package:barbeer/features/auth/data/models/auth_models.dart';
import 'package:barbeer/features/auth/presentation/providers/auth_provider.dart';
import 'package:barbeer/features/operaciones/data/operations_repository.dart';
import 'package:barbeer/features/ventas/presentation/screens/historical_sales_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeOperationsRepository extends OperationsRepository {
  _FakeOperationsRepository() : super(ApiClient.instance);

  final listedPaths = <String>[];

  @override
  Future<OperationsPage> list(
    String path, {
    String? sedeId,
    int page = 1,
    Map<String, dynamic> filters = const {},
  }) async {
    listedPaths.add(path);
    final data = switch (path) {
      '/caja/historial' => [
        {
          'id': 'historical-box-1',
          'abiertaAt': '2026-09-23T00:00:00.000Z',
          'montoApertura': 0,
          'montoDeclaradoCierre': 0,
          'sede': {'nombre': 'Centro'},
        },
      ],
      '/ventas/mias' => [
        {'id': 'sale-1', 'codigo': 'V-1', 'total': 25, 'estado': 'ACTIVA'},
      ],
      _ => throw StateError('Unexpected historical sales list path: $path'),
    };
    return OperationsPage.fromJson({
      'data': data,
      'total': data.length,
      'totalPaginas': 1,
    });
  }
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(super.repository, AuthState value) {
    state = value;
  }
}

Future<_FakeOperationsRepository> _pumpHistoricalSalesScreen(
  WidgetTester tester, {
  required List<String> permissions,
}) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final repository = _FakeOperationsRepository();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        operationsRepositoryProvider.overrideWithValue(repository),
        authProvider.overrideWith(
          (ref) => _TestAuthNotifier(
            ref.read(authRepositoryProvider),
            AuthState(
              status: AuthStatus.authenticated,
              user: UserProfile(
                id: 'seller-1',
                username: 'seller',
                rol: 'VENDEDORA',
                nivel: 10,
                createdAt: '2026-09-01',
                sedeId: 'sede-1',
                permisos: permissions,
              ),
            ),
          ),
        ),
      ],
      child: const MaterialApp(home: HistoricalSalesScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

Future<void> _openExistingBox(WidgetTester tester) async {
  await tester.tap(find.text('Ver caja'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'seller sees existing boxes and own sales without historical management actions',
    (tester) async {
      final repository = await _pumpHistoricalSalesScreen(
        tester,
        permissions: ['ventas:crear', 'ventas:sin-luz', 'ventas:leer-propias'],
      );

      expect(repository.listedPaths, contains('/caja/historial'));
      expect(find.text('Agregar'), findsNothing);
      await _openExistingBox(tester);

      expect(repository.listedPaths, contains('/ventas/mias'));
      expect(repository.listedPaths, isNot(contains('/ventas')));
      expect(
        find.text('Ventas que registraste en esta caja histórica.'),
        findsOneWidget,
      );
      expect(find.text('Agregar'), findsOneWidget);
      expect(find.text('Corregir conteo'), findsNothing);
      expect(find.byTooltip('Anular venta'), findsNothing);
    },
  );

  testWidgets('seller cannot create a historical sale without both grants', (
    tester,
  ) async {
    for (final permissions in [
      ['ventas:sin-luz', 'ventas:leer-propias', 'caja:leer'],
      ['ventas:crear', 'ventas:leer-propias', 'caja:leer'],
    ]) {
      await tester.pumpWidget(const SizedBox.shrink());
      final repository = await _pumpHistoricalSalesScreen(
        tester,
        permissions: permissions,
      );
      expect(repository.listedPaths, contains('/caja/historial'));

      await _openExistingBox(tester);

      expect(find.text('Agregar'), findsNothing);
      expect(find.text('Corregir conteo'), findsNothing);
      expect(find.byTooltip('Anular venta'), findsNothing);
    }
  });
}
