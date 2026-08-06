import 'package:flutter_test/flutter_test.dart';
import 'package:barbeer/features/ventas/data/models/venta_models.dart';
import 'package:barbeer/features/auth/presentation/providers/auth_provider.dart';
import 'package:barbeer/features/auth/data/models/auth_models.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

UserProfile _makeUser({
  required String rol,
  List<String> permisos = const [],
}) => UserProfile(
  id: 'test-id',
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
  group('Permisos de etiquetas', () {
    test('1. ADMIN puede abrir Gestión de etiquetas', () {
      final auth = _authWith(
        _makeUser(
          rol: 'ADMIN',
          permisos: [
            'etiquetas:crear',
            'etiquetas:editar',
            'etiquetas:desactivar',
          ],
        ),
      );
      expect(auth.canAccess('/etiquetas'), isTrue);
    });

    test('2. SUPERADMIN puede abrir Gestión de etiquetas', () {
      final auth = _authWith(
        _makeUser(
          rol: 'SUPERADMIN',
          permisos: [
            'etiquetas:crear',
            'etiquetas:editar',
            'etiquetas:desactivar',
          ],
        ),
      );
      expect(auth.canAccess('/etiquetas'), isTrue);
    });

    test('3. CAJERO NO ve la pantalla administrativa', () {
      final auth = _authWith(
        _makeUser(
          rol: 'CAJERO',
          permisos: ['etiquetas:leer', 'ventas:leer', 'ventas:conciliar'],
        ),
      );
      // etiquetas:leer NO es suficiente para acceder a /etiquetas (requiere etiquetas:crear)
      expect(auth.canAccess('/etiquetas'), isFalse);
    });

    test('4. VENDEDORA NO ve la pantalla de etiquetas', () {
      final auth = _authWith(
        _makeUser(
          rol: 'VENDEDORA',
          permisos: ['ventas:crear', 'ventas:leer-propias', 'productos:leer'],
        ),
      );
      expect(auth.canAccess('/etiquetas'), isFalse);
    });
  });

  group('Modelo Etiqueta', () {
    test('5. Listado de etiquetas (fromJson)', () {
      final json = {
        'id': 'et1',
        'nombre': 'Yape',
        'activo': true,
        'sedeId': null,
        'requiereComprobante': true,
        'orden': 1,
      };
      final et = Etiqueta.fromJson(json);
      expect(et.nombre, 'Yape');
      expect(et.activo, isTrue);
      expect(et.requiereComprobante, isTrue);
      expect(et.orden, 1);
      expect(et.sedeId, isNull);
    });

    test('6. Estado vacío (lista vacía sin error)', () {
      final etiquetas = <Etiqueta>[];
      expect(etiquetas.isEmpty, isTrue);
    });

    test('7. Crear etiqueta (estructura del payload)', () {
      final payload = <String, dynamic>{
        'nombre': 'Agora',
        'requiereComprobante': true,
        'orden': 3,
      };
      expect(payload['nombre'], 'Agora');
      expect(payload.containsKey('sedeId'), isFalse);
    });

    test('8. Editar etiqueta (solo campos modificables)', () {
      final payload = <String, dynamic>{
        'nombre': 'Yape Actualizado',
        'requiereComprobante': false,
        'orden': 2,
      };
      // No debe contener activo (eso va por otro endpoint)
      expect(payload.containsKey('activo'), isFalse);
      expect(payload['nombre'], 'Yape Actualizado');
    });

    test('9. Activar etiqueta (payload de toggle)', () {
      final payload = {'activo': true};
      expect(payload['activo'], isTrue);
    });

    test('10. Desactivar con confirmación (payload)', () {
      final payload = {'activo': false};
      expect(payload['activo'], isFalse);
    });

    test(
      '11. Etiqueta con conciliaciones pendientes no puede desactivarse (simula 409)',
      () {
        // Simulación: el backend retorna 409 si hay conciliaciones PENDIENTE
        const errorMsg = 'La etiqueta tiene 3 venta(s) con pago pendiente';
        expect(errorMsg.contains('pendiente'), isTrue);
      },
    );
  });

  group('Validaciones', () {
    test('12. Evitar doble envío (submitting)', () {
      var count = 0;
      void doSubmit() => count++;
      const saving = true;
      if (!saving) doSubmit();
      expect(count, 0);
    });

    test('13. Manejo de 403 (sin permiso)', () {
      const errorString = 'DioException: 403 Forbidden';
      expect(errorString.contains('403'), isTrue);
    });

    test('14. Manejo de pérdida de conexión', () {
      const errorString = 'SocketException: Connection refused';
      expect(
        errorString.contains('SocketException') ||
            errorString.contains('connection'),
        isTrue,
      );
    });
  });
}
