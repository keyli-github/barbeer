import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:barbeer/core/network/api_client.dart';
import 'package:barbeer/core/network/upload_client.dart';
import 'package:barbeer/core/errors/app_exception.dart';
import 'package:barbeer/features/ventas/data/models/venta_models.dart';
import 'package:barbeer/core/widgets/ds_product_image.dart';
import 'package:barbeer/features/productos/data/productos_repository.dart';
import 'package:barbeer/features/cuentas/data/cuentas_repository.dart';
import 'package:barbeer/features/cuentas/presentation/providers/cuentas_provider.dart';
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

class _PriceAuthorizationVentasRepository extends VentasRepository {
  _PriceAuthorizationVentasRepository() : super(ApiClient.instance);

  final authorizations = <Map<String, Object>>[];

  @override
  Future<String> autorizarPrecio({
    required String productoId,
    required double precioNuevo,
    required String pin,
  }) async {
    authorizations.add({
      'productoId': productoId,
      'precioNuevo': precioNuevo,
      'pin': pin,
    });
    return 'price-auth-token-p1';
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

class _RejectedAccountSaleRepository extends VentasRepository {
  _RejectedAccountSaleRepository() : super(ApiClient.instance);
  final attempts = <CreateVentaPayload>[];
  @override
  Future<Venta> crearVenta({required CreateVentaPayload payload}) async {
    attempts.add(payload);
    throw const AppException(
      message: 'La cuenta del cliente no existe o está inactiva',
      statusCode: 400,
      code: 'CUENTA_INVALIDA',
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

class _ConfirmReceiptRepository extends VentasRepository {
  _ConfirmReceiptRepository({required this.analysis, this.result})
    : super(ApiClient.instance);

  final ComprobanteAnalisis analysis;
  final Venta? result;
  final creates = <CreateVentaPayload>[];

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
    creates.add(payload);
    return result ??
        Venta(
          id: 'v1',
          codigo: 'V-001',
          cajaSesionId: 'c1',
          sedeId: 's1',
          total: 12,
          estado: EstadoVenta.activa,
          conciliacion: const ConciliacionVenta(
            id: 'co1',
            estado: EstadoConciliacion.billetera,
            etiquetaId: 'et-1',
          ),
          items: const [],
          createdAt: '2026-08-13T10:00:00Z',
        );
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
  Future<List<Producto>> Function()? loader,
  List<String> permissions = const [],
  String role = 'VENDEDORA',
  String? sedeId = 's1',
  VentasRepository? repository,
  CuentasRepository? accountsRepository,
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
                rol: role,
                nivel: 10,
                sedeId: sedeId,
                createdAt: '2026-01-01',
                permisos: permissions,
              ),
            ),
          ),
        ),
        ventasRepositoryProvider.overrideWithValue(
          repository ?? VentasRepository(ApiClient.instance),
        ),
        if (accountsRepository != null)
          cuentasRepositoryProvider.overrideWithValue(accountsRepository),
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
    testWidgets('desktop shows the redesigned dense grid and fixed cart', (
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
      expect(delegate.crossAxisCount, 4);
      expect(delegate.mainAxisExtent, 240);

      final disabledConfirm = tester.widget<ElevatedButton>(
        find.byKey(const Key('desktop-cart-confirm')),
      );
      expect(disabledConfirm.onPressed, isNull);

      await tester.tap(find.byKey(const ValueKey('desktop-product-p1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('add-to-sale-modal')), findsOneWidget);
      expect(find.text('Añadir a la Venta'), findsOneWidget);
      expect(find.text('Precio base: S/ 12.00'), findsOneWidget);
      expect(find.byKey(const Key('product-quantity-field')), findsOneWidget);
      expect(find.byKey(const Key('product-add-total')), findsOneWidget);

      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

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

    testWidgets('mobile usa tarjetas horizontales y carrito en bottom sheet', (
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

      final list = tester.widget<ListView>(
        find.byKey(const Key('mobile-catalog-list')),
      );
      expect(list.scrollDirection, Axis.vertical);

      await tester.tap(find.byKey(const ValueKey('mobile-product-p1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('add-to-sale-modal')), findsOneWidget);

      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
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

    testWidgets('shows approved payment actions after adding an item', (
      tester,
    ) async {
      await _pumpNuevaVenta(
        tester,
        size: const Size(1440, 900),
        loader: () async => _products,
        role: 'SUPERADMIN',
        sedeId: 's1',
        permissions: const ['ventas:precio-personalizado'],
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('desktop-product-p1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('custom-price-field')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('custom-price-field')), '0');
      await tester.tap(find.text('Confirmar'));
      await tester.pump();
      expect(find.text('Ingresa un precio mayor a 0'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('custom-price-field')),
        '16.50',
      );
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sale-details')), findsOneWidget);
      expect(find.byKey(const ValueKey('payment-pendiente')), findsNothing);
      expect(find.byKey(const ValueKey('payment-efectivo')), findsOneWidget);
      expect(find.byKey(const ValueKey('payment-billetera')), findsOneWidget);
      expect(
        find.byKey(const Key('desktop-cart-save-pending')),
        findsOneWidget,
      );
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
      await tester.tap(find.byKey(const ValueKey('desktop-product-p1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('desktop-cart-confirm')).hitTestable(),
        findsOneWidget,
      );
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

    testWidgets(
      'wallet charge sends authoritative fields and keeps backend result through refresh',
      (tester) async {
        var productLoads = 0;
        final accounts = CuentasRepository(
          ApiClient.instance,
          request: (_, _) async => [
            {
              'id': 'account-wallet',
              'nombre': 'Rosa',
              'documento': null,
              'telefono': null,
              'saldo': 3,
              'activo': true,
              'esPersonal': false,
              'cantidadPendientes': 2,
              'createdAt': '2026-08-01T10:00:00Z',
              'updatedAt': '2026-08-01T10:00:00Z',
            },
          ],
        );
        final analysis = ComprobanteAnalisis(
          id: 'analysis-wallet',
          estado: 'APTO',
          posibleDuplicado: false,
          coincidencias: const [],
          entidad: 'Yape',
          etiquetaSugerida: const Etiqueta(
            id: 'et-1',
            nombre: 'Yape',
            activo: true,
            requiereComprobante: true,
            orden: 1,
          ),
          monto: 5,
          codigoOperacion: 'YAPE-7788',
          imagenUrl: '/wallet.jpg',
          thumbnailUrl: '/wallet-thumb.jpg',
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
        final result = Venta(
          id: 'sale-wallet',
          codigo: 'V-CEN-2026-0042',
          cajaSesionId: 'cash-1',
          sedeId: 's1',
          total: 12,
          estado: EstadoVenta.activa,
          cuentaId: 'account-wallet',
          cuentaNombre: 'Rosa',
          cuentaMonto: 7,
          conciliacion: const ConciliacionVenta(
            id: 'pay-1',
            estado: EstadoConciliacion.billetera,
            etiquetaId: 'et-1',
            etiquetaNombre: 'Yape',
            monto: 5,
            comprobante: '/wallet.jpg',
            codigoOperacion: 'YAPE-7788',
          ),
          items: const [],
          createdAt: '2026-08-30T10:00:00Z',
        );
        final sales = _ConfirmReceiptRepository(
          analysis: analysis,
          result: result,
        );
        await _pumpNuevaVenta(
          tester,
          size: const Size(1440, 900),
          loader: () async {
            productLoads++;
            return _products;
          },
          permissions: const ['ventas:crear'],
          repository: sales,
          accountsRepository: accounts,
          pickedVoucher: PickedUploadImage(
            bytes: base64Decode(
              'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
            ),
            filename: 'wallet.png',
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('desktop-product-p1')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirmar'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('payment-billetera')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('wallet-field')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Yape').last);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('voucher-picker')));
        await tester.pumpAndSettle();
        expect(find.text('Cargar diferencia a cuenta'), findsOneWidget);
        await tester.ensureVisible(
          find.byKey(const Key('account-charge-open')),
        );
        await tester.tap(find.byKey(const Key('account-charge-open')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('account-option-account-wallet')),
        );
        await tester.pump();
        expect(find.text('Monto en comprobante (S/)'), findsOneWidget);
        expect(find.textContaining('7.00'), findsOneWidget);
        await tester.tap(find.byKey(const Key('account-charge-apply')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const Key('desktop-cart-confirm')),
        );
        await tester.tap(find.byKey(const Key('desktop-cart-confirm')));
        await tester.pumpAndSettle();

        final payload = sales.creates.single.json;
        expect(payload['cuentaId'], 'account-wallet');
        expect(payload['cuentaMonto'], 7);
        expect(payload['comprobanteAnalisisIds'], ['analysis-wallet']);
        expect(payload.containsKey('comprobante'), isFalse);
        expect(find.text('Venta V-CEN-2026-0042 registrada'), findsOneWidget);
        expect(find.textContaining('Billetera · Yape'), findsOneWidget);
        expect(find.textContaining('Comprobante: YAPE-7788'), findsOneWidget);
        expect(find.textContaining('Cuenta: Rosa · S/ 7.00'), findsOneWidget);
        expect(productLoads, 2);
      },
    );

    testWidgets(
      'charged-sale selector retries, stays backend-backed, and preserves rejected draft',
      (tester) async {
        final first = Completer<Object?>();
        var calls = 0;
        final accounts = CuentasRepository(
          ApiClient.instance,
          request: (_, query) {
            calls++;
            if (calls == 1) return first.future;
            if (calls == 2) return Future.value(<Object?>[]);
            return Future.value([
              {
                'id': 'account-1',
                'nombre': 'Ana',
                'documento': null,
                'telefono': null,
                'saldo': 8,
                'activo': true,
                'esPersonal': true,
                'cantidadPendientes': 1,
                'createdAt': '2026-08-01T10:00:00Z',
                'updatedAt': '2026-08-01T10:00:00Z',
              },
            ]);
          },
        );
        final sales = _RejectedAccountSaleRepository();
        await _pumpNuevaVenta(
          tester,
          size: const Size(1440, 900),
          loader: () async => _products,
          permissions: const ['ventas:crear'],
          repository: sales,
          accountsRepository: accounts,
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('desktop-product-p1')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirmar'));
        await tester.pumpAndSettle();
        expect(find.text('Cargar diferencia a cuenta'), findsOneWidget);
        await tester.tap(find.byKey(const Key('account-charge-open')));
        await tester.pump();
        expect(find.text('Buscando cuentas...'), findsOneWidget);
        first.completeError(
          const AppException(
            message: 'No se pudieron buscar las cuentas.',
            statusCode: 503,
          ),
        );
        await tester.pump();
        expect(find.text('No se pudieron buscar las cuentas.'), findsOneWidget);
        await tester.tap(find.text('Reintentar'));
        await tester.pumpAndSettle();
        expect(find.text('No se encontraron resultados'), findsOneWidget);
        await tester.enterText(find.byKey(const Key('account-search')), 'Ana');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        expect(find.textContaining('1 pendiente'), findsOneWidget);
        await tester.ensureVisible(
          find.byKey(const Key('account-option-account-1')),
        );
        await tester.tap(find.byKey(const Key('account-option-account-1')));
        await tester.pump();
        expect(find.text('Cuenta personal'), findsOneWidget);
        expect(find.text('Cliente Seleccionado: Ana'), findsOneWidget);
        await tester.enterText(
          find.byKey(const Key('account-cash-amount')),
          '5',
        );
        await tester.pump();
        await tester.ensureVisible(
          find.byKey(const Key('account-charge-apply')),
        );
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('account-charge-apply')),
              )
              .onPressed,
          isNotNull,
        );
        await tester.tap(find.byKey(const Key('account-charge-apply')));
        await tester.pumpAndSettle();
        expect(find.text('Cargar a Cuenta de Cliente'), findsNothing);
        expect(find.text('Cargado a cuenta (Ana)'), findsOneWidget);
        await tester.ensureVisible(
          find.byKey(const Key('desktop-cart-confirm')),
        );
        await tester.tap(find.byKey(const Key('desktop-cart-confirm')));
        await tester.pump();
        expect(sales.attempts.single.json['cuentaId'], 'account-1');
        expect(sales.attempts.single.json['cuentaMonto'], 7);
        expect(
          find.textContaining(
            'La cuenta del cliente no existe o está inactiva',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('CUENTA_INVALIDA'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('desktop-cart-item-p1')),
          findsOneWidget,
        );
        expect(find.text('Cargado a cuenta (Ana)'), findsOneWidget);
      },
    );

    testWidgets('account charge stays hidden without selector permissions', (
      tester,
    ) async {
      var selectorCalls = 0;
      final accounts = CuentasRepository(
        ApiClient.instance,
        request: (_, _) async {
          selectorCalls++;
          return [];
        },
      );
      await _pumpNuevaVenta(
        tester,
        size: const Size(1440, 900),
        loader: () async => _products,
        accountsRepository: accounts,
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('desktop-product-p1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('account-charge-open')), findsNothing);
      expect(selectorCalls, 0);
    });

    testWidgets(
      'mobile creates an account then charges the full sale through production submit',
      (tester) async {
        late String createPath;
        late Map<String, dynamic> createBody;
        final accounts = CuentasRepository(
          ApiClient.instance,
          request: (_, _) async => [],
          post: (path, body) async {
            createPath = path;
            createBody = body;
            return {
              'id': 'created-account',
              'nombre': 'Luis',
              'documento': null,
              'telefono': null,
              'saldo': '0',
              'activo': true,
              'cantidadPendientes': null,
              'createdAt': '2026-08-01T10:00:00Z',
              'updatedAt': '2026-08-01T10:00:00Z',
            };
          },
        );
        final sales = _ConfirmReceiptRepository(
          analysis: _validAnalysis('unused', 'Yape'),
        );
        await _pumpNuevaVenta(
          tester,
          size: const Size(390, 844),
          loader: () async => _products,
          permissions: const ['ventas:crear', 'cuentas:crear'],
          repository: sales,
          accountsRepository: accounts,
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('mobile-product-p1')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirmar'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('mobile-cart-bar')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const Key('account-charge-open')),
        );
        await tester.tap(find.byKey(const Key('account-charge-open')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Crear Nueva Cuenta'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('account-name')), ' Luis ');
        await tester.pump();
        await tester.tap(find.byKey(const Key('account-create-submit')));
        await tester.pumpAndSettle();
        expect(find.text('Cliente Seleccionado: Luis'), findsOneWidget);
        await tester.enterText(
          find.byKey(const Key('account-cash-amount')),
          '0',
        );
        await tester.pump();
        await tester.ensureVisible(
          find.byKey(const Key('account-charge-apply')),
        );
        await tester.tap(find.byKey(const Key('account-charge-apply')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('CONFIRMAR VENTA'));
        await tester.tap(find.text('CONFIRMAR VENTA'));
        await tester.pumpAndSettle();
        expect(createPath, '/cuentas');
        expect(createBody, {'nombre': 'Luis'});
        expect(sales.creates.single.json['cuentaId'], 'created-account');
        expect(sales.creates.single.json['cuentaMonto'], 12);
        expect(find.byKey(const Key('mobile-cart-bar')), findsNothing);
      },
    );

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

      await tester.tap(find.byKey(const ValueKey('desktop-product-p1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('payment-billetera')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('voucher-picker')));
      await tester.pumpAndSettle();

      expect(find.text('Posible comprobante duplicado'), findsOneWidget);
      expect(find.byKey(const Key('receipt-analysis-panel')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('desktop-cart-confirm')));
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
      await tester.tap(find.byKey(const ValueKey('desktop-product-p1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
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

    testWidgets('autoriza el precio personalizado con PIN de SUPERADMIN', (
      tester,
    ) async {
      final repository = _PriceAuthorizationVentasRepository();
      await _pumpNuevaVenta(
        tester,
        size: const Size(390, 844),
        loader: () async => _products,
        repository: repository,
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('mobile-product-p1')));
      await tester.pumpAndSettle();

      final field = tester.widget<TextFormField>(
        find.byKey(const Key('custom-price-field')),
      );
      expect(field.enabled, isTrue);

      await tester.enterText(
        find.byKey(const Key('custom-price-field')),
        '8.75',
      );
      await tester.pump();
      await tester.enterText(find.byKey(const Key('precio-auth-pin')), '1234');
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(repository.authorizations, [
        {'productoId': 'p1', 'precioNuevo': 8.75, 'pin': '1234'},
      ]);
      expect(find.byKey(const Key('mobile-cart-bar')), findsOneWidget);
    });

    testWidgets('sin sede muestra una indicación neutral, no un error', (
      tester,
    ) async {
      await _pumpNuevaVenta(
        tester,
        size: const Size(1440, 900),
        role: 'SUPERADMIN',
        sedeId: null,
      );
      await tester.pump();

      expect(find.byKey(const Key('select-sede-empty-state')), findsOneWidget);
      expect(find.text('Selecciona una sede'), findsWidgets);
      expect(find.text('Algo salió mal'), findsNothing);
      expect(find.text('Reintentar'), findsNothing);
    });

    testWidgets('el dropdown de billetera abre y lista billeteras reales', (
      tester,
    ) async {
      final repo = _ReceiptVentasRepository(
        analysis: _validAnalysis('analysis-1', 'Yape'),
      );
      await _pumpNuevaVenta(
        tester,
        size: const Size(1440, 900),
        loader: () async => _products,
        repository: repo,
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('desktop-product-p1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('payment-billetera')));
      await tester.pump();

      expect(find.byKey(const Key('wallet-field')), findsOneWidget);
      await tester.tap(find.byKey(const Key('wallet-field')));
      await tester.pumpAndSettle();

      expect(find.text('Yape'), findsWidgets);
      await tester.tap(find.text('Yape').last);
      await tester.pumpAndSettle();

      final dropdown = tester.widget<DropdownButton<String>>(
        find.byKey(const Key('wallet-field')),
      );
      expect(dropdown.value, 'et-1');
      expect(find.text('Yape'), findsWidgets);
    });

    testWidgets('monto menor al total: permite confirmar y avisa pago parcial', (
      tester,
    ) async {
      final repo = _ConfirmReceiptRepository(
        analysis: ComprobanteAnalisis(
          id: 'analysis-partial',
          estado: 'APTO',
          posibleDuplicado: false,
          coincidencias: const [],
          entidad: 'Yape',
          etiquetaSugerida: const Etiqueta(
            id: 'et-1',
            nombre: 'Yape',
            activo: true,
            requiereComprobante: true,
            orden: 1,
          ),
          monto: 10,
          codigoOperacion: 'OP-P',
          codigoSeguridad: 'SEC-P',
          fechaOperacion: '2026-08-13',
          horaOperacion: '12:30:00',
          imagenUrl: '/receipt-partial.jpg',
          thumbnailUrl: '/receipt-partial-thumb.jpg',
          confianza: const ComprobanteConfianza(
            documento: .9,
            entidad: .9,
            monto: .9,
            operacion: .9,
            fecha: .9,
          ),
          advertencias: const [],
          expiraAt: DateTime(2099),
        ),
      );
      await _pumpNuevaVenta(
        tester,
        size: const Size(1440, 900),
        loader: () async => _products,
        repository: repo,
        voucherPicker: () async => PickedUploadImage(
          bytes: base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
          ),
          filename: 'voucher-partial.png',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('desktop-product-p1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('payment-billetera')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('voucher-picker')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Monto menor al total'),
        findsOneWidget,
        reason: 'Pago parcial: se avisa pero no bloquea',
      );

      await tester.ensureVisible(find.byKey(const Key('desktop-cart-confirm')));
      await tester.tap(find.byKey(const Key('desktop-cart-confirm')));
      await tester.pumpAndSettle();

      expect(repo.creates, hasLength(1));
      expect(repo.creates.single.json['comprobanteAnalisisIds'], [
        'analysis-partial',
      ]);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('monto mayor al total: bloquea la confirmación', (
      tester,
    ) async {
      final repo = _ReceiptVentasRepository(
        analysis: ComprobanteAnalisis(
          id: 'analysis-over',
          estado: 'APTO',
          posibleDuplicado: false,
          coincidencias: const [],
          entidad: 'Yape',
          etiquetaSugerida: const Etiqueta(
            id: 'et-1',
            nombre: 'Yape',
            activo: true,
            requiereComprobante: true,
            orden: 1,
          ),
          monto: 30,
          codigoOperacion: 'OP-O',
          codigoSeguridad: 'SEC-O',
          fechaOperacion: '2026-08-13',
          horaOperacion: '12:30:00',
          imagenUrl: '/receipt-over.jpg',
          thumbnailUrl: '/receipt-over-thumb.jpg',
          confianza: const ComprobanteConfianza(
            documento: .9,
            entidad: .9,
            monto: .9,
            operacion: .9,
            fecha: .9,
          ),
          advertencias: const [],
          expiraAt: DateTime(2099),
        ),
      );
      await _pumpNuevaVenta(
        tester,
        size: const Size(1440, 900),
        loader: () async => _products,
        repository: repo,
        voucherPicker: () async => PickedUploadImage(
          bytes: base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
          ),
          filename: 'voucher-over.png',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('desktop-product-p1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('payment-billetera')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('voucher-picker')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('supera el total'),
        findsOneWidget,
        reason:
            'El monto del comprobante supera el total → no se puede confirmar',
      );

      await tester.ensureVisible(find.byKey(const Key('desktop-cart-confirm')));
      await tester.tap(find.byKey(const Key('desktop-cart-confirm')));
      await tester.pump();

      expect(repo.createCalls, 0, reason: 'No debe crear la venta');
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets(
      'post-success partial refresh shows sale result and stock warning without retrying',
      (tester) async {
        var productLoads = 0;
        final result = Venta(
          id: 'sale-refresh',
          codigo: 'V-REF-001',
          cajaSesionId: 'c1',
          sedeId: 's1',
          total: 12,
          estado: EstadoVenta.activa,
          cuentaId: 'acc-1',
          cuentaNombre: 'Elena',
          cuentaMonto: 12,
          conciliacion: const ConciliacionVenta(
            id: 'pay-1',
            estado: EstadoConciliacion.efectivo,
          ),
          items: const [],
          createdAt: '2026-08-30T10:00:00Z',
        );
        final sales = _ConfirmReceiptRepository(
          analysis: _validAnalysis('unused', 'Yape'),
          result: result,
        );
        await _pumpNuevaVenta(
          tester,
          size: const Size(1440, 900),
          loader: () async {
            productLoads++;
            if (productLoads > 1) throw Exception('stock refresh failure');
            return _products;
          },
          repository: sales,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('desktop-product-p1')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirmar'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const Key('desktop-cart-confirm')),
        );
        await tester.tap(find.byKey(const Key('desktop-cart-confirm')));
        await tester.pumpAndSettle();

        expect(sales.creates, hasLength(1));
        expect(find.text('Venta V-REF-001 registrada'), findsOneWidget);
        expect(find.textContaining('Cuenta: Elena'), findsOneWidget);
        expect(
          find.textContaining('no se pudo actualizar el stock'),
          findsOneWidget,
        );
        expect(productLoads, 2);
        // Cart cleared — sale was NOT retried with a new key
        expect(
          find.byKey(const ValueKey('desktop-cart-item-p1')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'wallet 400 rejection preserves billetera, receipt, account, and cart intact',
      (tester) async {
        final analysis = ComprobanteAnalisis(
          id: 'analysis-rej',
          estado: 'APTO',
          posibleDuplicado: false,
          coincidencias: const [],
          entidad: 'BCP',
          etiquetaSugerida: const Etiqueta(
            id: 'et-1',
            nombre: 'Yape',
            activo: true,
            requiereComprobante: true,
            orden: 1,
          ),
          monto: 5,
          codigoOperacion: 'BCP-9900',
          imagenUrl: '/bcp.jpg',
          thumbnailUrl: '/bcp-thumb.jpg',
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
        final creates = <CreateVentaPayload>[];
        final repo = _WalletRejectedRepository(
          analysis: analysis,
          creates: creates,
        );
        final accounts = CuentasRepository(
          ApiClient.instance,
          request: (_, _) async => [
            {
              'id': 'acc-w',
              'nombre': 'Pedro',
              'documento': null,
              'telefono': null,
              'saldo': 5,
              'activo': true,
              'esPersonal': false,
              'cantidadPendientes': 0,
              'createdAt': '2026-01-01T00:00:00Z',
              'updatedAt': '2026-01-01T00:00:00Z',
            },
          ],
        );
        await _pumpNuevaVenta(
          tester,
          size: const Size(1440, 900),
          loader: () async => _products,
          permissions: const ['ventas:crear'],
          repository: repo,
          accountsRepository: accounts,
          pickedVoucher: PickedUploadImage(
            bytes: base64Decode(
              'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
            ),
            filename: 'receipt.png',
          ),
        );
        await tester.pumpAndSettle();

        // Add product to cart
        await tester.tap(find.byKey(const ValueKey('desktop-product-p1')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirmar'));
        await tester.pumpAndSettle();

        // Select billetera payment
        await tester.tap(find.byKey(const ValueKey('payment-billetera')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('wallet-field')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Yape').last);
        await tester.pumpAndSettle();

        // Pick and analyze receipt
        await tester.tap(find.byKey(const Key('voucher-picker')));
        await tester.pumpAndSettle();
        expect(find.text('BCP'), findsOneWidget);

        // Open account charge and select account
        expect(find.text('Cargar diferencia a cuenta'), findsOneWidget);
        await tester.ensureVisible(
          find.byKey(const Key('account-charge-open')),
        );
        await tester.tap(find.byKey(const Key('account-charge-open')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('account-option-acc-w')));
        await tester.pump();
        expect(find.text('Monto en comprobante (S/)'), findsOneWidget);
        await tester.tap(find.byKey(const Key('account-charge-apply')));
        await tester.pumpAndSettle();
        expect(find.text('Cargado a cuenta (Pedro)'), findsOneWidget);

        // Submit → 400 rejection
        await tester.ensureVisible(
          find.byKey(const Key('desktop-cart-confirm')),
        );
        await tester.tap(find.byKey(const Key('desktop-cart-confirm')));
        await tester.pump();

        // Assert full state preserved
        expect(creates, hasLength(1));
        expect(find.textContaining('Cuenta inactiva'), findsOneWidget);
        expect(find.textContaining('CUENTA_INACTIVA'), findsOneWidget);
        // Cart item preserved
        expect(
          find.byKey(const ValueKey('desktop-cart-item-p1')),
          findsOneWidget,
        );
        // Account charge preserved
        expect(find.text('Cargado a cuenta (Pedro)'), findsOneWidget);
        // Receipt analysis preserved
        expect(find.byKey(const Key('receipt-analysis-panel')), findsOneWidget);
        expect(find.text('BCP'), findsOneWidget);
        // Wallet still selected
        expect(find.byKey(const Key('wallet-field')), findsOneWidget);
      },
    );
  });
}

class _WalletRejectedRepository extends VentasRepository {
  _WalletRejectedRepository({required this.analysis, required this.creates})
    : super(ApiClient.instance);
  final ComprobanteAnalisis analysis;
  final List<CreateVentaPayload> creates;

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
    creates.add(payload);
    throw const AppException(
      message: 'Cuenta inactiva o monto insuficiente',
      statusCode: 400,
      code: 'CUENTA_INACTIVA',
    );
  }
}
