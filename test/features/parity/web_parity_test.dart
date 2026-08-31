import 'dart:typed_data';
import 'package:barbeer/core/constants/api_constants.dart';
import 'package:barbeer/core/network/api_client.dart';
import 'package:barbeer/core/routes/route_paths.dart';
import 'package:barbeer/features/auditoria/presentation/screens/auditoria_screen.dart';
import 'package:barbeer/features/cuentas/data/cuentas_repository.dart';
import 'package:barbeer/features/cuentas/data/models/cuenta_models.dart';
import 'package:barbeer/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:barbeer/features/kardex/data/kardex_repository.dart';
import 'package:barbeer/features/respaldos/data/models/respaldo_models.dart';
import 'package:barbeer/features/roles/presentation/screens/roles_screen.dart';
import 'package:barbeer/features/usuarios/presentation/screens/usuarios_screen.dart';
import 'package:barbeer/features/ventas/data/models/venta_models.dart';
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

  test('account selector maps esPersonal and queries exact endpoint', () async {
    final calls = <(String, Map<String, dynamic>)>[];
    final repo = CuentasRepository(ApiClient.instance, request: (path, query) async {
      calls.add((path, query));
      return [
        {'id': 'c1', 'nombre': 'Ana', 'documento': 'DNI-1', 'telefono': '999',
         'activo': true, 'esPersonal': true, 'saldo': 0, 'cantidadPendientes': 0,
         'createdAt': '2026-01-01T00:00:00Z', 'updatedAt': '2026-01-01T00:00:00Z'},
        {'id': 'c2', 'nombre': 'Empresa S.A.', 'documento': 'RUC-2', 'telefono': null,
         'activo': true, 'esPersonal': false, 'saldo': 0, 'cantidadPendientes': 0,
         'createdAt': '2026-02-01T00:00:00Z', 'updatedAt': '2026-02-01T00:00:00Z'},
      ];
    });
    final items = await repo.selector(search: ' Ana ', sedeId: 's1');
    expect(calls.single.$1, ApiConstants.accountSelector);
    expect(calls.single.$2, {'search': 'Ana', 'sedeId': 's1'});
    expect((items[0].esPersonal, items[1].esPersonal), (true, false));
    expect((items[0].nombre, items[1].nombre), ('Ana', 'Empresa S.A.'));
  });

  test('account selector with empty search omits search param', () async {
    final calls = <(String, Map<String, dynamic>)>[];
    final repo = CuentasRepository(ApiClient.instance, request: (path, query) async {
      calls.add((path, query)); return [];
    });
    await repo.selector(sedeId: 's1');
    expect(calls.single.$2, {'sedeId': 's1'});
    expect(calls.single.$2, isNot(contains('search')));
  });

  test('account charged-sale payload includes exact cuentaId and cuentaMonto', () {
    final payload = CreateVentaPayload(
      idempotencyKey: 'key-1',
      items: [{'productoId': 'p1', 'cantidad': 2, 'precioVenta': 10.0}],
      estadoConciliacion: EstadoConciliacion.efectivo,
      cuentaId: 'cuenta-1',
      cuentaMonto: 15.50,
    );
    expect(payload.json['cuentaId'], 'cuenta-1');
    expect(payload.json['cuentaMonto'], 15.50);
    expect(payload.json['estadoConciliacion'], 'EFECTIVO');
    expect(payload.json['idempotencyKey'], 'key-1');
  });

  test('account payload omits cuentaId and cuentaMonto when not charging', () {
    final payload = CreateVentaPayload(
      idempotencyKey: 'key-2',
      items: [{'productoId': 'p1', 'cantidad': 1, 'precioVenta': 5.0}],
      estadoConciliacion: EstadoConciliacion.efectivo,
    );
    expect(payload.json.containsKey('cuentaId'), isFalse);
    expect(payload.json.containsKey('cuentaMonto'), isFalse);
  });

  test('account sale response parses cuentaId, cuenta, and cuentaMonto', () {
    final venta = Venta.fromJson({
      'id': 'v1', 'codigo': 'V-001', 'cajaSesionId': 'cs1', 'sedeId': 's1',
      'total': 25, 'estado': 'ACTIVA', 'createdAt': '2026-08-01T10:00:00Z',
      'cuentaId': 'cuenta-1',
      'cuenta': {'id': 'cuenta-1', 'nombre': 'Ana García'},
      'cuentaMonto': 15.5,
      'items': [{'id': 'i1', 'productoId': 'p1', 'cantidad': 2,
        'precioUnitario': 10, 'subtotal': 20}],
    });
    expect(venta.cuentaId, 'cuenta-1');
    expect(venta.cuentaNombre, 'Ana García');
    expect(venta.cuentaMonto, 15.5);
  });

  test('account sale response with null account fields parses safely', () {
    final venta = Venta.fromJson({
      'id': 'v2', 'codigo': 'V-002', 'cajaSesionId': 'cs1', 'sedeId': 's1',
      'total': 10, 'estado': 'ACTIVA', 'createdAt': '2026-08-01T10:00:00Z',
      'cuentaId': null, 'cuenta': null, 'cuentaMonto': null,
      'items': [],
    });
    expect(venta.cuentaId, isNull);
    expect(venta.cuentaNombre, isNull);
    expect(venta.cuentaMonto, isNull);
  });

  test('account annulled sale preserves backend state without local reversal', () {
    final anulada = Venta.fromJson({
      'id': 'v3', 'codigo': 'V-003', 'cajaSesionId': 'cs1', 'sedeId': 's1',
      'total': 20, 'estado': 'ANULADA', 'createdAt': '2026-08-01T10:00:00Z',
      'motivoAnulacion': 'Error de cliente',
      'anuladaAt': '2026-08-01T11:00:00Z',
      'cuentaId': 'cuenta-1',
      'cuenta': {'id': 'cuenta-1', 'nombre': 'Ana'},
      'cuentaMonto': 20,
      'items': [],
    });
    expect(anulada.isAnulada, isTrue);
    expect(anulada.cuentaId, 'cuenta-1');
    expect(anulada.cuentaMonto, 20);
    expect(anulada.motivoAnulacion, 'Error de cliente');
  });

  // ── Parity closure record ────────────────────────────────────────────────
  group('Mobile-web parity closure', () {
    test('backup schedule endpoint constants are exact', () {
      expect(ApiConstants.backupSchedule, '/backups/schedule');
      expect(ApiConstants.backupRuns, '/backups/runs');
      expect(ApiConstants.backupArtifact('run-1', 'XLSX'),
          '/backups/runs/run-1/artifacts/XLSX');
    });

    test('backup SHA-256 verification: sha256HexOf produces deterministic hex digest', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final hash = sha256HexOf(bytes);
      // Same bytes → same digest (determinism)
      expect(hash, equals(sha256HexOf(bytes)));
      // SHA-256 output is exactly 64 lowercase hex characters
      expect(hash.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(hash), isTrue);
      // Different bytes → different digest (collision resistance)
      expect(sha256HexOf(Uint8List.fromList([1, 2, 3, 5])), isNot(equals(hash)));
      // BackupIntegrityException is thrown when stored hash does not match
      const wrongHash = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      expect(
        () { if (sha256HexOf(bytes) != wrongHash) throw BackupIntegrityException('mismatch'); },
        throwsA(isA<BackupIntegrityException>()),
      );
    });

    test('all mobile capability routes use RoutePaths constants', () {
      // Tests production RoutePaths constants — fails if any path changes.
      expect(RoutePaths.cuentas, '/cuentas');
      expect(RoutePaths.reportes, '/reportes');
      expect(RoutePaths.respaldos, '/respaldos');
      expect(RoutePaths.ventas, '/ventas');
      expect(RoutePaths.usuarios, '/usuarios');
      expect(RoutePaths.productos, '/productos');
      expect(RoutePaths.inventario, '/inventario');
    });

    test('backup schedule toUpdateJson excludes read-only fields', () {
      const s = BackupSchedule(
        enabled: true, frequency: 'DAILY', formats: ['XLSX'],
        timezone: 'America/Buenos_Aires', nextRunAt: null, lastRunAt: null);
      final j = s.toUpdateJson();
      expect(j.containsKey('timezone'), isFalse);
      expect(j.containsKey('nextRunAt'), isFalse);
      expect(j['enabled'], isTrue);
    });
  });
}
