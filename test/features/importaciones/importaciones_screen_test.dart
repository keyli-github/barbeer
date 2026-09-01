import 'dart:typed_data';

import 'package:barbeer/core/network/api_client.dart';
import 'package:barbeer/core/storage/secure_storage.dart';
import 'package:barbeer/core/theme/app_theme.dart';
import 'package:barbeer/features/auth/data/models/auth_models.dart';
import 'package:barbeer/features/auth/data/repositories/auth_repository.dart';
import 'package:barbeer/features/auth/presentation/providers/auth_provider.dart';
import 'package:barbeer/features/importaciones/data/excel_import_file_picker.dart';
import 'package:barbeer/features/importaciones/data/importaciones_repository.dart';
import 'package:barbeer/features/importaciones/presentation/providers/importaciones_provider.dart';
import 'package:barbeer/features/importaciones/presentation/screens/importaciones_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'importaciones_fixtures.dart';

void main() {
  testWidgets('mobile 400x800 uses cards, scrolls and completes the flow', (
    tester,
  ) async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);
    await _setSize(tester, const Size(400, 800));

    await _pump(tester, harness);

    expect(find.text('Importación inicial desde Excel'), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(
      find.byKey(const ValueKey('preview-products-cards')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('preview-products-table')), findsNothing);
    expect(find.byKey(const ValueKey('preview-sales-cards')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('preview-expenses-cards')),
      findsOneWidget,
    );
    expect(find.text('Descargar plantilla'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.byKey(const ValueKey('confirm-checkbox')));
    await tester.tap(find.byKey(const ValueKey('confirm-checkbox')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('import-button')));
    await tester.tap(find.byKey(const ValueKey('import-button')));
    await tester.pumpAndSettle();

    expect(find.text('Importación reconciliada'), findsOneWidget);
    expect(find.byKey(const ValueKey('import-result-cards')), findsOneWidget);
    expect(
      find.textContaining('Gemini no devolvió una imagen.'),
      findsOneWidget,
    );
    expect(harness.importCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop 1400x900 uses compact tables without overflow', (
    tester,
  ) async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);
    await _setSize(tester, const Size(1400, 900));

    await _pump(tester, harness);

    expect(
      find.byKey(const ValueKey('preview-products-table')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('preview-sales-table')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('preview-expenses-table')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('preview-products-cards')), findsNothing);
    expect(find.byKey(const ValueKey('preview-totals-table')), findsOneWidget);
    expect(find.text('Confirmar e importar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pull to refresh reloads only venues', (tester) async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);
    await _setSize(tester, const Size(400, 800));
    await _pump(tester, harness);
    final previewsBefore = harness.previewCalls;
    final importsBefore = harness.importCalls;

    await tester.drag(
      find.byKey(const ValueKey('importaciones-scroll')),
      const Offset(0, 320),
    );
    await tester.pumpAndSettle();

    expect(harness.venueCalls, 2);
    expect(harness.previewCalls, previewsBefore);
    expect(harness.importCalls, importsBefore);
  });
}

Future<void> _setSize(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

Future<void> _pump(WidgetTester tester, _Harness harness) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(
          (_) => _AuthorizedAuthNotifier(harness.authRepository),
        ),
        importacionesProvider.overrideWith((_) => harness.notifier),
        excelImportFilePickerProvider.overrideWithValue(harness.picker),
        importacionesRepositoryProvider.overrideWithValue(harness.repository),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ImportacionesScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _Harness {
  final ImportacionesRepository repository;
  final ExcelImportFilePicker picker;
  final ImportacionesNotifier notifier;
  final AuthRepository authRepository;
  int venueCalls;
  int previewCalls;
  int importCalls;

  _Harness._({
    required this.repository,
    required this.picker,
    required this.notifier,
    required this.authRepository,
    required this.venueCalls,
    required this.previewCalls,
    required this.importCalls,
  });

  static Future<_Harness> create() async {
    var venueCalls = 0;
    var previewCalls = 0;
    var importCalls = 0;
    final file = ExcelImportFile.validated(
      name: 'ACTUALIZADO.xlsx',
      bytes: Uint8List.fromList([1, 2, 3]),
    );
    late _Harness harness;
    final repository = ImportacionesRepository(
      null,
      getRequest: (_) async {
        venueCalls++;
        if (harnessIsReady) harness.venueCalls = venueCalls;
        return [
          {'id': 'venue-1', 'nombre': 'Principal', 'codigoSede': 'PRI'},
        ];
      },
      multipartRequest:
          (path, _, {required receiveTimeout, required sendTimeout}) async {
            if (path == ImportacionesRepository.previewPath) {
              previewCalls++;
              if (harnessIsReady) harness.previewCalls = previewCalls;
              return previewJson();
            }
            importCalls++;
            if (harnessIsReady) harness.importCalls = importCalls;
            return importResultJson();
          },
    );
    final picker = _Picker(file);
    final notifier = ImportacionesNotifier(repository, picker);
    final authRepository = AuthRepository(
      api: ApiClient.instance,
      storage: SecureStorageService.instance,
    );
    harness = _Harness._(
      repository: repository,
      picker: picker,
      notifier: notifier,
      authRepository: authRepository,
      venueCalls: venueCalls,
      previewCalls: previewCalls,
      importCalls: importCalls,
    );
    harnessIsReady = true;
    await notifier.loadVenues();
    notifier.selectVenue('venue-1');
    notifier.setFile(file);
    await notifier.previewExcel();
    return harness;
  }

  void dispose() {
    harnessIsReady = false;
  }
}

bool harnessIsReady = false;

class _Picker implements ExcelImportFilePicker {
  final ExcelImportFile file;

  const _Picker(this.file);

  @override
  Future<ExcelImportFile?> pick() async => file;
}

class _AuthorizedAuthNotifier extends AuthNotifier {
  _AuthorizedAuthNotifier(super.repository) {
    state = const AuthState(
      status: AuthStatus.authenticated,
      user: UserProfile(
        id: 'user-1',
        username: 'admin',
        rol: 'SUPERADMIN',
        nivel: 100,
        createdAt: '2026-01-01',
        permisos: ['importaciones:ejecutar'],
      ),
    );
  }
}
