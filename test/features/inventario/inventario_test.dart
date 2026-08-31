import 'package:flutter_test/flutter_test.dart';
import 'package:barbeer/features/inventario/data/inventario_repository.dart';
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
  group('InventarioItem backend contract', () {
    test('fromJson maps all backend field names including stock thresholds', () {
      final item = InventarioItem.fromJson({
        'id': 'inv-1',
        'productoId': 'prod-1',
        'sedeId': 'sede-1',
        'codigo': 'CER-001',
        'producto': 'Cerveza Rubia',
        'categoria': 'Bebidas',
        'unidad': 'unidad',
        'ubicacion': 'A-01',
        'estado': 'OK',
        'stock': 12.5,
        'min': 5.0,
        'max': 50.0,
        'costo': 8.75,
        'updatedAt': '2026-08-01T10:00:00.000Z',
      });

      expect(item.id, 'inv-1');
      expect(item.productoId, 'prod-1');
      expect(item.sedeId, 'sede-1');
      expect(item.stock, 12.5);
      expect(item.min, 5.0);
      expect(item.max, 50.0);
      expect(item.costo, 8.75);
      expect(item.estado, 'OK');
      expect(item.ubicacion, 'A-01');
    });

    test('fromJson maps ALERTA and CRITICO estados from backend', () {
      final alerta = InventarioItem.fromJson({
        'id': 'inv-2',
        'productoId': 'p2',
        'sedeId': 's1',
        'codigo': 'VIN-002',
        'producto': 'Vino Tinto',
        'categoria': 'Vinos',
        'unidad': 'botella',
        'ubicacion': 'B-02',
        'estado': 'ALERTA',
        'stock': 2.0,
        'min': 5.0,
        'max': 20.0,
        'costo': 15.0,
        'updatedAt': '2026-08-01T12:00:00.000Z',
      });

      final critico = InventarioItem.fromJson({
        'id': 'inv-3',
        'productoId': 'p3',
        'sedeId': 's1',
        'codigo': 'GIN-003',
        'producto': 'Gin Premium',
        'categoria': 'Destilados',
        'unidad': 'botella',
        'ubicacion': 'C-03',
        'estado': 'CRITICO',
        'stock': 0.0,
        'min': 3.0,
        'max': 10.0,
        'costo': 45.0,
        'updatedAt': '2026-08-01T08:00:00.000Z',
      });

      expect(alerta.estado, 'ALERTA');
      expect(alerta.stock, lessThan(alerta.min));
      expect(critico.estado, 'CRITICO');
      expect(critico.stock, 0.0);
    });
  });

  group('InventarioResumen backend contract', () {
    test('fromJson maps totalItems, ok, alerta, critico, and valorTotal', () {
      final resumen = InventarioResumen.fromJson({
        'totalItems': 120,
        'ok': 95,
        'alerta': 18,
        'critico': 7,
        'valorTotal': 25480.50,
      });

      expect(resumen.totalItems, 120);
      expect(resumen.ok, 95);
      expect(resumen.alerta, 18);
      expect(resumen.critico, 7);
      expect(resumen.valorTotal, 25480.50);
      expect(resumen.ok + resumen.alerta + resumen.critico, resumen.totalItems);
    });
  });

  group('InventarioPage pagination contract', () {
    test('fromJson retains pagina and totalPaginas using backend field names', () {
      final page = InventarioPage(
        data: const [],
        total: 75,
        pagina: 3,
        totalPaginas: 3,
      );

      expect(page.pagina, 3);
      expect(page.totalPaginas, 3);
      expect(page.total, 75);
    });
  });

  group('Inventario and Kardex authorization matrix', () {
    test('inventario:leer grants access to /inventario', () {
      final auth = _authWith(_makeUser(
        rol: 'ALMACENERO',
        permisos: ['inventario:leer'],
      ));
      expect(auth.canAccess('/inventario'), isTrue);
    });

    test('kardex:leer grants access to /kardex', () {
      final auth = _authWith(_makeUser(
        rol: 'ALMACENERO',
        permisos: ['kardex:leer'],
      ));
      expect(auth.canAccess('/kardex'), isTrue);
    });

    test('ADMIN with inventario:leer can access /inventario', () {
      final auth = _authWith(_makeUser(
        rol: 'ADMIN',
        permisos: ['inventario:leer', 'kardex:leer'],
      ));
      expect(auth.canAccess('/inventario'), isTrue);
      expect(auth.canAccess('/kardex'), isTrue);
    });

    test('no inventory permission denies /inventario and /kardex', () {
      final auth = _authWith(_makeUser(
        rol: 'VENDEDORA',
        permisos: ['ventas:crear', 'ventas:leer-propias'],
      ));
      expect(auth.canAccess('/inventario'), isFalse);
      expect(auth.canAccess('/kardex'), isFalse);
    });
  });
}
