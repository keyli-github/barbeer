import 'dart:async';
import 'package:barbeer/core/async/operation_state.dart';
import 'package:barbeer/core/errors/app_exception.dart';
import 'package:barbeer/core/navigation/route_access_policy.dart';
import 'package:barbeer/core/network/api_client.dart';
import 'package:barbeer/core/routes/route_paths.dart';
import 'package:barbeer/features/cuentas/data/cuentas_repository.dart';
import 'package:barbeer/features/cuentas/data/models/cuenta_models.dart';
import 'package:barbeer/features/cuentas/presentation/providers/cuentas_provider.dart';
import 'package:barbeer/features/cuentas/presentation/screens/cuentas_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
Map<String, dynamic> account(String id, String name, [double balance = 10]) => {
  'id': id, 'nombre': name, 'documento': 'DOC-$id', 'telefono': '999',
  'saldo': balance, 'activo': true, 'cantidadPendientes': 1,
  'createdAt': '2026-08-01T10:00:00.000Z', 'updatedAt': '2026-08-02T10:00:00.000Z'};
Map<String, dynamic> detail(String id, String name, [double balance = 10]) => {
  ...account(id, name, balance),
  'movimientos': [{'id': 'm-$id', 'cuentaId': id, 'tipo': 'CARGO', 'monto': balance,
    'referencia': 'V-01', 'ventaId': 'v-$id', 'createdAt': '2026-08-03T10:00:00.000Z',
    'medioPago': null, 'comprobante': null}],
  'pendientes': [{'id': 'v-$id', 'codigo': 'V-01', 'fecha': '2026-08-03T10:00:00.000Z',
    'montoPendiente': balance, 'totalVenta': 25, 'recargoMonto': 5,
    'recargoMotivo': 'private', 'sede': {'id': 's1', 'nombre': 'Centro'},
    'items': [{'id': 'i1', 'cantidad': 2, 'precioUnitario': 10, 'subtotal': 20,
      'producto': {'id': 'p1', 'codigo': 'P-1', 'nombre': 'Producto'}}]}]};
