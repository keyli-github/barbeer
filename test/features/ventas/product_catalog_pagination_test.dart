import 'dart:async';

import 'package:barbeer/core/network/api_client.dart';
import 'package:barbeer/features/auth/data/models/auth_models.dart';
import 'package:barbeer/features/auth/presentation/providers/auth_provider.dart';
import 'package:barbeer/features/productos/data/productos_repository.dart';
import 'package:barbeer/features/ventas/data/models/venta_models.dart';
import 'package:barbeer/features/ventas/data/ventas_repository.dart';
import 'package:barbeer/features/ventas/presentation/providers/ventas_provider.dart';
import 'package:barbeer/features/ventas/presentation/screens/nueva_venta_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _PageResponse =
    Future<ProductosPage> Function({
      required int pagina,
      required int limite,
      String? q,
      String? activo,
      String? disponiblePos,
      String? sedeId,
    });

class _PageProductsRepository extends ProductosRepository {
  _PageProductsRepository(this.respond) : super(ApiClient.instance);

  final _PageResponse respond;
  final calls = <Map<String, Object?>>[];

  @override
  Future<ProductosPage> list({
    int pagina = 1,
    int limite = 25,
    String? q,
    String? categoriaId,
    String? activo,
    String? disponiblePos,
    String? sedeId,
  }) {
    calls.add({
      'pagina': pagina,
      'limite': limite,
      'q': q,
      'activo': activo,
      'disponiblePos': disponiblePos,
      'sedeId': sedeId,
    });
    return respond(
      pagina: pagina,
      limite: limite,
      q: q,
      activo: activo,
      disponiblePos: disponiblePos,
      sedeId: sedeId,
    );
  }
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(super.repository, AuthState value) {
    state = value;
  }
}

class _CatalogSalesRepository extends VentasRepository {
  _CatalogSalesRepository() : super(ApiClient.instance);

  @override
  Future<List<Etiqueta>> listEtiquetasActivas({String? sedeId}) async => [];
}

Producto _product(String id, {String? name, int? stock = 10}) => Producto(
  id: id,
  codigo: 'SKU-$id',
  nombre: name ?? 'Product $id',
  categoria: 'Drinks',
  categoriaId: 'category-1',
  unidad: 'unit',
  precioVenta: 12,
  disponiblePos: true,
  activo: true,
  stockDisponible: stock,
);

ProductosPage _page(
  List<Producto> data, {
  required int pagina,
  required int total,
}) => ProductosPage(
  data: data,
  total: total,
  pagina: pagina,
  totalPaginas: (total + 49) ~/ 50,
);

