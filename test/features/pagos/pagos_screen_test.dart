import 'dart:async';

import 'package:barbeer/core/errors/app_exception.dart';
import 'package:barbeer/core/network/api_client.dart';
import 'package:barbeer/core/offline/offline_store.dart';
import 'package:barbeer/features/auth/data/models/auth_models.dart';
import 'package:barbeer/features/auth/presentation/providers/auth_provider.dart';
import 'package:barbeer/features/operaciones/data/operations_repository.dart';
import 'package:barbeer/features/pagos/presentation/manual_recargo_rules.dart';
import 'package:barbeer/features/pagos/presentation/pagos_screen.dart';
import 'package:barbeer/features/recargo/data/recargo_control_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

OperationJson _employee({List<OperationJson> manualSurcharges = const []}) => {
  'id': 'employee-1',
  'username': 'Luna',
  'rol': {'nombre': 'CAJERA'},
  'sede': {'nombre': 'Centro'},
  'configuracion': {'periodicidad': 'MENSUAL', 'montoBase': 1000},
  'periodo': {'inicio': '2026-09-01', 'fin': '2026-09-30'},
  'cuentaPorCobrar': {'saldo': 0},
  'resumen': {
    'montoBase': 1000,
    'bonos': 0,
    'recargos': 0,
    'recargosIncluidos': 0,
    'ajustes': 0,
    'totalNetoPendiente': 1000,
    'total': 1000,
  },
  'bonos': <OperationJson>[],
  'ajustes': <OperationJson>[],
  'recargos': <OperationJson>[],
  'recargosManuales': manualSurcharges,
  'pagoPeriodo': null,
  'liquidaciones': <OperationJson>[],
};

OperationJson _manualSurcharge({String id = 'manual-1'}) => {
  'id': id,
  'monto': 25.5,
  'motivo': 'Turno adicional',
  'fecha': '2026-09-12T17:00:00.000Z',
  'creadoPor': {'username': 'Administradora'},
};

class _FakeOperationsRepository extends OperationsRepository {
  _FakeOperationsRepository({
    this.createError,
    this.removeError,
    this.createCompleter,
    this.removeCompleter,
    List<OperationJson> manualSurcharges = const [],
  }) : super(ApiClient.instance) {
    employee = _employee(manualSurcharges: manualSurcharges);
  }

  late OperationJson employee;
  final Object? createError;
  final Object? removeError;
  final Completer<void>? createCompleter;
  final Completer<void>? removeCompleter;
  int listCalls = 0;
  int detailCalls = 0;
  int createCalls = 0;
  int removeCalls = 0;
  OperationJson? lastCreatedPayload;
  String? lastRemovedId;

  @override
  Future<OperationsPage> list(
    String path, {
    String? sedeId,
    int page = 1,
    Map<String, dynamic> filters = const {},
  }) async {
    if (path != '/pagos') throw StateError('Unexpected list path: $path');
    listCalls++;
    return OperationsPage.fromJson({
      'data': [employee],
      'total': 1,
      'totalPaginas': 1,
    });
  }

  @override
  Future<OperationJson> detail(String path) async {
    if (path != '/pagos/employee-1') {
      throw StateError('Unexpected detail path: $path');
    }
    detailCalls++;
    return Map<String, dynamic>.from(employee);
  }

  @override
  Future<OperationJson> createManualRecargo({
    required String usuarioId,
    required double monto,
    required String motivo,
    required String fecha,
  }) async {
    createCalls++;
    lastCreatedPayload = {
      'usuarioId': usuarioId,
      'monto': monto,
      'motivo': motivo,
      'fecha': fecha,
    };
    if (createCompleter != null) await createCompleter!.future;
    if (createError != null) throw createError!;
    final created = {
      'id': 'manual-created',
      'monto': monto,
      'motivo': motivo,
      'fecha': '${fecha}T17:00:00.000Z',
      'creadoPor': {'username': 'Administradora'},
    };
    employee['recargosManuales'] = [
      ...objectList(employee['recargosManuales']),
      created,
    ];
    return {'id': 'manual-created'};
  }

  @override
  Future<void> removeManualRecargo(String recargoId) async {
    removeCalls++;
    lastRemovedId = recargoId;
    if (removeCompleter != null) await removeCompleter!.future;
    if (removeError != null) throw removeError!;
    employee['recargosManuales'] = objectList(
      employee['recargosManuales'],
    ).where((item) => item['id'] != recargoId).toList();
  }
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(super.repository, AuthState value) {
    state = value;
  }
}

AuthState _auth({
  String role = 'ADMIN',
  List<String> permissions = const ['pagos:gestionar'],
}) => AuthState(
  status: AuthStatus.authenticated,
  user: UserProfile(
    id: 'manager-1',
    username: 'manager',
    rol: role,
    nivel: 10,
    sedeId: 'branch-1',
    sede: 'Centro',
    createdAt: '2026-09-01',
    permisos: permissions,
  ),
);

