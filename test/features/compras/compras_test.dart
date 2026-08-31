import 'package:barbeer/features/compras/data/compras_repository.dart';
import 'package:barbeer/features/auth/presentation/providers/auth_provider.dart';
import 'package:barbeer/features/auth/data/models/auth_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Item de nueva compra', () {
    test('parsea valores positivos y calcula el subtotal', () {
      final item = parseCompraCreateItem(
        productoId: 'producto-1',
        cantidad: '2.5',
        costoUnit: '10,20',
        precioVenta: '15.50',
      );

      expect(item, isNotNull);
      expect(item!.cantidad, 2.5);
      expect(item.costoUnit, 10.2);
      expect(item.precioVenta, 15.5);
      expect(item.subtotal, 25.5);
    });

    test('rechaza cero, negativos y texto no numerico', () {
      for (final values in [
        ('0', '10', '15'),
        ('1', '-10', '15'),
        ('1', '10', 'abc'),
      ]) {
        expect(
          parseCompraCreateItem(
            productoId: 'producto-1',
            cantidad: values.$1,
            costoUnit: values.$2,
            precioVenta: values.$3,
          ),
          isNull,
        );
      }
    });

    test('rechaza un producto sin identificador', () {
      expect(
        parseCompraCreateItem(
          productoId: '   ',
          cantidad: '1',
          costoUnit: '10',
          precioVenta: '15',
        ),
        isNull,
      );
    });

    test('rechaza dinero con mas de dos decimales o fuera de rango', () {
      expect(
        parseCompraCreateItem(
          productoId: 'producto-1',
          cantidad: '1',
          costoUnit: '10.123',
          precioVenta: '15',
        ),
        isNull,
      );
      expect(
        parseCompraCreateItem(
          productoId: 'producto-1',
          cantidad: '1',
          costoUnit: '10',
          precioVenta: '10000000000',
        ),
        isNull,
      );
    });
  });

  group('Payload de nueva compra', () {
    const item = CompraCreateItem(
      productoId: 'producto-1',
      cantidad: 3,
      costoUnit: 8.5,
      precioVenta: 12,
    );

    test('incluye sedeId e items con valores numericos tipados', () {
      final payload = buildCompraCreateData(
        proveedorId: 'proveedor-1',
        sedeId: 'sede-1',
        items: const [item],
        eta: ' 2026-08-15 ',
        notas: ' Entrega principal ',
      );
      final items = payload['items'] as List<Map<String, dynamic>>;

      expect(payload['proveedorId'], 'proveedor-1');
      expect(payload['sedeId'], 'sede-1');
      expect(payload['eta'], '2026-08-15');
      expect(payload['notas'], 'Entrega principal');
      expect(items, hasLength(1));
      expect(items.single, {
        'productoId': 'producto-1',
        'cantidad': 3.0,
        'costoUnit': 8.5,
        'precioVenta': 12.0,
      });
      expect(items.single['cantidad'], isA<double>());
      expect(items.single['costoUnit'], isA<double>());
      expect(items.single['precioVenta'], isA<double>());
    });

    test('normaliza identificadores antes de enviarlos', () {
      final payload = buildCompraCreateData(
        proveedorId: ' proveedor-1 ',
        sedeId: ' sede-1 ',
        items: const [
          CompraCreateItem(
            productoId: ' producto-1 ',
            cantidad: 1,
            costoUnit: 8.5,
            precioVenta: 12,
          ),
        ],
      );
      final items = payload['items'] as List<Map<String, dynamic>>;

      expect(payload['proveedorId'], 'proveedor-1');
      expect(payload['sedeId'], 'sede-1');
      expect(items.single['productoId'], 'producto-1');
    });

    test('omite opcionales vacios', () {
      final payload = buildCompraCreateData(
        proveedorId: 'proveedor-1',
        sedeId: 'sede-1',
        items: const [item],
        eta: ' ',
        notas: '',
      );

      expect(payload, isNot(contains('eta')));
      expect(payload, isNot(contains('notas')));
    });

    test('requiere sede, proveedor y al menos un item valido', () {
      expect(
        () => buildCompraCreateData(
          proveedorId: '',
          sedeId: 'sede-1',
          items: const [item],
        ),
        throwsArgumentError,
      );
      expect(
        () => buildCompraCreateData(
          proveedorId: 'proveedor-1',
          sedeId: '',
          items: const [item],
        ),
        throwsArgumentError,
      );
      expect(
        () => buildCompraCreateData(
          proveedorId: 'proveedor-1',
          sedeId: 'sede-1',
          items: const [],
        ),
        throwsArgumentError,
      );
      expect(
        () => buildCompraCreateData(
          proveedorId: 'proveedor-1',
          sedeId: 'sede-1',
          items: const [
            CompraCreateItem(
              productoId: 'producto-1',
              cantidad: 1,
              costoUnit: 0,
              precioVenta: 12,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });
  });

  group('Parseo defensivo de compras', () {
    test('acepta cantidades serializadas como texto', () {
      final compra = Compra.fromJson({
        'id': 'compra-1',
        'articulos': '2',
        'total': '25.50',
        'items': [
          {
            'id': 'item-1',
            'cantidad': '2',
            'costoUnit': '10.25',
            'subtotal': '20.50',
          },
        ],
      });

      expect(compra.articulos, 2);
      expect(compra.total, 25.5);
      expect(compra.items, hasLength(1));
      expect(compra.items!.single.cantidad, 2);
      expect(compra.items!.single.costoUnit, 10.25);
    });

    test('ignora tipos inesperados sin lanzar excepciones', () {
      final proveedor = Proveedor.fromJson({
        'id': 7,
        'nombre': <String>[],
        'categoria': 9,
        'activo': 'true',
        'ordenes': 'invalido',
        'total': <String, Object>{},
      });

      expect(proveedor.id, isEmpty);
      expect(proveedor.activo, isFalse);
      expect(
        () => CompraSede.fromJson({'id': 1, 'nombre': false}),
        returnsNormally,
      );
    });
  });

  group('Compra backend contract', () {
    test('fromJson maps nested proveedor as provider name string', () {
      final compra = Compra.fromJson({
        'id': 'c-1',
        'orden': 'OC-001',
        'fecha': '2026-08-10',
        'proveedor': {'id': 'prov-1', 'nombre': 'Distribuidora Sur'},
        'proveedorId': 'prov-1',
        'estado': 'PENDIENTE',
        'solicitadoPor': {'username': 'admin'},
        'notas': '',
        'articulos': '3',
        'total': '120.50',
      });

      expect(compra.proveedor, 'Distribuidora Sur');
      expect(compra.proveedorId, 'prov-1');
      expect(compra.estado, 'PENDIENTE');
      expect(compra.solicitadoPor, 'admin');
      expect(compra.articulos, 3);
      expect(compra.total, 120.50);
    });

    test('fromJson defaults estado to PENDIENTE when field is absent', () {
      final sin = Compra.fromJson({
        'id': 'c-2',
        'proveedorId': 'prov-1',
        'notas': '',
        'articulos': 1,
        'total': 10.0,
      });

      expect(sin.estado, 'PENDIENTE');
    });
  });

  group('Compras and providers authorization matrix', () {
    AuthState _auth(String rol, List<String> permisos) => AuthState(
      status: AuthStatus.authenticated,
      user: UserProfile(
        id: 'u1',
        username: 'test',
        rol: rol,
        nivel: 10,
        createdAt: '2026-01-01',
        permisos: permisos,
      ),
    );

    test('compras:leer grants access to /compras', () {
      expect(_auth('ALMACENERO', ['compras:leer']).canAccess('/compras'), isTrue);
    });

    test('no compras permission denies /compras', () {
      final auth = _auth('CAJERO', ['caja:leer', 'ventas:leer']);
      expect(auth.canAccess('/compras'), isFalse);
    });
  });
}
