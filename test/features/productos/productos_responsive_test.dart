import 'dart:async';

import 'package:barbeer/core/network/api_client.dart';
import 'package:barbeer/features/auth/data/models/auth_models.dart';
import 'package:barbeer/features/auth/presentation/providers/auth_provider.dart';
import 'package:barbeer/features/categorias/data/categorias_repository.dart';
import 'package:barbeer/features/inventario/data/inventario_repository.dart';
import 'package:barbeer/features/productos/data/productos_repository.dart';
import 'package:barbeer/features/productos/presentation/screens/productos_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _product = Producto(
  id: 'product-1',
  codigo: 'AGU-1',
  nombre: 'Agua',
  categoria: 'Bebidas',
  categoriaId: 'category-1',
  unidad: 'unidad',
  precioVenta: 5,
  precioCosto: 2,
  disponiblePos: true,
  activo: true,
  margin: 60,
  stockDisponible: 20,
);

class _FakeProductsRepository extends ProductosRepository {
  _FakeProductsRepository() : super(ApiClient.instance);

  @override
  Future<ProductosPage> list({
    int pagina = 1,
    int limite = 25,
    String? q,
    String? categoriaId,
    String? activo,
    String? sedeId,
  }) async => const ProductosPage(
    data: [_product],
    total: 1,
    pagina: 1,
    totalPaginas: 1,
  );

  @override
  Future<ProductosResumen> resumen() async => const ProductosResumen(
    total: 1,
    activos: 1,
    enPos: 1,
    valorCatalogo: 2,
    margenPromedio: 60,
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

class _FakeInventoryRepository extends InventarioRepository {
  _FakeInventoryRepository() : super(ApiClient.instance);

  final response = Completer<InventarioPage>();

  @override
  Future<InventarioPage> list({
    int pagina = 1,
    int limite = 25,
    String? q,
    String? categoriaId,
    String? estado,
    String? sedeId,
    String? productoId,
  }) => response.future;
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(super.repository, AuthState value) {
    state = value;
  }
}

const _user = UserProfile(
  id: 'user-1',
  username: 'admin',
  rol: 'ADMIN',
  nivel: 80,
  sedeId: 'branch-1',
  createdAt: '2026-09-01',
  permisos: [
    'productos:leer',
    'productos:crear',
    'productos:editar',
    'productos:ver-utilidad',
    'inventario:ajustar',
  ],
);

Future<void> _pumpProducts(
  WidgetTester tester,
  Size size, {
  InventarioRepository? inventoryRepository,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        productosCatalogRepositoryProvider.overrideWithValue(
          _FakeProductsRepository(),
        ),
        if (inventoryRepository != null)
          productosInventarioRepositoryProvider.overrideWithValue(
            inventoryRepository,
          ),
        authProvider.overrideWith(
          (ref) => _TestAuthNotifier(
            ref.read(authRepositoryProvider),
            const AuthState(status: AuthStatus.authenticated, user: _user),
          ),
        ),
      ],
      child: const MaterialApp(home: ProductosScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mobile product cards stay compact at phone width', (
    tester,
  ) async {
    await _pumpProducts(tester, const Size(390, 844));

    final card = find.byKey(const Key('product-card-product-1'));
    expect(card, findsOneWidget);
    expect(tester.getSize(card).height, lessThan(500));
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop product cards are compact and create opens a dialog', (
    tester,
  ) async {
    await _pumpProducts(tester, const Size(1440, 900));

    final card = find.byKey(const Key('product-card-product-1'));
    expect(card, findsOneWidget);
    expect(tester.getSize(card).height, lessThan(360));

    await tester.tap(find.byKey(const Key('productos-create-desktop')));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Nuevo producto'), findsOneWidget);
  });

  testWidgets('wide desktop adds columns instead of stretching product cards', (
    tester,
  ) async {
    await _pumpProducts(tester, const Size(1920, 1080));

    final card = find.byKey(const Key('product-card-product-1'));
    expect(card, findsOneWidget);
    expect(tester.getSize(card).width, lessThan(300));
    expect(tester.getSize(card).height, lessThan(360));
    expect(tester.takeException(), isNull);
  });

  testWidgets('stock adjustment dialog opens before inventory request ends', (
    tester,
  ) async {
    final inventory = _FakeInventoryRepository();
    await _pumpProducts(
      tester,
      const Size(1440, 900),
      inventoryRepository: inventory,
    );

    await tester.tap(find.text('Ingreso'));
    await tester.pump();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Ingreso de stock'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    inventory.response.complete(
      const InventarioPage(
        data: [
          InventarioItem(
            id: 'inventory-1',
            productoId: 'product-1',
            sedeId: 'branch-1',
            codigo: 'AGU-1',
            producto: 'Agua',
            categoria: 'Bebidas',
            unidad: 'unidad',
            ubicacion: '',
            estado: 'OK',
            stock: 20,
            min: 5,
            max: 50,
            costo: 2,
            updatedAt: '2026-09-04',
          ),
        ],
        total: 1,
        pagina: 1,
        totalPaginas: 1,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cantidad'), findsOneWidget);
    expect(find.text('Agua · Stock 20.0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
