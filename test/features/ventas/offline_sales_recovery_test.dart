import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barbeer/core/errors/app_exception.dart';
import 'package:barbeer/core/network/api_client.dart';
import 'package:barbeer/core/offline/offline_store.dart';
import 'package:barbeer/features/offline/presentation/offline_sales_screen.dart';
import 'package:barbeer/features/ventas/data/models/venta_models.dart';
import 'package:barbeer/features/ventas/data/ventas_repository.dart';

CreateVentaPayload _payload(String key) => CreateVentaPayload(
  idempotencyKey: key,
  items: const [
    {'productoId': 'product-1', 'cantidad': 2},
  ],
  manualReviewItems: const [
    {'productId': 'product-1', 'productName': 'Cerveza rubia', 'quantity': 2},
  ],
  sedeId: 'sede-1',
  vendedoraId: 'user-1',
  estadoConciliacion: EstadoConciliacion.efectivo,
);

Response<dynamic> _response(
  String path,
  Object? data, {
  Map<String, dynamic> extra = const {},
}) => Response<dynamic>(
  requestOptions: RequestOptions(path: path),
  data: data,
  statusCode: 200,
  extra: extra,
);

void main() {
  setUp(() {
    final encodedClaims = base64Url
        .encode(utf8.encode(jsonEncode({'sub': 'user-1'})))
        .replaceAll('=', '');
    FlutterSecureStorage.setMockInitialValues({
      'bb.at': 'header.$encodedClaims.signature',
    });
  });

  group('offline sale drafts', () {
    test(
      'cold offline preflight persists the original key without posting',
      () async {
        final store = OfflineStore();
        var preflightCalls = 0;
        var postCalls = 0;
        final repository = VentasRepository(
          ApiClient.instance,
          offlineStore: store,
          responsableCajaRequest: (_) async {
            preflightCalls++;
            throw const NetworkException();
          },
          createVentaRequest: (_) async {
            postCalls++;
            return _response('/ventas', const {});
          },
        );
        final payload = _payload('cold-offline-sale-key');

        await expectLater(
          repository.crearVenta(payload: payload),
          throwsA(isA<OfflineSaleDraftSaved>()),
        );

        final scope = await store.scope();
        final saved = await OfflineStore().sales(scope!);
        expect(preflightCalls, 1);
        expect(postCalls, 0);
        expect(saved, hasLength(1));
        expect(saved.single['status'], 'DRAFT');
        expect(
          saved.single['payload']['idempotencyKey'],
          payload.idempotencyKey,
        );
        expect(saved.single['payload'].containsKey('_originalCajaId'), isFalse);
        expect(saved.single['error'], contains('revisión manual'));
        final recovered = CreateVentaPayload.fromRecovery(
          Map<String, dynamic>.from(saved.single['payload'] as Map),
        );
        expect(recovered.idempotencyKey, payload.idempotencyKey);
        expect(
          recovered.manualReviewItems.single['productName'],
          'Cerveza rubia',
        );
        expect(recovered.json.containsKey('_manualReviewItems'), isFalse);
      },
    );

    test(
      'a saved draft cannot be retried or duplicated by the repository',
      () async {
        final store = OfflineStore();
        var preflightCalls = 0;
        var postCalls = 0;
        final repository = VentasRepository(
          ApiClient.instance,
          offlineStore: store,
          responsableCajaRequest: (_) async {
            preflightCalls++;
            throw const NetworkException();
          },
          createVentaRequest: (_) async {
            postCalls++;
            return _response('/ventas', const {});
          },
        );
        final payload = _payload('draft-retry-sale-key');

        await expectLater(
          repository.crearVenta(payload: payload),
          throwsA(isA<OfflineSaleDraftSaved>()),
        );
        await expectLater(
          repository.crearVenta(payload: payload),
          throwsA(isA<OfflineSaleDraftSaved>()),
        );

        final scope = await store.scope();
        final saved = await store.sales(scope!);
        expect(preflightCalls, 1);
        expect(postCalls, 0);
        expect(saved, hasLength(1));
        expect(
          saved.single['payload']['idempotencyKey'],
          payload.idempotencyKey,
        );
      },
    );

    test(
      'legacy unresolved sale with a cash ID but no replay triplet becomes a draft',
      () async {
        final store = OfflineStore();
        final scope = await store.scope();
        final payload = _payload('legacy-unresolved-sale-key');
        await store.record(scope!, {
          ...payload.json,
          '_originalCajaId': 'original-cash-session',
        }, 'PENDING');
        var preflightCalls = 0;
        var postCalls = 0;
        final repository = VentasRepository(
          ApiClient.instance,
          offlineStore: store,
          responsableCajaRequest: (_) async {
            preflightCalls++;
            return _response('/caja/responsable', {
              'id': 'current-cash-session',
            });
          },
          createVentaRequest: (_) async {
            postCalls++;
            return _response('/ventas', const {});
          },
        );

        await expectLater(
          repository.crearVenta(payload: payload),
          throwsA(isA<OfflineSaleDraftSaved>()),
        );

        final saved = await store.sales(scope);
        final recovery = Map<String, dynamic>.from(
          saved.single['payload'] as Map,
        );
        expect(preflightCalls, 0);
        expect(postCalls, 0);
        expect(saved.single['status'], 'DRAFT');
        expect(recovery['_originalCajaId'], 'original-cash-session');
        expect(recovery.containsKey('offlineCajaSesionId'), isFalse);
        expect(recovery.containsKey('offlineOccurredAt'), isFalse);
        expect(recovery.containsKey('offlineDeviceId'), isFalse);
      },
    );

    test(
      'a cached cash session without replay metadata becomes a draft',
      () async {
        final store = OfflineStore();
        var postCalls = 0;
        final repository = VentasRepository(
          ApiClient.instance,
          offlineStore: store,
          responsableCajaRequest: (_) async => _response(
            '/caja/responsable',
            {'id': 'cached-cash-session'},
            extra: {'offline': true},
          ),
          createVentaRequest: (_) async {
            postCalls++;
            return _response('/ventas', const {});
          },
        );

        await expectLater(
          repository.crearVenta(payload: _payload('cached-box-sale-key')),
          throwsA(isA<OfflineSaleDraftSaved>()),
        );

        final scope = await store.scope();
        final saved = await store.sales(scope!);
        final recovery = Map<String, dynamic>.from(
          saved.single['payload'] as Map,
        );
        expect(postCalls, 0);
        expect(saved.single['status'], 'DRAFT');
        expect(recovery['_originalCajaId'], 'cached-cash-session');
        expect(recovery.containsKey('offlineCajaSesionId'), isFalse);
        expect(recovery.containsKey('offlineOccurredAt'), isFalse);
        expect(recovery.containsKey('offlineDeviceId'), isFalse);
      },
    );

    test(
      'lost post confirmation becomes a manual-review draft, not a replay',
      () async {
        final store = OfflineStore();
        var postCalls = 0;
        final repository = VentasRepository(
          ApiClient.instance,
          offlineStore: store,
          responsableCajaRequest: (_) async =>
              _response('/caja/responsable', {'id': 'original-cash-session'}),
          createVentaRequest: (_) async {
            postCalls++;
            throw const NetworkException();
          },
        );
        final payload = _payload('uncertain-post-sale-key');

        await expectLater(
          repository.crearVenta(payload: payload),
          throwsA(isA<OfflineSaleDraftSaved>()),
        );
        await expectLater(
          repository.crearVenta(payload: payload),
          throwsA(isA<OfflineSaleDraftSaved>()),
        );

        final scope = await store.scope();
        final saved = await store.sales(scope!);
        expect(postCalls, 1);
        expect(saved, hasLength(1));
        expect(saved.single['status'], 'DRAFT');
        expect(
          saved.single['payload']['_originalCajaId'],
          'original-cash-session',
        );
        expect(saved.single['error'], contains('No se recibió confirmación'));
      },
    );

    test(
      'an online sale still posts once and persists as synchronized',
      () async {
        final store = OfflineStore();
        final submitted = <Map<String, dynamic>>[];
        final repository = VentasRepository(
          ApiClient.instance,
          offlineStore: store,
          responsableCajaRequest: (_) async =>
              _response('/caja/responsable', {'id': 'online-cash-session'}),
          createVentaRequest: (payload) async {
            submitted.add(payload);
            return _response('/ventas', {
              'id': 'sale-1',
              'codigo': 'V-001',
              'cajaSesionId': 'online-cash-session',
              'sedeId': 'sede-1',
              'total': 24,
              'estado': 'ACTIVA',
              'items': const [],
              'createdAt': '2026-09-24T10:00:00Z',
            });
          },
        );
        final payload = _payload('online-sale-key');

        final sale = await repository.crearVenta(payload: payload);

        final scope = await store.scope();
        final saved = await store.sales(scope!);
        expect(sale.id, 'sale-1');
        expect(submitted, hasLength(1));
        expect(submitted.single['idempotencyKey'], payload.idempotencyKey);
        expect(submitted.single.containsKey('offlineCajaSesionId'), isFalse);
        expect(submitted.single.containsKey('_manualReviewItems'), isFalse);
        expect(saved, hasLength(1));
        expect(saved.single['status'], 'SYNCED');
        expect(
          saved.single['payload']['idempotencyKey'],
          payload.idempotencyKey,
        );
      },
    );
  });

  testWidgets('manual-review drafts show details without a retry action', (
    tester,
  ) async {
    final draft = <String, dynamic>{
      'id': 'manual-review-sale-key',
      'payload': {
        ..._payload('manual-review-sale-key').json,
        '_manualReviewItems': _payload(
          'manual-review-sale-key',
        ).manualReviewItems,
        '_originalCajaId': 'cached-cash-session',
      },
      'status': 'DRAFT',
      'createdAt': '2026-09-24T10:00:00Z',
      'error': 'No se pudo verificar la caja original sin conexión.',
    };
    final unresolvedSale = <String, dynamic>{
      'id': 'unresolved-sale-key',
      'payload': {
        ..._payload('unresolved-sale-key').json,
        '_originalCajaId': 'original-cash-session',
      },
      'status': 'PENDING',
      'createdAt': '2026-09-24T09:00:00Z',
      'error': null,
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          offlineSalesProvider.overrideWith(
            (ref) async => [draft, unresolvedSale],
          ),
        ],
        child: const MaterialApp(home: OfflineSalesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Borrador para revisión manual (sin confirmar)'),
      findsOneWidget,
    );
    expect(
      find.textContaining('no se sincroniza automáticamente'),
      findsWidgets,
    );
    expect(find.text('Caja original: cached-cash-session'), findsOneWidget);
    expect(find.text('2 × Cerveza rubia'), findsOneWidget);
    expect(find.text('Venta pendiente de revisión manual'), findsOneWidget);
    expect(find.text('Reintentar operación'), findsNothing);
    expect(find.text('Operación sincronizada'), findsNothing);
  });
}
