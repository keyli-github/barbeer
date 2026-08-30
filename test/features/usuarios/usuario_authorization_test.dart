import 'package:barbeer/core/constants/api_constants.dart';
import 'package:barbeer/core/errors/app_exception.dart';
import 'package:barbeer/core/network/api_client.dart';
import 'package:barbeer/features/usuarios/data/models/usuario_permission_models.dart';
import 'package:barbeer/features/usuarios/data/usuario_admin_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _resp({List<String> added = const [], List<String> revoked = const []}) {
  final addSet = added.toSet();
  final revSet = revoked.toSet();
  const roleIds = {'p-ventas-leer', 'p-ventas-crear'};
  final catalog = [
    {'id': 'p-ventas-leer', 'nombre': 'ventas:leer', 'modulo': 'ventas', 'descripcion': 'Leer ventas'},
    {'id': 'p-ventas-crear', 'nombre': 'ventas:crear', 'modulo': 'ventas', 'descripcion': 'Crear ventas'},
    {'id': 'p-cuentas-leer', 'nombre': 'cuentas:leer', 'modulo': 'cuentas', 'descripcion': 'Leer cuentas'},
    {'id': 'p-inv-leer', 'nombre': 'inventario:leer', 'modulo': 'inventario', 'descripcion': 'Leer inventario'},
  ];
  return {
    'usuario': {'id': 'u-1', 'username': 'maria', 'rol': 'VENDEDORA'},
    'permisosPorRol': catalog.where((p) => roleIds.contains(p['id'])).toList(),
    'permisosAdicionales': catalog.where((p) => addSet.contains(p['id'])).toList(),
    'permisosRevocados': catalog.where((p) => revSet.contains(p['id'])).toList(),
    'permisosEfectivos': catalog.map((p) {
      final id = p['id'] as String;
      final porRol = roleIds.contains(id);
      final adicional = addSet.contains(id);
      final revocado = revSet.contains(id);
      return {...p, 'porRol': porRol, 'adicional': adicional, 'revocado': revocado,
        'activo': (porRol || adicional) && !revocado};
    }).toList(),
  };
}

