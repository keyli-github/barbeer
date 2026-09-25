import 'dart:async';

import 'package:barbeer/core/network/api_client.dart';
import 'package:barbeer/features/asistencia/data/asistencia_repository.dart';
import 'package:barbeer/features/asistencia/presentation/screens/asistencia_screen.dart';
import 'package:barbeer/features/auth/data/models/auth_models.dart';
import 'package:barbeer/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';

const _qrToken = 'v1.test-payload.test-signature';
const _permissionChannel = MethodChannel(
  'flutter.baseflow.com/permissions/methods',
);

const _employee = UserProfile(
  id: 'employee-1',
  username: 'employee',
  rol: 'VENDEDORA',
  nivel: 10,
  sedeId: 'branch-1',
  createdAt: '2026-01-01',
  permisos: [],
);

const _admin = UserProfile(
  id: 'admin-1',
  username: 'admin',
  rol: 'ADMIN',
  nivel: 80,
  sedeId: 'branch-1',
  createdAt: '2026-01-01',
  permisos: ['asistencia:leer'],
);

class _FakeAttendanceRepository extends AsistenciaRepository {
  _FakeAttendanceRepository() : super(ApiClient.instance);

  final submittedTokens = <String>[];

  @override
  Future<AsistenciaPage> list({
    int pagina = 1,
    int limite = 25,
    String? fecha,
    String? usuarioId,
    String? sedeId,
  }) async =>
      const AsistenciaPage(data: [], total: 0, pagina: 1, totalPaginas: 1);

  @override
  Future<AsistenciaResumen> resumen({String? fecha, String? sedeId}) async =>
      const AsistenciaResumen(
        fecha: '2026-09-25',
        totalEmpleados: 1,
        presente: 0,
        tardanza: 0,
        diaLibre: 0,
        ausente: 1,
      );

  @override
  Future<QrKioscoResponse> qrKiosco({String? sedeId}) async =>
      const QrKioscoResponse(
        token: _qrToken,
        sedeId: 'branch-1',
        fecha: '2026-09-25',
        expiraEnSegundos: 300,
      );

  @override
  Future<MarcajeQrResponse> marcar(String token) async {
    submittedTokens.add(token);
    return const MarcajeQrResponse(
      tipo: 'ENTRADA',
      username: 'employee',
      estado: 'PRESENTE',
      hora: '08:00',
      mensaje: 'Asistencia registrada.',
    );
  }
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(super.repository, AuthState initialState) {
    state = initialState;
  }
}

class _FakeMobileScannerPlatform extends MobileScannerPlatform {
  final _barcodeController = StreamController<BarcodeCapture>.broadcast();
  int startCalls = 0;

  void emitBarcode(String value) {
    _barcodeController.add(
      BarcodeCapture(barcodes: [Barcode(rawValue: value)]),
    );
  }

  @override
  Stream<BarcodeCapture?> get barcodesStream => _barcodeController.stream;

  @override
  Stream<TorchState> get torchStateStream =>
      Stream<TorchState>.value(TorchState.unavailable);

  @override
  Stream<double> get zoomScaleStateStream => Stream<double>.value(1);

  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) async {
    startCalls++;
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.unavailable,
      size: Size(200, 200),
      numberOfCameras: 1,
    );
  }

  @override
  Widget buildCameraView() => const SizedBox.square(dimension: 200);

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() => _barcodeController.close();
}

