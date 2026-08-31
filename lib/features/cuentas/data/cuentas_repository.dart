import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'models/cuenta_models.dart';
typedef CuentasRequest = Future<Object?> Function(String path, Json query);
class CuentasRepository {
  final ApiClient _api;
  final CuentasRequest? request, post;
  const CuentasRepository(this._api, {this.request, this.post});
  Future<List<Cuenta>> selector({String? search, required String sedeId}) async {
    final query = <String, dynamic>{
      if (search?.trim().isNotEmpty ?? false) 'search': search!.trim(),
      'sedeId': sedeId,
    };
    final data = await _get(ApiConstants.accountSelector, query) as List;
    return data.map((value) => Cuenta.fromJson(Json.from(value as Map))).toList();
  }
  Future<List<Cuenta>> list({String? search, required String sedeId}) async {
    final query = <String, dynamic>{
      if (search?.trim().isNotEmpty ?? false) 'search': search!.trim(),
      'sedeId': sedeId,
    };
    final data = await _get(ApiConstants.accounts, query) as List;
    return data.map((value) => Cuenta.fromJson(Json.from(value as Map))).toList();
  }
  Future<Cuenta> create({required String nombre, String? documento, String? telefono}) async {
    final body = <String, dynamic>{'nombre': nombre.trim(),
      if (documento?.trim().isNotEmpty ?? false) 'documento': documento!.trim(),
      if (telefono?.trim().isNotEmpty ?? false) 'telefono': telefono!.trim()};
    final data = post != null ? await post!(ApiConstants.accounts, body)
      : (await _api.post(ApiConstants.accounts, data: body)).data;
    return Cuenta.fromJson(Json.from(data as Map));
  }
  Future<CuentaDetalle> detail(String id, {required String sedeId}) async =>
    CuentaDetalle.fromJson(Json.from(await _get(ApiConstants.account(id), {'sedeId': sedeId}) as Map));
  Future<CuentaDetalle> collect(String id, {required double monto, required String medioPago,
    required String idempotencyKey, String? comprobanteAnalisisId, String? sedeId}) async {
    final body = <String, dynamic>{'monto': monto, 'medioPago': medioPago,
      'idempotencyKey': idempotencyKey, if (comprobanteAnalisisId?.isNotEmpty ?? false)
        'comprobanteAnalisisId': comprobanteAnalisisId, if (sedeId?.isNotEmpty ?? false) 'sedeId': sedeId};
    final data = post != null ? await post!(ApiConstants.accountPayments(id), body)
      : (await _api.post(ApiConstants.accountPayments(id), data: body)).data;
    return CuentaDetalle.fromJson(Json.from(data as Map));
  }
  Future<Object?> _get(String path, Json query) async {
    if (request != null) return request!(path, query);
    return (await _api.get(path, queryParameters: query)).data;
  }
}
