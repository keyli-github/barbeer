import '../../../core/network/api_client.dart';

bool kardexIsEntrada(String tipo) =>
    tipo == 'ENTRADA' || tipo == 'ENTRADA_ANULACION';

bool kardexIsSalida(String tipo) => tipo == 'SALIDA' || tipo == 'SALIDA_VENTA';

String kardexTipoLabel(String tipo) => switch (tipo) {
  'SALIDA_VENTA' => 'VENTA',
  'ENTRADA_ANULACION' => 'ANULACIÓN',
  _ => tipo,
};

class KardexMovimiento {
  final String id,
      producto,
      codigo,
      tipo,
      unidad,
      referencia,
      usuario,
      fecha,
      hora;
  final double cantidad, stockAnterior, stockNuevo, valor;

  const KardexMovimiento({
    required this.id,
    required this.producto,
    required this.codigo,
    required this.tipo,
    required this.unidad,
    required this.referencia,
    required this.usuario,
    required this.fecha,
    required this.hora,
    required this.cantidad,
    required this.stockAnterior,
    required this.stockNuevo,
    required this.valor,
  });

  factory KardexMovimiento.fromJson(Map<String, dynamic> j) => KardexMovimiento(
    id: j['id'] as String? ?? '',
    producto: j['producto'] as String? ?? '',
    codigo: j['codigo'] as String? ?? '',
    tipo: j['tipo'] as String? ?? '',
    unidad: j['unidad'] as String? ?? 'un',
    referencia: j['referencia'] as String? ?? '',
    usuario: j['usuario'] as String? ?? '',
    fecha: j['fecha'] as String? ?? '',
    hora: j['hora'] as String? ?? '',
    cantidad: (j['cantidad'] as num?)?.toDouble() ?? 0,
    stockAnterior: (j['stockAnterior'] as num?)?.toDouble() ?? 0,
    stockNuevo: (j['stockNuevo'] as num?)?.toDouble() ?? 0,
    valor: (j['valor'] as num?)?.toDouble() ?? 0,
  );
}

class KardexResumen {
  final int totalMovimientos, entradas, salidas;
  final double valorTotal;
  const KardexResumen({
    required this.totalMovimientos,
    required this.entradas,
    required this.salidas,
    required this.valorTotal,
  });
  factory KardexResumen.fromJson(Map<String, dynamic> j) => KardexResumen(
    totalMovimientos: (j['totalMovimientos'] as num?)?.toInt() ?? 0,
    entradas: (j['entradas'] as num?)?.toInt() ?? 0,
    salidas: (j['salidas'] as num?)?.toInt() ?? 0,
    valorTotal: (j['valorTotal'] as num?)?.toDouble() ?? 0,
  );
}

class KardexPage {
  final List<KardexMovimiento> data;
  final int total, pagina, totalPaginas;
  const KardexPage({
    required this.data,
    required this.total,
    required this.pagina,
    required this.totalPaginas,
  });
}

class KardexRepository {
  final ApiClient _api;
  const KardexRepository(this._api);

  Future<KardexPage> list({
    int pagina = 1,
    int limite = 25,
    String? q,
    String? tipo,
    String? productoId,
    String? desde,
    String? hasta,
    String? sedeId,
  }) async {
    final r = await _api.get(
      '/kardex',
      queryParameters: {
        'pagina': pagina,
        'limite': limite,
        if (q != null && q.isNotEmpty) 'q': q,
        if (tipo != null) 'tipo': tipo,
        if (productoId != null) 'productoId': productoId,
        if (desde != null) 'desde': desde,
        if (hasta != null) 'hasta': hasta,
        if (sedeId != null) 'sedeId': sedeId,
      },
    );
    final json = Map<String, dynamic>.from(r.data as Map);
    return KardexPage(
      data: (json['data'] as List? ?? [])
          .map(
            (e) =>
                KardexMovimiento.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      pagina: (json['pagina'] as num?)?.toInt() ?? pagina,
      totalPaginas: (json['totalPaginas'] as num?)?.toInt() ?? 1,
    );
  }

  Future<KardexResumen> resumen({
    String? tipo,
    String? productoId,
    String? desde,
    String? hasta,
    String? sedeId,
  }) async {
    final r = await _api.get(
      '/kardex/resumen',
      queryParameters: {
        if (tipo != null) 'tipo': tipo,
        if (productoId != null) 'productoId': productoId,
        if (desde != null) 'desde': desde,
        if (hasta != null) 'hasta': hasta,
        if (sedeId != null) 'sedeId': sedeId,
      },
    );
    return KardexResumen.fromJson(Map<String, dynamic>.from(r.data as Map));
  }
}
