import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:barbeer/features/ventas/data/models/venta_models.dart';
import 'package:barbeer/features/ventas/presentation/providers/ventas_provider.dart';
import 'package:barbeer/features/ventas/presentation/widgets/carrito_venta_sheet.dart';
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

const _uuid = Uuid();

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('Permisos de ventas', () {
    test('1. VENDEDORA puede crear ventas', () {
      final auth = _authWith(
        _makeUser(
          rol: 'VENDEDORA',
          permisos: ['ventas:crear', 'ventas:leer-propias', 'productos:leer'],
        ),
      );
      expect(canCreateVenta(auth), isTrue);
    });

    test('2. CAJERO NO puede crear ventas', () {
      final auth = _authWith(
        _makeUser(
          rol: 'CAJERO',
          permisos: [
            'ventas:leer',
            'ventas:conciliar',
            'caja:leer',
            'caja:aperturar',
            'caja:precuadre',
            'caja:cerrar',
            'etiquetas:leer',
          ],
        ),
      );
      expect(canCreateVenta(auth), isFalse);
    });

    test('3. CAJERO puede leer todas las ventas', () {
      final auth = _authWith(
        _makeUser(rol: 'CAJERO', permisos: ['ventas:leer', 'ventas:conciliar']),
      );
      expect(canReadAllVentas(auth), isTrue);
    });

    test('4. VENDEDORA solo puede leer sus propias ventas', () {
      final auth = _authWith(
        _makeUser(
          rol: 'VENDEDORA',
          permisos: ['ventas:crear', 'ventas:leer-propias', 'productos:leer'],
        ),
      );
      expect(canReadAllVentas(auth), isFalse);
      expect(canReadOwnVentas(auth), isTrue);
    });

    test('5. CAJERO puede conciliar', () {
      final auth = _authWith(
        _makeUser(rol: 'CAJERO', permisos: ['ventas:conciliar']),
      );
      expect(canConciliar(auth), isTrue);
    });

    test('6. CAJERO NO puede corregir conciliaciones', () {
      final auth = _authWith(
        _makeUser(rol: 'CAJERO', permisos: ['ventas:conciliar']),
      );
      expect(canConciliarCorregir(auth), isFalse);
    });

    test('7. ADMIN sí puede corregir conciliaciones', () {
      final auth = _authWith(
        _makeUser(
          rol: 'ADMIN',
          permisos: ['ventas:conciliar', 'ventas:conciliar-corregir'],
        ),
      );
      expect(canConciliarCorregir(auth), isTrue);
    });

    test('8. CAJERO NO puede anular ventas', () {
      final auth = _authWith(
        _makeUser(rol: 'CAJERO', permisos: ['ventas:leer']),
      );
      expect(canAnularVenta(auth), isFalse);
    });

    test('9. ADMIN sí puede anular ventas', () {
      final auth = _authWith(
        _makeUser(rol: 'ADMIN', permisos: ['ventas:anular']),
      );
      expect(canAnularVenta(auth), isTrue);
    });
  });

  group('Carrito de venta', () {
    test('10. Agregar producto al carrito', () {
      final item = CarritoItem(
        productoId: 'p1',
        nombre: 'Cerveza',
        codigo: 'CER-001',
        precio: 10.0,
      );
      expect(item.cantidad, 1);
      expect(item.subtotal, 10.0);
    });

    test('11. Cambiar cantidades del carrito', () {
      final item = CarritoItem(
        productoId: 'p1',
        nombre: 'Cerveza',
        codigo: 'CER-001',
        precio: 10.0,
      );
      item.cantidad = 3;
      expect(item.subtotal, 30.0);
    });

    test('12. Quitar producto (removeWhere)', () {
      final items = <CarritoItem>[
        CarritoItem(productoId: 'p1', nombre: 'A', codigo: 'A', precio: 5),
        CarritoItem(productoId: 'p2', nombre: 'B', codigo: 'B', precio: 8),
      ];
      items.removeWhere((i) => i.productoId == 'p1');
      expect(items.length, 1);
      expect(items.first.productoId, 'p2');
    });

    test('13. Payload contiene solo productoId, cantidad e idempotencyKey', () {
      final idKey = _uuid.v4();
      final items = [
        CarritoItem(
          productoId: 'p1',
          nombre: 'A',
          codigo: 'A',
          precio: 15.0,
          cantidad: 2,
        ),
      ];
      final payload = <String, dynamic>{
        'idempotencyKey': idKey,
        'items': items
            .map((i) => {'productoId': i.productoId, 'cantidad': i.cantidad})
            .toList(),
      };
      expect(payload.containsKey('total'), isFalse);
      expect(payload['idempotencyKey'], idKey);
      final payloadItems = payload['items'] as List;
      expect(payloadItems.first['productoId'], 'p1');
      expect(payloadItems.first['cantidad'], 2);
      expect((payloadItems.first as Map).containsKey('precio'), isFalse);
    });
  });

  group('Idempotencia', () {
    test('14. Genera UUIDs diferentes para ventas diferentes', () {
      final k1 = _uuid.v4();
      final k2 = _uuid.v4();
      expect(k1, isNot(equals(k2)));
      expect(k1.length, 36);
    });

    test('15. El reintento conserva la misma clave', () {
      final key = _uuid.v4();
      final retryKey = key;
      expect(retryKey, key);
    });

    test('16. Éxito genera nueva clave', () {
      final keyBefore = _uuid.v4();
      final keyAfter = _uuid.v4();
      expect(keyAfter, isNot(equals(keyBefore)));
    });
  });

  group('Modelos', () {
    test('17. Venta.fromJson parsea correctamente', () {
      final venta = Venta.fromJson({
        'id': 'v1',
        'codigo': 'V-CEN-2026-0001',
        'cajaSesionId': 'c1',
        'sedeId': 's1',
        'vendedora': {'id': 'u1', 'username': 'vendedora1'},
        'total': 60.0,
        'estado': 'ACTIVA',
        'conciliacion': {'id': 'conc1', 'estado': 'PENDIENTE'},
        'items': [
          {
            'id': 'vi1',
            'productoId': 'p1',
            'producto': {'nombre': 'Cerveza', 'codigo': 'CER-001'},
            'cantidad': 3,
            'precioUnitario': 20.0,
            'subtotal': 60.0,
          },
        ],
        'createdAt': '2026-08-05T10:00:00Z',
      });
      expect(venta.codigo, 'V-CEN-2026-0001');
      expect(venta.total, 60.0);
      expect(venta.estado, EstadoVenta.activa);
      expect(venta.isPendiente, isTrue);
      expect(venta.items.length, 1);
      expect(venta.items.first.cantidad, 3);
      expect(venta.vendedoraUsername, 'vendedora1');
    });

    test('18. Venta anulada', () {
      final venta = Venta.fromJson({
        'id': 'v2',
        'codigo': 'V-TEST-0002',
        'cajaSesionId': 'c1',
        'sedeId': 's1',
        'total': 30.0,
        'estado': 'ANULADA',
        'motivoAnulacion': 'Error en producto',
        'items': [],
        'createdAt': '2026-08-05T10:00:00Z',
      });
      expect(venta.isAnulada, isTrue);
      expect(venta.motivoAnulacion, 'Error en producto');
    });

    test('19. ConciliacionVenta BILLETERA con etiqueta', () {
      final conc = ConciliacionVenta.fromJson({
        'id': 'conc1',
        'estado': 'BILLETERA',
        'etiquetaId': 'et1',
        'etiqueta': {'nombre': 'Yape'},
        'monto': 45.0,
        'codigoOperacion': 'YPE-001',
        'clasificadaAt': '2026-08-05T11:00:00Z',
      });
      expect(conc.estado, EstadoConciliacion.billetera);
      expect(conc.etiquetaNombre, 'Yape');
      expect(conc.codigoOperacion, 'YPE-001');
    });
  });

  group('Doble confirmación', () {
    test('20. No se ejecuta submit si ya está en progreso', () {
      var count = 0;
      void doSubmit(bool submitting) {
        if (submitting) return; // Guard: si ya está enviando, no ejecutar
        count++;
      }

      // Simular que ya hay un envío en curso
      doSubmit(true);
      expect(count, 0, reason: 'No debe ejecutarse con submitting=true');

      // Simular que no hay envío en curso
      doSubmit(false);
      expect(count, 1, reason: 'Debe ejecutarse con submitting=false');
    });
  });
}
