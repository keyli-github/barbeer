import 'package:barbeer/core/errors/app_exception.dart';
import 'package:barbeer/core/network/api_client.dart';
import 'package:barbeer/core/offline/offline_store.dart';
import 'package:barbeer/core/theme/app_theme.dart';
import 'package:barbeer/features/caja/data/caja_repository.dart';
import 'package:barbeer/features/caja/presentation/providers/caja_provider.dart';
import 'package:barbeer/features/caja/presentation/widgets/anular_movimiento_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCajaRepository extends CajaRepository {
  _FakeCajaRepository({this.annulError, this.sessionVersion = 'V2'})
    : super(ApiClient.instance);

  final Object? annulError;
  String sessionVersion;
  int annulCalls = 0;
  int detailCalls = 0;
  String? lastCajaSesionId;
  String? lastMovimientoId;
  String? lastMotivo;
  String? lastSuperadminPin;

  @override
  Future<void> anularMovimiento({
    required String cajaSesionId,
    required String movimientoId,
    required String motivo,
    String? superadminPin,
  }) async {
    annulCalls++;
    lastCajaSesionId = cajaSesionId;
    lastMovimientoId = movimientoId;
    lastMotivo = motivo;
    lastSuperadminPin = superadminPin;
    if (annulError != null) throw annulError!;
  }

  @override
  Future<CajaSesion> detalle(String id) async {
    detailCalls++;
    return CajaSesion.fromJson({
      'id': id,
      'estado': 'CERRADA',
      'version': sessionVersion,
    });
  }
}

CajaMovimiento _movement({bool anulable = true}) => CajaMovimiento(
  id: 'movement-1',
  cajaSesionId: 'session-1',
  sedeId: 'branch-1',
  tipo: 'SALIDA',
  origen: 'MANUAL',
  concepto: 'Supplier payment',
  monto: 25.5,
  usuario: 'cashier',
  createdAt: DateTime(2026, 8, 13, 10),
  anulable: anulable,
);

Widget _actionHarness({
  required _FakeCajaRepository repository,
  required TargetPlatform platform,
  required Size size,
  required bool hasCajaReadPermission,
  required bool isSuperAdmin,
  required String? sessionVersion,
  required Future<void> Function() onRefresh,
  CajaMovimiento? movement,
}) => ProviderScope(
  overrides: [cajaRepositoryProvider.overrideWithValue(repository)],
  child: MaterialApp(
    theme: AppTheme.lightTheme.copyWith(platform: platform),
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(
        body: Center(
          child: CashMovementAnnulmentAction(
            movement: movement ?? _movement(),
            hasCajaReadPermission: hasCajaReadPermission,
            isSuperAdmin: isSuperAdmin,
            sessionVersion: sessionVersion,
            onRefresh: onRefresh,
          ),
        ),
      ),
    ),
  ),
);

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
}

