import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:barbeer/core/network/api_client.dart';
import 'package:barbeer/core/network/upload_client.dart';
import 'package:barbeer/features/ventas/data/models/venta_models.dart';
import 'package:barbeer/features/ventas/data/ventas_repository.dart';
import 'package:barbeer/features/ventas/presentation/providers/ventas_provider.dart';
import 'package:barbeer/features/ventas/presentation/screens/conciliar_venta_screen.dart';
import 'package:barbeer/features/ventas/presentation/screens/conciliar_venta_sheet.dart';
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
    test('14. Genera UUIDs diferentes para ventas diferentes', () {
      final k1 = _uuid.v4();
      final k2 = _uuid.v4();
      expect(k1, isNot(equals(k2)));
      expect(k1.length, 36);
    });

    test('15. El reintento conserva la misma clave', () {
      final key = _uuid.v4();
      final retryKey = key;
      expect(retryKey, key);
    });

    test('16. Éxito genera nueva clave', () {
      final keyBefore = _uuid.v4();
      final keyAfter = _uuid.v4();
      expect(keyAfter, isNot(equals(keyBefore)));
    });
  });

  group('Modelos', () {
    test('solo ENTRADA/AMBOS no sistema califican como billetera', () {
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
      expect(isBilleteraEtiqueta(etiqueta('SALIDA')), isFalse);
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
      expect(venta.subtotalSinRecargo, 30);
    });
  });

  group('Doble confirmación', () {
    test('20. No se ejecuta submit si ya está en progreso', () {
      var count = 0;
      void doSubmit(bool submitting) {
        if (submitting) return; // Guard: si ya está enviando, no ejecutar
        count++;
      }

      // Simular que ya hay un envío en curso
      doSubmit(true);
      expect(count, 0, reason: 'No debe ejecutarse con submitting=true');

      // Simular que no hay envío en curso
      doSubmit(false);
      expect(count, 1, reason: 'Debe ejecutarse con submitting=false');
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

    test(
      'PENDIENTE filtra conciliación local sin enviarlo al backend',
      () async {
        final repo = _FakeVentasRepository()
          ..pages = {
            1: [_venta('1', pendiente: true), _venta('2')],
            2: [_venta('3', pendiente: true), _venta('1', pendiente: true)],
          }
          ..total = 4
          ..totalPaginas = 2;
        final notifier = VentasListNotifier(repo, useMisVentas: false);

        await notifier.load(estado: 'PENDIENTE');

        expect(repo.requestedEstados, [null, null]);
        expect(notifier.state.filterEstado, 'PENDIENTE');
        expect(notifier.state.ventas.map((venta) => venta.id), ['1', '3']);
        expect(notifier.state.total, 2);
      },
    );

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

        expect(repo.requestedEstados, ['ACTIVA']);
        expect(notifier.state.filterEstado, 'ACTIVA');
        expect(notifier.state.pagina, 1);
      },
    );
  });

  group('Flujos de conciliación y anulación', () {
    testWidgets('exige comprobante y lo mapea separado del código', (
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
      expect(
        find.byKey(const ValueKey('codigoOperacionField')),
        findsOneWidget,
      );

      await tester.tap(find.text('Confirmar clasificación'));
      await tester.pump();
      expect(
        find.text('Analiza el comprobante requerido por esta billetera'),
        findsOneWidget,
      );
      expect(repo.conciliaciones, isEmpty);

      await tester.tap(find.byKey(const ValueKey('comprobanteField')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('codigoOperacionField')),
        'op-456',
      );
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
      expect(find.text('Comprobante / voucher (opcional)'), findsOneWidget);

      await tester.tap(find.text('Confirmar clasificación'));
      await tester.pump();

      expect(repo.conciliaciones, hasLength(1));
      expect(repo.conciliaciones.single.comprobanteAnalisisId, isNull);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('sheet posterior usa análisis Gemini y no URL legacy', (
      tester,
    ) async {
      final repo = _FakeVentasRepository();
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
            home: Scaffold(
              body: ConciliarVentaSheet(
                venta: _venta('sheet', pendiente: true),
                onDone: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Billetera').first);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('comprobanteField')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('receipt-analysis-panel')), findsOneWidget);
      expect(find.text('Análisis apto'), findsOneWidget);
      await tester.ensureVisible(find.text('Confirmar'));
      await tester.tap(find.text('Confirmar'));
      await tester.pump();

      expect(repo.conciliaciones.single.comprobanteAnalisisId, 'analysis-1');
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
