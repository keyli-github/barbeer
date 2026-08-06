class Categoria {
  final String id;
  final String nombre;
  final String? descripcion;
  final bool activo;
  final int productosCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Categoria({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.activo,
    required this.productosCount,
    this.createdAt,
    this.updatedAt,
  });

  factory Categoria.fromJson(Map<String, dynamic> json) => Categoria(
    id: json['id'] as String? ?? '',
    nombre: json['nombre'] as String? ?? '',
    descripcion: json['descripcion'] as String?,
    activo: json['activo'] as bool? ?? false,
    productosCount: (json['productosCount'] as num?)?.toInt() ?? 0,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
  );
}

class CategoriasPage {
  final List<Categoria> data;
  final int total;
  final int pagina;
  final int limite;
  final int totalPaginas;

  const CategoriasPage({
    required this.data,
    required this.total,
    required this.pagina,
    required this.limite,
    required this.totalPaginas,
  });

  factory CategoriasPage.fromJson(Map<String, dynamic> json) => CategoriasPage(
    data: (json['data'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Categoria.fromJson(Map<String, dynamic>.from(item)))
        .toList(),
    total: (json['total'] as num?)?.toInt() ?? 0,
    pagina: (json['pagina'] as num?)?.toInt() ?? 1,
    limite: (json['limite'] as num?)?.toInt() ?? 25,
    totalPaginas: (json['totalPaginas'] as num?)?.toInt() ?? 0,
  );
}
