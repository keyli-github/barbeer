import 'package:barbeer/core/network/api_client.dart';
import 'package:barbeer/features/auth/data/models/auth_models.dart';
import 'package:barbeer/features/auth/presentation/providers/auth_provider.dart';
import 'package:barbeer/features/categorias/data/categorias_repository.dart';
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

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(super.repository, AuthState value) {
    state = value;
  }
}

void main() {
  testWidgets('desktop product cards are compact and create opens a dialog', (
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
        'productos:leer',
        'productos:crear',
        'productos:editar',
        'productos:ver-utilidad',
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productosCatalogRepositoryProvider.overrideWithValue(
            _FakeProductsRepository(),
          ),
          authProvider.overrideWith(
            (ref) => _TestAuthNotifier(
              ref.read(authRepositoryProvider),
              const AuthState(status: AuthStatus.authenticated, user: user),
            ),
          ),
        ],
        child: const MaterialApp(home: ProductosScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final card = find.byKey(const Key('product-card-product-1'));
    expect(card, findsOneWidget);
    expect(tester.getSize(card).height, lessThan(390));

    await tester.tap(find.byKey(const Key('productos-create-desktop')));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Nuevo producto'), findsOneWidget);
  });
}