Map<String, dynamic> paidDetail(String id, double balance) => {
  ...detail(id, 'Ana', balance),
  'movimientos': [{...((detail(id, 'Ana', balance)['movimientos'] as List).single as Map),
    'tipo': 'ABONO', 'monto': 4, 'medioPago': 'EFECTIVO'}],
  'pendientes': balance == 0 ? [] : detail(id, 'Ana', balance)['pendientes'],
};
void main() {
  test('read repository maps exact list/detail DTOs and query names', () async {
    final calls = <(String, Map<String, dynamic>)>[];
    final repo = CuentasRepository(ApiClient.instance, request: (path, query) async {
      calls.add((path, query));
      return path == '/cuentas' ? [account('c1', 'Ana', 12.5)] : detail('c1', 'Ana', 12.5);
    });
    final item = (await repo.list(search: ' Ana ', sedeId: 's1')).single;
    final selected = await repo.detail('c1', sedeId: 's1');
    expect((item.id, item.nombre, item.documento, item.telefono, item.saldo,
      item.activo, item.cantidadPendientes, item.createdAt, item.updatedAt),
      ('c1', 'Ana', 'DOC-c1', '999', 12.5, true, 1,
       '2026-08-01T10:00:00.000Z', '2026-08-02T10:00:00.000Z'));
    expect((selected.movimientos.single.tipo, selected.movimientos.single.monto,
      selected.movimientos.single.referencia), ('CARGO', 12.5, 'V-01'));
    expect((selected.pendientes.single.codigo, selected.pendientes.single.totalVenta,
      selected.pendientes.single.items.single.producto.nombre), ('V-01', 25, 'Producto'));
    expect(calls.map((call) => call.$1), ['/cuentas', '/cuentas/c1']);
    expect(calls[0].$2, {'search': 'Ana', 'sedeId': 's1'});
    expect(calls[1].$2, {'sedeId': 's1'});
    expect(calls.first.$2, isNot(anyOf(contains('pagina'), contains('limite'))));
  });
  test('read state distinguishes empty, denied, paged, and missing detail', () async {
    var calls = 0;
    final denied = CuentasNotifier(CuentasRepository(ApiClient.instance,
      request: (_, __) async { calls++; return []; }), authorized: false, sedeId: 's1');
    await denied.load();
    expect((calls, (denied.state.listState as OperationRecoverableError).error.statusCode), (0, 403));
    final repo = CuentasRepository(ApiClient.instance, request: (path, query) async {
      if (path.endsWith('/missing')) throw const AppException(message: 'La cuenta no existe',
        statusCode: 404, path: '/cuentas/missing');
      return query['search'] == 'none' ? []
        : [account('1', 'A'), account('2', 'B'), account('3', 'C')];
    });
    final notifier = CuentasNotifier(repo, authorized: true, sedeId: 's1', pageSize: 2);
    await notifier.load(search: 'none');
    expect(notifier.state.listState, isA<OperationEmpty<List<Cuenta>>>());
    await notifier.load(search: ''); notifier.setPage(2);
    expect((notifier.state.pageItems.single.nombre, notifier.state.totalPages), ('C', 2));
    await notifier.select('missing');
    final failure = notifier.state.detailState as OperationRecoverableError<CuentaDetalle>;
    expect((failure.error.message, failure.error.statusCode, failure.error.path),
      ('La cuenta no existe', 404, '/cuentas/missing'));
    expect(notifier.state.listState, isA<OperationPartial<List<Cuenta>>>());
    expect((RouteAccessPolicy.canAccess(RoutePaths.cuentas, role: 'ADMIN',
      permissions: const {'cuentas:leer'}), RouteAccessPolicy.canAccess(RoutePaths.cuentas,
      role: 'VENDEDORA', permissions: const {'cuentas:leer'})), (true, false));
  });
  testWidgets('read harness keeps newest scoped search and detail response', (tester) async {
    final initial = Completer<Object?>(), olderSearch = Completer<Object?>(),
      newestSearch = Completer<Object?>(), oldDetail = Completer<Object?>(),
      newDetail = Completer<Object?>();
    final repo = CuentasRepository(ApiClient.instance, request: (path, query) {
      if (path == '/cuentas/old') return oldDetail.future;
      if (path == '/cuentas/new') return newDetail.future;
      return switch (query['search']) {
        'older' => olderSearch.future, 'newest' => newestSearch.future, _ => initial.future};
    });
    final notifier = CuentasNotifier(repo, authorized: true, sedeId: 's1');
    final loading = notifier.load();
    await tester.pumpWidget(ProviderScope(overrides: [cuentasProvider.overrideWith((_) => notifier)],
      child: const MaterialApp(home: CuentasScreen())));
    expect(find.text('Cargando cuentas...'), findsOneWidget);
    initial.complete([account('old', 'Old account'), account('new', 'New account')]);
    await loading; await tester.pump();
    await tester.tap(find.text('Old account')); await tester.pump();
    await tester.tap(find.text('New account')); await tester.pump();
    newDetail.complete(detail('new', 'New account', 22)); await tester.pump();
    expect(find.text('Saldo S/ 22.00'), findsOneWidget);
    oldDetail.complete(detail('old', 'Old account', 99)); await tester.pump();
    expect(find.text('Saldo S/ 99.00'), findsNothing);
    await tester.enterText(find.byKey(const Key('cuentas-search')), 'older');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.enterText(find.byKey(const Key('cuentas-search')), 'newest');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    newestSearch.complete([account('scope', 'Scoped result')]); await tester.pump();
    olderSearch.complete([account('stale', 'Foreign stale result')]); await tester.pump();
    expect((find.text('Scoped result').evaluate().length, find.text('Foreign stale result').evaluate().length), (1, 0));
  });
  test('collection repository sends exact DTO and maps authoritative response', () async {
    late String path; late Map<String, dynamic> body;
    final repo = CuentasRepository(ApiClient.instance, request: (_, __) async => [],
      post: (value, payload) async { path = value; body = payload; return paidDetail('c1', 6); });
    final result = await repo.collect('c1', monto: 4, medioPago: 'TRANSFERENCIA',
      idempotencyKey: '11111111-1111-4111-8111-111111111111',
      comprobanteAnalisisId: '22222222-2222-4222-8222-222222222222', sedeId: 's1');
    expect(path, '/cuentas/c1/pagos');
    expect(body, {'monto': 4, 'medioPago': 'TRANSFERENCIA',
      'idempotencyKey': '11111111-1111-4111-8111-111111111111',
      'comprobanteAnalisisId': '22222222-2222-4222-8222-222222222222', 'sedeId': 's1'});
    expect((result.saldo, result.movimientos.single.tipo,
      result.movimientos.single.raw['medioPago']), (6, 'ABONO', 'EFECTIVO'));
  });
  test('collection state authorizes, preserves errors, deduplicates, and safely retries', () async {
    var posts = 0; final keys = <String>[];
    final deniedRepo = CuentasRepository(ApiClient.instance,
      request: (_, __) async => detail('c1', 'Ana'),
      post: (_, body) async { posts++; return paidDetail('c1', 0); });
    final denied = CuentasNotifier(deniedRepo, authorized: true, canCollect: false,
      sedeId: 's1', keyFactory: () => 'denied-key');
    await denied.select('c1'); await denied.collect(monto: 10, medioPago: 'EFECTIVO');
    expect((posts, denied.state.collectionError?.statusCode,
      (denied.state.detailState as OperationContent<CuentaDetalle>).data.saldo), (0, 403, 10));
    for (final status in [400, 403, 404, 409]) {
      final repo = CuentasRepository(ApiClient.instance,
        request: (_, __) async => detail('c1', 'Ana'), post: (_, __) async =>
          throw AppException(message: 'error-$status', statusCode: status,
            path: '/cuentas/c1/pagos', code: 'E$status'));
      final notifier = CuentasNotifier(repo, authorized: true, canCollect: true,
        sedeId: 's1', keyFactory: () => 'key-$status');
      await notifier.select('c1'); await notifier.collect(monto: 4, medioPago: 'EFECTIVO');
      final error = notifier.state.collectionError!;
      expect((error.message, error.statusCode, error.path, error.code),
        ('error-$status', status, '/cuentas/c1/pagos', 'E$status'));
      expect((notifier.state.detailState as OperationContent<CuentaDetalle>).data.saldo, 10);
    }
    final pending = Completer<Object?>(); var failOnce = true;
    final repo = CuentasRepository(ApiClient.instance,
      request: (_, __) async => detail('c1', 'Ana'), post: (_, body) {
        posts++; keys.add(body['idempotencyKey'] as String);
        if (failOnce) { failOnce = false; throw const NetworkException(); }
        return pending.future;
      });
    final notifier = CuentasNotifier(repo, authorized: true, canCollect: true,
      sedeId: 's1', keyFactory: () => 'retry-key');
    await notifier.select('c1'); await notifier.collect(monto: 4, medioPago: 'EFECTIVO');
    final first = notifier.collect(monto: 4, medioPago: 'EFECTIVO');
    final duplicate = notifier.collect(monto: 4, medioPago: 'EFECTIVO');
    expect(posts, 2); expect(keys, ['retry-key', 'retry-key']);
    pending.complete(paidDetail('c1', 6)); await Future.wait([first, duplicate]);
    expect((posts, notifier.state.collectionSucceeded,
      (notifier.state.detailState as OperationContent<CuentaDetalle>).data.saldo), (2, true, 6));
  });
  testWidgets('collection harness applies partial and full payment once per action', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final responses = <Completer<Object?>>[]; final payloads = <Map<String, dynamic>>[];
    var key = 0;
    final repo = CuentasRepository(ApiClient.instance,
      request: (path, __) async => path == '/cuentas' ? [account('c1', 'Ana')] : detail('c1', 'Ana'),
      post: (_, body) {
        payloads.add(body); final response = Completer<Object?>(); responses.add(response); return response.future;
      });
    final notifier = CuentasNotifier(repo, authorized: true, canCollect: true,
      sedeId: 's1', keyFactory: () => '00000000-0000-4000-8000-${(++key).toString().padLeft(12, '0')}');
    await notifier.load(); await notifier.select('c1');
    await tester.pumpWidget(ProviderScope(overrides: [cuentasProvider.overrideWith((_) => notifier)],
      child: const MaterialApp(home: CuentasScreen())));
    await tester.tap(find.byKey(const Key('collection-open'))); await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('collection-amount')), '4');
    await tester.tap(find.byKey(const Key('collection-submit')));
    await tester.tap(find.byKey(const Key('collection-submit'))); await tester.pump();
    expect((payloads.length, payloads.single['monto']), (1, 4));
    responses.single.complete(paidDetail('c1', 6)); await tester.pumpAndSettle();
    expect((notifier.state.detailState as OperationContent<CuentaDetalle>).data.saldo, 6);
    await tester.drag(find.byType(ListView), const Offset(0, -300)); await tester.pump();
    expect(find.text('Saldo S/ 6.00'), findsOneWidget);
    await tester.tap(find.byKey(const Key('collection-open'))); await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('collection-submit'))); await tester.pump();
    expect((payloads.length, payloads.last['monto']), (2, 6));
    responses.last.complete(paidDetail('c1', 0)); await tester.pumpAndSettle();
    expect(find.text('Saldo S/ 0.00'), findsOneWidget);
    expect(payloads.map((item) => item.keys.toSet()).toList(), everyElement(
      {'monto', 'medioPago', 'idempotencyKey', 'sedeId'}));
    expect(payloads[0]['idempotencyKey'], isNot(payloads[1]['idempotencyKey']));
  });
}
