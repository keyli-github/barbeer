import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';
import '../../../core/network/api_client.dart';

typedef OperationJson = Map<String, dynamic>;
typedef OperationMutationRequest =
    Future<Object?> Function(String method, String path, OperationJson? data);

OperationJson objectValue(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
List<OperationJson> objectList(dynamic value) =>
    value is List ? value.map(objectValue).toList() : [];
double decimalValue(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
String soles(dynamic value) => 'S/ ${decimalValue(value).toStringAsFixed(2)}';

class OperationsPage {
  final List<OperationJson> items;
  final int total;
  final int pages;
  final double totalAmount;
  OperationsPage.fromJson(OperationJson json)
    : items = objectList(json['data']),
      total = (json['total'] as num?)?.toInt() ?? 0,
      pages = (json['totalPaginas'] as num?)?.toInt() ?? 1,
      totalAmount = decimalValue(json['totalMonto']);
}

final operationsRepositoryProvider = Provider(
  (ref) => OperationsRepository(ApiClient.instance),
);

class OperationsRepository {
  final ApiClient api;
  final OperationMutationRequest? payrollRecargoRequest;
  OperationsRepository(this.api, {this.payrollRecargoRequest});

  Future<OperationsPage> list(
    String path, {
    String? sedeId,
    int page = 1,
    Map<String, dynamic> filters = const {},
  }) async {
    final response = await api.get(
      path,
      queryParameters: {
        'pagina': page,
        'limite': 25,
        'sedeId': ?sedeId,
        ...filters,
      },
    );
    return OperationsPage.fromJson(objectValue(response.data));
  }

  Future<OperationJson> detail(String path) async =>
      objectValue((await api.get(path)).data);
  Future<OperationJson> create(String path, OperationJson data) async =>
      objectValue((await api.post(path, data: data)).data);
  Future<void> update(String path, OperationJson data) async {
    await api.patch(path, data: data);
  }

  Future<void> configurePay(String id, OperationJson data) async {
    await api.put('/pagos/$id/configuracion', data: data);
  }

  Future<void> remove(String path) async {
    await api.delete(path);
  }

  Future<OperationJson> createManualRecargo({
    required String usuarioId,
    required double monto,
    required String motivo,
    required String fecha,
  }) async {
    final path = '/pagos/$usuarioId/recargos';
    final data = {'monto': monto, 'motivo': motivo, 'fecha': fecha};
    if (payrollRecargoRequest != null) {
      return objectValue(await payrollRecargoRequest!('POST', path, data));
    }
    return objectValue((await api.post(path, data: data)).data);
  }

  Future<void> removeManualRecargo(String recargoId) async {
    final path = '/pagos/recargos/$recargoId';
    if (payrollRecargoRequest != null) {
      await payrollRecargoRequest!('DELETE', path, null);
      return;
    }
    await api.delete(path);
  }

  Future<List<OperationJson>> expenseStaff(String sedeId) async => objectList(
    (await api.get(
      '/gastos-internos/personal',
      queryParameters: {'sedeId': sedeId},
    )).data,
  );
  Future<OperationJson> expenseDestination(String sedeId, String date) async =>
      objectValue(
        (await api.get(
          '/gastos-internos/destino',
          queryParameters: {'sedeId': sedeId, 'fecha': date},
        )).data,
      );

  Future<void> uploadAssetImage(String id, Uint8List bytes, String name) async {
    final extension = name.split('.').last.toLowerCase();
    await api.postMultipart(
      '/productos-internos/$id/imagen',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: name,
          contentType: MediaType(
            'image',
            extension == 'jpg' ? 'jpeg' : extension,
          ),
        ),
      }),
    );
  }
}
