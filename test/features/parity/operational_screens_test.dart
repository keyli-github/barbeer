import 'package:barbeer/core/network/api_client.dart';
import 'package:barbeer/core/theme/app_theme.dart';
import 'package:barbeer/features/auth/data/models/auth_models.dart';
import 'package:barbeer/features/auth/presentation/providers/auth_provider.dart';
import 'package:barbeer/features/gastos_internos/presentation/gastos_internos_screen.dart';
import 'package:barbeer/features/operaciones/data/operations_repository.dart';
import 'package:barbeer/features/pagos/presentation/pagos_screen.dart';
import 'package:barbeer/features/productos_internos/presentation/productos_internos_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Auth extends AuthNotifier {
  _Auth(super.repository, List<String> permissions) {
    state = AuthState(
      status: AuthStatus.authenticated,
      user: UserProfile(
        id: 'u',
        username: 'Employee',
        rol: 'ADMIN',
        nivel: 50,
        sedeId: 'sede',
        createdAt: '',
        permisos: permissions,
      ),
    );
  }
}

class _Repository extends OperationsRepository {
  _Repository() : super(ApiClient.instance);
  final writes = <OperationJson>[];
  @override
  Future<OperationsPage> list(
    String path, {
    String? sedeId,
    int page = 1,
    Map<String, dynamic> filters = const {},
  }) async => OperationsPage.fromJson({
    'total': 1,
    'totalPaginas': 1,
    'totalMonto': '15.50',
    'data': [
      if (path == '/pagos')
        {
          'id': 'u',
          'username': 'Empleado de prueba',
          'sede': {'nombre': 'Sede principal'},
          'rol': {'nombre': 'CAJERO'},
          'resumen': {'totalNetoPendiente': 100},
          'cuentaPorCobrar': {'saldo': 10},
        }
      else if (path == '/productos-internos')
        {
          'id': 'asset',
          'nombre': 'Mesa de madera del salón principal',
          'cantidad': 4,
          'costo': '350.00',
          'estado': 'OPERATIVO',
          'sede': {'nombre': 'Sede principal'},
        }
      else
        {
          'id': 'expense',
          'motivo': 'Reposición de materiales para mantenimiento',
          'monto': '15.50',
          'fecha': '2026-09-23',
          'destino': 'GENERAL',
          'sede': {'nombre': 'Sede principal'},
        },
    ],
  });
  @override
  Future<List<OperationJson>> expenseStaff(String sedeId) async => [];
  @override
  Future<OperationJson> expenseDestination(String sedeId, String date) async =>
      {
        'caja': {'disponible': true},
      };
  @override
  Future<OperationJson> create(String path, OperationJson data) async {
    writes.add({'path': path, ...data});
    return {};
  }
}

void main() {
  for (final width in [320.0, 390.0, 768.0, 1280.0]) {
    for (final entry in <String, Widget>{
      'payroll': const PagosScreen(),
      'expenses': const GastosInternosScreen(),
      'assets': const ProductosInternosScreen(),
    }.entries) {
      testWidgets('${entry.key} fits $width with enlarged text', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(
                (ref) => _Auth(ref.read(authRepositoryProvider), []),
              ),
              operationsRepositoryProvider.overrideWithValue(_Repository()),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!,
              ),
              home: entry.value,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(Card), findsWidgets);
        expect(find.byType(FloatingActionButton), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets(
    'expense form validates and sends selected scope and decimal amount',
    (tester) async {
      final repository = _Repository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(
              (ref) => _Auth(ref.read(authRepositoryProvider), [
                'gastos-internos:leer',
                'gastos-internos:crear',
              ]),
            ),
            operationsRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const GastosInternosScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agregar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar'));
      await tester.pump();
      expect(repository.writes, isEmpty);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Motivo'),
        'Materiales',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Monto (S/)'),
        '12,50',
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(repository.writes.single, containsPair('sedeId', 'sede'));
      expect(repository.writes.single, containsPair('monto', 12.5));
      expect(repository.writes.single, containsPair('destino', 'GENERAL'));
      expect(tester.takeException(), isNull);
    },
  );
}
