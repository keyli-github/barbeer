import 'package:barbeer/core/constants/api_constants.dart';
import 'package:barbeer/core/errors/app_exception.dart';
import 'package:barbeer/core/network/api_client.dart';
import 'package:barbeer/features/recargo/data/recargo_control_repository.dart';
import 'package:barbeer/features/recargo/presentation/providers/recargo_control_provider.dart';
import 'package:barbeer/features/recargo/presentation/widgets/recargo_control_sheet.dart';
import 'package:barbeer/features/ventas/data/models/venta_models.dart';
import 'package:barbeer/features/ventas/data/ventas_repository.dart';
import 'package:barbeer/features/ventas/presentation/providers/ventas_provider.dart';
import 'package:barbeer/features/ventas/presentation/screens/historial_ventas_view.dart';
import 'package:barbeer/features/ventas/presentation/screens/venta_detail_screen.dart';
import 'package:barbeer/features/ventas/presentation/screens/venta_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const recargoConfiguration = <String, dynamic>{
  'oculto': true,
  'configurado': true,
  'puedeConfigurar': true,
  'puedeCambiar': true,
  'sedes': [
    {
      'id': 's1', 'nombre': 'Centro', 'responsableId': 'u1',
      'usuarios': [{'id': 'u1', 'username': 'ana'}],
    },
  ],
};

class _HistoryRepository extends VentasRepository { final Venta sale; _HistoryRepository(this.sale) : super(ApiClient.instance);
  @override Future<({List<Venta> data, int total, int totalPaginas})> listMisVentas({int pagina = 1, int limite = 20, String? estado, String? cajaSesionId}) async => (data: [sale], total: 1, totalPaginas: 1); }

