import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'models/usuario_permission_models.dart';

typedef PermissionGetRequest = Future<Object?> Function(String path);
typedef PermissionPutRequest =
    Future<Object?> Function(String path, Map<String, dynamic> body);
typedef PermissionPatchRequest =
    Future<Object?> Function(String path, Map<String, dynamic> body);
typedef PermissionPostRequest =
    Future<Object?> Function(String path, Map<String, dynamic> body);

class UsuarioAdminRepository {
  final ApiClient _api;
  final PermissionGetRequest? getRequest;
  final PermissionPutRequest? putRequest;
  final PermissionPatchRequest? patchRequest;
  final PermissionPostRequest? postRequest;

  const UsuarioAdminRepository(
    this._api, {
    this.getRequest,
    this.putRequest,
    this.patchRequest,
    this.postRequest,
  });

  Future<UsuarioPermisosResponse> getPermissions(String userId) async {
    final path = ApiConstants.userPermissions(userId);
    final data = getRequest != null
        ? await getRequest!(path)
        : (await _api.get(path)).data;
    return UsuarioPermisosResponse.fromJson(data as Map<String, dynamic>);
  }

  Future<UsuarioPermisosResponse> replacePermissions(
    String userId,
    ReplacePermissionsPayload payload,
  ) async {
    final path = ApiConstants.userPermissions(userId);
    final body = payload.toJson();
    final data = putRequest != null
        ? await putRequest!(path, body)
        : (await _api.put(path, data: body)).data;
    return UsuarioPermisosResponse.fromJson(data as Map<String, dynamic>);
  }

  Future<void> configureSuperadminPin(
    String userId,
    PinConfigPayload payload,
  ) async {
    final path = ApiConstants.superadminPin(userId);
    final body = payload.toJson();
    if (patchRequest != null) {
      await patchRequest!(path, body);
    } else {
      await _api.patch(path, data: body);
    }
  }

  Future<List<Map<String, dynamic>>> getSuperadminPins() async {
    final data = getRequest != null
        ? await getRequest!(ApiConstants.superadminPins)
        : (await _api.get(ApiConstants.superadminPins)).data;
    return List<Map<String, dynamic>>.from(data as List? ?? const []);
  }

  Future<PinValidationResult> validatePin(String pin) async {
    const path = ApiConstants.validatePin;
    final body = <String, dynamic>{'pin': pin};
    final data = postRequest != null
        ? await postRequest!(path, body)
        : (await _api.post(path, data: body)).data;
    return PinValidationResult.fromJson(data as Map<String, dynamic>);
  }

  Future<StockAdjustResult> adjustStock(
    String productId,
    StockAdjustPayload payload,
  ) async {
    final path = ApiConstants.productStock(productId);
    final body = payload.toJson();
    final data = postRequest != null
        ? await postRequest!(path, body)
        : (await _api.post(path, data: body)).data;
    return StockAdjustResult.fromJson(data as Map<String, dynamic>);
  }
}
