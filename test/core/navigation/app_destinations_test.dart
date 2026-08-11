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
  });
}
