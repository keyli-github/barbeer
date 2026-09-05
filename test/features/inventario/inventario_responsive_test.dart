import 'package:barbeer/core/network/api_client.dart';
import 'package:barbeer/features/auth/data/models/auth_models.dart';
import 'package:barbeer/features/auth/presentation/providers/auth_provider.dart';
import 'package:barbeer/features/categorias/data/categorias_repository.dart';
import 'package:barbeer/features/inventario/data/inventario_repository.dart';
import 'package:barbeer/features/inventario/presentation/screens/inventario_screen.dart';
import 'package:barbeer/features/productos/data/productos_repository.dart'
    as products;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _item = InventarioItem(
  id: 'inventory-1',
  productoId: 'product-1',
  sedeId: 'branch-1',
  codigo: 'AGU-1',
  producto: 'Agua',
  categoria: 'Bebidas',
  unidad: 'unidad',
  ubicacion: 'A-1',
  estado: 'OK',
  stock: 20,
  min: 5,
  max: 30,
  costo: 2,
  updatedAt: '2026-09-01',
);

class _FakeInventoryRepository extends InventarioRepository {
  _FakeInventoryRepository() : super(ApiClient.instance);

  @override
  Future<InventarioPage> list({
    int pagina = 1,
    int limite = 25,
    String? q,
    String? categoriaId,
    String? estado,
    String? sedeId,
    String? productoId,
  }) async =>
      const InventarioPage(data: [_item], total: 1, pagina: 1, totalPaginas: 1);

  @override
  Future<InventarioResumen> resumen({String? sedeId}) async =>
      const InventarioResumen(
        totalItems: 1,
        ok: 1,
        alerta: 0,
        critico: 0,
        valorTotal: 40,
      );
}

class _FakeProductsRepository extends products.ProductosRepository {
  _FakeProductsRepository() : super(ApiClient.instance);

  @override
  Future<products.ProductosPage> list({
    int pagina = 1,
    int limite = 25,
    String? q,
    String? categoriaId,
    String? activo,
    String? sedeId,
  }) async => const products.ProductosPage(
    data: [
      products.Producto(
        id: 'product-1',
        codigo: 'AGU-1',
        nombre: 'Agua',
        categoria: 'Bebidas',
        categoriaId: 'category-1',
        unidad: 'unidad',
        precioVenta: 5,
        disponiblePos: true,
        activo: true,
      ),
    ],
    total: 1,
    pagina: 1,
    totalPaginas: 1,
  );

  @override
  Future<List<Categoria>> categorias({String? activo = 'true'}) async => const [
    Categoria(
      id: 'category-1',
      nombre: 'Bebidas',
      activo: true,
      productosCount: 1,
    ),
  ];
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(super.repository, AuthState value) {
    state = value;
  }
}

void main() {
  testWidgets('desktop inventory actions open centered bounded dialogs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const user = UserProfile(
      id: 'user-1',
      username: 'admin',
      rol: 'ADMIN',
      nivel: 80,
      sedeId: 'branch-1',
      createdAt: '2026-09-01',
      permisos: [
        'inventario:leer',
        'inventario:configurar',
        'inventario:ajustar-stock',
        'productos:leer',
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inventarioRepositoryProvider.overrideWithValue(
            _FakeInventoryRepository(),
          ),
          inventarioProductsRepositoryProvider.overrideWithValue(
            _FakeProductsRepository(),
          ),
          authProvider.overrideWith(
            (ref) => _TestAuthNotifier(
              ref.read(authRepositoryProvider),
              const AuthState(status: AuthStatus.authenticated, user: user),
            ),
          ),
        ],
        child: const MaterialApp(home: InventarioScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('inventario-configure-all')));
    await tester.pumpAndSettle();
    final addDialog = find.byKey(const Key('inventory-config-dialog'));
    expect(addDialog, findsOneWidget);
    expect(tester.getSize(addDialog).width, 640);
    expect(tester.getSize(addDialog).height, lessThan(580));
    expect(tester.getCenter(addDialog), const Offset(720, 450));
    expect(find.text('Agregar al inventario'), findsOneWidget);
    await tester.tap(find.byKey(const Key('responsive-form-close')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('inventario-configure-inventory-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('inventory-config-dialog')), findsOneWidget);
    expect(find.text('Configurar inventario'), findsWidgets);
    await tester.tap(find.byKey(const Key('responsive-form-close')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('inventario-adjust-inventory-1')));
    await tester.pumpAndSettle();
    final adjustDialog = find.byKey(const Key('inventory-adjust-dialog'));
    expect(adjustDialog, findsOneWidget);
    expect(tester.getSize(adjustDialog).width, 580);
    expect(tester.getSize(adjustDialog).height, lessThan(520));
    expect(tester.getCenter(adjustDialog), const Offset(720, 450));
    expect(find.text('Ajuste de stock'), findsOneWidget);
    expect(find.text('Agua'), findsWidgets);
  });
}