Future<void> _pumpPayroll(
  WidgetTester tester, {
  required _FakeOperationsRepository repository,
  required Size size,
  String role = 'ADMIN',
  List<String> permissions = const ['pagos:gestionar'],
  bool oculto = false,
  TargetPlatform platform = TargetPlatform.android,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        operationsRepositoryProvider.overrideWithValue(repository),
        payrollRecargoStatusProvider.overrideWith(
          (ref) async => RecargoControlData(oculto: oculto),
        ),
        authProvider.overrideWith(
          (ref) => _TestAuthNotifier(
            ref.read(authRepositoryProvider),
            _auth(role: role, permissions: permissions),
          ),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        home: const PagosScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openEmployeeDetail(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Ver detalle →'));
  await tester.tap(find.text('Ver detalle →'));
  await tester.pumpAndSettle();
}

Future<void> _openManualRecargoForm(WidgetTester tester) async {
  final action = find.byKey(const ValueKey('manual-recargo-add-employee-1'));
  await tester.ensureVisible(action);
  await tester.tap(action);
  await tester.pumpAndSettle();
}

Future<void> _fillManualRecargoForm(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey('manual-recargo-amount')),
    '12.50',
  );
  await tester.enterText(
    find.byKey(const ValueKey('manual-recargo-reason')),
    '  Turno de apoyo  ',
  );
}

void main() {
  group('Manual payroll recargo rules', () {
    test('validates dates against server-provided inclusive period bounds', () {
      final period = ManualRecargoPeriod.tryParse('2026-09-01', '2026-09-15')!;

      expect(period.validateDate('2026-09-01'), isNull);
      expect(period.validateDate('2026-09-15'), isNull);
      expect(period.validateDate('2026-08-31'), isNotNull);
      expect(period.validateDate('2026-09-16'), isNotNull);
      expect(period.validateDate('2026-02-30'), isNotNull);
      expect(ManualRecargoPeriod.tryParse('2026-02-30', '2026-03-01'), isNull);
    });

    test('chooses a Lima date clamped to the current payroll period', () {
      final period = ManualRecargoPeriod.tryParse('2026-09-01', '2026-09-15')!;

      expect(
        period.initialDateKey(now: DateTime.utc(2026, 9, 20, 12)),
        '2026-09-15',
      );
      expect(
        period.initialDateKey(now: DateTime.utc(2026, 9, 10, 12)),
        '2026-09-10',
      );
    });

    test('only treats non-4xx mutation failures as uncertain', () {
      expect(manualRecargoOutcomeIsUncertain(const NetworkException()), isTrue);
      expect(
        manualRecargoOutcomeIsUncertain(
          const AppException(message: 'Server error', statusCode: 500),
        ),
        isTrue,
      );
      expect(
        manualRecargoOutcomeIsUncertain(
          const AppException(message: 'Invalid date', statusCode: 400),
        ),
        isFalse,
      );
    });
  });

  group('Manual payroll recargo API contract', () {
    test(
      'posts the DTO payload and deletes through the manual recargo route',
      () async {
        final requests =
            <({String method, String path, OperationJson? data})>[];
        final repository = OperationsRepository(
          ApiClient.instance,
          payrollRecargoRequest: (method, path, data) async {
            requests.add((method: method, path: path, data: data));
            return method == 'POST'
                ? {'id': 'manual-1'}
                : {'message': 'Retirado'};
          },
        );

        final created = await repository.createManualRecargo(
          usuarioId: 'employee-1',
          monto: 12.5,
          motivo: 'Turno de apoyo',
          fecha: '2026-09-12',
        );
        await repository.removeManualRecargo('manual-1');

        expect(created, {'id': 'manual-1'});
        expect(requests.map((request) => request.method), ['POST', 'DELETE']);
        expect(requests.map((request) => request.path), [
          '/pagos/employee-1/recargos',
          '/pagos/recargos/manual-1',
        ]);
        expect(requests.first.data, {
          'monto': 12.5,
          'motivo': 'Turno de apoyo',
          'fecha': '2026-09-12',
        });
        expect(requests.last.data, isNull);
      },
    );

    test('excludes manual recargos without blocking payroll bonuses', () {
      expect(
        OfflineStore.canQueue('POST', '/pagos/employee-1/recargos'),
        isFalse,
      );
      expect(
        OfflineStore.canQueue('DELETE', '/pagos/recargos/manual-1'),
        isFalse,
      );
      expect(OfflineStore.canQueue('POST', '/pagos/employee-1/bonos'), isTrue);
    });
  });

  group('Manual payroll recargo UI', () {
    testWidgets('requires payroll management permission, except SUPERADMIN', (
      tester,
    ) async {
      final repository = _FakeOperationsRepository();
      await _pumpPayroll(
        tester,
        repository: repository,
        size: const Size(390, 844),
        role: 'VENDEDORA',
        permissions: const [],
      );
      await _openEmployeeDetail(tester);
      expect(
        find.byKey(const ValueKey('manual-recargo-add-employee-1')),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await _pumpPayroll(
        tester,
        repository: _FakeOperationsRepository(),
        size: const Size(390, 844),
        role: 'SUPERADMIN',
        permissions: const [],
      );
      await _openEmployeeDetail(tester);
      final action = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('manual-recargo-add-employee-1')),
      );
      expect(action.onPressed, isNotNull);
    });

    testWidgets('blocks manual recargos while the backend marks them hidden', (
      tester,
    ) async {
      await _pumpPayroll(
        tester,
        repository: _FakeOperationsRepository(),
        size: const Size(390, 844),
        oculto: true,
      );
      await _openEmployeeDetail(tester);

      final action = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('manual-recargo-add-employee-1')),
      );
      expect(action.onPressed, isNull);
      expect(find.textContaining('Los recargos están ocultos'), findsOneWidget);
    });

    testWidgets('keeps existing payroll management actions available', (
      tester,
    ) async {
      await _pumpPayroll(
        tester,
        repository: _FakeOperationsRepository(),
        size: const Size(1280, 900),
        platform: TargetPlatform.windows,
        permissions: const ['pagos:gestionar', 'caja:movimientos'],
      );
      await _openEmployeeDetail(tester);

      for (final label in [
        'Configurar sueldo',
        'Bono',
        'Adelanto',
        'Descuento',
        'Multa',
        'Liquidar periodo',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Liquidar periodo'),
            )
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('validates amount and reason before sending a POST', (
      tester,
    ) async {
      final repository = _FakeOperationsRepository();
      await _pumpPayroll(
        tester,
        repository: repository,
        size: const Size(390, 844),
      );
      await _openEmployeeDetail(tester);
      await _openManualRecargoForm(tester);

      await tester.enterText(
        find.byKey(const ValueKey('manual-recargo-amount')),
        '0',
      );
      await tester.enterText(
        find.byKey(const ValueKey('manual-recargo-reason')),
        '   ',
      );
      await tester.tap(find.text('Agregar recargo'));
      await tester.pumpAndSettle();

      expect(find.text('Ingresa un monto mayor a 0'), findsOneWidget);
      expect(find.text('Este campo es obligatorio'), findsOneWidget);
      expect(repository.createCalls, 0);
    });

    testWidgets('submits once, gives feedback, and refreshes payroll', (
      tester,
    ) async {
      final repository = _FakeOperationsRepository();
      await _pumpPayroll(
        tester,
        repository: repository,
        size: const Size(390, 844),
      );
      await _openEmployeeDetail(tester);
      final detailCallsBefore = repository.detailCalls;
      await _openManualRecargoForm(tester);
      await _fillManualRecargoForm(tester);
      final selectedDate = tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('manual-recargo-date')),
          )
          .controller!
          .text;

      await tester.tap(find.text('Agregar recargo'));
      await tester.pumpAndSettle();

      expect(repository.createCalls, 1);
      expect(repository.lastCreatedPayload, {
        'usuarioId': 'employee-1',
        'monto': 12.5,
        'motivo': 'Turno de apoyo',
        'fecha': selectedDate,
      });
      expect(repository.detailCalls, greaterThan(detailCallsBefore));
      expect(
        find.text('Recargo manual agregado al pago del período.'),
        findsOneWidget,
      );
      expect(find.text('Recargo manual · Turno de apoyo'), findsOneWidget);
    });

    testWidgets('disables submit while the POST is pending', (tester) async {
      final pending = Completer<void>();
      final repository = _FakeOperationsRepository(createCompleter: pending);
      await _pumpPayroll(
        tester,
        repository: repository,
        size: const Size(390, 844),
      );
      await _openEmployeeDetail(tester);
      await _openManualRecargoForm(tester);
      await _fillManualRecargoForm(tester);

      await tester.tap(find.text('Agregar recargo'));
      await tester.pump();
      expect(find.text('Guardando…'), findsOneWidget);
      expect(repository.createCalls, 1);

      await tester.tap(find.byType(FilledButton).last);
      await tester.pump();
      expect(repository.createCalls, 1);

      pending.complete();
      await tester.pumpAndSettle();
      expect(
        find.text('Recargo manual agregado al pago del período.'),
        findsOneWidget,
      );
      expect(repository.createCalls, 1);
    });

    testWidgets('refreshes and blocks another POST after an uncertain result', (
      tester,
    ) async {
      final repository = _FakeOperationsRepository(
        createError: const NetworkException(),
      );
      await _pumpPayroll(
        tester,
        repository: repository,
        size: const Size(390, 844),
      );
      await _openEmployeeDetail(tester);
      final detailCallsBefore = repository.detailCalls;
      await _openManualRecargoForm(tester);
      await _fillManualRecargoForm(tester);
      await tester.tap(find.text('Agregar recargo'));
      await tester.pumpAndSettle();

      expect(repository.createCalls, 1);
      expect(repository.detailCalls, greaterThan(detailCallsBefore));
      expect(
        find.text(
          'No se pudo confirmar el resultado. Revisa la nómina y no repitas el envío.',
        ),
        findsOneWidget,
      );
      final action = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('manual-recargo-add-employee-1')),
      );
      expect(action.onPressed, isNull);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await _openEmployeeDetail(tester);
      final reopenedAction = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('manual-recargo-add-employee-1')),
      );
      expect(reopenedAction.onPressed, isNull);
      expect(repository.createCalls, 1);
    });

    testWidgets('removes unpaid manual recargos with feedback and refresh', (
      tester,
    ) async {
      final repository = _FakeOperationsRepository(
        manualSurcharges: [_manualSurcharge()],
      );
      await _pumpPayroll(
        tester,
        repository: repository,
        size: const Size(1280, 900),
        platform: TargetPlatform.windows,
      );
      await _openEmployeeDetail(tester);
      final detailCallsBefore = repository.detailCalls;
      final removeFinder = find.byKey(
        const ValueKey('manual-recargo-remove-manual-1'),
      );
      await tester.ensureVisible(removeFinder);
      expect(tester.widget<IconButton>(removeFinder).onPressed, isNotNull);
      await tester.tap(removeFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(repository.removeCalls, 1);
      expect(repository.lastRemovedId, 'manual-1');
      expect(repository.detailCalls, greaterThan(detailCallsBefore));
      expect(find.text('Recargo manual retirado.'), findsOneWidget);
      expect(find.text('Recargo manual · Turno adicional'), findsNothing);
    });

    testWidgets('disables removal while the DELETE is pending', (tester) async {
      final pending = Completer<void>();
      final repository = _FakeOperationsRepository(
        removeCompleter: pending,
        manualSurcharges: [_manualSurcharge()],
      );
      await _pumpPayroll(
        tester,
        repository: repository,
        size: const Size(1280, 900),
        platform: TargetPlatform.windows,
      );
      await _openEmployeeDetail(tester);
      final removeFinder = find.byKey(
        const ValueKey('manual-recargo-remove-manual-1'),
      );
      await tester.tap(removeFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pump();

      expect(repository.removeCalls, 1);
      expect(tester.widget<IconButton>(removeFinder).onPressed, isNull);

      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Recargo manual retirado.'), findsOneWidget);
      expect(repository.removeCalls, 1);
    });

    testWidgets('blocks a repeated DELETE after an uncertain result', (
      tester,
    ) async {
      final repository = _FakeOperationsRepository(
        removeError: const NetworkException(),
        manualSurcharges: [_manualSurcharge()],
      );
      await _pumpPayroll(
        tester,
        repository: repository,
        size: const Size(1280, 900),
        platform: TargetPlatform.windows,
      );
      await _openEmployeeDetail(tester);
      final removeFinder = find.byKey(
        const ValueKey('manual-recargo-remove-manual-1'),
      );
      expect(tester.widget<IconButton>(removeFinder).onPressed, isNotNull);
      await tester.tap(removeFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(repository.removeCalls, 1);
      expect(find.textContaining('no repitas la operación'), findsOneWidget);
      final remove = tester.widget<IconButton>(
        find.byKey(const ValueKey('manual-recargo-remove-manual-1')),
      );
      expect(remove.onPressed, isNull);
    });

    testWidgets('fits the manual recargo form at 390 and 1280 pixels', (
      tester,
    ) async {
      for (final viewport in [
        (size: const Size(390, 844), platform: TargetPlatform.android),
        (size: const Size(1280, 900), platform: TargetPlatform.windows),
      ]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await _pumpPayroll(
          tester,
          repository: _FakeOperationsRepository(),
          size: viewport.size,
          platform: viewport.platform,
        );
        await _openEmployeeDetail(tester);
        await _openManualRecargoForm(tester);

        expect(
          find.byKey(const ValueKey('manual-recargo-amount')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('manual-recargo-reason')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('manual-recargo-date')),
          findsOneWidget,
        );
        if (viewport.size.width < 1024) {
          expect(find.byType(Dialog), findsNothing);
        } else {
          expect(find.byType(Dialog), findsWidgets);
        }
        expect(tester.takeException(), isNull);
      }
    });
  });
}
