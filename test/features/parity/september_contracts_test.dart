import 'dart:convert';
import 'package:barbeer/core/navigation/route_access_policy.dart';
import 'package:barbeer/core/offline/offline_store.dart';
import 'package:barbeer/core/utils/business_time.dart';
import 'package:barbeer/core/widgets/operation_form.dart';
import 'package:barbeer/features/asistencia/data/asistencia_repository.dart';
import 'package:barbeer/features/ventas/data/models/venta_models.dart';
import 'package:barbeer/features/ventas/presentation/widgets/carrito_venta_sheet.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('historical routes are root-only and payroll reads allow employees', () {
    expect(
      RouteAccessPolicy.canAccess(
        '/ventas-sin-luz',
        role: 'ADMIN',
        permissions: ['ventas:crear'],
      ),
      isFalse,
    );
    expect(
      RouteAccessPolicy.canAccess(
        '/ventas-sin-luz',
        role: 'SUPERADMIN',
        permissions: [],
      ),
      isTrue,
    );
    expect(
      RouteAccessPolicy.canAccess(
        '/pagos/detalle/self',
        role: 'VENDEDORA',
        permissions: [],
      ),
      isTrue,
    );
    expect(
      RouteAccessPolicy.canAccess(
        '/gastos-internos',
        role: 'VENDEDORA',
        permissions: [],
      ),
      isFalse,
    );
    expect(
      RouteAccessPolicy.canAccess(
        '/productos-internos',
        role: 'ADMIN',
        permissions: ['productos-internos:leer'],
      ),
      isTrue,
    );
  });
  test('business dates remain in Peru across UTC midnight', () {
    expect(businessDate(DateTime.parse('2026-09-24T04:59:00Z')), '2026-09-23');
    expect(businessDate(DateTime.parse('2026-09-24T05:00:00Z')), '2026-09-24');
  });
  test('per-item surcharge is fixed rather than multiplied by quantity', () {
    final item = CarritoItem(
      productoId: 'p',
      nombre: 'Producto',
      codigo: 'P',
      precio: 10,
      cantidad: 3,
    )..recargoMonto = 5;
    expect(item.subtotal, 35);
    item.cantidad = 4;
    expect(item.subtotal, 45);
  });
  test('mixed payments and annulled sales are not pending', () {
    expect(
      Venta.fromJson({
        'conciliacion': {'estado': 'MULTIPLE'},
      }).isPendiente,
      isFalse,
    );
    expect(
      Venta.fromJson({
        'estado': 'ANULADA',
        'conciliacion': {'estado': 'PENDIENTE'},
      }).isPendiente,
      isFalse,
    );
  });
  test('shift schedules preserve independent weekday and role values', () {
    final shift = Turno.fromJson({
      'rolId': 'role',
      'horarios': [
        {'diaSemana': 1, 'horaInicio': 1200, 'horaFin': 180, 'activo': true},
        {'diaSemana': 2, 'horaInicio': 480, 'horaFin': 960, 'activo': false},
      ],
    });
    expect(shift.rolId, 'role');
    expect(shift.horarios.last['activo'], isFalse);
    expect(shift.horarios.first['horaFin'], 180);
  });
  test(
    'money validation rejects non-finite, overprecision and negative inputs',
    () {
      for (final value in [
        'NaN',
        'Infinity',
        '-1',
        '1.234',
        '10000000000',
        '',
      ]) {
        expect(moneyValidator(value), isNotNull);
      }
      expect(moneyValidator('12,50'), isNull);
      expect(moneyValidator('0', allowZero: true), isNull);
    },
  );
  test(
    'recovery survives a new store and strips PIN without crossing users',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final store = OfflineStore();
      final payload = CreateVentaPayload(
        idempotencyKey: 'sale',
        items: [
          {'productoId': 'p', 'cantidad': 2},
        ],
        estadoConciliacion: EstadoConciliacion.efectivo,
        cuentaCargos: [
          {'cuentaId': 'a', 'monto': 5},
        ],
      );
      await store.record(
        'owner-a',
        payload.withEphemeralPin('never-store').json,
        'PENDING',
      );
      final records = await OfflineStore().sales('owner-a');
      expect(jsonEncode(records), isNot(contains('never-store')));
      expect(records.single['payload']['idempotencyKey'], 'sale');
      expect(await store.sales('owner-b'), isEmpty);
      await store.record('owner-a', payload.json, 'SYNCED');
      expect((await store.sales('owner-a')).single['status'], 'SYNCED');
      expect(payload.json.containsKey('superadminPin'), isFalse);
    },
  );
  test(
    'command retries retain one identity and immutable original data',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final store = OfflineStore();
      final data = <String, dynamic>{'monto': 12.5};
      final first = await store.stageCommand(
        'owner',
        'POST',
        '/gastos-internos',
        data,
      );
      data['monto'] = 99;
      final retry = await store.stageCommand(
        'owner',
        'POST',
        '/gastos-internos',
        {'monto': 12.5},
      );
      expect(retry['idempotencyKey'], first['idempotencyKey']);
      expect(
        (await store.sales('owner')).single['payload']['data']['monto'],
        12.5,
      );
      expect(OfflineStore.canQueue('POST', '/auth/login'), isFalse);
      expect(OfflineStore.canQueue('POST', '/ventas/validar-clave'), isFalse);
      expect(OfflineStore.canQueue('POST', '/asistencia/marcar'), isFalse);
      expect(OfflineStore.canQueue('POST', '/productos/p-1/stock'), isFalse);
      expect(OfflineStore.canCache('/asistencia/qr-kiosco'), isFalse);
    },
  );
}
