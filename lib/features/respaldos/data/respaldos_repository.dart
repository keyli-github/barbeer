import 'dart:typed_data';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'models/respaldo_models.dart';

typedef Json = Map<String, dynamic>;
typedef BackupGetRequest = Future<Object?> Function(String path);
typedef BackupGetWithQueryRequest = Future<Object?> Function(
    String path, Json query);
typedef BackupPutRequest = Future<Object?> Function(String path, Json body);
typedef BackupBytesRequest = Future<Uint8List> Function(String path);

class RespaldosRepository {
  final ApiClient? _api;
  final BackupGetRequest? getRequest;
  final BackupGetWithQueryRequest? getWithQueryRequest;
  final BackupPutRequest? putRequest;
  final BackupBytesRequest? bytesRequest;

  const RespaldosRepository(
    this._api, {
    this.getRequest,
    this.getWithQueryRequest,
    this.putRequest,
    this.bytesRequest,
  });

  Future<BackupSchedule> getSchedule() async {
    final data = getRequest != null
        ? await getRequest!(ApiConstants.backupSchedule)
        : (await _api!.get(ApiConstants.backupSchedule)).data;
    return BackupSchedule.fromJson(data as Json);
  }

  Future<BackupSchedule> updateSchedule(BackupSchedule schedule) async {
    final body = schedule.toUpdateJson();
    final data = putRequest != null
        ? await putRequest!(ApiConstants.backupSchedule, body)
        : (await _api!.put(ApiConstants.backupSchedule, data: body)).data;
    return BackupSchedule.fromJson(data as Json);
  }

  Future<BackupRunsPage> listRuns({int page = 1, int limit = 20}) async {
    final query = <String, dynamic>{'page': page, 'limit': limit};
    final data = getWithQueryRequest != null
        ? await getWithQueryRequest!(ApiConstants.backupRuns, query)
        : (await _api!.get(ApiConstants.backupRuns,
                queryParameters: query))
            .data;
    return BackupRunsPage.fromJson(data as Json);
  }

  Future<Uint8List> downloadArtifact(
    String runId,
    String format, {
    String? expectedSha256,
  }) async {
    final path = ApiConstants.backupArtifact(runId, format);
    final bytes = bytesRequest != null
        ? await bytesRequest!(path)
        : await _api!.getBytes(path);
    if (expectedSha256 != null) {
      final actual = sha256HexOf(bytes);
      if (actual != expectedSha256) {
        throw BackupIntegrityException(
            'SHA-256 mismatch: expected $expectedSha256 got $actual');
      }
    }
    return bytes;
  }
}