void main() {
  group('Cash movement annulment repository contract', () {
    test('parses server eligibility and fails closed when it is absent', () {
      final eligible = CajaMovimiento.fromJson({
        'id': 'movement-1',
        'cajaSesionId': 'session-1',
        'anulable': true,
        'revierteAId': null,
        'revertidoPorId': null,
      });
      final unavailable = CajaMovimiento.fromJson({
        'id': 'movement-2',
        'cajaSesionId': 'session-1',
      });

      expect(eligible.anulable, isTrue);
      expect(unavailable.anulable, isFalse);
    });

    test('uses the movement-scoped endpoint and DTO payload', () async {
      String? requestPath;
      Map<String, dynamic>? requestData;
      final repository = CajaRepository(
        ApiClient.instance,
        annulMovementRequest: (path, data) async {
          requestPath = path;
          requestData = data;
        },
      );

      await repository.anularMovimiento(
        cajaSesionId: 'session-1',
        movimientoId: 'movement-1',
        motivo: '  Duplicate cash outflow  ',
        superadminPin: '1234',
      );

      expect(requestPath, '/caja/session-1/movimientos/movement-1/anular');
      expect(requestData, {
        'motivo': 'Duplicate cash outflow',
        'superadminPin': '1234',
      });
    });

    test(
      'omits an absent SUPERADMIN PIN and validates supplied PINs',
      () async {
        final payloads = <Map<String, dynamic>>[];
        final repository = CajaRepository(
          ApiClient.instance,
          annulMovementRequest: (_, data) async => payloads.add(data),
        );

        await repository.anularMovimiento(
          cajaSesionId: 'session-1',
          movimientoId: 'movement-1',
          motivo: 'Approved by SUPERADMIN',
        );
        expect(payloads.single, {'motivo': 'Approved by SUPERADMIN'});

        await expectLater(
          repository.anularMovimiento(
            cajaSesionId: 'session-1',
            movimientoId: 'movement-1',
            motivo: 'Invalid PIN',
            superadminPin: '12',
          ),
          throwsFormatException,
        );
        await expectLater(
          repository.anularMovimiento(
            cajaSesionId: 'session-1',
            movimientoId: 'movement-1',
            motivo: '   ',
          ),
          throwsFormatException,
        );
      },
    );

    test('annulment requests cannot enter the offline mutation queue', () {
      expect(
        OfflineStore.canQueue(
          'POST',
          '/caja/session-1/movimientos/movement-1/anular',
        ),
        isFalse,
      );
      expect(
        OfflineStore.canQueue('POST', '/caja/session-1/movimientos'),
        isTrue,
      );
    });
  });

  group('Cash movement annulment eligibility', () {
    test(
      'requires caja read permission, backend eligibility and V2 session',
      () {
        final eligible = _movement();
        expect(
          cashMovementCanBeAnnulled(
            movement: eligible,
            hasCajaReadPermission: true,
            sessionVersion: 'V2',
          ),
          isTrue,
        );
        expect(
          cashMovementCanBeAnnulled(
            movement: eligible,
            hasCajaReadPermission: false,
            sessionVersion: 'V2',
          ),
          isFalse,
        );
        expect(
          cashMovementCanBeAnnulled(
            movement: _movement(anulable: false),
            hasCajaReadPermission: true,
            sessionVersion: 'V2',
          ),
          isFalse,
        );
        expect(
          cashMovementCanBeAnnulled(
            movement: eligible,
            hasCajaReadPermission: true,
            sessionVersion: 'V1',
          ),
          isFalse,
        );
      },
    );

    testWidgets('does not submit a historical movement from a V1 session', (
      tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      _setViewport(tester, const Size(390, 844));
      final repository = _FakeCajaRepository(sessionVersion: 'V1');

      await tester.pumpWidget(
        _actionHarness(
          repository: repository,
          platform: TargetPlatform.android,
          size: const Size(390, 844),
          hasCajaReadPermission: true,
          isSuperAdmin: false,
          sessionVersion: null,
          onRefresh: () async {},
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('cash-movement-annul-movement-1')),
      );
      await tester.pumpAndSettle();

      expect(repository.detailCalls, 1);
      expect(repository.annulCalls, 0);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('cash-movement-annul-movement-1')),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets(
      'renders the action disabled without permission or eligibility',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        _setViewport(tester, const Size(390, 844));

        for (final config in [
          (canRead: false, anulable: true),
          (canRead: true, anulable: false),
        ]) {
          await tester.pumpWidget(
            _actionHarness(
              repository: _FakeCajaRepository(),
              platform: TargetPlatform.android,
              size: const Size(390, 844),
              hasCajaReadPermission: config.canRead,
              isSuperAdmin: false,
              sessionVersion: 'V2',
              onRefresh: () async {},
              movement: _movement(anulable: config.anulable),
            ),
          );

          expect(
            tester
                .widget<OutlinedButton>(
                  find.byKey(const ValueKey('cash-movement-annul-movement-1')),
                )
                .onPressed,
            isNull,
          );
        }
      },
    );
  });

  group('Cash movement annulment dialog', () {
    testWidgets('requires reason and a four-digit PIN before submission', (
      tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      _setViewport(tester, const Size(390, 844));
      final repository = _FakeCajaRepository();
      var refreshCalls = 0;

      await tester.pumpWidget(
        _actionHarness(
          repository: repository,
          platform: TargetPlatform.android,
          size: const Size(390, 844),
          hasCajaReadPermission: true,
          isSuperAdmin: false,
          sessionVersion: 'V2',
          onRefresh: () async => refreshCalls++,
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('cash-movement-annul-movement-1')),
      );
      await tester.pumpAndSettle();

      final pinField = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const ValueKey('cash-annul-pin')),
          matching: find.byType(EditableText),
        ),
      );
      expect(pinField.obscureText, isTrue);
      await tester.enterText(
        find.byKey(const ValueKey('cash-annul-reason')),
        '  Correct an accidental payment  ',
      );
      await tester.enterText(
        find.byKey(const ValueKey('cash-annul-pin')),
        '123',
      );
      await tester.tap(find.byKey(const ValueKey('cash-annul-confirm')));
      await tester.pumpAndSettle();

      expect(repository.annulCalls, 0);
      expect(
        find.text('Ingresa una clave de SUPERADMIN de 4 dígitos.'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('cash-annul-pin')),
        '1234',
      );
      await tester.tap(find.byKey(const ValueKey('cash-annul-confirm')));
      await tester.pumpAndSettle();

      expect(repository.annulCalls, 1);
      expect(repository.lastCajaSesionId, 'session-1');
      expect(repository.lastMovimientoId, 'movement-1');
      expect(repository.lastMotivo, 'Correct an accidental payment');
      expect(repository.lastSuperadminPin, '1234');
      expect(refreshCalls, 1);
    });

    testWidgets('SUPERADMIN does not receive or send a PIN field', (
      tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      _setViewport(tester, const Size(1440, 900));
      final repository = _FakeCajaRepository();

      await tester.pumpWidget(
        _actionHarness(
          repository: repository,
          platform: TargetPlatform.windows,
          size: const Size(1440, 900),
          hasCajaReadPermission: true,
          isSuperAdmin: true,
          sessionVersion: 'V2',
          onRefresh: () async {},
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('cash-movement-annul-movement-1')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('cash-annul-pin')), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('cash-annul-reason')),
        'Approved correction',
      );
      await tester.tap(find.byKey(const ValueKey('cash-annul-confirm')));
      await tester.pumpAndSettle();

      expect(repository.annulCalls, 1);
      expect(repository.lastSuperadminPin, isNull);
    });

    testWidgets('definitive API errors remain visible and do not refresh', (
      tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      _setViewport(tester, const Size(1440, 900));
      final repository = _FakeCajaRepository(
        annulError: const AppException(
          message: 'La clave de SUPERADMIN no es válida.',
          statusCode: 403,
        ),
      );
      var refreshCalls = 0;

      await tester.pumpWidget(
        _actionHarness(
          repository: repository,
          platform: TargetPlatform.windows,
          size: const Size(1440, 900),
          hasCajaReadPermission: true,
          isSuperAdmin: false,
          sessionVersion: 'V2',
          onRefresh: () async => refreshCalls++,
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('cash-movement-annul-movement-1')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('cash-annul-reason')),
        'Correct the cash record',
      );
      await tester.enterText(
        find.byKey(const ValueKey('cash-annul-pin')),
        '1234',
      );
      await tester.tap(find.byKey(const ValueKey('cash-annul-confirm')));
      await tester.pumpAndSettle();

      expect(find.text('La clave de SUPERADMIN no es válida.'), findsOneWidget);
      expect(repository.annulCalls, 1);
      expect(refreshCalls, 0);
    });

    testWidgets('uncertain outcomes refresh and block blind resubmission', (
      tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      _setViewport(tester, const Size(390, 844));
      final repository = _FakeCajaRepository(
        annulError: const NetworkException(),
      );
      var refreshCalls = 0;

      await tester.pumpWidget(
        _actionHarness(
          repository: repository,
          platform: TargetPlatform.android,
          size: const Size(390, 844),
          hasCajaReadPermission: true,
          isSuperAdmin: false,
          sessionVersion: 'V2',
          onRefresh: () async => refreshCalls++,
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('cash-movement-annul-movement-1')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('cash-annul-reason')),
        'Correct the cash record',
      );
      await tester.enterText(
        find.byKey(const ValueKey('cash-annul-pin')),
        '1234',
      );
      await tester.tap(find.byKey(const ValueKey('cash-annul-confirm')));
      await tester.pumpAndSettle();

      expect(repository.annulCalls, 1);
      expect(refreshCalls, 1);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('cash-movement-annul-movement-1')),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('dialog fits Android and Windows viewports', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const viewports = <({TargetPlatform platform, Size size})>[
        (platform: TargetPlatform.android, size: Size(390, 844)),
        (platform: TargetPlatform.windows, size: Size(1440, 900)),
      ];

      for (final viewport in viewports) {
        _setViewport(tester, viewport.size);
        await tester.pumpWidget(
          _actionHarness(
            repository: _FakeCajaRepository(),
            platform: viewport.platform,
            size: viewport.size,
            hasCajaReadPermission: true,
            isSuperAdmin: false,
            sessionVersion: 'V2',
            onRefresh: () async {},
          ),
        );
        await tester.tap(
          find.byKey(const ValueKey('cash-movement-annul-movement-1')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.byKey(const ValueKey('cash-annul-reason')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
      }
    });
  });
}