void main() {
  group('permission', () {
    test('DTO maps GET response with inherited, granted, revoked, and effective', () {
      final r = UsuarioPermisosResponse.fromJson(
        _resp(added: ['p-cuentas-leer'], revoked: ['p-ventas-crear']));
      expect(r.usuario.id, 'u-1');
      expect(r.usuario.username, 'maria');
      expect(r.usuario.rol, 'VENDEDORA');
      expect(r.permisosPorRol.length, 2);
      expect(r.permisosAdicionales.length, 1);
      expect(r.permisosRevocados.length, 1);
      expect(r.permisosEfectivos.length, 4);
      final inherited = r.permisosEfectivos.firstWhere((e) => e.id == 'p-ventas-leer');
      expect((inherited.porRol, inherited.adicional, inherited.activo), (true, false, true));
      final granted = r.permisosEfectivos.firstWhere((e) => e.id == 'p-cuentas-leer');
      expect((granted.porRol, granted.adicional, granted.activo), (false, true, true));
      final revoked = r.permisosEfectivos.firstWhere((e) => e.id == 'p-ventas-crear');
      expect((revoked.porRol, revoked.revocado, revoked.activo), (true, true, false));
    });

    test('replace payload serializes exact PUT body and omits empty revocations', () {
      final full = ReplacePermissionsPayload(
        permisoIds: ['p-cuentas-leer', 'p-inv-leer'], permisoIdsRevocados: ['p-ventas-crear']);
      final fullJson = full.toJson();
      expect(fullJson['permisoIds'], ['p-cuentas-leer', 'p-inv-leer']);
      expect(fullJson['permisoIdsRevocados'], ['p-ventas-crear']);
      final noRevocations = ReplacePermissionsPayload(permisoIds: ['p-cuentas-leer']);
      expect(noRevocations.toJson().containsKey('permisoIdsRevocados'), isFalse);
    });

    test('API constant builds correct user permission path', () {
      expect(ApiConstants.userPermissions('u-abc'), '/usuarios/u-abc/permisos');
    });

    test('catalog permission parses id, nombre, modulo, and descripcion', () {
      final p = CatalogPermission.fromJson(
        {'id': 'p-1', 'nombre': 'ventas:leer', 'modulo': 'ventas', 'descripcion': 'Leer ventas'});
      expect((p.id, p.nombre, p.modulo, p.descripcion), ('p-1', 'ventas:leer', 'ventas', 'Leer ventas'));
    });

    test('effective semantics: activo = (porRol || adicional) && !revocado', () {
      final all = UsuarioPermisosResponse.fromJson(
        _resp(added: ['p-cuentas-leer'], revoked: ['p-ventas-crear'])).permisosEfectivos;
      final activeIds = all.where((e) => e.activo).map((e) => e.id).toSet();
      expect(activeIds, {'p-ventas-leer', 'p-cuentas-leer'});
      expect(activeIds.contains('p-ventas-crear'), isFalse);
      expect(activeIds.contains('p-inv-leer'), isFalse);
    });

    test('repository GET returns parsed response from exact endpoint', () async {
      final paths = <String>[];
      final repo = UsuarioAdminRepository(ApiClient.instance,
        getRequest: (path) async { paths.add(path); return _resp(); });
      final result = await repo.getPermissions('u-1');
      expect(result.usuario.username, 'maria');
      expect(result.permisosEfectivos.length, 4);
      expect(paths.single, '/usuarios/u-1/permisos');
    });

    test('repository PUT sends payload and returns updated model', () async {
      Map<String, dynamic>? body; String? path;
      final repo = UsuarioAdminRepository(ApiClient.instance,
        putRequest: (p, b) async { path = p; body = b; return _resp(added: ['p-cuentas-leer']); });
      final result = await repo.replacePermissions('u-1',
        ReplacePermissionsPayload(permisoIds: ['p-cuentas-leer'], permisoIdsRevocados: ['p-ventas-crear']));
      expect(path, '/usuarios/u-1/permisos');
      expect(body!['permisoIds'], ['p-cuentas-leer']);
      expect(body!['permisoIdsRevocados'], ['p-ventas-crear']);
      expect(result.permisosAdicionales.first.nombre, 'cuentas:leer');
    });

    test('repository surfaces 403 and 400 backend errors', () async {
      final denied = UsuarioAdminRepository(ApiClient.instance,
        putRequest: (_, __) async { throw const AppException(
          message: 'Solo el SUPERADMIN puede modificar permisos.', statusCode: 403); });
      expect(() => denied.replacePermissions('u-1', ReplacePermissionsPayload(permisoIds: ['p-1'])),
        throwsA(isA<AppException>().having((e) => e.statusCode, 'status', 403)));
      final invalid = UsuarioAdminRepository(ApiClient.instance,
        putRequest: (_, __) async { throw const AppException(
          message: 'Uno o mas permisos no existen en el catalogo.', statusCode: 400); });
      expect(() => invalid.replacePermissions('u-1', ReplacePermissionsPayload(permisoIds: ['bad'])),
        throwsA(isA<AppException>().having((e) => e.statusCode, 'status', 400)));
    });

    test('permission harness: create, replace, and delete exception flows', () async {
      final ops = <(String, Map<String, dynamic>?)>[];
      var current = _resp();
      final repo = UsuarioAdminRepository(ApiClient.instance,
        getRequest: (path) async { ops.add(('GET', null)); return current; },
        putRequest: (path, body) async {
          ops.add(('PUT', Map<String, dynamic>.from(body)));
          final adds = (body['permisoIds'] as List).cast<String>();
          final revs = (body['permisoIdsRevocados'] as List?)?.cast<String>() ?? [];
          current = _resp(added: adds, revoked: revs);
          return current;
        });
      // Load: no exceptions
      var r = await repo.getPermissions('u-1');
      expect(r.permisosAdicionales, isEmpty);
      expect(r.permisosEfectivos.where((e) => e.activo).map((e) => e.id).toSet(),
        {'p-ventas-leer', 'p-ventas-crear'});
      // Create: grant cuentas:leer
      r = await repo.replacePermissions('u-1', ReplacePermissionsPayload(permisoIds: ['p-cuentas-leer']));
      expect(r.permisosAdicionales.map((e) => e.id), ['p-cuentas-leer']);
      expect(r.permisosEfectivos.where((e) => e.activo).length, 3);
      // Replace: swap to inventario:leer + revoke ventas:crear
      r = await repo.replacePermissions('u-1', ReplacePermissionsPayload(
        permisoIds: ['p-inv-leer'], permisoIdsRevocados: ['p-ventas-crear']));
      expect(r.permisosAdicionales.map((e) => e.id), ['p-inv-leer']);
      expect(r.permisosRevocados.map((e) => e.id), ['p-ventas-crear']);
      expect(r.permisosEfectivos.firstWhere((e) => e.id == 'p-ventas-crear').activo, isFalse);
      // Delete: clear all exceptions
      r = await repo.replacePermissions('u-1', ReplacePermissionsPayload(permisoIds: []));
      expect(r.permisosAdicionales, isEmpty);
      expect(r.permisosRevocados, isEmpty);
      expect(ops.map((op) => op.$1), ['GET', 'PUT', 'PUT', 'PUT']);
    });
  });

  group('PIN', () {
    test('PinConfigPayload serializes manual four-digit PIN', () {
      final p = PinConfigPayload(superadminPin: '4321', pinAutoGenerate: false);
      final j = p.toJson();
      expect(j['superadminPin'], '4321');
      expect(j['pinAutoGenerate'], false);
    });

    test('PinConfigPayload serializes auto-generate with null PIN', () {
      final p = PinConfigPayload(pinAutoGenerate: true);
      final j = p.toJson();
      expect(j.containsKey('superadminPin'), isFalse);
      expect(j['pinAutoGenerate'], true);
    });

    test('PinValidationResult parses success with username', () {
      final r = PinValidationResult.fromJson(
        {'success': true, 'username': 'admin1'});
      expect(r.success, true);
      expect(r.username, 'admin1');
    });

    test('PinValidationResult parses failure without username', () {
      final r = PinValidationResult.fromJson({'success': false});
      expect(r.success, false);
      expect(r.username, isNull);
    });

    test('StockAdjustPayload serializes all fields including superadminPin', () {
      final p = StockAdjustPayload(
        sedeId: 's-1', tipo: 'ENTRADA', cantidad: 10,
        referencia: 'Purchase order', superadminPin: '1234');
      final j = p.toJson();
      expect(j['sedeId'], 's-1');
      expect(j['tipo'], 'ENTRADA');
      expect(j['cantidad'], 10);
      expect(j['referencia'], 'Purchase order');
      expect(j['superadminPin'], '1234');
    });

    test('StockAdjustPayload omits optional fields when absent', () {
      final p = StockAdjustPayload(tipo: 'SALIDA', cantidad: 3);
      final j = p.toJson();
      expect(j.containsKey('sedeId'), isFalse);
      expect(j.containsKey('referencia'), isFalse);
      expect(j.containsKey('superadminPin'), isFalse);
      expect(j['tipo'], 'SALIDA');
      expect(j['cantidad'], 3);
    });

    test('StockAdjustResult parses productoId, sedeId, stock, tipo, cantidad', () {
      final r = StockAdjustResult.fromJson({
        'productoId': 'prod-1', 'sedeId': 's-1',
        'stock': 18, 'tipo': 'ENTRADA', 'cantidad': 10});
      expect((r.productoId, r.sedeId, r.stock, r.tipo, r.cantidad),
        ('prod-1', 's-1', 18, 'ENTRADA', 10));
    });

    test('API constants build superadmin-pin, validate-pin, and product stock paths', () {
      expect(ApiConstants.superadminPin('u-x'), '/usuarios/u-x/superadmin-pin');
      expect(ApiConstants.validatePin, '/usuarios/validate-pin');
      expect(ApiConstants.productStock('p-y'), '/productos/p-y/stock');
    });

    test('repository PATCH configures superadmin PIN at exact endpoint', () async {
      String? path; Map<String, dynamic>? body;
      final repo = UsuarioAdminRepository(ApiClient.instance,
        patchRequest: (p, b) async { path = p; body = b; return {'message': 'ok'}; });
      await repo.configureSuperadminPin('u-1',
        PinConfigPayload(superadminPin: '9876', pinAutoGenerate: false));
      expect(path, '/usuarios/u-1/superadmin-pin');
      expect(body!['superadminPin'], '9876');
      expect(body!['pinAutoGenerate'], false);
    });

    test('repository POST validate-pin returns parsed result', () async {
      String? path; Map<String, dynamic>? body;
      final repo = UsuarioAdminRepository(ApiClient.instance,
        postRequest: (p, b) async { path = p; body = b;
          return {'success': true, 'username': 'admin1'}; });
      final result = await repo.validatePin('1234');
      expect(path, '/usuarios/validate-pin');
      expect(body!['pin'], '1234');
      expect(result.success, true);
      expect(result.username, 'admin1');
    });

    test('repository surfaces 429 throttle on excessive PIN attempts', () async {
      final repo = UsuarioAdminRepository(ApiClient.instance,
        postRequest: (_, __) async { throw const AppException(
          message: 'Demasiados intentos fallidos. Intenta nuevamente en 15 minutos.',
          statusCode: 429); });
      expect(() => repo.validatePin('0000'),
        throwsA(isA<AppException>().having((e) => e.statusCode, 'status', 429)));
    });

    test('repository POST adjustStock sends payload with PIN authorization', () async {
      String? path; Map<String, dynamic>? body;
      final repo = UsuarioAdminRepository(ApiClient.instance,
        postRequest: (p, b) async { path = p; body = b;
          return {'productoId': 'prod-1', 'sedeId': 's-1',
            'stock': 18, 'tipo': 'ENTRADA', 'cantidad': 10}; });
      final result = await repo.adjustStock('prod-1',
        StockAdjustPayload(tipo: 'ENTRADA', cantidad: 10,
          referencia: 'Restock', superadminPin: '1234'));
      expect(path, '/productos/prod-1/stock');
      expect(body!['tipo'], 'ENTRADA');
      expect(body!['superadminPin'], '1234');
      expect(result.stock, 18);
    });

    test('repository surfaces 403 on stock without PIN and 400 on negative stock', () async {
      final noPinRepo = UsuarioAdminRepository(ApiClient.instance,
        postRequest: (_, __) async { throw const AppException(
          message: 'Se requiere el PIN de un superadministrador para ajustar stock',
          statusCode: 403); });
      expect(() => noPinRepo.adjustStock('p-1',
        StockAdjustPayload(tipo: 'SALIDA', cantidad: 5)),
        throwsA(isA<AppException>().having((e) => e.statusCode, 'status', 403)));
      final negativeRepo = UsuarioAdminRepository(ApiClient.instance,
        postRequest: (_, __) async { throw const AppException(
          message: 'El stock no puede quedar negativo', statusCode: 400); });
      expect(() => negativeRepo.adjustStock('p-1',
        StockAdjustPayload(tipo: 'SALIDA', cantidad: 999, superadminPin: '1234')),
        throwsA(isA<AppException>().having((e) => e.statusCode, 'status', 400)));
    });

    test('PIN harness: throttled PIN entry, then stock-check authorization', () async {
      final ops = <(String, String, Map<String, dynamic>?)>[];
      var pinAttempts = 0;
      final repo = UsuarioAdminRepository(ApiClient.instance,
        postRequest: (path, body) async {
          ops.add(('POST', path, Map<String, dynamic>.from(body)));
          if (path == ApiConstants.validatePin) {
            pinAttempts++;
            if (pinAttempts >= 5) {
              throw const AppException(
                message: 'Demasiados intentos fallidos. Intenta nuevamente en 15 minutos.',
                statusCode: 429);
            }
            final pin = body['pin'] as String;
            if (pin == '1234') return {'success': true, 'username': 'admin1'};
            return {'success': false};
          }
          // Stock endpoint
          return {'productoId': 'prod-1', 'sedeId': 's-1',
            'stock': 8, 'tipo': body['tipo'], 'cantidad': body['cantidad']};
        });
      // Wrong PIN twice → failure, no throttle yet
      var v = await repo.validatePin('0000');
      expect(v.success, false);
      v = await repo.validatePin('9999');
      expect(v.success, false);
      // Correct PIN → success
      v = await repo.validatePin('1234');
      expect(v.success, true);
      expect(v.username, 'admin1');
      // Authorized stock adjustment succeeds
      final s = await repo.adjustStock('prod-1',
        StockAdjustPayload(tipo: 'SALIDA', cantidad: 2,
          referencia: 'Sold', superadminPin: '1234'));
      expect(s.stock, 8);
      expect(s.tipo, 'SALIDA');
      // Exhaust remaining attempts → 429 throttle
      await repo.validatePin('0000'); // attempt 4
      expect(() => repo.validatePin('0000'), // attempt 5 → throttle
        throwsA(isA<AppException>().having((e) => e.statusCode, 'status', 429)));
      // Verify operation sequence
      expect(ops.map((o) => '${o.$1} ${o.$2}'), [
        'POST /usuarios/validate-pin',
        'POST /usuarios/validate-pin',
        'POST /usuarios/validate-pin',
        'POST /productos/prod-1/stock',
        'POST /usuarios/validate-pin',
        'POST /usuarios/validate-pin',
      ]);
    });
  });
}
