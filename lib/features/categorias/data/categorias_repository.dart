import '../../../core/network/api_client.dart';

class Categoria {
  final String id, nombre;
  final String? descripcion;
  final bool activo;
  final int productosCount;

  const Categoria({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.activo,
    this.productosCount = 0,
  });

  factory Categoria.fromJson(Map<String, dynamic> j) => Categoria(
    id: j['id'] as String? ?? '',
    nombre: j['nombre'] as String? ?? '',
    descripcion: j['descripcion'] as String?,
    activo: j['activo'] as bool? ?? true,
    productosCount: (j['productosCount'] as num?)?.toInt() ?? 0,
  );
}

class CategoriasPage {
  final List<Categoria> data;
  final int total, pagina, totalPaginas;
  const CategoriasPage({
    required this.data,
    required this.total,
    required this.pagina,
    required this.totalPaginas,
  });
}

class CategoriasRepository {
  final ApiClient _api;
  const CategoriasRepository(this._api);

  Future<CategoriasPage> list({
    int pagina = 1,
    int limite = 100,
    String? q,
    String? activo,
  }) async {
    final r = await _api.get(
      '/categorias',
      queryParameters: {
        'pagina': pagina,
        'limite': limite,
        if (q != null && q.isNotEmpty) 'q': q,
        if (activo != null) 'activo': activo,
      },
    );
    final json = Map<String, dynamic>.from(r.data as Map);
    return CategoriasPage(
      data: (json['data'] as List? ?? [])
          .map((e) => Categoria.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      pagina: (json['pagina'] as num?)?.toInt() ?? pagina,
      totalPaginas: (json['totalPaginas'] as num?)?.toInt() ?? 1,
    );
  }

  Future<Categoria> create(String nombre, {String? descripcion}) async {
    final r = await _api.post('/categorias', data: {
      'nombre': nombre,
      if (descripcion?.trim().isNotEmpty ?? false) 'descripcion': descripcion!.trim(),
    });
    return Categoria.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<Categoria> update(String id, {String? nombre, String? descripcion, bool? activo}) async {
    final r = await _api.patch('/categorias/$id', data: {
      if (nombre != null) 'nombre': nombre,
      if (descripcion != null) 'descripcion': descripcion,
      if (activo != null) 'activo': activo,
    });
    return Categoria.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<void> delete(String id) => _api.delete('/categorias/$id');
}
