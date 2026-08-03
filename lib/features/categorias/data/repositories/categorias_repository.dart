import '../../../../core/network/api_client.dart';
import '../models/categoria.dart';

class CategoriasRepository {
  final ApiClient _api;

  CategoriasRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  Future<CategoriasPage> list({
    int pagina = 1,
    int limite = 25,
    String? q,
    bool? activo,
  }) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/categorias',
      queryParameters: {
        'pagina': pagina,
        'limite': limite,
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        if (activo != null) 'activo': activo.toString(),
      },
    );
    return CategoriasPage.fromJson(response.data ?? const {});
  }

  Future<Categoria> detail(String id) async {
    final response = await _api.get<Map<String, dynamic>>('/categorias/$id');
    return Categoria.fromJson(response.data ?? const {});
  }

  Future<Categoria> create({
    required String nombre,
    String? descripcion,
    bool activo = true,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/categorias',
      data: {
        'nombre': nombre.trim(),
        if (descripcion != null) 'descripcion': descripcion.trim(),
        'activo': activo,
      },
    );
    return Categoria.fromJson(response.data ?? const {});
  }

  Future<Categoria> update(
    String id, {
    required String nombre,
    required String descripcion,
    required bool activo,
  }) async {
    final response = await _api.patch<Map<String, dynamic>>(
      '/categorias/$id',
      data: {
        'nombre': nombre.trim(),
        'descripcion': descripcion.trim(),
        'activo': activo,
      },
    );
    return Categoria.fromJson(response.data ?? const {});
  }

  Future<void> delete(String id) => _api.delete<void>('/categorias/$id');
}
