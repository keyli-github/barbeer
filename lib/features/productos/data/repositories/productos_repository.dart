import '../../../../core/network/api_client.dart';
import '../models/producto.dart';

class ProductosRepository {
  final ApiClient _api;

  ProductosRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  Future<ProductosPage> list({
    int pagina = 1,
    int limite = 25,
    String? q,
    String? categoriaId,
    bool? activo,
    String? sedeId,
  }) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/productos',
      queryParameters: {
        'pagina': pagina,
        'limite': limite,
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        if (categoriaId != null && categoriaId.isNotEmpty)
          'categoriaId': categoriaId,
        if (activo case final activo?) 'activo': activo.toString(),
        'sedeId': ?sedeId,
      },
    );
    return ProductosPage.fromJson(response.data ?? const {});
  }

  Future<ProductosResumen> summary() async {
    final response = await _api.get<Map<String, dynamic>>('/productos/resumen');
    return ProductosResumen.fromJson(response.data ?? const {});
  }

  Future<Producto> detail(String id) async {
    final response = await _api.get<Map<String, dynamic>>('/productos/$id');
    return Producto.fromJson(response.data ?? const {});
  }

  Future<Producto> create(ProductoPayload payload) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/productos',
      data: payload.toCreateJson(),
    );
    return Producto.fromJson(response.data ?? const {});
  }

  Future<Producto> update(String id, ProductoPayload payload) async {
    final response = await _api.patch<Map<String, dynamic>>(
      '/productos/$id',
      data: payload.toUpdateJson(),
    );
    return Producto.fromJson(response.data ?? const {});
  }

  Future<void> delete(String id) => _api.delete<void>('/productos/$id');
}
