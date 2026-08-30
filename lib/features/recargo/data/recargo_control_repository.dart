import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

typedef Json = Map<String, dynamic>;
typedef RecargoRequest = Future<Json> Function(String, String, Json?);
typedef RecargoControlUser = ({String id, String username});

class RecargoControlData {
  final bool oculto, configurado, puedeConfigurar, puedeCambiar;
  final List<RecargoControlSede> sedes;
  const RecargoControlData({
    this.oculto = false, this.configurado = false,
    this.puedeConfigurar = false, this.puedeCambiar = false,
    this.sedes = const [],
  });
  factory RecargoControlData.fromJson(Json json) => RecargoControlData(
    oculto: json['oculto'] as bool? ?? false,
    configurado: json['configurado'] as bool? ?? false,
    puedeConfigurar: json['puedeConfigurar'] as bool? ?? false,
    puedeCambiar: json['puedeCambiar'] as bool? ?? false,
    sedes: (json['sedes'] as List? ?? const [])
        .map((value) => RecargoControlSede.fromJson(Json.from(value as Map)))
        .toList(),
  );
  RecargoControlData withHidden(bool value) => RecargoControlData(
    oculto: value, configurado: configurado,
    puedeConfigurar: puedeConfigurar, puedeCambiar: puedeCambiar, sedes: sedes,
  );
}

class RecargoControlSede {
  final String id, nombre;
  final String? responsableId;
  final List<RecargoControlUser> usuarios;
  RecargoControlSede.fromJson(Json json)
    : id = json['id'] as String, nombre = json['nombre'] as String,
      responsableId = json['responsableId'] as String?,
      usuarios = (json['usuarios'] as List? ?? const [])
          .map((value) => Json.from(value as Map))
          .map((user) => (id: user['id'] as String, username: user['username'] as String))
          .toList();
}

class RecargoControlRepository {
  final ApiClient _api;
  final RecargoRequest? request;
  const RecargoControlRepository(this._api, {this.request});
  Future<RecargoControlData> estado() async =>
      RecargoControlData.fromJson(await _send('GET', ApiConstants.recargoEstado));
  Future<RecargoControlData> configuracion() async => RecargoControlData.fromJson(
    await _send('GET', ApiConstants.recargoConfiguracion));
  Future<RecargoControlData> guardarConfiguracion({String? clave, required Json responsables}) async =>
      RecargoControlData.fromJson(await _send('PUT', ApiConstants.recargoConfiguracion, {
        if (clave != null) 'clave': clave,
        'responsables': responsables.entries.map((entry) =>
          {'sedeId': entry.key, 'usuarioId': entry.value}).toList(),
      }));
  Future<({bool oculto})> cambiar({required String clave, required bool oculto}) async =>
      (oculto: (await _send('POST', ApiConstants.recargoCambiar,
        {'clave': clave, 'oculto': oculto}))['oculto'] as bool);

  Future<Json> _send(String method, String path, [Json? data]) async {
    if (request != null) return request!(method, path, data);
    final response = switch (method) {
      'GET' => await _api.get(path),
      'PUT' => await _api.put(path, data: data),
      _ => await _api.post(path, data: data),
    };
    return Json.from(response.data as Map);
  }
}
