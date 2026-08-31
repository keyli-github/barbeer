import 'package:flutter_test/flutter_test.dart';
import 'package:barbeer/features/auth/presentation/providers/auth_provider.dart';
import 'package:barbeer/features/auth/data/models/auth_models.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

UserProfile _makeUser({
  required String rol,
  List<String> permisos = const [],
}) => UserProfile(
  id: 'u-test',
  username: 'test',
  rol: rol,
  nivel: 10,
  createdAt: '2026-01-01',
  permisos: permisos,
);

AuthState _authWith(UserProfile user) =>
    AuthState(status: AuthStatus.authenticated, user: user);

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('Sucursales authorization matrix', () {
    test('establecimientos:leer grants access to /sucursales', () {
      final auth = _authWith(_makeUser(
        rol: 'ADMIN',
        permisos: ['establecimientos:leer'],
      ));
      expect(auth.canAccess('/sucursales'), isTrue);
    });

    test('SUPERADMIN with establecimientos:leer can access /sucursales', () {
      final auth = _authWith(_makeUser(
        rol: 'SUPERADMIN',
        permisos: ['establecimientos:leer', 'establecimientos:gestionar'],
      ));
      expect(auth.canAccess('/sucursales'), isTrue);
    });

    test('establecimientos:gestionar alone grants access to /sucursales', () {
      final auth = _authWith(_makeUser(
        rol: 'ADMIN',
        permisos: ['establecimientos:gestionar'],
      ));
      // establecimientos:gestionar is not the declared read permission —
      // only establecimientos:leer unlocks the route
      expect(auth.canAccess('/sucursales'), isFalse);
    });

    test('no establecimientos permission denies /sucursales', () {
      final auth = _authWith(_makeUser(
        rol: 'CAJERO',
        permisos: ['caja:leer', 'ventas:leer'],
      ));
      expect(auth.canAccess('/sucursales'), isFalse);
    });
  });
}
