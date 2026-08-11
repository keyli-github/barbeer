import '../../../core/network/api_client.dart';

class InventarioItem {
  final String id,
      productoId,
      sedeId,
      codigo,
      producto,
      categoria,
      unidad,
      ubicacion,
      estado;
  final double stock, min, max, costo;
  final String updatedAt;

  const InventarioItem({
    required this.id,
    required this.productoId,
    required this.sedeId,
    required this.codigo,
    required this.producto,
    required this.categoria,
    required this.unidad,
    required this.ubicacion,
    required this.estado,
    required this.stock,
    required this.min,
    required this.max,
    required this.costo,
    required this.updatedAt,
  });

  factory InventarioItem.fromJson(Map<String, dynamic> j) => InventarioItem(
    id: j['id'] as String? ?? '',
    productoId: j['productoId'] as String? ?? '',
    sedeId: j['sedeId'] as String? ?? '',
    codigo: j['codigo'] as String? ?? '',
    producto: j['producto'] as String? ?? '',
    categoria: j['categoria'] as String? ?? '',
    unidad: j['unidad'] as String? ?? 'un',
    ubicacion: j['ubicacion'] as String? ?? '',
    estado: j['estado'] as String? ?? 'OK',
    stock: (j['stock'] as num?)?.toDouble() ?? 0,
    min: (j['min'] as num?)?.toDouble() ?? 0,
    max: (j['max'] as num?)?.toDouble() ?? 0,
    costo: (j['costo'] as num?)?.toDouble() ?? 0,
    updatedAt: j['updatedAt'] as String? ?? '',
  );
}

class InventarioResumen {
  final int totalItems, ok, alerta, critico;
  final double valorTotal;
  const InventarioResumen({
    required this.totalItems,
    required this.ok,
    required this.alerta,
    required this.critico,
    required this.valorTotal,
  });
  factory InventarioResumen.fromJson(Map<String, dynamic> j) =>
      InventarioResumen(
        totalItems: (j['totalItems'] as num?)?.toInt() ?? 0,
        ok: (j['ok'] as num?)?.toInt() ?? 0,
        alerta: (j['alerta'] as num?)?.toInt() ?? 0,
        critico: (j['critico'] as num?)?.toInt() ?? 0,
        valorTotal: (j['valorTotal'] as num?)?.toDouble() ?? 0,
      );
}

class InventarioPage {
  final List<InventarioItem> data;
  final int total, pagina, totalPaginas;
  const InventarioPage({
    required this.data,
    required this.total,
    required this.pagina,
    required this.totalPaginas,
  });
}

class InventarioRepository {
  final ApiClient _api;
  const InventarioRepository(this._api);

  Future<InventarioPage> list({
    int pagina = 1,
    int limite = 25,
    String? q,
    String? categoriaId,
    String? estado,
    String? sedeId,
    String? productoId,
  }) async {
    final r = await _api.get(
      '/inventario',
      queryParameters: {
        'pagina': pagina,
        'limite': limite,
        if (q != null && q.isNotEmpty) 'q': q,
        if (categoriaId != null) 'categoriaId': categoriaId,
        if (estado != null) 'estado': estado,
        if (sedeId != null) 'sedeId': sedeId,
        if (productoId != null) 'productoId': productoId,
      },
    );
    final json = Map<String, dynamic>.from(r.data as Map);
    return InventarioPage(
      data: (json['data'] as List? ?? [])
          .map(
            (e) => InventarioItem.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      pagina: (json['pagina'] as num?)?.toInt() ?? pagina,
      totalPaginas: (json['totalPaginas'] as num?)?.toInt() ?? 1,
    );
  }

  Future<InventarioResumen> resumen({String? sedeId}) async {
    final r = await _api.get(
      '/inventario/resumen',
      queryParameters: {if (sedeId != null) 'sedeId': sedeId},
    );
    return InventarioResumen.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<InventarioItem> upsert({
    required String productoId,
    String? sedeId,
    double? stockMin,
    double? stockMax,
    String? ubicacion,
  }) async {
    final r = await _api.post(
      '/inventario',
      data: {
        'productoId': productoId,
        if (sedeId != null) 'sedeId': sedeId,
        if (stockMin != null) 'stockMin': stockMin,
        if (stockMax != null) 'stockMax': stockMax,
        if (ubicacion != null) 'ubicacion': ubicacion,
      },
    );
    return InventarioItem.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<InventarioItem> ajustar(
    String id, {
    required String tipo,
    required double cantidad,
    String? referencia,
  }) async {
    final r = await _api.patch(
      '/inventario/$id/ajuste',
      data: {
        'tipo': tipo,
        'cantidad': cantidad,
        if (referencia?.trim().isNotEmpty ?? false)
          'referencia': referencia!.trim(),
      },
    );
    return InventarioItem.fromJson(Map<String, dynamic>.from(r.data as Map));
  }
}
