import '../../../core/network/api_client.dart';
import '../../categorias/data/categorias_repository.dart';

class Producto {
  final String id, codigo, nombre, categoriaId, unidad;
  final String categoria;
  final String? descripcion, presentacion, imageUrl;
  final double precioVenta, precioCosto;
  final bool disponiblePos, activo;
  final double margin;
  final int? stockDisponible;

  const Producto({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.categoria,
    required this.categoriaId,
    required this.unidad,
    this.descripcion,
    this.presentacion,
    this.imageUrl,
    required this.precioVenta,
    required this.precioCosto,
    required this.disponiblePos,
    required this.activo,
    required this.margin,
    this.stockDisponible,
  });

  factory Producto.fromJson(Map<String, dynamic> j) => Producto(
    id: j['id'] as String? ?? '',
    codigo: j['codigo'] as String? ?? '',
    nombre: j['nombre'] as String? ?? '',
    // categoria puede llegar como String o como Map{nombre:...}
    categoria: j['categoria'] is Map
        ? ((j['categoria'] as Map)['nombre'] as String? ?? '')
        : j['categoria'] as String? ?? '',
    categoriaId: j['categoriaId'] as String? ?? '',
    unidad: j['unidad'] as String? ?? 'un',
    descripcion: j['descripcion'] as String?,
    presentacion: j['presentacion'] as String?,
    imageUrl: j['imageUrl'] as String?,
    precioVenta: (j['precioVenta'] as num?)?.toDouble() ?? 0,
    precioCosto: (j['precioCosto'] as num?)?.toDouble() ?? 0,
    disponiblePos: j['disponiblePos'] as bool? ?? false,
    activo: j['activo'] as bool? ?? true,
    margin: (j['margin'] as num?)?.toDouble() ?? 0,
    stockDisponible: (j['stockDisponible'] as num?)?.toInt(),
  );
}

class ProductosResumen {
  final int total, activos, enPos;
  final double valorCatalogo, margenPromedio;
  const ProductosResumen({
    required this.total,
    required this.activos,
    required this.enPos,
    required this.valorCatalogo,
    required this.margenPromedio,
  });
  factory ProductosResumen.fromJson(Map<String, dynamic> j) => ProductosResumen(
    total: (j['total'] as num?)?.toInt() ?? 0,
    activos: (j['activos'] as num?)?.toInt() ?? 0,
    enPos: (j['enPos'] as num?)?.toInt() ?? 0,
    valorCatalogo: (j['valorCatalogo'] as num?)?.toDouble() ?? 0,
    margenPromedio: (j['margenPromedio'] as num?)?.toDouble() ?? 0,
  );
}

class ProductosPage {
  final List<Producto> data;
  final int total, pagina, totalPaginas;
  const ProductosPage({
    required this.data,
    required this.total,
    required this.pagina,
    required this.totalPaginas,
  });
}

class ProductosRepository {
  final ApiClient _api;
  const ProductosRepository(this._api);

  Future<ProductosPage> list({
    int pagina = 1,
    int limite = 25,
    String? q,
    String? categoriaId,
    String? activo,
    String? sedeId,
  }) async {
    final r = await _api.get(
      '/productos',
      queryParameters: {
        'pagina': pagina,
        'limite': limite,
        if (q != null && q.isNotEmpty) 'q': q,
        if (categoriaId != null) 'categoriaId': categoriaId,
        if (activo != null) 'activo': activo,
        if (sedeId != null) 'sedeId': sedeId,
      },
    );
    final json = Map<String, dynamic>.from(r.data as Map);
    return ProductosPage(
      data: (json['data'] as List? ?? [])
          .map((e) => Producto.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      pagina: (json['pagina'] as num?)?.toInt() ?? pagina,
      totalPaginas: (json['totalPaginas'] as num?)?.toInt() ?? 1,
    );
  }

  Future<ProductosResumen> resumen() async {
    final r = await _api.get('/productos/resumen');
    return ProductosResumen.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<Producto> getById(String id) async {
    final r = await _api.get('/productos/$id');
    return Producto.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<Producto> create({
    required String codigo,
    required String nombre,
    required String categoriaId,
    required double precioVenta,
    required double precioCosto,
    String? descripcion,
    String? unidad,
    bool disponiblePos = false,
    bool activo = true,
  }) async {
    final r = await _api.post(
      '/productos',
      data: {
        'codigo': codigo,
        'nombre': nombre,
        'categoriaId': categoriaId,
        'precioVenta': precioVenta,
        'precioCosto': precioCosto,
        if (descripcion?.trim().isNotEmpty ?? false)
          'descripcion': descripcion!.trim(),
        if (unidad != null) 'unidad': unidad,
        'disponiblePos': disponiblePos,
        'activo': activo,
      },
    );
    return Producto.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<Producto> update(String id, Map<String, dynamic> data) async {
    final r = await _api.patch('/productos/$id', data: data);
    return Producto.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<void> delete(String id) => _api.delete('/productos/$id');

  Future<Producto> toggle(String id, bool activo) async {
    final r = await _api.patch('/productos/$id', data: {'activo': activo});
    return Producto.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<List<Categoria>> categorias({String? activo = 'true'}) async {
    final r = await _api.get(
      '/categorias',
      queryParameters: {
        'pagina': 1,
        'limite': 100,
        if (activo != null) 'activo': activo,
      },
    );
    final json = Map<String, dynamic>.from(r.data as Map);
    return (json['data'] as List? ?? [])
        .map((e) => Categoria.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
