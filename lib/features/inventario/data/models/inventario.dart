class InventarioItem {
  final String id;
  final String productoId;
  final String sedeId;
  final String codigo;
  final String producto;
  final String categoria;
  final String unidad;
  final double stock;
  final double min;
  final double max;
  final double costo;
  final String ubicacion;
  final String estado;
  final DateTime? updatedAt;

  const InventarioItem({
    required this.id,
    required this.productoId,
    required this.sedeId,
    required this.codigo,
    required this.producto,
    required this.categoria,
    required this.unidad,
    required this.stock,
    required this.min,
    required this.max,
    required this.costo,
    required this.ubicacion,
    required this.estado,
    this.updatedAt,
  });

  factory InventarioItem.fromJson(Map<String, dynamic> json) => InventarioItem(
    id: json['id'] as String? ?? '',
    productoId: json['productoId'] as String? ?? '',
    sedeId: json['sedeId'] as String? ?? '',
    codigo: json['codigo'] as String? ?? '',
    producto: json['producto'] as String? ?? '',
    categoria: json['categoria'] as String? ?? '',
    unidad: json['unidad'] as String? ?? '',
    stock: (json['stock'] as num?)?.toDouble() ?? 0,
    min: (json['min'] as num?)?.toDouble() ?? 0,
    max: (json['max'] as num?)?.toDouble() ?? 0,
    costo: (json['costo'] as num?)?.toDouble() ?? 0,
    ubicacion: json['ubicacion'] as String? ?? '',
    estado: json['estado'] as String? ?? 'OK',
    updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
  );
}

class InventarioResumen {
  final int totalItems;
  final int ok;
  final int alerta;
  final int critico;
  final double valorTotal;

  const InventarioResumen({
    this.totalItems = 0,
    this.ok = 0,
    this.alerta = 0,
    this.critico = 0,
    this.valorTotal = 0,
  });

  factory InventarioResumen.fromJson(Map<String, dynamic> json) =>
      InventarioResumen(
        totalItems: (json['totalItems'] as num?)?.toInt() ?? 0,
        ok: (json['ok'] as num?)?.toInt() ?? 0,
        alerta: (json['alerta'] as num?)?.toInt() ?? 0,
        critico: (json['critico'] as num?)?.toInt() ?? 0,
        valorTotal: (json['valorTotal'] as num?)?.toDouble() ?? 0,
      );
}

class InventarioPage {
  final List<InventarioItem> data;
  final int total;
  final int pagina;
  final int limite;
  final int totalPaginas;

  const InventarioPage({
    required this.data,
    required this.total,
    required this.pagina,
    required this.limite,
    required this.totalPaginas,
  });

  factory InventarioPage.fromJson(Map<String, dynamic> json) => InventarioPage(
    data: (json['data'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => InventarioItem.fromJson(Map<String, dynamic>.from(item)))
        .toList(),
    total: (json['total'] as num?)?.toInt() ?? 0,
    pagina: (json['pagina'] as num?)?.toInt() ?? 1,
    limite: (json['limite'] as num?)?.toInt() ?? 25,
    totalPaginas: (json['totalPaginas'] as num?)?.toInt() ?? 0,
  );
}

class SedeOption {
  final String id;
  final String nombre;

  const SedeOption({required this.id, required this.nombre});

  factory SedeOption.fromJson(Map<String, dynamic> json) => SedeOption(
    id: json['id'] as String? ?? '',
    nombre: json['nombre'] as String? ?? '',
  );
}

class ProductoOption {
  final String id;
  final String codigo;
  final String nombre;
  final String unidad;

  const ProductoOption({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.unidad,
  });

  factory ProductoOption.fromJson(Map<String, dynamic> json) => ProductoOption(
    id: json['id'] as String? ?? '',
    codigo: json['codigo'] as String? ?? '',
    nombre: json['nombre'] as String? ?? '',
    unidad: json['unidad'] as String? ?? 'unidad',
  );
}
