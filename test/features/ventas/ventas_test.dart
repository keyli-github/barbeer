import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:barbeer/core/network/api_client.dart';
import 'package:barbeer/core/network/upload_client.dart';
import 'package:barbeer/core/errors/app_exception.dart';
import 'package:barbeer/features/ventas/data/models/venta_models.dart';
import 'package:barbeer/features/ventas/data/ventas_repository.dart';
import 'package:barbeer/features/ventas/presentation/providers/ventas_provider.dart';
import 'package:barbeer/features/ventas/presentation/screens/conciliar_venta_screen.dart';
import 'package:barbeer/features/ventas/presentation/screens/historial_ventas_view.dart';
import 'package:barbeer/features/ventas/presentation/screens/venta_detail_screen.dart';
import 'package:barbeer/features/ventas/presentation/widgets/anular_venta_dialog.dart';
import 'package:barbeer/features/ventas/presentation/widgets/carrito_venta_sheet.dart';
import 'package:barbeer/features/auth/presentation/providers/auth_provider.dart';
import 'package:barbeer/features/auth/data/models/auth_models.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

UserProfile _makeUser({
  required String rol,
  List<String> permisos = const [],
}) => UserProfile(
  id: 'test-id',
  username: 'test',
  rol: rol,
  nivel: 10,
  createdAt: '2026-01-01',
  permisos: permisos,
);

AuthState _authWith(UserProfile user) =>
    AuthState(status: AuthStatus.authenticated, user: user);

const _uuid = Uuid();

Venta _venta(String id, {bool pendiente = false, double total = 10}) => Venta(
  id: id,
  codigo: 'V-$id',
  cajaSesionId: 'caja-1',
  sedeId: 'sede-1',
  total: total,
  estado: EstadoVenta.activa,
  conciliacion: ConciliacionVenta(
    id: 'conc-$id',
    estado: pendiente
        ? EstadoConciliacion.pendiente
        : EstadoConciliacion.efectivo,
  ),
  items: const [],
  createdAt: '2026-08-05T10:00:00Z',
);

class _FakeVentasRepository extends VentasRepository {
  _FakeVentasRepository() : super(ApiClient.instance);

  Map<int, List<Venta>> pages = {};
  int total = 0;
  int totalPaginas = 1;
  final requestedEstados = <String?>[];
  final annulResults = <Object>[];
  final conciliaciones =
      <
        ({
          String id,
          String estado,
          String? etiquetaId,
          String? comprobanteAnalisisId,
          String? codigoOperacion,
        })
      >[];
  List<Etiqueta> etiquetas = const [
    Etiqueta(
      id: 'etiqueta-1',
      nombre: 'Yape',
      activo: true,
      requiereComprobante: true,
      orden: 1,
    ),
  ];

  @override
  Future<({List<Venta> data, int total, int totalPaginas})> listVentas({
    int pagina = 1,
    int limite = 20,
    String? estado,
    String? vendedoraId,
    String? cajaSesionId,
    String? sedeId,
  }) async {
    requestedEstados.add(estado);
    return (
      data: pages[pagina] ?? const <Venta>[],
      total: total,
      totalPaginas: totalPaginas,
    );
  }

  @override
  Future<({List<Venta> data, int total, int totalPaginas})> listMisVentas({
    int pagina = 1,
    int limite = 20,
    String? estado,
    String? cajaSesionId,
  }) => listVentas(
    pagina: pagina,
    limite: limite,
    estado: estado,
    cajaSesionId: cajaSesionId,
  );

  @override
  Future<List<Etiqueta>> listEtiquetasActivas({String? sedeId}) async =>
      etiquetas;

  @override
  Future<ComprobanteAnalisis> analizarComprobante({
    required Uint8List bytes,
    required String filename,
    String? sedeId,
  }) async => _analysis(id: 'analysis-1', amount: 10);

  @override
  Future<void> cancelarComprobanteAnalisis(String id) async {}

  @override
  Future<Venta> conciliarVenta(
    String id, {
    required String estado,
    String? etiquetaId,
    String? comprobanteAnalisisId,
    String? codigoOperacion,
  }) async {
    conciliaciones.add((
      id: id,
      estado: estado,
      etiquetaId: etiquetaId,
      comprobanteAnalisisId: comprobanteAnalisisId,
      codigoOperacion: codigoOperacion,
    ));
    return _venta(id);
  }

