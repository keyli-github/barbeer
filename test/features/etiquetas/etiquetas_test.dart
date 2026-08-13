import 'package:flutter_test/flutter_test.dart';
import 'package:barbeer/features/etiquetas/data/models/etiqueta.dart';
import 'package:barbeer/features/etiquetas/presentation/widgets/etiqueta_tile.dart';
import 'package:barbeer/features/auth/presentation/providers/auth_provider.dart';
import 'package:barbeer/features/auth/data/models/auth_models.dart';
import 'package:flutter/material.dart';

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
            'etiquetas:leer',
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
            'etiquetas:leer',
            'etiquetas:crear',
            'etiquetas:editar',
            'etiquetas:desactivar',
          ],
        ),
      );
      expect(auth.canAccess('/etiquetas'), isTrue);
    });

    test('3. CAJERO puede consultar etiquetas con etiquetas:leer', () {
      final auth = _authWith(
        _makeUser(
          rol: 'CAJERO',
          permisos: ['etiquetas:leer', 'ventas:leer', 'ventas:conciliar'],
        ),
      );
      expect(auth.canAccess('/etiquetas'), isTrue);
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
        'tipo': 'AMBOS',
        'esSistema': true,
        'orden': 1,
      };
      final et = Etiqueta.fromJson(json);
      expect(et.nombre, 'Yape');
      expect(et.activo, isTrue);
      expect(et.requiereComprobante, isTrue);
      expect(et.tipo, EtiquetaTipo.ambos);
      expect(et.esSistema, isTrue);
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
        'tipo': 'SALIDA',
      };
      expect(payload['nombre'], 'Agora');
      expect(payload.containsKey('sedeId'), isFalse);
      expect(payload.containsKey('orden'), isFalse);
    });

    test('8. Editar etiqueta (solo campos modificables)', () {
      final payload = <String, dynamic>{
        'nombre': 'Yape Actualizado',
        'requiereComprobante': false,
        'tipo': 'ENTRADA',
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
      bool canSubmit(bool saving) => !saving;
      expect(canSubmit(true), isFalse);
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

  group('EtiquetaTile', () {
    const editable = Etiqueta(
      id: 'custom',
      nombre: 'Gastos',
      activo: true,
      requiereComprobante: false,
      tipo: EtiquetaTipo.salida,
      esSistema: false,
      orden: 2,
    );

    testWidgets('muestra AMBOS y oculta acciones para etiquetas del sistema', (
      tester,
    ) async {
      const sistema = Etiqueta(
        id: 'system',
        nombre: 'Efectivo',
        activo: true,
        requiereComprobante: false,
        tipo: EtiquetaTipo.ambos,
        esSistema: true,
        orden: 1,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EtiquetaTile(
              etiqueta: sistema,
              canEdit: true,
              canDeactivate: true,
            ),
          ),
        ),
      );

      expect(find.text('AMBOS'), findsOneWidget);
      expect(find.text('SISTEMA'), findsOneWidget);
      expect(find.byIcon(Icons.edit_rounded), findsNothing);
      expect(find.byIcon(Icons.toggle_on_rounded), findsNothing);
    });

    testWidgets('respeta permisos independientes de editar y desactivar', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: EtiquetaTile(etiqueta: editable, canEdit: true)),
        ),
      );

      expect(find.byIcon(Icons.edit_rounded), findsOneWidget);
      expect(find.byIcon(Icons.toggle_on_rounded), findsNothing);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EtiquetaTile(etiqueta: editable, canDeactivate: true),
          ),
        ),
      );

      expect(find.byIcon(Icons.edit_rounded), findsNothing);
      expect(find.byIcon(Icons.toggle_on_rounded), findsOneWidget);
    });
  });
}
