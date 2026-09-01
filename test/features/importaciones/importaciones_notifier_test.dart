import 'dart:async';
import 'dart:typed_data';

import 'package:barbeer/features/importaciones/data/excel_import_file_picker.dart';
import 'package:barbeer/features/importaciones/data/importaciones_repository.dart';
import 'package:barbeer/features/importaciones/presentation/providers/importaciones_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'importaciones_fixtures.dart';

void main() {
  final file = ExcelImportFile.validated(
    name: 'ACTUALIZADO.xlsx',
    bytes: Uint8List.fromList([1, 2, 3]),
  );

  test('loads venues and preserves a valid initial venue', () async {
    final notifier = ImportacionesNotifier(
      _repository(),
      _Picker(file),
      initialVenueId: 'venue-1',
    );
    addTearDown(notifier.dispose);

    await notifier.loadVenues();

    expect(notifier.state.venues.first.nombre, 'Principal');
    expect(notifier.state.selectedVenueId, 'venue-1');
    expect(notifier.state.venuesLoading, isFalse);
    expect(notifier.state.venuesError, isNull);
  });

  test(
    'changing venue or file resets preview, confirmation and result',
    () async {
      final notifier = ImportacionesNotifier(_repository(), _Picker(file));
      addTearDown(notifier.dispose);
      await notifier.loadVenues();
      notifier.selectVenue('venue-1');
      notifier.setFile(file);
      await notifier.previewExcel();
      notifier.setConfirmed(true);
      await notifier.importExcel();
      expect(notifier.state.result, isNotNull);

      notifier.selectVenue('venue-2');

      expect(notifier.state.selectedFile, same(file));
      expect(notifier.state.preview, isNull);
      expect(notifier.state.result, isNull);
      expect(notifier.state.confirmed, isFalse);
      expect(notifier.state.previewStatus, ImportOperationStatus.idle);

      notifier.selectVenue('venue-1');
      await notifier.previewExcel();
      notifier.setConfirmed(true);
      final replacement = ExcelImportFile.validated(
        name: 'NUEVO.xlsx',
        bytes: Uint8List.fromList([4, 5]),
      );
      notifier.setFile(replacement);

      expect(notifier.state.selectedFile?.name, 'NUEVO.xlsx');
      expect(notifier.state.preview, isNull);
      expect(notifier.state.confirmed, isFalse);
    },
  );

  test(
    'picker cancellation keeps the current file and invalid selection clears it',
    () async {
      final picker = _SequencePicker([
        null,
        const ExcelImportFileException('El archivo no debe superar 15 MB.'),
      ]);
      final notifier = ImportacionesNotifier(_repository(), picker);
      addTearDown(notifier.dispose);
      notifier.setFile(file);

      await notifier.pickFile();
      expect(notifier.state.selectedFile, same(file));

      await notifier.pickFile();
      expect(notifier.state.selectedFile, isNull);
      expect(notifier.state.fileError, contains('15 MB'));
    },
  );

  test('duplicate preview cannot be confirmed or submitted', () async {
    var importCalls = 0;
    final notifier = ImportacionesNotifier(
      _repository(
        duplicate: true,
        onImport: () {
          importCalls++;
          return importResultJson();
        },
      ),
      _Picker(file),
    );
    addTearDown(notifier.dispose);
    notifier.selectVenue('venue-1');
    notifier.setFile(file);

    await notifier.previewExcel();
    notifier.setConfirmed(true);
    await notifier.importExcel();

    expect(notifier.state.preview?.duplicate, isNotNull);
    expect(notifier.state.confirmed, isFalse);
    expect(notifier.state.canSubmit, isFalse);
    expect(importCalls, 0);
  });

  test('protects final import from concurrent double submit', () async {
    var importCalls = 0;
    final completer = Completer<Map<String, dynamic>>();
    final notifier = ImportacionesNotifier(
      _repository(
        onImport: () {
          importCalls++;
          return completer.future;
        },
      ),
      _Picker(file),
    );
    addTearDown(notifier.dispose);
    notifier.selectVenue('venue-1');
    notifier.setFile(file);
    await notifier.previewExcel();
    notifier.setConfirmed(true);

    final first = notifier.importExcel();
    final second = notifier.importExcel();
    await Future<void>.delayed(Duration.zero);

    expect(importCalls, 1);
    expect(notifier.state.importStatus, ImportOperationStatus.loading);
    completer.complete(importResultJson());
    await Future.wait([first, second]);
    expect(notifier.state.result?.reconciled, isTrue);
    expect(notifier.state.confirmed, isFalse);
    expect(notifier.state.canSubmit, isFalse);
  });

  test('does not allow another submit after a successful import', () async {
    var importCalls = 0;
    final notifier = ImportacionesNotifier(
      _repository(
        onImport: () {
          importCalls++;
          return importResultJson();
        },
      ),
      _Picker(file),
    );
    addTearDown(notifier.dispose);
    notifier.selectVenue('venue-1');
    notifier.setFile(file);
    await notifier.previewExcel();
    notifier.setConfirmed(true);
    await notifier.importExcel();

    notifier.setConfirmed(true);
    await notifier.importExcel();

    expect(importCalls, 1);
    expect(notifier.state.confirmed, isFalse);
    expect(notifier.state.canSubmit, isFalse);
  });

  test('ignores a preview completion after notifier disposal', () async {
    final previewCompleter = Completer<Map<String, dynamic>>();
    final repository = ImportacionesRepository(
      null,
      multipartRequest:
          (path, _, {required receiveTimeout, required sendTimeout}) {
            return previewCompleter.future;
          },
    );
    final notifier = ImportacionesNotifier(repository, _Picker(file));
    notifier.selectVenue('venue-1');
    notifier.setFile(file);

    final pendingPreview = notifier.previewExcel();
    notifier.dispose();
    previewCompleter.complete(previewJson());

    await expectLater(pendingPreview, completes);
  });
}

ImportacionesRepository _repository({
  bool duplicate = false,
  FutureOr<Map<String, dynamic>> Function()? onImport,
}) => ImportacionesRepository(
  null,
  getRequest: (_) async => [
    {'id': 'venue-1', 'nombre': 'Principal', 'codigoSede': 'PRI'},
    {'id': 'venue-2', 'nombre': 'Norte', 'codigoSede': 'NOR'},
  ],
  multipartRequest:
      (path, _, {required receiveTimeout, required sendTimeout}) async {
        if (path == ImportacionesRepository.previewPath) {
          return previewJson(duplicate: duplicate);
        }
        return await onImport?.call() ?? importResultJson();
      },
);

class _Picker implements ExcelImportFilePicker {
  final ExcelImportFile? file;

  const _Picker(this.file);

  @override
  Future<ExcelImportFile?> pick() async => file;
}

class _SequencePicker implements ExcelImportFilePicker {
  final List<Object?> results;
  var index = 0;

  _SequencePicker(this.results);

  @override
  Future<ExcelImportFile?> pick() async {
    final result = results[index++];
    if (result is Exception) throw result;
    return result as ExcelImportFile?;
  }
}
