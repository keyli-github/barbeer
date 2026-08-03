import '../../../../core/network/api_client.dart';
import '../models/kardex.dart';

class KardexRepository {
  final ApiClient _api;

  KardexRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  Map<String, dynamic> _filters({
    String? q,
    String? tipo,
    String? productoId,
    String? desde,
    String? hasta,
    String? sedeId,
  }) =>
      {
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        if (tipo != null && tipo.isNotEmpty) 'tipo': tipo,
        if (productoId != null && productoId.isNotEmpty)
          'productoId': productoId,
        if (desde != null && desde.isNotEmpty) 'desde': desde,
        if (hasta != null && hasta.isNotEmpty) 'hasta': hasta,
        if (sedeId != null && sedeId.isNotEmpty) 'sedeId': sedeId,
      };

  Future<KardexPage> list({
    int pagina = 1,
    int limite = 25,
    String? q,
    String? tipo,
    String? productoId,
    String? desde,
    String? hasta,
    String? sedeId,
  }) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/kardex',
      queryParameters: {
        'pagina': pagina,
        'limite': limite,
        ..._filters(
          q: q,
          tipo: tipo,
          productoId: productoId,
          desde: desde,
          hasta: hasta,
          sedeId: sedeId,
        ),
      },
    );
    return KardexPage.fromJson(response.data ?? const {});
  }

  Future<KardexResumen> summary({
    String? q,
    String? tipo,
    String? productoId,
    String? desde,
    String? hasta,
    String? sedeId,
  }) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/kardex/resumen',
      queryParameters: _filters(
        q: q,
        tipo: tipo,
        productoId: productoId,
        desde: desde,
        hasta: hasta,
        sedeId: sedeId,
      ),
    );
    return KardexResumen.fromJson(response.data ?? const {});
  }

  Future<List<KardexOption>> sedes() async {
    final response = await _api.get<Map<String, dynamic>>(
      '/establecimientos',
      queryParameters: {'pagina': 1, 'limite': 100},
    );
    return (response.data?['data'] as List? ?? const [])
        .whereType<Map>()
        .where((item) => item['activo'] == true)
        .map(
          (item) => KardexOption(
            id: item['id'] as String? ?? '',
            nombre: item['nombre'] as String? ?? '',
          ),
        )
        .toList();
  }

  Future<List<KardexOption>> productos() async {
    final response = await _api.get<Map<String, dynamic>>(
      '/productos',
      queryParameters: {'pagina': 1, 'limite': 100},
    );
    return (response.data?['data'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => KardexOption(
            id: item['id'] as String? ?? '',
            nombre: item['nombre'] as String? ?? '',
            codigo: item['codigo'] as String?,
          ),
        )
        .toList();
  }
}
