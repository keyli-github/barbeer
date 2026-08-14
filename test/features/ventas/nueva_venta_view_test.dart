import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:barbeer/core/network/api_client.dart';
import 'package:barbeer/core/network/upload_client.dart';
import 'package:barbeer/core/errors/app_exception.dart';
import 'package:barbeer/features/ventas/data/models/venta_models.dart';
import 'package:barbeer/core/widgets/ds_product_image.dart';
import 'package:barbeer/features/productos/data/productos_repository.dart';
import 'package:barbeer/features/ventas/data/ventas_repository.dart';
import 'package:barbeer/features/ventas/presentation/providers/ventas_provider.dart';
import 'package:barbeer/features/ventas/presentation/screens/nueva_venta_view.dart';
import 'package:barbeer/features/ventas/presentation/widgets/carrito_venta_sheet.dart';
import 'package:barbeer/features/auth/data/models/auth_models.dart';
import 'package:barbeer/features/auth/presentation/providers/auth_provider.dart';
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

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(super.repository, AuthState value) {
    state = value;
  }
}

class _RetryVentasRepository extends VentasRepository {
  _RetryVentasRepository() : super(ApiClient.instance);

  final attempts = <CreateVentaPayload>[];

  @override
  Future<Venta> crearVenta({required CreateVentaPayload payload}) async {
    attempts.add(payload);
    if (attempts.length == 1) throw const NetworkException();
    return Venta(
      id: 'v1',
      codigo: 'V-001',
      cajaSesionId: 'c1',
      sedeId: 's1',
      total: 12,
      estado: EstadoVenta.activa,
      conciliacion: const ConciliacionVenta(
        id: 'co1',
        estado: EstadoConciliacion.efectivo,
      ),
      items: const [],
      createdAt: '2026-08-13T10:00:00Z',
    );
  }
}

class _ReceiptVentasRepository extends VentasRepository {
  _ReceiptVentasRepository({required this.analysis})
    : super(ApiClient.instance);

  final ComprobanteAnalisis analysis;
  var createCalls = 0;

  @override
  Future<List<Etiqueta>> listEtiquetasActivas({String? sedeId}) async => const [
    Etiqueta(
      id: 'et-1',
      nombre: 'Yape',
      activo: true,
      requiereComprobante: true,
      orden: 1,
    ),
  ];

  @override
  Future<ComprobanteAnalisis> analizarComprobante({
    required Uint8List bytes,
    required String filename,
    String? sedeId,
  }) async => analysis;

  @override
  Future<void> cancelarComprobanteAnalisis(String id) async {}

  @override
  Future<Venta> crearVenta({required CreateVentaPayload payload}) async {
    createCalls++;
    throw StateError('No debe crear una venta bloqueada');
  }
}

class _RaceReceiptRepository extends VentasRepository {
  _RaceReceiptRepository() : super(ApiClient.instance);

  final first = Completer<ComprobanteAnalisis>();
  final second = Completer<ComprobanteAnalisis>();
  final cancelled = <String>[];
  var calls = 0;

  @override
  Future<List<Etiqueta>> listEtiquetasActivas({String? sedeId}) async => const [
    Etiqueta(
      id: 'et-1',
      nombre: 'Yape',
      activo: true,
      requiereComprobante: true,
      orden: 1,
    ),
  ];

  @override
  Future<ComprobanteAnalisis> analizarComprobante({
    required Uint8List bytes,
    required String filename,
    String? sedeId,
  }) => calls++ == 0 ? first.future : second.future;

  @override
  Future<void> cancelarComprobanteAnalisis(String id) async {
    cancelled.add(id);
  }
}

ComprobanteAnalisis _validAnalysis(String id, String entity) =>
    ComprobanteAnalisis(
      id: id,
      estado: 'APTO',
      posibleDuplicado: false,
      coincidencias: const [],
      entidad: entity,
      etiquetaSugerida: const Etiqueta(
        id: 'et-1',
        nombre: 'Yape',
        activo: true,
        requiereComprobante: true,
        orden: 1,
      ),
      monto: 12,
      codigoOperacion: id,
      fechaOperacion: '2026-08-13',
      imagenUrl: '/$id.jpg',
      thumbnailUrl: '/$id-thumb.jpg',
      confianza: const ComprobanteConfianza(
        documento: .9,
        entidad: .9,
        monto: .9,
        operacion: .9,
        fecha: .9,
      ),
      advertencias: const [],
      expiraAt: DateTime(2099),
    );

