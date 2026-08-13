class Producto {
  final String id;
  final String codigo;
  final String nombre;
  final String? descripcion;
  final String? presentacion;
  final String categoriaId;
  final String categoria;
  final String unidad;
  final double precioVenta;
  final double precioCosto;
  final bool disponiblePos;
  final bool activo;
  final double margin;
  final int? stockDisponible;
  final String? imagenUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Producto({
    required this.id,
    required this.codigo,
    required this.nombre,
    this.descripcion,
    this.presentacion,
    required this.categoriaId,
    required this.categoria,
    required this.unidad,
    required this.precioVenta,
    required this.precioCosto,
    required this.disponiblePos,
    required this.activo,
    required this.margin,
    this.stockDisponible,
    this.imagenUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory Producto.fromJson(Map<String, dynamic> json) => Producto(
    id: json['id'] as String? ?? '',
    codigo: json['codigo'] as String? ?? '',
    nombre: json['nombre'] as String? ?? '',
    descripcion: json['descripcion'] as String?,
    presentacion: json['presentacion'] as String?,
    categoriaId: json['categoriaId'] as String? ?? '',
    categoria: json['categoria'] is Map
        ? ((json['categoria'] as Map)['nombre'] as String? ?? '')
        : json['categoria'] as String? ?? '',
    unidad: json['unidad'] as String? ?? 'unidad',
    precioVenta: (json['precioVenta'] as num?)?.toDouble() ?? 0,
    precioCosto: (json['precioCosto'] as num?)?.toDouble() ?? 0,
    disponiblePos: json['disponiblePos'] as bool? ?? false,
    activo: json['activo'] as bool? ?? false,
    margin: (json['margin'] as num?)?.toDouble() ?? 0,
    stockDisponible: (json['stockDisponible'] as num?)?.toInt(),
    imagenUrl: json['imagenUrl'] as String?,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
  );

  String? get imageUrl => imagenUrl;
}

class ProductosResumen {
  final int total;
  final int activos;
  final int enPos;
  final double valorCatalogo;
  final double margenPromedio;

  const ProductosResumen({
    this.total = 0,
    this.activos = 0,
    this.enPos = 0,
    this.valorCatalogo = 0,
    this.margenPromedio = 0,
  });

  factory ProductosResumen.fromJson(Map<String, dynamic> json) =>
      ProductosResumen(
        total: (json['total'] as num?)?.toInt() ?? 0,
        activos: (json['activos'] as num?)?.toInt() ?? 0,
        enPos: (json['enPos'] as num?)?.toInt() ?? 0,
        valorCatalogo: (json['valorCatalogo'] as num?)?.toDouble() ?? 0,
        margenPromedio: (json['margenPromedio'] as num?)?.toDouble() ?? 0,
      );
}

class ProductosPage {
  final List<Producto> data;
  final int total;
  final int pagina;
  final int limite;
  final int totalPaginas;

  const ProductosPage({
    required this.data,
    required this.total,
    required this.pagina,
    required this.limite,
    required this.totalPaginas,
  });

  factory ProductosPage.fromJson(Map<String, dynamic> json) => ProductosPage(
    data: (json['data'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Producto.fromJson(Map<String, dynamic>.from(item)))
        .toList(),
    total: (json['total'] as num?)?.toInt() ?? 0,
    pagina: (json['pagina'] as num?)?.toInt() ?? 1,
    limite: (json['limite'] as num?)?.toInt() ?? 25,
    totalPaginas: (json['totalPaginas'] as num?)?.toInt() ?? 0,
  );
}

class ProductoPayload {
  final String codigo;
  final String nombre;
  final String descripcion;
  final String categoriaId;
  final String unidad;
  final double precioVenta;
  final double precioCosto;
  final bool disponiblePos;
  final bool activo;
  final String? imagenUrl;

  const ProductoPayload({
    required this.codigo,
    required this.nombre,
    required this.descripcion,
    required this.categoriaId,
    required this.unidad,
    required this.precioVenta,
    required this.precioCosto,
    required this.disponiblePos,
    required this.activo,
    this.imagenUrl,
  });

  Map<String, dynamic> toCreateJson() => {
    'codigo': codigo.trim(),
    'nombre': nombre.trim(),
    'descripcion': descripcion.trim(),
    'categoriaId': categoriaId,
    'unidad': unidad.trim(),
    'precioVenta': precioVenta,
    'precioCosto': precioCosto,
    'disponiblePos': disponiblePos,
    'activo': activo,
    if (imagenUrl case final imagenUrl?) 'imagenUrl': imagenUrl.trim(),
  };

  Map<String, dynamic> toUpdateJson() {
    final json = toCreateJson();
    json.remove('codigo');
    return json;
  }
}
