import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'models/reporte_models.dart';
typedef Json = Map<String, dynamic>;
typedef ReportBytesRequest = Future<ReporteExportado> Function(String path, Json query);
typedef ReportGetRequest = Future<Object?> Function(String path);
typedef ReportPutRequest = Future<Object?> Function(String path, Json body);
typedef ReportPostRequest = Future<Object?> Function(String path, Json body);
class ReportesRepository {
  final ApiClient _api;
  final ReportBytesRequest? bytesRequest;
  final ReportGetRequest? getRequest;
  final ReportPutRequest? putRequest;
  final ReportPostRequest? postRequest;
  const ReportesRepository(this._api,
      {this.bytesRequest, this.getRequest, this.putRequest, this.postRequest});
  Future<ReporteExportado> exportReport(String tipo,
      {required String formato, required String fechaInicio, required String fechaFin, String? sedeId}) async {
    final query = <String, dynamic>{'formato': formato, 'fechaInicio': fechaInicio, 'fechaFin': fechaFin,
      if (sedeId?.isNotEmpty ?? false) 'sedeId': sedeId};
    final path = ApiConstants.reportExport(tipo);
    if (bytesRequest != null) return bytesRequest!(path, query);
    return ReporteExportado(bytes: await _api.getBytes(path, queryParameters: query),
        contentType: 'application/octet-stream', filename: 'reporte.$formato');
  }
  Future<ReporteExportado> exportCajaReport(String cajaId, {required String formato}) async {
    final query = <String, dynamic>{'formato': formato};
    final path = ApiConstants.reportCajaExport(cajaId);
    if (bytesRequest != null) return bytesRequest!(path, query);
    return ReporteExportado(bytes: await _api.getBytes(path, queryParameters: query),
        contentType: 'application/octet-stream', filename: 'caja.$formato');
  }
  Future<ReporteEmailConfig> getEmailConfig() async {
    final data = getRequest != null ? await getRequest!(ApiConstants.reportEmailConfig)
        : (await _api.get(ApiConstants.reportEmailConfig)).data;
    return ReporteEmailConfig.fromJson(data as Json);
  }
  Future<ReporteEmailConfig> updateEmailConfig(List<String> recipients) async {
    final body = <String, dynamic>{'recipients': recipients};
    final data = putRequest != null ? await putRequest!(ApiConstants.reportEmailConfig, body)
        : (await _api.put(ApiConstants.reportEmailConfig, data: body)).data;
    return ReporteEmailConfig.fromJson(data as Json);
  }
  Future<ReporteEmailTestResult> testEmailDelivery({List<String>? recipients}) async {
    final body = <String, dynamic>{if (recipients?.isNotEmpty ?? false) 'recipients': recipients};
    final data = postRequest != null ? await postRequest!(ApiConstants.reportEmailTest, body)
        : (await _api.post(ApiConstants.reportEmailTest, data: body)).data;
    return ReporteEmailTestResult.fromJson(data as Json);
  }
}
