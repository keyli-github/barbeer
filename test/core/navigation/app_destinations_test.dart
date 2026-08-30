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
          id: 'sa', username: 'sa', rol: 'SUPERADMIN',
          nivel: 99, createdAt: '2026-01-01', permisos: [],
        ),
      );
      expect(superadmin.canAccess('/reportes'), isTrue);
      expect(_authWith([]).canAccess('/reportes'), isFalse);
    });

    test('respaldos requires respaldos:gestionar', () {
      expect(
          _authWith(['respaldos:gestionar']).canAccess('/respaldos'), isTrue);
      expect(_authWith([]).canAccess('/respaldos'), isFalse);
    });
  });
}
