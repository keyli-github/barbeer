import '../../../../core/network/api_client.dart';
import '../models/inventario.dart';

class InventarioRepository {
  final ApiClient _api;

  InventarioRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  Future<InventarioPage> list({
    int pagina = 1,
    int limite = 25,
    String? q,
    String? categoriaId,
    String? estado,
    String? sedeId,
  }) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/inventario',
      queryParameters: {
        'pagina': pagina,
        'limite': limite,
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        if (categoriaId != null && categoriaId.isNotEmpty)
          'categoriaId': categoriaId,
        if (estado != null && estado.isNotEmpty) 'estado': estado,
        if (sedeId != null && sedeId.isNotEmpty) 'sedeId': sedeId,
      },
    );
    return InventarioPage.fromJson(response.data ?? const {});
  }

  Future<InventarioResumen> summary({String? sedeId}) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/inventario/resumen',
      queryParameters: {
        if (sedeId != null && sedeId.isNotEmpty) 'sedeId': sedeId,
      },
    );
    return InventarioResumen.fromJson(response.data ?? const {});
  }

  Future<List<SedeOption>> sedes() async {
    final response = await _api.get<Map<String, dynamic>>(
      '/establecimientos',
      queryParameters: {'pagina': 1, 'limite': 100},
    );
    return (response.data?['data'] as List? ?? const [])
        .whereType<Map>()
        .where((item) => item['activo'] == true)
        .map((item) => SedeOption.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<ProductoOption>> productos() async {
    final response = await _api.get<Map<String, dynamic>>(
      '/productos',
      queryParameters: {'pagina': 1, 'limite': 100, 'activo': 'true'},
    );
    return (response.data?['data'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => ProductoOption.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<InventarioItem> upsert({
    required String productoId,
    String? sedeId,
    required double stockMin,
    required double stockMax,
    required String ubicacion,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/inventario',
      data: {
        'productoId': productoId,
        if (sedeId != null && sedeId.isNotEmpty) 'sedeId': sedeId,
        'stockMin': stockMin,
        'stockMax': stockMax,
        'ubicacion': ubicacion.trim(),
      },
    );
    return InventarioItem.fromJson(response.data ?? const {});
  }

  Future<InventarioItem> adjust({
    required String inventarioId,
    required String tipo,
    required double cantidad,
    required String referencia,
  }) async {
    final response = await _api.patch<Map<String, dynamic>>(
      '/inventario/$inventarioId/ajuste',
      data: {
        'tipo': tipo,
        'cantidad': cantidad,
        if (referencia.trim().isNotEmpty) 'referencia': referencia.trim(),
      },
    );
    return InventarioItem.fromJson(response.data ?? const {});
  }
}
