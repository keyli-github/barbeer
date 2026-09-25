import 'package:barbeer/core/constants/api_constants.dart';
import 'package:barbeer/core/network/api_client.dart';
import 'package:barbeer/features/auth/data/models/auth_models.dart';
import 'package:barbeer/features/auth/presentation/providers/auth_provider.dart';
import 'package:barbeer/features/categorias/data/categorias_repository.dart';
import 'package:barbeer/features/productos/data/productos_repository.dart';
import 'package:barbeer/features/productos/presentation/screens/productos_screen.dart';
import 'package:barbeer/features/usuarios/data/usuario_admin_repository.dart';
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
  UserProfile? user = _user,
  AuthStatus status = AuthStatus.authenticated,
  UsuarioAdminRepository? stockRepository,
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
        if (stockRepository != null)
          productoStockAdjustmentRepositoryProvider.overrideWithValue(
            stockRepository,
          ),
        authProvider.overrideWith(
          (ref) => _TestAuthNotifier(
            ref.read(authRepositoryProvider),
            AuthState(status: status, user: user),
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

  testWidgets('product stock action uses the PIN-authorized product endpoint', (
    tester,
  ) async {
    final operations = <(String, Map<String, dynamic>)>[];
    final repository = UsuarioAdminRepository(
      ApiClient.instance,
      postRequest: (path, body) async {
        operations.add((path, Map<String, dynamic>.from(body)));
        if (path == ApiConstants.validatePin) {
          return {'success': true, 'username': 'superadmin'};
        }
        return {
          'productoId': 'product-1',
          'sedeId': 'branch-1',
          'stock': 23,
          'tipo': body['tipo'],
          'cantidad': body['cantidad'],
        };
      },
    );
    await _pumpProducts(
      tester,
      const Size(1440, 900),
      stockRepository: repository,
    );

    await tester.tap(find.byKey(const Key('product-stock-in-product-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('product-stock-adjust-dialog')), findsOneWidget);
    expect(find.text('Ingreso de stock'), findsOneWidget);
    expect(find.byKey(const Key('stock-pin')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('stock-cantidad')), '3');
    await tester.tap(find.text('Confirmar ajuste'));
    await tester.pumpAndSettle();
    expect(find.text('La referencia es obligatoria.'), findsOneWidget);
    expect(operations, isEmpty);

    await tester.enterText(
      find.byKey(const Key('stock-referencia')),
      'Restock',
    );
    await tester.enterText(find.byKey(const Key('stock-pin')), '1234');
    await tester.tap(find.text('Confirmar ajuste'));
    await tester.pumpAndSettle();

    expect(operations.map((operation) => operation.$1), [
      ApiConstants.validatePin,
      ApiConstants.productStock('product-1'),
    ]);
    expect(operations.last.$2, {
      'tipo': 'ENTRADA',
      'cantidad': 3.0,
      'referencia': 'Restock',
      'superadminPin': '1234',
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('Superadmin product adjustment skips PIN and validation', (
    tester,
  ) async {
    final requests = <(String, Map<String, dynamic>)>[];
    final repository = UsuarioAdminRepository(
      ApiClient.instance,
      postRequest: (path, body) async {
        requests.add((path, Map<String, dynamic>.from(body)));
        return {
          'productoId': 'product-1',
          'sedeId': 'branch-1',
          'stock': 23,
          'tipo': body['tipo'],
          'cantidad': body['cantidad'],
        };
      },
    );
    const superAdmin = UserProfile(
      id: 'root-1',
      username: 'root',
      rol: 'SUPERADMIN',
      nivel: 100,
      sedeId: 'branch-1',
      createdAt: '2026-09-01',
      permisos: [],
    );
    await _pumpProducts(
      tester,
      const Size(1440, 900),
      user: superAdmin,
      stockRepository: repository,
    );

    await tester.tap(find.byKey(const Key('product-stock-out-product-1')));
    await tester.pumpAndSettle();
    expect(find.text('Salida de stock'), findsOneWidget);
    expect(find.byKey(const Key('stock-pin')), findsNothing);
    await tester.enterText(find.byKey(const Key('stock-cantidad')), '2');
    await tester.tap(find.text('Confirmar ajuste'));
    await tester.pumpAndSettle();

    expect(requests, hasLength(1));
    expect(requests.single.$1, ApiConstants.productStock('product-1'));
    expect(requests.single.$2, {
      'sedeId': 'branch-1',
      'tipo': 'SALIDA',
      'cantidad': 2.0,
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('product stock adjustment opens as a mobile page', (
    tester,
  ) async {
    await _pumpProducts(tester, const Size(390, 844));

    await tester.tap(find.byKey(const Key('product-stock-in-product-1')));
    await tester.pumpAndSettle();

    expect(find.text('Ingreso de stock'), findsOneWidget);
    expect(find.byKey(const Key('stock-cantidad')), findsOneWidget);
    expect(find.byKey(const Key('stock-referencia')), findsOneWidget);
    expect(find.byKey(const Key('stock-pin')), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('VENDEDORA cannot use the direct product stock action', (
    tester,
  ) async {
    const seller = UserProfile(
      id: 'seller-1',
      username: 'seller',
      rol: 'VENDEDORA',
      nivel: 10,
      sedeId: 'branch-1',
      createdAt: '2026-09-01',
      permisos: ['productos:leer'],
    );
    await _pumpProducts(
      tester,
      const Size(390, 844),
      user: seller,
    );

    expect(find.byKey(const Key('product-stock-in-product-1')), findsNothing);
    expect(find.byKey(const Key('product-stock-out-product-1')), findsNothing);
  });

  testWidgets('unauthenticated users do not see direct product stock actions', (
    tester,
  ) async {
    await _pumpProducts(
      tester,
      const Size(390, 844),
      user: null,
      status: AuthStatus.unauthenticated,
    );

    expect(find.byKey(const Key('product-stock-in-product-1')), findsNothing);
    expect(find.byKey(const Key('product-stock-out-product-1')), findsNothing);
  });
}