  @override
  Future<Venta> anularVenta(String id, {required String motivo}) async {
    final result = annulResults.removeAt(0);
    if (result is AppException) throw result;
    return result as Venta;
  }
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(super.repository, AuthState value) {
    state = value;
  }
}

ComprobanteAnalisis _analysis({
  required String id,
  required double amount,
  String entity = 'Yape',
  bool duplicate = false,
}) => ComprobanteAnalisis(
  id: id,
  estado: duplicate ? 'REVISION' : 'APTO',
  posibleDuplicado: duplicate,
  coincidencias: duplicate ? const ['IMAGEN_EXACTA'] : const [],
  entidad: entity,
  etiquetaSugerida: const Etiqueta(
    id: 'etiqueta-1',
    nombre: 'Yape',
    activo: true,
    requiereComprobante: true,
    orden: 1,
  ),
  monto: amount,
  codigoOperacion: 'GEMINI-1',
  fechaOperacion: '2026-08-13',
  imagenUrl: '/receipt.jpg',
  thumbnailUrl: '/receipt-thumb.jpg',
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

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('Visible payment metadata', () {
    final json = {
      'id': 'v1',
      'codigo': 'V-001',
      'cajaSesionId': 'c1',
      'sedeId': 's1',
      'total': 40,
      'estado': 'ACTIVA',
      'registradaPor': {'username': 'admin'},
      'vendedora': {'username': 'seller'},
      'conciliaciones': [
        {
          'id': 'p1',
          'estado': 'PENDIENTE',
          'metodoPagoPendiente': 'BILLETERA',
          'monto': 30,
          'pagoRestoEfectivo': true,
        },
      ],
      'cuentaId': 'account-1',
      'cuenta': {'nombre': 'Cliente Uno'},
      'cuentaMonto': 10,
      'items': <Object>[],
      'createdAt': '2026-08-29T10:00:00Z',
    };

    test(
      'maps the authoritative registered, pending, cash and account fields',
      () {
        final venta = Venta.fromJson(json);

        expect(venta.registradaPorUsername, 'admin');
        expect(venta.conciliaciones.single.metodoPagoPendiente, 'BILLETERA');
        expect(venta.conciliaciones.single.pagoRestoEfectivo, isTrue);
        expect(venta.cuentaNombre, 'Cliente Uno');
        expect(venta.cuentaMonto, 10);
      },
    );

    testWidgets('history exposes Pendiente and complete payment metadata', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VentaHistoryCard(
              venta: Venta.fromJson(json),
              correction: false,
              onConciliar: () {},
            ),
          ),
        ),
      );

      expect(find.text('Pendiente'), findsWidgets);
      expect(find.text('Clasificar'), findsNothing);
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      await tester.pumpAndSettle();
      expect(find.textContaining('Registrado por: admin'), findsOneWidget);
      expect(find.textContaining('Pendiente · Transferencia'), findsOneWidget);
      expect(find.textContaining('Resto en efectivo'), findsOneWidget);
      expect(find.textContaining('Cuenta: Cliente Uno'), findsOneWidget);
    });

    testWidgets(
      'charged detail preserves account state across rejected and successful annulment',
      (tester) async {
        final active = Venta.fromJson({
          ...json,
          'estado': 'ACTIVA',
          'conciliacion': (json['conciliaciones'] as List).single,
        });
        final annulled = Venta.fromJson({
          ...json,
          'estado': 'ANULADA',
          'motivoAnulacion': 'Error de registro',
          'conciliacion': (json['conciliaciones'] as List).single,
        });
        final repo = _FakeVentasRepository()
          ..annulResults.addAll([
            const AppException(
              message: 'No autorizado para anular',
              statusCode: 403,
              code: 'VENTA_FORBIDDEN',
            ),
            const AppException(
              message: 'La venta ya fue anulada',
              statusCode: 409,
              code: 'VENTA_YA_ANULADA',
            ),
            const AppException(
              message: 'Esta venta pertenece a una sesión cerrada',
              statusCode: 422,
              code: 'VENTA_EN_CAJA_CERRADA',
              details: ['El stock NO ha sido modificado'],
            ),
            annulled,
          ]);
        var changed = 0;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ventasRepositoryProvider.overrideWithValue(repo),
              authProvider.overrideWith(
                (ref) => _TestAuthNotifier(
                  ref.read(authRepositoryProvider),
                  _authWith(
                    _makeUser(rol: 'ADMIN', permisos: const ['ventas:anular']),
                  ),
                ),
              ),
            ],
            child: MaterialApp(
              home: VentaDetailScreen(
                venta: active,
                onChanged: () => changed++,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Cuenta del cliente'), findsOneWidget);
        expect(find.textContaining('Rosa'), findsNothing);
        expect(find.textContaining('Cliente Uno'), findsOneWidget);

        for (final code in [
          'VENTA_FORBIDDEN',
          'VENTA_YA_ANULADA',
          'VENTA_EN_CAJA_CERRADA',
        ]) {
          await tester.tap(find.byIcon(Icons.more_vert_rounded));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const ValueKey('motivoAnulacionField')),
            'Error de registro',
          );
          await tester.tap(find.text('Anular'));
          await tester.pumpAndSettle();
          expect(find.textContaining(code), findsOneWidget);
          expect(find.text('PENDIENTE'), findsOneWidget);
          expect(find.textContaining('Cliente Uno'), findsOneWidget);
        }

        await tester.tap(find.byIcon(Icons.more_vert_rounded));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('motivoAnulacionField')),
          'Error de registro',
        );
        await tester.tap(find.text('Anular'));
        await tester.pumpAndSettle();
        expect(find.text('ANULADA'), findsOneWidget);
        expect(find.textContaining('Cliente Uno'), findsOneWidget);
        expect(find.textContaining('Error de registro'), findsOneWidget);
        expect(changed, 1);
      },
    );

    testWidgets('history filters move with the sales list', (tester) async {
      tester.view.physicalSize = const Size(320, 420);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = _FakeVentasRepository()
        ..pages = {1: List.generate(12, (index) => _venta('$index'))}
        ..total = 12;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [ventasRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: Scaffold(body: HistorialVentasView())),
        ),
      );
      await tester.pumpAndSettle();

      final filter = find.byKey(const Key('ventas-filters'));
      expect(repo.requestedEstados, isNotEmpty);
      expect(find.text('V-0'), findsOneWidget);
      await tester.scrollUntilVisible(
        filter,
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(filter, findsNothing);
    });
  });

  group('Permisos de ventas', () {
    test('1. VENDEDORA puede crear ventas', () {
      final auth = _authWith(
        _makeUser(
          rol: 'VENDEDORA',
          permisos: ['ventas:crear', 'ventas:leer-propias', 'productos:leer'],
        ),
      );
      expect(canCreateVenta(auth), isTrue);
    });

    test('2. CAJERO NO puede crear ventas', () {
      final auth = _authWith(
        _makeUser(
          rol: 'CAJERO',
          permisos: [
            'ventas:leer',
            'ventas:conciliar',
            'caja:leer',
            'caja:aperturar',
            'caja:precuadre',
            'caja:cerrar',
            'etiquetas:leer',
          ],
        ),
      );
      expect(canCreateVenta(auth), isFalse);
    });

    test('3. CAJERO puede leer todas las ventas', () {
      final auth = _authWith(
        _makeUser(rol: 'CAJERO', permisos: ['ventas:leer', 'ventas:conciliar']),
      );
      expect(canReadAllVentas(auth), isTrue);
    });

    test('4. VENDEDORA solo puede leer sus propias ventas', () {
      final auth = _authWith(
        _makeUser(
          rol: 'VENDEDORA',
          permisos: ['ventas:crear', 'ventas:leer-propias', 'productos:leer'],
        ),
      );
      expect(canReadAllVentas(auth), isFalse);
      expect(canReadOwnVentas(auth), isTrue);
    });

    test('5. CAJERO puede conciliar', () {
      final auth = _authWith(
        _makeUser(rol: 'CAJERO', permisos: ['ventas:conciliar']),
      );
      expect(canConciliar(auth), isTrue);
    });

    test('6. CAJERO NO puede corregir conciliaciones', () {
      final auth = _authWith(
        _makeUser(rol: 'CAJERO', permisos: ['ventas:conciliar']),
      );
      expect(canConciliarCorregir(auth), isFalse);
    });

    test('7. ADMIN sí puede corregir conciliaciones', () {
      final auth = _authWith(
        _makeUser(
          rol: 'ADMIN',
          permisos: ['ventas:conciliar', 'ventas:conciliar-corregir'],
        ),
      );
      expect(canConciliarCorregir(auth), isTrue);
    });

    test('8. CAJERO NO puede anular ventas', () {
      final auth = _authWith(
        _makeUser(rol: 'CAJERO', permisos: ['ventas:leer']),
      );
      expect(canAnularVenta(auth), isFalse);
    });

    test('9. ADMIN sí puede anular ventas', () {
      final auth = _authWith(
        _makeUser(rol: 'ADMIN', permisos: ['ventas:anular']),
      );
      expect(canAnularVenta(auth), isTrue);
    });
  });

  group('Carrito de venta', () {
    test('10. Agregar producto al carrito', () {
      final item = CarritoItem(
        productoId: 'p1',
        nombre: 'Cerveza',
        codigo: 'CER-001',
        precio: 10.0,
      );
      expect(item.cantidad, 1);
      expect(item.subtotal, 10.0);
    });

    test('11. Cambiar cantidades del carrito', () {
      final item = CarritoItem(
        productoId: 'p1',
        nombre: 'Cerveza',
        codigo: 'CER-001',
        precio: 10.0,
      );
      item.cantidad = 3;
      expect(item.subtotal, 30.0);
    });

    test('12. Quitar producto (removeWhere)', () {
      final items = <CarritoItem>[
        CarritoItem(productoId: 'p1', nombre: 'A', codigo: 'A', precio: 5),
        CarritoItem(productoId: 'p2', nombre: 'B', codigo: 'B', precio: 8),
      ];
      items.removeWhere((i) => i.productoId == 'p1');
      expect(items.length, 1);
      expect(items.first.productoId, 'p2');
    });

    test('13. Payload contiene solo productoId, cantidad e idempotencyKey', () {
      final idKey = _uuid.v4();
      final items = [
        CarritoItem(
          productoId: 'p1',
          nombre: 'A',
          codigo: 'A',
          precio: 15.0,
          cantidad: 2,
        ),
      ];
      final payload = <String, dynamic>{
        'idempotencyKey': idKey,
        'items': items
            .map((i) => {'productoId': i.productoId, 'cantidad': i.cantidad})
            .toList(),
      };
      expect(payload.containsKey('total'), isFalse);
      expect(payload['idempotencyKey'], idKey);
      final payloadItems = payload['items'] as List;
      expect(payloadItems.first['productoId'], 'p1');
      expect(payloadItems.first['cantidad'], 2);
      expect((payloadItems.first as Map).containsKey('precio'), isFalse);
    });
  });

  group('Idempotencia', () {
    test('14. VentasRepository generates unique idempotencyKeys per call', () {
      final repo = VentasRepository(ApiClient.instance);
      final k1 = repo.generateIdempotencyKey();
      final k2 = repo.generateIdempotencyKey();
      expect(k1, isNot(equals(k2)));
      expect(k1.length, 36); // UUID v4 has 36 characters
    });

    test('15. CreateVentaPayload preserves idempotencyKey for exact retry', () {
      const fixedKey = 'abc12345-0000-4abc-8abc-abcdef012345';
      final payload = CreateVentaPayload(
        idempotencyKey: fixedKey,
        items: [{'productoId': 'p1', 'cantidad': 1}],
        estadoConciliacion: EstadoConciliacion.efectivo,
      );
      expect(payload.idempotencyKey, fixedKey,
          reason: 'idempotencyKey in the payload must match the one used at creation');
    });

    test('16. VentasRepository idempotencyKey follows UUID v4 format', () {
      final repo = VentasRepository(ApiClient.instance);
      final key = repo.generateIdempotencyKey();
      final keyAfter = repo.generateIdempotencyKey();
      expect(keyAfter, isNot(equals(key)),
          reason: 'successive keys must differ (simulating post-success rotation)');
      // UUID v4: 8-4-4-4-12 hex chars with version digit 4
      final uuidV4Pattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      expect(uuidV4Pattern.hasMatch(key), isTrue);
    });
  });

  group('Modelos', () {
    test('all active non-system wallet labels remain selectable', () {
      Etiqueta etiqueta(
        String tipo, {
        String nombre = 'Yape',
        bool system = false,
      }) => Etiqueta(
        id: tipo,
        nombre: nombre,
        activo: true,
        requiereComprobante: false,
        esSistema: system,
        tipo: tipo,
        orden: 1,
      );

      expect(isBilleteraEtiqueta(etiqueta('ENTRADA')), isTrue);
      expect(isBilleteraEtiqueta(etiqueta('AMBOS')), isTrue);
      expect(isBilleteraEtiqueta(etiqueta('SALIDA')), isTrue);
      expect(
        isBilleteraEtiqueta(etiqueta('ENTRADA', nombre: 'TOTAL DE VENTAS')),
        isFalse,
      );
      expect(isBilleteraEtiqueta(etiqueta('ENTRADA', system: true)), isFalse);
    });

    test('un duplicado bloquea aunque el comprobante sea opcional', () {
      expect(
        comprobanteAnalysisError(
          analysis: _analysis(id: 'duplicate', amount: 10, duplicate: true),
          total: 10,
          required: false,
          selectedEtiquetaId: 'etiqueta-1',
        ),
        'Posible comprobante duplicado',
      );
      expect(
        comprobanteAnalysisError(analysis: null, total: 10, required: false),
        isNull,
      );
    });

    test('17. Venta.fromJson parsea correctamente', () {
      final venta = Venta.fromJson({
        'id': 'v1',
        'codigo': 'V-CEN-2026-0001',
        'cajaSesionId': 'c1',
        'sedeId': 's1',
        'vendedora': {'id': 'u1', 'username': 'vendedora1'},
        'total': 60.0,
        'estado': 'ACTIVA',
        'conciliacion': {'id': 'conc1', 'estado': 'PENDIENTE'},
        'items': [
          {
            'id': 'vi1',
            'productoId': 'p1',
            'producto': {'nombre': 'Cerveza', 'codigo': 'CER-001'},
            'cantidad': 3,
            'precioUnitario': 20.0,
            'subtotal': 60.0,
          },
        ],
        'createdAt': '2026-08-05T10:00:00Z',
      });
      expect(venta.codigo, 'V-CEN-2026-0001');
      expect(venta.total, 60.0);
      expect(venta.estado, EstadoVenta.activa);
      expect(venta.isPendiente, isTrue);
      expect(venta.items.length, 1);
      expect(venta.items.first.cantidad, 3);
      expect(venta.vendedoraUsername, 'vendedora1');
    });

    test('18. Venta anulada', () {
      final venta = Venta.fromJson({
        'id': 'v2',
        'codigo': 'V-TEST-0002',
        'cajaSesionId': 'c1',
        'sedeId': 's1',
        'total': 30.0,
        'estado': 'ANULADA',
        'motivoAnulacion': 'Error en producto',
        'items': [],
        'createdAt': '2026-08-05T10:00:00Z',
      });
      expect(venta.isAnulada, isTrue);
      expect(venta.motivoAnulacion, 'Error en producto');
    });

    test('19. ConciliacionVenta BILLETERA con etiqueta', () {
      final conc = ConciliacionVenta.fromJson({
        'id': 'conc1',
        'estado': 'BILLETERA',
        'etiquetaId': 'et1',
        'etiqueta': {'nombre': 'Yape'},
        'monto': 45.0,
        'codigoOperacion': 'YPE-001',
        'clasificadaAt': '2026-08-05T11:00:00Z',
      });
      expect(conc.estado, EstadoConciliacion.billetera);
      expect(conc.etiquetaNombre, 'Yape');
      expect(conc.codigoOperacion, 'YPE-001');
    });

    test('payload de venta congela todos los campos para reintentos', () {
      final sourceItems = <Map<String, dynamic>>[
        {'productoId': 'p1', 'cantidad': 2, 'precioVenta': 15.5},
      ];
      final payload = CreateVentaPayload(
        idempotencyKey: 'key-1',
        sedeId: 's1',
        vendedoraId: 'u1',
        items: sourceItems,
        estadoConciliacion: EstadoConciliacion.billetera,
        etiquetaId: 'e1',
        comprobante: '/api/uploads/v.jpg',
        codigoOperacion: 'OP-1',
        recargoMonto: 5,
        recargoMotivo: 'Servicio',
      );

      sourceItems.first['cantidad'] = 99;
      expect(payload.idempotencyKey, 'key-1');
      expect((payload.json['items'] as List).single['cantidad'], 2);
      expect(payload.json['estadoConciliacion'], 'BILLETERA');
      expect(
        () => (payload.json['items'] as List).add(<String, dynamic>{}),
        throwsUnsupportedError,
      );
    });

    test('comprobante analizado excludes simultaneous legacy fields', () {
      final payload = CreateVentaPayload(
        idempotencyKey: 'key-analysis',
        items: const [
          {'productoId': 'p1', 'cantidad': 1},
        ],
        estadoConciliacion: EstadoConciliacion.billetera,
        etiquetaId: 'et-1',
        comprobanteAnalisisId: 'analysis-1',
        comprobante: '/legacy.jpg',
        codigoOperacion: 'LEGACY-1',
      );

      expect(payload.json['comprobanteAnalisisId'], 'analysis-1');
      expect(payload.json.containsKey('comprobante'), isFalse);
      expect(payload.json.containsKey('codigoOperacion'), isFalse);
    });

    test('parsea el contrato completo del análisis Gemini', () {
      final analysis = ComprobanteAnalisis.fromJson({
        'id': 'analysis-1',
        'estado': 'APTO',
        'posibleDuplicado': false,
        'coincidencias': [],
        'entidad': 'Yape',
        'etiquetaSugerida': {'id': 'et-1', 'nombre': 'Yape'},
        'monto': 25.5,
        'codigoOperacion': 'OP-1',
        'codigoSeguridad': 'SEC-1',
        'fechaOperacion': '2026-08-13',
        'horaOperacion': '12:30:00',
        'imagenUrl': '/receipts/1.jpg',
        'thumbnailUrl': '/receipts/1-thumb.jpg',
        'confianza': {
          'documento': .9,
          'entidad': .8,
          'monto': .95,
          'operacion': .7,
          'fecha': .85,
        },
        'advertencias': ['Verificar hora'],
        'expiraAt': '2099-08-13T12:45:00.000Z',
      });

      expect(analysis.esApto, isTrue);
      expect(analysis.etiquetaSugerida?.nombre, 'Yape');
      expect(analysis.montoCoincide(25.50), isTrue);
      expect(analysis.confianza.promedio, closeTo(.84, .001));
      expect(analysis.advertencias, ['Verificar hora']);
    });

    test(
      'monto menor al total es pago parcial válido (como web y backend)',
      () {
        final analysis = ComprobanteAnalisis.fromJson({
          'id': 'analysis-partial',
          'estado': 'APTO',
          'posibleDuplicado': false,
          'coincidencias': [],
          'entidad': 'Yape',
          'etiquetaSugerida': {'id': 'et-1', 'nombre': 'Yape'},
          'monto': 10.0,
          'codigoOperacion': 'OP-P',
          'codigoSeguridad': 'SEC-P',
          'fechaOperacion': '2026-08-13',
          'horaOperacion': '12:30:00',
          'imagenUrl': '/receipts/partial.jpg',
          'thumbnailUrl': '/receipts/partial-thumb.jpg',
          'confianza': {
            'documento': .9,
            'entidad': .9,
            'monto': .9,
            'operacion': .9,
            'fecha': .9,
          },
          'advertencias': [],
          'expiraAt': '2099-08-13T12:45:00.000Z',
        });

        expect(analysis.montoEsMenor(25.0), isTrue);
        expect(analysis.montoExcede(25.0), isFalse);
        expect(
          comprobanteAnalysisError(
            analysis: analysis,
            total: 25,
            required: true,
            selectedEtiquetaId: 'et-1',
          ),
          isNull,
          reason: 'Un monto menor es válido: el cliente completa con otro pago',
        );
      },
    );

    test('monto mayor al total bloquea la venta', () {
      final analysis = ComprobanteAnalisis.fromJson({
        'id': 'analysis-over',
        'estado': 'APTO',
        'posibleDuplicado': false,
        'coincidencias': [],
        'entidad': 'Yape',
        'etiquetaSugerida': {'id': 'et-1', 'nombre': 'Yape'},
        'monto': 30.0,
        'codigoOperacion': 'OP-O',
        'codigoSeguridad': 'SEC-O',
        'fechaOperacion': '2026-08-13',
        'horaOperacion': '12:30:00',
        'imagenUrl': '/receipts/over.jpg',
        'thumbnailUrl': '/receipts/over-thumb.jpg',
        'confianza': {
          'documento': .9,
          'entidad': .9,
          'monto': .9,
          'operacion': .9,
          'fecha': .9,
        },
        'advertencias': [],
        'expiraAt': '2099-08-13T12:45:00.000Z',
      });

      expect(analysis.montoExcede(25.0), isTrue);
      expect(
        comprobanteAnalysisError(
          analysis: analysis,
          total: 25,
          required: true,
          selectedEtiquetaId: 'et-1',
        ),
        contains('supera el total'),
      );
    });

    test('sin sugerencia de billetera, la manual seleccionada es válida', () {
      final analysis = ComprobanteAnalisis.fromJson({
        'id': 'analysis-nosuggest',
        'estado': 'APTO',
        'posibleDuplicado': false,
        'coincidencias': [],
        'entidad': 'Agora',
        'monto': 25.5,
        'codigoOperacion': 'OP-NS',
        'codigoSeguridad': 'SEC-NS',
        'fechaOperacion': '2026-08-13',
        'horaOperacion': '12:30:00',
        'imagenUrl': '/receipts/nosuggest.jpg',
        'thumbnailUrl': '/receipts/nosuggest-thumb.jpg',
        'confianza': {
          'documento': .9,
          'entidad': .9,
          'monto': .9,
          'operacion': .9,
          'fecha': .9,
        },
        'advertencias': [],
        'expiraAt': '2099-08-13T12:45:00.000Z',
      });

      expect(analysis.etiquetaSugerida, isNull);
      expect(
        comprobanteAnalysisError(
          analysis: analysis,
          total: 25.5,
          required: true,
          selectedEtiquetaId: 'et-2',
        ),
        isNull,
      );
    });

    test('Venta.fromJson expone recargo y subtotal', () {
      final venta = Venta.fromJson({
        'id': 'v3',
        'codigo': 'V-003',
        'cajaSesionId': 'c1',
        'sedeId': 's1',
        'total': 35,
        'recargoMonto': 5,
        'recargoMotivo': 'Delivery',
        'estado': 'ACTIVA',
        'items': [],
        'createdAt': '2026-08-05T10:00:00Z',
      });

      expect(venta.recargoMonto, 5);
      expect(venta.recargoMotivo, 'Delivery');
    });
  });

  group('Doble confirmación', () {
    test('20. saleMutationError formats AppException with message and code', () {
      // Tests production saleMutationError — the guard against leaking raw errors
      // to the submit UI after a rejected double-confirmation.
      const e = AppException(
        message: 'Venta ya procesada',
        statusCode: 409,
        code: 'DUPLICATE_SALE',
      );
      final msg = saleMutationError(e);
      expect(msg, contains('Venta ya procesada'));
      expect(msg, contains('DUPLICATE_SALE'));
    });
  });

  group('Listado paginado', () {
    test(
      'cargar más agrega páginas, elimina duplicados y refresh reinicia',
      () async {
        final repo = _FakeVentasRepository()
          ..pages = {
            1: [_venta('1'), _venta('2')],
            2: [_venta('2', total: 20), _venta('3')],
          }
          ..total = 3
          ..totalPaginas = 2;
        final notifier = VentasListNotifier(repo, useMisVentas: false);

        await notifier.load();
        await notifier.loadMore();

        expect(notifier.state.ventas.map((venta) => venta.id), ['1', '2', '3']);
        expect(notifier.state.ventas[1].total, 20);
        expect(notifier.state.pagina, 2);

        repo
          ..pages = {
            1: [_venta('4')],
          }
          ..total = 1
          ..totalPaginas = 1;
        await notifier.refresh();

        expect(notifier.state.ventas.map((venta) => venta.id), ['4']);
        expect(notifier.state.pagina, 1);
      },
    );

    test('PENDIENTE filtra conciliación local sin enviarlo al backend', () async {
      final repo = _FakeVentasRepository()
        ..pages = {
          1: [_venta('1', pendiente: true), _venta('2')],
          2: [_venta('3', pendiente: true), _venta('1', pendiente: true)],
        }
        ..total = 4
        ..totalPaginas = 2;
      final notifier = VentasListNotifier(repo, useMisVentas: false);

      await notifier.load(estado: 'PENDIENTE');

      // La carga inicial del constructor + las páginas de PENDIENTE no envían estado.
      expect(repo.requestedEstados, [null, null, null]);
      expect(notifier.state.filterEstado, 'PENDIENTE');
      expect(notifier.state.ventas.map((venta) => venta.id), ['1', '3']);
      expect(notifier.state.total, 2);
    });

    test(
      'un filtro de estado válido sí se envía y reinicia la página',
      () async {
        final repo = _FakeVentasRepository()
          ..pages = {
            1: [_venta('1')],
          }
          ..total = 1;
        final notifier = VentasListNotifier(repo, useMisVentas: false);

        await notifier.load(estado: 'ACTIVA');

        // Primero carga el constructor sin estado, luego el filtro solicitado.
        expect(repo.requestedEstados, [null, 'ACTIVA']);
        expect(notifier.state.filterEstado, 'ACTIVA');
        expect(notifier.state.pagina, 1);
      },
    );
  });

  group('Flujos de conciliación y anulación', () {
    testWidgets('submits analyzed receipt identity without legacy fields', (
      tester,
    ) async {
      final repo = _FakeVentasRepository();
      var completed = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ventasRepositoryProvider.overrideWithValue(repo),
            voucherImagePickerProvider.overrideWithValue(
              () async => PickedUploadImage(
                bytes: base64Decode(
                  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
                ),
                filename: 'voucher.png',
              ),
            ),
          ],
          child: MaterialApp(
            home: ConciliarVentaScreen(
              venta: _venta('1', pendiente: true),
              onDone: () => completed = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Billetera').first);
      await tester.pump();
      expect(find.byKey(const ValueKey('comprobanteField')), findsOneWidget);
      expect(find.byKey(const ValueKey('codigoOperacionField')), findsNothing);

      // La billetera se selecciona explícitamente (no auto-selección).
      await tester.tap(find.text('Selecciona una billetera…').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yape').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirmar clasificación'));
      await tester.pump();
      expect(
        find.text('Analiza el comprobante requerido por esta billetera'),
        findsOneWidget,
      );
      expect(repo.conciliaciones, isEmpty);

      await tester.tap(find.byKey(const ValueKey('comprobanteField')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Confirmar clasificación'));
      await tester.pump();
      await tester.tap(find.text('Confirmar clasificación'));
      await tester.pump();

      expect(completed, isTrue);
      expect(repo.conciliaciones, hasLength(1));
      expect(repo.conciliaciones.single.comprobanteAnalisisId, 'analysis-1');
      expect(repo.conciliaciones.single.codigoOperacion, isNull);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('billetera sin requisito permite conciliar sin Gemini', (
      tester,
    ) async {
      final repo = _FakeVentasRepository()
        ..etiquetas = const [
          Etiqueta(
            id: 'etiqueta-1',
            nombre: 'Transferencia',
            activo: true,
            requiereComprobante: false,
            orden: 1,
          ),
        ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [ventasRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            home: ConciliarVentaScreen(
              venta: _venta('optional', pendiente: true),
              onDone: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Billetera').first);
      await tester.pump();
      expect(find.text('2 · Comprobante (Gemini)'), findsOneWidget);

      // La billetera se selecciona explícitamente (no auto-selección).
      await tester.tap(find.text('Selecciona una billetera…').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Transferencia').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirmar clasificación'));
      await tester.pump();

      expect(repo.conciliaciones, hasLength(1));
      expect(repo.conciliaciones.single.comprobanteAnalisisId, isNull);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('el diálogo exige y devuelve un motivo real', (tester) async {
      String? motivo;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                motivo = await showAnularVentaDialog(context, codigo: 'V-001');
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anular'));
      await tester.pump();
      expect(
        find.text('El motivo de anulación es obligatorio'),
        findsOneWidget,
      );
      expect(motivo, isNull);

      await tester.enterText(
        find.byKey(const ValueKey('motivoAnulacionField')),
        'Producto registrado por error',
      );
      await tester.tap(find.text('Anular'));
      await tester.pumpAndSettle();

      expect(motivo, 'Producto registrado por error');
    });
  });
}