Future<void> _pumpNuevaVenta(
  WidgetTester tester, {
  required Size size,
  required Future<List<Producto>> Function() loader,
  List<String> permissions = const [],
  VentasRepository? repository,
  PickedUploadImage? pickedVoucher,
  Future<PickedUploadImage?> Function()? voucherPicker,
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
                id: 'u1',
                username: 'seller',
                rol: 'VENDEDORA',
                nivel: 10,
                sedeId: 's1',
                createdAt: '2026-01-01',
                permisos: permissions,
              ),
            ),
          ),
        ),
        ventasRepositoryProvider.overrideWithValue(
          repository ?? VentasRepository(ApiClient.instance),
        ),
        if (voucherPicker != null)
          voucherImagePickerProvider.overrideWithValue(voucherPicker)
        else if (pickedVoucher != null)
          voucherImagePickerProvider.overrideWithValue(
            () async => pickedVoucher,
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

    testWidgets('permite precio positivo y muestra detalles de pago', (
      tester,
    ) async {
      await _pumpNuevaVenta(
        tester,
        size: const Size(1440, 900),
        loader: () async => _products,
        permissions: const ['ventas:precio-personalizado'],
      );
      await tester.pump();

      await tester.tap(find.text('+ Agregar').first);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('custom-price-field')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('custom-price-field')), '0');
      await tester.tap(find.text('Guardar'));
      await tester.pump();
      expect(find.text('Ingresa un precio mayor a 0'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('custom-price-field')),
        '16.50',
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sale-details')), findsOneWidget);
      expect(find.byKey(const ValueKey('payment-pendiente')), findsOneWidget);
      expect(find.byKey(const ValueKey('payment-efectivo')), findsOneWidget);
      expect(find.byKey(const ValueKey('payment-billetera')), findsOneWidget);
      expect(find.textContaining('16.50'), findsWidgets);
    });

    testWidgets('reintento ambiguo usa el mismo payload congelado y clave', (
      tester,
    ) async {
      final repo = _RetryVentasRepository();
      await _pumpNuevaVenta(
        tester,
        size: const Size(1440, 900),
        loader: () async => _products,
        repository: repo,
      );
      await tester.pump();
      await tester.tap(find.text('+ Agregar').first);
      await tester.pump();
      await tester.tap(find.byKey(const Key('desktop-cart-confirm')));
      await tester.pump();

      expect(repo.attempts, hasLength(1));
      final frozenPayload = repo.attempts.single;
      expect(find.byKey(const Key('desktop-cart-retry')), findsOneWidget);

      await tester.tap(find.byKey(const Key('desktop-cart-retry')));
      await tester.pump();
      expect(repo.attempts, hasLength(2));
      expect(identical(repo.attempts.first, repo.attempts.last), isTrue);
      expect(repo.attempts.last.idempotencyKey, frozenPayload.idempotencyKey);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('duplicado muestra alerta exacta y bloquea la venta', (
      tester,
    ) async {
      final repo = _ReceiptVentasRepository(
        analysis: ComprobanteAnalisis(
          id: 'analysis-duplicate',
          estado: 'REVISION',
          posibleDuplicado: true,
          coincidencias: const ['IMAGEN_EXACTA'],
          entidad: 'Yape',
          etiquetaSugerida: const Etiqueta(
            id: 'et-1',
            nombre: 'Yape',
            activo: true,
            requiereComprobante: true,
            orden: 1,
          ),
          monto: 12,
          codigoOperacion: 'OP-1',
          codigoSeguridad: 'SEC-1',
          fechaOperacion: '2026-08-13',
          horaOperacion: '10:30:00',
          imagenUrl: '/receipt.jpg',
          thumbnailUrl: '/receipt-thumb.jpg',
          confianza: const ComprobanteConfianza(
            documento: .9,
            entidad: .9,
            monto: .9,
            operacion: .9,
            fecha: .9,
          ),
          advertencias: const ['El comprobante coincide con otro análisis'],
          expiraAt: DateTime(2099),
        ),
      );
      await _pumpNuevaVenta(
        tester,
        size: const Size(1440, 900),
        loader: () async => _products,
        repository: repo,
        pickedVoucher: PickedUploadImage(
          bytes: base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
          ),
          filename: 'voucher.png',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('+ Agregar').first);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('payment-billetera')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('voucher-picker')));
      await tester.pumpAndSettle();

      expect(find.text('Posible comprobante duplicado'), findsOneWidget);
      expect(find.byKey(const Key('receipt-analysis-panel')), findsOneWidget);

      await tester.tap(find.byKey(const Key('desktop-cart-confirm')));
      await tester.pump();
      expect(find.text('Posible comprobante duplicado'), findsWidgets);
      expect(repo.createCalls, 0);
    });

    testWidgets('una respuesta Gemini antigua no reemplaza la selección nueva', (
      tester,
    ) async {
      final repo = _RaceReceiptRepository();
      var picks = 0;
      await _pumpNuevaVenta(
        tester,
        size: const Size(1440, 900),
        loader: () async => _products,
        repository: repo,
        voucherPicker: () async => PickedUploadImage(
          bytes: base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
          ),
          filename: 'voucher-${++picks}.png',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('+ Agregar').first);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('payment-billetera')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('voucher-picker')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('voucher-picker')));
      await tester.pump();
      expect(repo.calls, 2);

      repo.second.complete(_validAnalysis('second', 'Segundo'));
      await tester.pump();
      expect(find.text('Segundo'), findsOneWidget);

      repo.first.complete(_validAnalysis('first', 'Primero'));
      await tester.pump();
      expect(find.text('Segundo'), findsOneWidget);
      expect(find.text('Primero'), findsNothing);
      expect(repo.cancelled, ['first']);
    });
  });
}