Future<void> _pumpCatalog(
  WidgetTester tester, {
  required Size size,
  required ProductosRepository repository,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(
          (ref) => _TestAuthNotifier(
            ref.read(authRepositoryProvider),
            AuthState(
              status: AuthStatus.authenticated,
              user: UserProfile(
                id: 'seller-1',
                username: 'seller',
                rol: 'CAJERO',
                nivel: 10,
                sedeId: 'sede-1',
                createdAt: '2026-01-01',
                permisos: const ['ventas:crear'],
              ),
            ),
          ),
        ),
        ventasRepositoryProvider.overrideWithValue(_CatalogSalesRepository()),
      ],
      child: MaterialApp(
        home: Scaffold(body: NuevaVentaView(productosRepository: repository)),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _scrollToLoadMore(
  WidgetTester tester, {
  required Key scrollableKey,
  required Key buttonKey,
}) async {
  final scrollable = find.descendant(
    of: find.byKey(scrollableKey),
    matching: find.byType(Scrollable),
  );
  await tester.scrollUntilVisible(
    find.byKey(buttonKey),
    500,
    scrollable: scrollable.first,
  );
  await tester.ensureVisible(find.byKey(buttonKey));
  await tester.pumpAndSettle();
}

Future<void> _activateByKeyboard(
  WidgetTester tester, {
  required Key buttonKey,
  required IconData icon,
}) async {
  final iconFinder = find.descendant(
    of: find.byKey(buttonKey),
    matching: find.byIcon(icon),
  );
  Focus.of(tester.element(iconFinder)).requestFocus();
  await tester.pump();
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pump();
}

void main() {
  testWidgets('loads bounded pages beyond 100 and keeps the cart selection', (
    tester,
  ) async {
    final products = List.generate(
      125,
      (index) => _product(
        'p${index.toString().padLeft(3, '0')}',
        stock: index == 0 ? -2 : 10,
      ),
    );
    final repository = _PageProductsRepository(({
      required pagina,
      required limite,
      q,
      activo,
      disponiblePos,
      sedeId,
    }) async {
      final start = (pagina - 1) * limite;
      return _page(
        products.skip(start).take(limite).toList(),
        pagina: pagina,
        total: products.length,
      );
    });

    await _pumpCatalog(
      tester,
      size: const Size(1280, 900),
      repository: repository,
    );

    expect(repository.calls.single, {
      'pagina': 1,
      'limite': 50,
      'q': null,
      'activo': 'true',
      'disponiblePos': 'true',
      'sedeId': 'sede-1',
    });
    expect(find.text('50 de 125 disponibles'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('desktop-product-p000')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add-to-sale-modal')), findsOneWidget);
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('desktop-cart-item-p000')),
      findsOneWidget,
    );

    for (final expectedPage in [2, 3]) {
      await _scrollToLoadMore(
        tester,
        scrollableKey: const Key('desktop-catalog-grid'),
        buttonKey: const Key('desktop-catalog-load-more'),
      );
      await tester.tap(find.byKey(const Key('desktop-catalog-load-more')));
      await tester.pump();
      await tester.pump();

      expect(repository.calls.last['pagina'], expectedPage);
      expect(repository.calls.last['limite'], 50);
      expect(
        find.byKey(const ValueKey('desktop-cart-item-p000')),
        findsOneWidget,
      );
    }

    expect(repository.calls, hasLength(3));
    expect(find.text('1 producto seleccionado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'debounces server search and can request a matching second page',
    (tester) async {
      final matchingProducts = List.generate(
        51,
        (index) => _product('match-$index', name: 'Special product $index'),
      );
      final repository = _PageProductsRepository(({
        required pagina,
        required limite,
        q,
        activo,
        disponiblePos,
        sedeId,
      }) async {
        if (q == null) return _page([_product('initial')], pagina: 1, total: 1);
        final start = (pagina - 1) * limite;
        return _page(
          matchingProducts.skip(start).take(limite).toList(),
          pagina: pagina,
          total: matchingProducts.length,
        );
      });

      await _pumpCatalog(
        tester,
        size: const Size(1280, 900),
        repository: repository,
      );
      await tester.enterText(find.byType(TextField).first, 'special');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 299));
      expect(repository.calls, hasLength(1));

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(repository.calls, hasLength(2));
      expect(repository.calls[1]['q'], 'special');
      expect(repository.calls[1]['pagina'], 1);
      expect(
        find.byKey(const ValueKey('desktop-product-match-0')),
        findsOneWidget,
      );

      await _scrollToLoadMore(
        tester,
        scrollableKey: const Key('desktop-catalog-grid'),
        buttonKey: const Key('desktop-catalog-load-more'),
      );
      await tester.tap(find.byKey(const Key('desktop-catalog-load-more')));
      await tester.pump();
      await tester.pump();

      expect(repository.calls.last['q'], 'special');
      expect(repository.calls.last['pagina'], 2);
      expect(
        find.byKey(const ValueKey('desktop-product-match-50')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a late response from an older search cannot replace newer results',
    (tester) async {
      final staleResponse = Completer<ProductosPage>();
      final repository = _PageProductsRepository(({
        required pagina,
        required limite,
        q,
        activo,
        disponiblePos,
        sedeId,
      }) {
        if (q == null) {
          return Future.value(
            _page([_product('initial')], pagina: 1, total: 1),
          );
        }
        if (q == 'cereza') return staleResponse.future;
        return Future.value(
          _page([_product('water', name: 'Agua mineral')], pagina: 1, total: 1),
        );
      });

      await _pumpCatalog(
        tester,
        size: const Size(1280, 900),
        repository: repository,
      );
      final search = find.byType(TextField).first;
      await tester.enterText(search, 'cereza');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(repository.calls.last['q'], 'cereza');

      await tester.enterText(search, 'agua');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(repository.calls.last['q'], 'agua');
      expect(
        find.byKey(const ValueKey('desktop-product-water')),
        findsOneWidget,
      );

      staleResponse.complete(
        _page([_product('stale', name: 'Cereza tardía')], pagina: 1, total: 1),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const ValueKey('desktop-product-water')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('desktop-product-stale')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('mobile empty catalog exposes refresh without overflowing', (
    tester,
  ) async {
    final firstPage = Completer<ProductosPage>();
    var requests = 0;
    final repository = _PageProductsRepository(({
      required pagina,
      required limite,
      q,
      activo,
      disponiblePos,
      sedeId,
    }) async {
      requests++;
      if (requests == 1) return firstPage.future;
      return _page([], pagina: pagina, total: 0);
    });

    await _pumpCatalog(
      tester,
      size: const Size(390, 844),
      repository: repository,
    );

    expect(find.text('Sin productos'), findsNothing);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('mobile-products-refresh')))
          .onPressed,
      isNull,
    );
    firstPage.complete(_page([], pagina: 1, total: 0));
    await tester.pump();
    await tester.pump();

    expect(find.text('Sin productos'), findsOneWidget);
    expect(find.byKey(const Key('mobile-products-refresh')), findsOneWidget);
    await tester.tap(find.byKey(const Key('mobile-products-refresh')));
    await tester.pump();
    await tester.pump();

    expect(repository.calls, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop product query errors can be retried', (tester) async {
    var repositoryCalls = 0;
    final repository = _PageProductsRepository(({
      required pagina,
      required limite,
      q,
      activo,
      disponiblePos,
      sedeId,
    }) async {
      if (pagina == 1 && repositoryCalls == 0) {
        repositoryCalls++;
        throw StateError('Catalog temporarily unavailable');
      }
      repositoryCalls++;
      return _page([_product('retried')], pagina: pagina, total: 1);
    });

    await _pumpCatalog(
      tester,
      size: const Size(1280, 900),
      repository: repository,
    );

    expect(find.text('Catalog temporarily unavailable'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('desktop-product-retried')),
      findsOneWidget,
    );
    expect(repository.calls, hasLength(2));
    await tester.tap(find.byKey(const Key('desktop-products-refresh')));
    await tester.pump();
    await tester.pump();
    expect(repository.calls, hasLength(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop cart quantity controls are keyboard operable', (
    tester,
  ) async {
    final repository = _PageProductsRepository(
      ({
        required pagina,
        required limite,
        q,
        activo,
        disponiblePos,
        sedeId,
      }) async => _page([_product('keyboard')], pagina: 1, total: 1),
    );

    await _pumpCatalog(
      tester,
      size: const Size(1280, 900),
      repository: repository,
    );
    await tester.tap(find.byKey(const ValueKey('desktop-product-keyboard')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('product-quantity-field')),
      '2',
    );
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    await _activateByKeyboard(
      tester,
      buttonKey: const ValueKey('desktop-cart-increase-keyboard'),
      icon: Icons.add_rounded,
    );
    expect(find.text('3 productos seleccionados'), findsOneWidget);

    await _activateByKeyboard(
      tester,
      buttonKey: const ValueKey('desktop-cart-decrease-keyboard'),
      icon: Icons.remove_rounded,
    );
    expect(find.text('2 productos seleccionados'), findsOneWidget);

    await _activateByKeyboard(
      tester,
      buttonKey: const ValueKey('desktop-cart-remove-keyboard'),
      icon: Icons.close_rounded,
    );
    expect(
      find.byKey(const ValueKey('desktop-cart-item-keyboard')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
