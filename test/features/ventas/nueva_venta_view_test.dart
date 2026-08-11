import 'dart:async';

import 'package:barbeer/core/network/api_client.dart';
import 'package:barbeer/core/widgets/ds_product_image.dart';
import 'package:barbeer/features/productos/data/productos_repository.dart';
import 'package:barbeer/features/ventas/data/ventas_repository.dart';
import 'package:barbeer/features/ventas/presentation/providers/ventas_provider.dart';
import 'package:barbeer/features/ventas/presentation/screens/nueva_venta_view.dart';
import 'package:barbeer/features/ventas/presentation/widgets/carrito_venta_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _products = [
  Producto(
    id: 'p1',
    codigo: 'CER-001',
    nombre: 'Cerveza rubia',
    categoria: 'Cervezas',
    categoriaId: 'c1',
    unidad: 'unidad',
    precioVenta: 12,
    precioCosto: 7,
    disponiblePos: true,
    activo: true,
    margin: 5,
    stockDisponible: 20,
  ),
  Producto(
    id: 'p2',
    codigo: 'CER-002',
    nombre: 'Cerveza negra',
    categoria: 'Cervezas',
    categoriaId: 'c1',
    unidad: 'unidad',
    precioVenta: 14,
    precioCosto: 8,
    disponiblePos: true,
    activo: true,
    margin: 6,
    stockDisponible: 4,
  ),
  Producto(
    id: 'p3',
    codigo: 'COC-001',
    nombre: 'Cóctel de la casa',
    categoria: 'Cócteles',
    categoriaId: 'c2',
    unidad: 'unidad',
    precioVenta: 22,
    precioCosto: 10,
    disponiblePos: true,
    activo: true,
    margin: 12,
    stockDisponible: 10,
  ),
  Producto(
    id: 'p4',
    codigo: 'AGU-001',
    nombre: 'Agua mineral',
    categoria: 'Sin alcohol',
    categoriaId: 'c3',
    unidad: 'unidad',
    precioVenta: 6,
    precioCosto: 2,
    disponiblePos: true,
    activo: true,
    margin: 4,
    stockDisponible: 12,
  ),
];

Future<void> _pumpNuevaVenta(
  WidgetTester tester, {
  required Size size,
  required Future<List<Producto>> Function() loader,
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
        ventasRepositoryProvider.overrideWithValue(
          VentasRepository(ApiClient.instance),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(body: NuevaVentaView(productsLoader: loader)),
      ),
    ),
  );
}

void main() {
  group('NuevaVentaView responsive', () {
    testWidgets('desktop muestra catálogo horizontal y carrito fijo', (
      tester,
    ) async {
      await _pumpNuevaVenta(
        tester,
        size: const Size(1440, 900),
        loader: () async => _products,
      );
      await tester.pump();

      expect(find.byKey(const Key('desktop-sales-layout')), findsOneWidget);
      expect(find.byKey(const Key('desktop-catalog-panel')), findsOneWidget);
      expect(find.byKey(const Key('desktop-cart-panel')), findsOneWidget);
      expect(find.byKey(const Key('mobile-cart-bar')), findsNothing);
      expect(find.byType(DSProductImage), findsNWidgets(_products.length));
      expect(find.text('4 disponibles'), findsOneWidget);

      final grid = tester.widget<GridView>(
        find.byKey(const Key('desktop-catalog-grid')),
      );
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 3);
      expect(delegate.mainAxisExtent, 148);

      final disabledConfirm = tester.widget<ElevatedButton>(
        find.byKey(const Key('desktop-cart-confirm')),
      );
      expect(disabledConfirm.onPressed, isNull);

      await tester.tap(find.text('+ Agregar').first);
      await tester.pump();

      expect(
        find.byKey(const ValueKey('desktop-cart-item-p1')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('desktop-cart-clear')), findsOneWidget);
      expect(find.text('1 producto seleccionado'), findsOneWidget);
      final enabledConfirm = tester.widget<ElevatedButton>(
        find.byKey(const Key('desktop-cart-confirm')),
      );
      expect(enabledConfirm.onPressed, isNotNull);

      await tester.enterText(find.byType(TextField), 'agua');
      await tester.pump();
      expect(find.text('1 disponibles'), findsOneWidget);
      expect(find.byKey(const ValueKey('desktop-product-p4')), findsOneWidget);
    });

    testWidgets('mobile conserva grid responsive y carrito en bottom sheet', (
      tester,
    ) async {
      await _pumpNuevaVenta(
        tester,
        size: const Size(390, 844),
        loader: () async => _products,
      );
      await tester.pump();

      expect(find.byKey(const Key('mobile-sales-layout')), findsOneWidget);
      expect(find.byKey(const Key('desktop-cart-panel')), findsNothing);
      expect(find.byKey(const Key('mobile-cart-bar')), findsNothing);

      final grid = tester.widget<GridView>(
        find.byKey(const Key('mobile-catalog-grid')),
      );
      expect(
        grid.gridDelegate,
        isA<SliverGridDelegateWithMaxCrossAxisExtent>(),
      );

      await tester.tap(find.text('+ Agregar').first);
      await tester.pump();
      expect(find.byKey(const Key('mobile-cart-bar')), findsOneWidget);
      expect(find.byKey(const Key('desktop-cart-panel')), findsNothing);

      await tester.tap(find.byKey(const Key('mobile-cart-bar')));
      await tester.pumpAndSettle();
      expect(find.byType(CarritoVentaSheet), findsOneWidget);
      expect(find.text('CONFIRMAR VENTA'), findsOneWidget);
    });

    testWidgets('muestra estados de carga y error con reintento', (
      tester,
    ) async {
      final loader = Completer<List<Producto>>();
      await _pumpNuevaVenta(
        tester,
        size: const Size(1280, 800),
        loader: () => loader.future,
      );

      expect(find.text('Cargando...'), findsOneWidget);
      loader.completeError(Exception('sin conexión'));
      await tester.pump();
      await tester.pump();

      expect(find.text('No disponible'), findsOneWidget);
      expect(find.text('No se pudieron cargar los productos'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });
}
