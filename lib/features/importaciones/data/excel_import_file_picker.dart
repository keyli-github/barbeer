import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

const int maxExcelImportBytes = 15 * 1024 * 1024;

class ExcelImportFile {
  final String name;
  final Uint8List bytes;

  const ExcelImportFile._({required this.name, required this.bytes});

  factory ExcelImportFile.validated({
    required String name,
    required Uint8List bytes,
    int? reportedSize,
  }) {
    final normalizedName = name.trim();
    if (!normalizedName.toLowerCase().endsWith('.xlsx')) {
      throw const ExcelImportFileException('Solo se admite Excel XLSX.');
    }
    if (bytes.isEmpty) {
      throw const ExcelImportFileException(
        'No se pudo leer el contenido del archivo.',
      );
    }
    if (bytes.lengthInBytes > maxExcelImportBytes ||
        (reportedSize ?? 0) > maxExcelImportBytes) {
      throw const ExcelImportFileException('El archivo no debe superar 15 MB.');
    }
    return ExcelImportFile._(name: normalizedName, bytes: bytes);
  }

  int get size => bytes.lengthInBytes;
}

class ExcelImportFileException implements Exception {
  final String message;

  const ExcelImportFileException(this.message);

  @override
  String toString() => message;
}

abstract interface class ExcelImportFilePicker {
  Future<ExcelImportFile?> pick();
}

class SystemExcelImportFilePicker implements ExcelImportFilePicker {
  const SystemExcelImportFilePicker();

  @override
  Future<ExcelImportFile?> pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      withData: true,
      allowMultiple: false,
    );
    final platformFile = result?.files.singleOrNull;
    if (platformFile == null) return null;
    final bytes = platformFile.bytes;
    if (bytes == null) {
      throw const ExcelImportFileException(
        'No se pudo leer el contenido del archivo.',
      );
    }
    return ExcelImportFile.validated(
      name: platformFile.name,
      bytes: bytes,
      reportedSize: platformFile.size,
    );
  }
}
