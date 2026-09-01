import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import '../../../core/network/api_client.dart';
import 'excel_import_file_picker.dart';
import 'models/importacion_models.dart';

typedef ImportGetRequest = Future<Object?> Function(String path);
typedef ImportMultipartRequest =
    Future<Object?> Function(
      String path,
      FormData data, {
      required Duration receiveTimeout,
      required Duration sendTimeout,
    });

class ImportacionesRepository {
  static const String venuesPath = '/importaciones/sedes';
  static const String previewPath = '/importaciones/excel/previsualizar';
  static const String importPath = '/importaciones/excel';
  static const String xlsxMime =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  static const Duration previewTimeout = Duration(seconds: 60);
  static const Duration importTimeout = Duration(minutes: 10);

  final ApiClient? _api;
  final ImportGetRequest? getRequest;
  final ImportMultipartRequest? multipartRequest;

  const ImportacionesRepository(
    this._api, {
    this.getRequest,
    this.multipartRequest,
  });

  Future<List<ImportVenue>> listVenues() async {
    final data = getRequest != null
        ? await getRequest!(venuesPath)
        : (await _api!.get(venuesPath)).data;
    if (data is! List) {
      throw const FormatException('Respuesta de sedes inválida.');
    }
    return data
        .whereType<Map>()
        .map((item) => ImportVenue.fromJson(_json(item)))
        .toList(growable: false);
  }

  Future<ExcelImportPreview> previewExcel(
    ExcelImportFile file,
    String sedeId,
  ) async {
    final data = await _postExcel(
      previewPath,
      file,
      sedeId,
      timeout: previewTimeout,
    );
    return ExcelImportPreview.fromJson(_json(data));
  }

  Future<ExcelImportResult> importExcel(
    ExcelImportFile file,
    String sedeId,
  ) async {
    final data = await _postExcel(
      importPath,
      file,
      sedeId,
      timeout: importTimeout,
    );
    return ExcelImportResult.fromJson(_json(data));
  }

  Future<Object?> _postExcel(
    String path,
    ExcelImportFile file,
    String sedeId, {
    required Duration timeout,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        file.bytes,
        filename: file.name,
        contentType: MediaType.parse(xlsxMime),
      ),
      'sedeId': sedeId,
    });
    if (multipartRequest != null) {
      return multipartRequest!(
        path,
        form,
        receiveTimeout: timeout,
        sendTimeout: timeout,
      );
    }
    final response = await _api!.postMultipart<Object?>(
      path,
      data: form,
      receiveTimeout: timeout,
      sendTimeout: timeout,
    );
    return response.data;
  }
}

Json _json(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw const FormatException('Respuesta de importación inválida.');
}
