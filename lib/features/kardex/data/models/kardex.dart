class KardexMovimiento {
  final String id;
  final String fecha;
  final String hora;
  final String producto;
  final String codigo;
  final String tipo;
  final double cantidad;
  final String unidad;
  final double stockAnterior;
  final double stockNuevo;
  final double valor;
  final String referencia;
  final String usuario;
  final String? imagenUrl;
  final DateTime? updatedAt;

  const KardexMovimiento({
    required this.id,
    required this.fecha,
    required this.hora,
    required this.producto,
    required this.codigo,
    required this.tipo,
    required this.cantidad,
    required this.unidad,
    required this.stockAnterior,
    required this.stockNuevo,
    required this.valor,
    required this.referencia,
    required this.usuario,
    this.imagenUrl,
    this.updatedAt,
  });

  factory KardexMovimiento.fromJson(Map<String, dynamic> json) =>
      KardexMovimiento(
        id: json['id'] as String? ?? '',
        fecha: json['fecha'] as String? ?? '',
        hora: json['hora'] as String? ?? '',
        producto: json['producto'] as String? ?? '',
        codigo: json['codigo'] as String? ?? '',
        tipo: json['tipo'] as String? ?? '',
        cantidad: (json['cantidad'] as num?)?.toDouble() ?? 0,
        unidad: json['unidad'] as String? ?? '',
        stockAnterior: (json['stockAnterior'] as num?)?.toDouble() ?? 0,
        stockNuevo: (json['stockNuevo'] as num?)?.toDouble() ?? 0,
        valor: (json['valor'] as num?)?.toDouble() ?? 0,
        referencia: json['referencia'] as String? ?? '',
        usuario: json['usuario'] as String? ?? 'sistema',
        imagenUrl: json['imagenUrl'] as String?,
        updatedAt: json['updatedAt'] is String
            ? DateTime.tryParse(json['updatedAt'] as String)
            : null,
      );
}

class KardexResumen {
  final int totalMovimientos;
  final int entradas;
  final int salidas;
  final double valorTotal;

  const KardexResumen({
    this.totalMovimientos = 0,
    this.entradas = 0,
    this.salidas = 0,
    this.valorTotal = 0,
  });

  factory KardexResumen.fromJson(Map<String, dynamic> json) => KardexResumen(
    totalMovimientos: (json['totalMovimientos'] as num?)?.toInt() ?? 0,
    entradas: (json['entradas'] as num?)?.toInt() ?? 0,
    salidas: (json['salidas'] as num?)?.toInt() ?? 0,
    valorTotal: (json['valorTotal'] as num?)?.toDouble() ?? 0,
  );
}

class KardexPage {
  final List<KardexMovimiento> data;
  final int total;
  final int pagina;
  final int limite;
  final int totalPaginas;

  const KardexPage({
    required this.data,
    required this.total,
    required this.pagina,
    required this.limite,
    required this.totalPaginas,
  });

  factory KardexPage.fromJson(Map<String, dynamic> json) => KardexPage(
    data: (json['data'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => KardexMovimiento.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(),
    total: (json['total'] as num?)?.toInt() ?? 0,
    pagina: (json['pagina'] as num?)?.toInt() ?? 1,
    limite: (json['limite'] as num?)?.toInt() ?? 25,
    totalPaginas: (json['totalPaginas'] as num?)?.toInt() ?? 0,
  );
}

class KardexOption {
  final String id;
  final String nombre;
  final String? codigo;

  const KardexOption({required this.id, required this.nombre, this.codigo});
}
