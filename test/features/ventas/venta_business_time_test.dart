import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barbeer/core/utils/business_time.dart';
import 'package:barbeer/features/auth/data/models/auth_models.dart';
import 'package:barbeer/features/auth/presentation/providers/auth_provider.dart';
import 'package:barbeer/features/ventas/data/models/venta_models.dart';
import 'package:barbeer/features/ventas/presentation/screens/historial_ventas_view.dart';
import 'package:barbeer/features/ventas/presentation/screens/venta_detail_screen.dart';
import 'package:barbeer/features/ventas/presentation/screens/venta_detail_sheet.dart';

UserProfile _testUser() => UserProfile(
  id: 'test-id',
  username: 'test',
  rol: 'ADMIN',
  nivel: 10,
  createdAt: '2026-01-01',
  permisos: const [],
);

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(super.repository) {
    state = AuthState(status: AuthStatus.authenticated, user: _testUser());
  }
}

Widget _appWithAuth(Widget home) => ProviderScope(
  overrides: [
    authProvider.overrideWith(
      (ref) => _TestAuthNotifier(ref.read(authRepositoryProvider)),
    ),
  ],
  child: MaterialApp(home: home),
);

Venta _sale({
  String createdAt = '2026-08-01T05:00:00Z',
  String? fechaVenta,
  String? registradaAt,
}) => Venta(
  id: 'sale-1',
  codigo: 'V-001',
  cajaSesionId: 'cash-1',
  sedeId: 'branch-1',
  total: 40,
  estado: EstadoVenta.activa,
  items: const [],
  createdAt: createdAt,
  fechaVenta: fechaVenta,
  registradaAt: registradaAt,
);

Map<String, dynamic> _saleJson({
  required String createdAt,
  String? fechaVenta,
  String? registradaAt,
}) {
  final json = <String, dynamic>{
    'id': 'sale-1',
    'codigo': 'V-001',
    'cajaSesionId': 'cash-1',
    'sedeId': 'branch-1',
    'total': 40,
    'estado': 'ACTIVA',
    'items': const [],
    'createdAt': createdAt,
  };
  if (fechaVenta != null) json['fechaVenta'] = fechaVenta;
  if (registradaAt != null) json['registradaAt'] = registradaAt;
  return json;
}

void main() {
  group('Business sale timestamps', () {
    test('converts UTC timestamps across the Lima midnight boundary', () {
      expect(
        formatBusinessDateTime('2026-08-01T04:59:00Z'),
        '31/07/2026 23:59',
      );
      expect(
        formatBusinessDateTime('2026-08-01T05:00:00Z'),
        '01/08/2026 00:00',
      );
    });

    test(
      'keeps zone-less legacy timestamps independent of device timezone',
      () {
        expect(
          formatBusinessDateTime('2026-08-01T00:15:00'),
          '01/08/2026 00:15',
        );
      },
    );

    test('recognizes equivalent timestamps with different offsets', () {
      expect(
        sameBusinessTime('2026-08-01T05:00:00Z', '2026-08-01T00:00:00-05:00'),
        isTrue,
      );
    });

    test('uses createdAt for missing timestamps in older sale responses', () {
      const createdAt = '2026-08-01T05:00:00Z';
      final sale = Venta.fromJson(_saleJson(createdAt: createdAt));

      expect(sale.fechaVenta, createdAt);
      expect(sale.registradaAt, createdAt);
    });

    test('parses explicit sale and registration timestamps', () {
      const saleTime = '2026-08-01T04:59:00Z';
      const registrationTime = '2026-08-01T05:30:00Z';
      final sale = Venta.fromJson(
        _saleJson(
          createdAt: registrationTime,
          fechaVenta: saleTime,
          registradaAt: registrationTime,
        ),
      );

      expect(sale.fechaVenta, saleTime);
      expect(sale.registradaAt, registrationTime);
    });

    testWidgets(
      'sale history labels distinct times at phone and desktop widths',
      (tester) async {
        final sale = _sale(
          createdAt: '2026-08-01T05:30:00Z',
          fechaVenta: '2026-08-01T04:59:00Z',
          registradaAt: '2026-08-01T05:30:00Z',
        );

        for (final width in [390.0, 1280.0]) {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 900);
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: VentaHistoryCard(venta: sale, correction: false),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Venta: 31/07/2026 23:59'), findsOneWidget);
          expect(find.text('Registrada: 01/08/2026 00:30'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }

        addTearDown(tester.view.reset);
      },
    );

    testWidgets('legacy responses do not repeat the registration timestamp', (
      tester,
    ) async {
      final sale = Venta.fromJson(_saleJson(createdAt: '2026-08-01T05:00:00Z'));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VentaHistoryCard(venta: sale, correction: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Venta: 01/08/2026 00:00'), findsOneWidget);
      expect(find.textContaining('Registrada:'), findsNothing);
    });

    testWidgets('does not repeat registration time at displayed precision', (
      tester,
    ) async {
      final sale = _sale(
        createdAt: '2026-08-01T05:00:45Z',
        fechaVenta: '2026-08-01T05:00:15Z',
        registradaAt: '2026-08-01T05:00:45Z',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VentaHistoryCard(venta: sale, correction: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Venta: 01/08/2026 00:00'), findsOneWidget);
      expect(find.textContaining('Registrada:'), findsNothing);
    });

    testWidgets(
      'detail screen and sheet show both timestamps at phone and desktop widths',
      (tester) async {
        final sale = _sale(
          createdAt: '2026-08-01T05:30:00Z',
          fechaVenta: '2026-08-01T04:59:00Z',
          registradaAt: '2026-08-01T05:30:00Z',
        );

        for (final width in [390.0, 1280.0]) {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 900);
          await tester.pumpWidget(_appWithAuth(VentaDetailScreen(venta: sale)));
          await tester.pumpAndSettle();

          expect(find.text('Venta: 31/07/2026 23:59'), findsOneWidget);
          expect(find.text('Registrada: 01/08/2026 00:30'), findsOneWidget);
          expect(tester.takeException(), isNull);

          await tester.pumpWidget(
            _appWithAuth(Scaffold(body: VentaDetailSheet(venta: sale))),
          );
          await tester.pumpAndSettle();

          expect(find.text('Venta: 31/07/2026 23:59'), findsOneWidget);
          expect(find.text('Registrada: 01/08/2026 00:30'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }

        addTearDown(tester.view.reset);
      },
    );
  });
}