Future<void> _withAttendanceScreen(
  WidgetTester tester, {
  required TargetPlatform platform,
  required UserProfile user,
  required _FakeAttendanceRepository repository,
  required Future<void> Function(_FakeMobileScannerPlatform scannerPlatform)
  run,
}) async {
  final previousTargetPlatform = debugDefaultTargetPlatformOverride;
  final previousScannerPlatform = MobileScannerPlatform.instance;
  debugDefaultTargetPlatformOverride = platform;
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;

  final scannerPlatform = _FakeMobileScannerPlatform();
  MobileScannerPlatform.instance = scannerPlatform;

  try {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asistenciaRepositoryProvider.overrideWithValue(repository),
          authProvider.overrideWith(
            (ref) => _TestAuthNotifier(
              ref.read(authRepositoryProvider),
              AuthState(status: AuthStatus.authenticated, user: user),
            ),
          ),
        ],
        child: const MaterialApp(home: AsistenciaScreen()),
      ),
    );
    await run(scannerPlatform);
  } finally {
    try {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    } finally {
      MobileScannerController.resetPlatformSessionOwner();
      MobileScannerPlatform.instance = previousScannerPlatform;
      debugDefaultTargetPlatformOverride = previousTargetPlatform;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_permissionChannel, null);
  });

  testWidgets('Windows employee must use a phone to mark attendance', (
    tester,
  ) async {
    var permissionRequests = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_permissionChannel, (call) async {
          permissionRequests++;
          return {Permission.camera.value: 1};
        });

    final repository = _FakeAttendanceRepository();
    await _withAttendanceScreen(
      tester,
      platform: TargetPlatform.windows,
      user: _employee,
      repository: repository,
      run: (scannerPlatform) async {
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('attendance-phone-guidance')),
          findsOneWidget,
        );
        expect(
          find.text(
            'Para marcar tu asistencia, usa la app móvil en tu teléfono y escanea el QR del kiosco de tu sede.',
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('attendance-scan-qr')), findsNothing);
        expect(
          find.byKey(const Key('attendance-paste-kiosk-token')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('attendance-submit-pasted-token')),
          findsNothing,
        );
        expect(find.byType(TextField), findsNothing);
        expect(find.byType(MobileScanner), findsNothing);
        expect(permissionRequests, 0);
        expect(repository.submittedTokens, isEmpty);
        expect(scannerPlatform.startCalls, 0);
      },
    );
  });

  testWidgets('Windows kiosk keeps its QR visible for phone scanning', (
    tester,
  ) async {
    await _withAttendanceScreen(
      tester,
      platform: TargetPlatform.windows,
      user: _admin,
      repository: _FakeAttendanceRepository(),
      run: (scannerPlatform) async {
        await tester.pumpAndSettle();

        expect(find.byType(QrImageView), findsOneWidget);
        expect(
          find.text('Escanea este código con la app móvil.'),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('attendance-copy-kiosk-token')),
          findsNothing,
        );
        expect(scannerPlatform.startCalls, 0);
      },
    );
  });

  testWidgets('Android employee scans a QR and marks attendance', (
    tester,
  ) async {
    var permissionRequests = 0;
    List<int> requestedPermissions = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_permissionChannel, (call) async {
          if (call.method == 'requestPermissions') {
            permissionRequests++;
            requestedPermissions = (call.arguments as List).cast<int>();
            return {Permission.camera.value: 1};
          }
          return null;
        });

    final repository = _FakeAttendanceRepository();
    await _withAttendanceScreen(
      tester,
      platform: TargetPlatform.android,
      user: _employee,
      repository: repository,
      run: (scannerPlatform) async {
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('attendance-scan-qr')), findsOneWidget);
        expect(
          find.byKey(const Key('attendance-paste-kiosk-token')),
          findsNothing,
        );
        await tester.tap(find.byKey(const Key('attendance-scan-qr')));
        await tester.pumpAndSettle();

        expect(permissionRequests, 1);
        expect(requestedPermissions, contains(Permission.camera.value));
        expect(find.byType(MobileScanner), findsOneWidget);
        expect(find.text('Escanear QR de asistencia'), findsOneWidget);
        expect(scannerPlatform.startCalls, 1);

        scannerPlatform.emitBarcode(_qrToken);
        await tester.pumpAndSettle();

        expect(repository.submittedTokens, [_qrToken]);
        expect(find.textContaining('Asistencia registrada.'), findsOneWidget);
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
      },
    );
  });
}
