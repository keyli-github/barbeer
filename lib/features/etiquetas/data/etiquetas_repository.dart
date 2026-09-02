import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'models/etiqueta.dart';

class EtiquetasRepository {
  const EtiquetasRepository(this._api);

  final ApiClient _api;

  Future<List<Etiqueta>> list({String? sedeId}) async {
    final response = await _api.get(
      ApiConstants.etiquetas,
      queryParameters: {
        'pagina': 1,
        'limite': 50,
        if (sedeId != null) 'sedeId': sedeId,
      },
    );
    final json = Map<String, dynamic>.from(response.data as Map);
    final etiquetas = (json['data'] as List? ?? const [])
        .map(
          (item) => Etiqueta.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    etiquetas.sort(
      (a, b) => a.orden.compareTo(b.orden) != 0
          ? a.orden.compareTo(b.orden)
          : a.nombre.compareTo(b.nombre),
    );
    return etiquetas;
  }

  Future<Etiqueta> create({
    required String nombre,
    required bool requiereComprobante,
  }) async {
    final response = await _api.post(
      ApiConstants.etiquetas,
      data: {
        'nombre': nombre.trim(),
        'requiereComprobante': requiereComprobante,
      },
    );
    return Etiqueta.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<Etiqueta> update(
    String id, {
    required String nombre,
    required bool requiereComprobante,
  }) async {
    final response = await _api.patch(
      ApiConstants.etiqueta(id),
      data: {
        'nombre': nombre.trim(),
        'requiereComprobante': requiereComprobante,
      },
    );
    return Etiqueta.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<Etiqueta> updateActivo(String id, {required bool activo}) async {
    final response = await _api.patch(
      ApiConstants.etiquetaEstado(id),
      data: {'activo': activo},
    );
    return Etiqueta.fromJson(Map<String, dynamic>.from(response.data as Map));
  }
}
