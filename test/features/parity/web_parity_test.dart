import 'package:barbeer/features/auditoria/presentation/screens/auditoria_screen.dart';
import 'package:barbeer/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:barbeer/features/kardex/data/kardex_repository.dart';
import 'package:barbeer/features/roles/presentation/screens/roles_screen.dart';
import 'package:barbeer/features/usuarios/presentation/screens/usuarios_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('audit username reads the nested usuario response', () {
    expect(
      auditUsername({
        'usuario': {'id': 'user-1', 'username': 'maria'},
      }),
      'maria',
    );
    expect(auditUsername({'usuario': null}), 'Sistema');
  });

  test('audit dates preserve the selected civil day at UTC-5', () {
    final civil = auditCivilDate('2026-08-13T05:00:00.000Z');

    expect(auditCivilDateString(civil!), '2026-08-13');
    expect(
      auditApiDate(civil, utcOffset: const Duration(hours: -5)),
      '2026-08-13T05:00:00.000Z',
    );
    expect(
      auditApiDate(civil, endOfDay: true, utcOffset: const Duration(hours: -5)),
      '2026-08-14T04:59:59.999Z',
    );
  });

  test('sale and annulment kardex types have correct semantics', () {
    expect(kardexIsSalida('SALIDA_VENTA'), isTrue);
    expect(kardexIsEntrada('SALIDA_VENTA'), isFalse);
    expect(kardexTipoLabel('SALIDA_VENTA'), 'VENTA');
    expect(kardexIsEntrada('ENTRADA_ANULACION'), isTrue);
    expect(kardexIsSalida('ENTRADA_ANULACION'), isFalse);
    expect(kardexTipoLabel('ENTRADA_ANULACION'), 'ANULACIÓN');
  });

  test('dashboard parses codigoSede and retains explicit module errors', () {
    final sede = DashboardSede.fromMap({
      'id': 'sede-1',
      'nombre': 'Centro',
      'codigoSede': 'CENT',
      'activo': true,
    });
    const data = DashboardData(errors: {'inventario': 'Sin conexión'});

    expect(sede.codigoSede, 'CENT');
    expect(data.hasError('inventario'), isTrue);
    expect(data.hasError('productos'), isFalse);
  });

  test('roles parse nested permission assignments without losing ids', () {
    expect(
      rolePermissionIds({
        'permisos': [
          {
            'permiso': {'id': 'p-1', 'nombre': 'ventas:leer'},
          },
          {'id': 'p-2'},
        ],
      }),
      {'p-1', 'p-2'},
    );
  });

  test('password policy and assignable roles match backend hierarchy', () {
    expect(passwordMeetsBackendPolicy('abc123'), isTrue);
    expect(passwordMeetsBackendPolicy('ABC123'), isFalse);
    expect(passwordMeetsBackendPolicy('abcde'), isFalse);
    expect(
      assignableRoles(
        [
          {'id': '1', 'nombre': 'SUPERADMIN', 'nivel': 100, 'activo': true},
          {'id': '2', 'nombre': 'ADMIN', 'nivel': 50, 'activo': true},
          {'id': '3', 'nombre': 'CAJERO', 'nivel': 10, 'activo': true},
          {'id': '4', 'nombre': 'INACTIVO', 'nivel': 5, 'activo': false},
        ],
        50,
        isSuperAdmin: false,
      ).map((role) => role['nombre']),
      ['CAJERO'],
    );
  });

  test('editing keeps the current inactive sede in the dropdown', () {
    final sedes = editableSedesForUser(
      [
        {'id': 'active', 'nombre': 'Centro', 'activo': true},
      ],
      {
        'sede': {'id': 'inactive', 'nombre': 'Norte', 'activo': false},
      },
    );

    expect(sedes.map((sede) => sede['id']), ['active', 'inactive']);
  });
}