void main() {
  test('control maps exact endpoints, DTO fields, and assignments', () async {
    final calls = <(String, String, Map<String, dynamic>?)>[];
    final repository = RecargoControlRepository(
      ApiClient.instance,
      request: (method, path, data) async {
        calls.add((method, path, data));
        if (path == ApiConstants.recargoConfiguracion && method == 'GET') {
          return {...recargoConfiguration, 'oculto': false};
        }
        if (path == ApiConstants.recargoCambiar) return {'oculto': true};
        return {
          'oculto': false,
          'configurado': true,
          'puedeConfigurar': true,
          'puedeCambiar': true,
        };
      },
    );

    final status = await repository.estado();
    final config = await repository.configuracion();
    final saved = await repository.guardarConfiguracion(
      clave: '123456',
      responsables: const {'s1': 'u1'},
    );
    final changed = await repository.cambiar(clave: '123456', oculto: true);

    expect((status.oculto, status.configurado, status.puedeConfigurar, status.puedeCambiar),
        (false, true, true, true));
    expect(config.sedes.single.responsableId, 'u1');
    expect(saved.configurado, isTrue);
    expect(config.sedes.single.usuarios.single.username, 'ana');
    expect(changed.oculto, isTrue);
    expect(calls.map((call) => (call.$1, call.$2)), [
      ('GET', '/recargo-control/estado'),
      ('GET', '/recargo-control/configuracion'),
      ('PUT', '/recargo-control/configuracion'),
      ('POST', '/recargo-control/cambiar'),
    ]);
    expect(calls[2].$3, {
      'clave': '123456',
      'responsables': [
        {'sedeId': 's1', 'usuarioId': 'u1'},
      ],
    });
    expect(calls[3].$3, {'clave': '123456', 'oculto': true});
    final notifier = RecargoControlNotifier(repository);
    await notifier.load();
    await notifier.loadConfiguration();
    await notifier.guardar(clave: '123456', responsables: const {'s1': 'foreign'});
    expect((notifier.state.error?.statusCode, calls.length), (400, 6));
  });

  test('control provider preserves denied and throttled changes', () async {
    for (final code in [401, 403, 429]) {
      final repository = RecargoControlRepository(
        ApiClient.instance,
        request: (method, path, data) async {
          if (path == ApiConstants.recargoCambiar) {
            throw AppException(message: 'backend-$code', statusCode: code);
          }
          return {
            'oculto': false,
            'configurado': true,
            'puedeConfigurar': false,
            'puedeCambiar': true,
          };
        },
      );
      final notifier = RecargoControlNotifier(repository);
      await notifier.load();
      await notifier.cambiar(clave: '123456', oculto: true);
      expect(notifier.state.oculto, isFalse);
      expect(notifier.state.error?.statusCode, code);
      expect(notifier.state.error?.message, 'backend-$code');
    }
  });

  testWidgets('control sheet loads, saves, and toggles authorized state', (tester) async {
    final repository = RecargoControlRepository(
      ApiClient.instance,
      request: (method, path, data) async => path == ApiConstants.recargoCambiar
          ? {'oculto': false}
          : recargoConfiguration,
    );
    final notifier = RecargoControlNotifier(repository);
    await notifier.load();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recargoControlProvider.overrideWith((ref) => notifier),
        ],
        child: const MaterialApp(home: Scaffold(body: RecargoControlSheet())),
      ),
    );
    await tester.pump();
    expect(find.text('Recargos ocultos'), findsOneWidget);
    expect(find.text('Guardar configuración'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('recargo-config-key')), '654321');
    await tester.tap(find.text('Guardar configuración'));
    await tester.pump();
    expect(notifier.state.data.sedes.single.responsableId, 'u1');
    await tester.enterText(find.byKey(const Key('recargo-control-key')), '123456');
    await tester.tap(find.byKey(const Key('recargo-control-toggle')));
    await tester.pump();
    expect(notifier.state.oculto, isFalse);
    expect(find.text('Recargos visibles'), findsOneWidget);
  });

  testWidgets('normal detail keeps final total confidential', (tester) async {
    final sale = Venta.fromJson({
      'id': 'v1', 'codigo': 'V-1', 'cajaSesionId': 'c1', 'sedeId': 's1',
      'total': 15, 'recargoMonto': 5, 'recargoMotivo': 'Delivery',
      'estado': 'ACTIVA', 'items': [], 'createdAt': '2026-08-28T10:00:00Z',
    });
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp(home: VentaDetailScreen(venta: sale))),
    );
    expect(find.text('S/ 15.00'), findsWidgets);
    expect(find.text('Delivery'), findsNothing);
    expect(find.text('Recargo'), findsNothing);
    expect(find.text('Subtotal'), findsNothing);

    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: Scaffold(body: VentaDetailSheet(venta: sale)))));
    expect(find.text('S/ 15.00'), findsOneWidget);
    for (final value in ['Delivery', 'Recargo']) expect(find.text(value), findsNothing);

    await tester.pumpWidget(ProviderScope(key: UniqueKey(), overrides: [ventasRepositoryProvider.overrideWithValue(_HistoryRepository(sale))],
      child: const MaterialApp(home: Scaffold(body: HistorialVentasView()))));
    await tester.pumpAndSettle();
    expect(find.text('S/ 15.00'), findsOneWidget);
    expect(find.text('Delivery'), findsNothing);

    expect(Venta.fromJson({'items': []}).hasAuthoritativeTotal, isFalse);
  });

  test('hidden drafts clear new recargo without changing payload invariants', () {
    final cleared = resolveRecargoDraft(oculto: true, monto: 5, motivo: 'Delivery');
    expect(cleared, (monto: null, motivo: null));
    final clearedPayload = CreateVentaPayload(
      idempotencyKey: 'cleared-key', items: const [],
      estadoConciliacion: EstadoConciliacion.efectivo,
      recargoMonto: cleared.monto, recargoMotivo: cleared.motivo,
    );
    expect(clearedPayload.json.containsKey('recargoMonto'), isFalse);
    expect(clearedPayload.json.containsKey('recargoMotivo'), isFalse);
    final payload = CreateVentaPayload(
      idempotencyKey: 'same-key',
      items: const [{'productoId': 'p1', 'cantidad': 1}],
      estadoConciliacion: EstadoConciliacion.efectivo,
      recargoMonto: 5,
      recargoMotivo: 'Delivery',
    );
    expect(shouldBlockPositiveRecargo(oculto: true, monto: 5), isTrue);
    expect(shouldBlockPositiveRecargo(oculto: false, monto: 5), isFalse);
    expect(payload.json['idempotencyKey'], 'same-key');
    expect(payload.json['recargoMonto'], 5);
    expect(payload.json['recargoMotivo'], 'Delivery');
    final omitted = Venta.fromJson({'total': 15, 'items': []});
    expect(omitted.total, 15);
    expect(omitted.recargoMonto, isNull);
    expect(omitted.recargoMotivo, isNull);
  });
}
