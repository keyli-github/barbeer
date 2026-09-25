import 'package:barbeer/features/auth/data/models/auth_models.dart';
import 'package:barbeer/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';

AuthState _authWith(List<String> permissions) => AuthState(
  status: AuthStatus.authenticated,
  user: UserProfile(
    id: 'test-id',
    username: 'test',
    rol: 'ADMIN',
    nivel: 10,
    createdAt: '2026-01-01',
    permisos: permissions,
  ),
);

AuthState _authWithRole(String role, List<String> permissions) => AuthState(
  status: AuthStatus.authenticated,
  user: UserProfile(
    id: 'test-id',
    username: 'test',
    rol: role,
    nivel: 10,
    createdAt: '2026-01-01',
    permisos: permissions,
  ),
);

void main() {
  group('destination permissions', () {
    test('productos uses the read permission', () {
      expect(_authWith(['productos:leer']).canAccess('/productos'), isTrue);
      expect(_authWith(['productos:crear']).canAccess('/productos'), isFalse);
    });

    test('etiquetas uses the read permission', () {
      expect(_authWith(['etiquetas:leer']).canAccess('/etiquetas'), isTrue);
      expect(_authWith(['etiquetas:crear']).canAccess('/etiquetas'), isFalse);
    });

    test('ventas accepts read, own-read, or create', () {
      for (final permission in [
        'ventas:leer',
        'ventas:leer-propias',
        'ventas:crear',
      ]) {
        expect(_authWith([permission]).canAccess('/ventas'), isTrue);
      }
      expect(_authWith([]).canAccess('/ventas'), isFalse);
    });

    test('historical sales requires both sale gates and own-sales access', () {
      const permissions = [
        'ventas:crear',
        'ventas:sin-luz',
        'ventas:leer-propias',
      ];

      expect(
        _authWithRole('VENDEDORA', permissions).canAccess('/ventas-sin-luz'),
        isTrue,
      );
      for (final missing in permissions) {
        expect(
          _authWithRole(
            'VENDEDORA',
            permissions.where((permission) => permission != missing).toList(),
          ).canAccess('/ventas-sin-luz'),
          isFalse,
          reason: 'Missing $missing must hide the historical sales route',
        );
      }
      expect(
        _authWithRole('ADMIN', permissions).canAccess('/ventas-sin-luz'),
        isTrue,
      );
      expect(
        _authWithRole('ADMIN', ['ventas:crear']).canAccess('/ventas-sin-luz'),
        isFalse,
      );
    });

    test('nested destination paths inherit their route permission', () {
      expect(
        _authWith(['productos:leer']).canAccess('/productos/detalle'),
        isTrue,
      );
    });

    test('movimientos is a caja:leer destination', () {
      expect(_authWith(['caja:leer']).canAccess('/movimientos'), isTrue);
      expect(
        _authWith(['caja:movimientos']).canAccess('/movimientos'),
        isFalse,
      );
    });

    test('seguridad is available to every authenticated user', () {
      expect(_authWith([]).canAccess('/seguridad'), isTrue);
    });

    test('cuentas uses cuentas:leer permission', () {
      expect(_authWith(['cuentas:leer']).canAccess('/cuentas'), isTrue);
      expect(_authWith(['cuentas:crear']).canAccess('/cuentas'), isFalse);
    });

    test('reportes requires SUPERADMIN role', () {
      final superadmin = AuthState(
        status: AuthStatus.authenticated,
        user: UserProfile(
          id: 'sa',
          username: 'sa',
          rol: 'SUPERADMIN',
          nivel: 99,
          createdAt: '2026-01-01',
          permisos: [],
        ),
      );
      expect(superadmin.canAccess('/reportes'), isTrue);
      expect(_authWith([]).canAccess('/reportes'), isFalse);
    });

    test('respaldos requires respaldos:gestionar', () {
      expect(
        _authWith(['respaldos:gestionar']).canAccess('/respaldos'),
        isTrue,
      );
      expect(_authWith([]).canAccess('/respaldos'), isFalse);
    });

    test('importaciones requires importaciones:ejecutar', () {
      expect(
        _authWith(['importaciones:ejecutar']).canAccess('/importaciones'),
        isTrue,
      );
      expect(_authWith([]).canAccess('/importaciones'), isFalse);
    });
  });
}
