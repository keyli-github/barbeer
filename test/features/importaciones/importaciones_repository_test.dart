import 'dart:typed_data';

import 'package:barbeer/features/importaciones/data/excel_import_file_picker.dart';
import 'package:barbeer/features/importaciones/data/importaciones_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'importaciones_fixtures.dart';

void main() {
  group('ExcelImportFile validation', () {
    test('accepts case-insensitive xlsx bytes in memory', () {
      final file = ExcelImportFile.validated(
        name: ' ACTUALIZADO.XLSX ',
        bytes: Uint8List.fromList([1, 2, 3]),
      );

      expect(file.name, 'ACTUALIZADO.XLSX');
      expect(file.size, 3);
    });

    test('rejects another extension, empty bytes and files over 15 MB', () {
      expect(
        () => ExcelImportFile.validated(
          name: 'datos.xls',
          bytes: Uint8List.fromList([1]),
        ),
        throwsA(
          isA<ExcelImportFileException>().having(
            (error) => error.message,
            'message',
            contains('XLSX'),
          ),
        ),
      );
      expect(
        () =>
            ExcelImportFile.validated(name: 'datos.xlsx', bytes: Uint8List(0)),
        throwsA(isA<ExcelImportFileException>()),
      );
      expect(
        () => ExcelImportFile.validated(
          name: 'datos.xlsx',
          bytes: Uint8List.fromList([1]),
          reportedSize: maxExcelImportBytes + 1,
        ),
        throwsA(
          isA<ExcelImportFileException>().having(
            (error) => error.message,
            'message',
            contains('15 MB'),
          ),
        ),
      );
    });
  });

  group('ImportacionesRepository', () {
    final file = ExcelImportFile.validated(
      name: 'ACTUALIZADO.xlsx',
      bytes: Uint8List.fromList([1, 2, 3, 4]),
    );

    test('GETs the exact venues endpoint and maps venues', () async {
      String? capturedPath;
      final repository = ImportacionesRepository(
        null,
        getRequest: (path) async {
          capturedPath = path;
          return [
            {'id': 'venue-1', 'nombre': 'Principal', 'codigoSede': 'PRI'},
          ];
        },
      );

      final venues = await repository.listVenues();

      expect(capturedPath, ImportacionesRepository.venuesPath);
      expect(venues.single.nombre, 'Principal');
      expect(venues.single.codigoSede, 'PRI');
    });

    test(
      'sends preview multipart with XLSX MIME and 60 second timeouts',
      () async {
        late _MultipartCapture capture;
        final repository = ImportacionesRepository(
          null,
          multipartRequest:
              (
                path,
                form, {
                required receiveTimeout,
                required sendTimeout,
              }) async {
                capture = _MultipartCapture(
                  path,
                  form,
                  receiveTimeout,
                  sendTimeout,
                );
                return previewJson();
              },
        );

        final preview = await repository.previewExcel(file, 'venue-1');

        expect(preview.valid, isTrue);
        expect(capture.path, ImportacionesRepository.previewPath);
        expect(capture.receiveTimeout, const Duration(seconds: 60));
        expect(capture.sendTimeout, const Duration(seconds: 60));
        expect(_field(capture.form, 'sedeId'), 'venue-1');
        final upload = _file(capture.form, 'file');
        expect(upload.filename, 'ACTUALIZADO.xlsx');
        expect(upload.length, 4);
        expect(
          upload.contentType?.toString(),
          ImportacionesRepository.xlsxMime,
        );
      },
    );

    test('sends final import with independent 10 minute timeouts', () async {
      late _MultipartCapture capture;
      final repository = ImportacionesRepository(
        null,
        multipartRequest:
            (
              path,
              form, {
              required receiveTimeout,
              required sendTimeout,
            }) async {
              capture = _MultipartCapture(
                path,
                form,
                receiveTimeout,
                sendTimeout,
              );
              return importResultJson();
            },
      );

      final result = await repository.importExcel(file, 'venue-1');

      expect(result.reconciled, isTrue);
      expect(capture.path, ImportacionesRepository.importPath);
      expect(capture.receiveTimeout, const Duration(minutes: 10));
      expect(capture.sendTimeout, const Duration(minutes: 10));
      expect(_field(capture.form, 'sedeId'), 'venue-1');
      expect(
        _file(capture.form, 'file').contentType?.toString(),
        ImportacionesRepository.xlsxMime,
      );
    });

    test('rejects non-list venue responses', () async {
      final repository = ImportacionesRepository(
        null,
        getRequest: (_) async => {'data': []},
      );

      await expectLater(repository.listVenues(), throwsFormatException);
    });
  });
}

String? _field(FormData form, String name) {
  for (final field in form.fields) {
    if (field.key == name) return field.value;
  }
  return null;
}

MultipartFile _file(FormData form, String name) =>
    form.files.singleWhere((entry) => entry.key == name).value;

class _MultipartCapture {
  final String path;
  final FormData form;
  final Duration receiveTimeout;
  final Duration sendTimeout;

  const _MultipartCapture(
    this.path,
    this.form,
    this.receiveTimeout,
    this.sendTimeout,
  );
}
