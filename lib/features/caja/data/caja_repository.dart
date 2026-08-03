import '../../../core/network/api_client.dart';

const cajaDenominaciones = <double>[
  200,
  100,
  50,
  20,
  10,
  5,
  2,
  1,
  0.2,
  0.1,
];

class CajaResumen {
  final double totalEntradas;
  final double totalSalidas;
  final double saldoEsperado;

  const CajaResumen({
    required this.totalEntradas,
    required this.totalSalidas,
    required this.saldoEsperado,
  });

  factory CajaResumen.fromJson(Map<String, dynamic> json) => CajaResumen(
        totalEntradas: (json['totalEntradas'] as num?)?.toDouble() ?? 0,
        totalSalidas: (json['totalSalidas'] as num?)?.toDouble() ?? 0,
        saldoEsperado: (json['saldoEsperado'] as num?)?.toDouble() ?? 0,
      );
}

class CajaSesion {
  final String id;
  final String estado;
  final String sedeId;
  final String sede;
  final double montoApertura;
  final DateTime abiertaAt;
  final DateTime? cerradaAt;
  final DateTime? precuadreAt;
  final double? montoDeclaradoPrecuadre;
  final double? diferenciaPrecuadre;
  final double? montoDeclaradoCierre;
  final double? diferenciaCierre;
  final String? observacionesCierre;
  final String usuarioApertura;
  final CajaResumen? resumen;
  final List<Map<String, dynamic>> denominaciones;

  const CajaSesion({
    required this.id,
    required this.estado,
    required this.sedeId,
    required this.sede,
    required this.montoApertura,
    required this.abiertaAt,
    required this.usuarioApertura,
    required this.denominaciones,
    this.cerradaAt,
    this.precuadreAt,
    this.montoDeclaradoPrecuadre,
    this.diferenciaPrecuadre,
    this.montoDeclaradoCierre,
    this.diferenciaCierre,
    this.observacionesCierre,
    this.resumen,
  });

  factory CajaSesion.fromJson(Map<String, dynamic> json) => CajaSesion(
        id: json['id'] as String? ?? '',
        estado: json['estado'] as String? ?? '',
        sedeId: json['sedeId'] as String? ?? '',
        sede: (json['sede'] as Map?)?['nombre'] as String? ?? '',
        montoApertura: (json['montoApertura'] as num?)?.toDouble() ?? 0,
        abiertaAt: DateTime.parse(json['abiertaAt'] as String),
        cerradaAt: _date(json['cerradaAt']),
        precuadreAt: _date(json['precuadreAt']),
        montoDeclaradoPrecuadre:
            (json['montoDeclaradoPrecuadre'] as num?)?.toDouble(),
        diferenciaPrecuadre:
            (json['diferenciaPrecuadre'] as num?)?.toDouble(),
        montoDeclaradoCierre:
            (json['montoDeclaradoCierre'] as num?)?.toDouble(),
        diferenciaCierre: (json['diferenciaCierre'] as num?)?.toDouble(),
        observacionesCierre: json['observacionesCierre'] as String?,
        usuarioApertura:
            (json['usuarioApertura'] as Map?)?['username'] as String? ?? '',
        resumen: json['resumen'] is Map
            ? CajaResumen.fromJson(
                Map<String, dynamic>.from(json['resumen'] as Map),
              )
            : null,
        denominaciones: (json['denominaciones'] as List? ?? const [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList(),
      );

  static DateTime? _date(dynamic value) =>
      value is String ? DateTime.tryParse(value) : null;
}

class CajaMovimiento {
  final String id;
  final String tipo;
  final String origen;
  final String medioPago;
  final String concepto;
  final double monto;
  final String? referencia;
  final String? comprobante;
  final String usuario;
  final DateTime createdAt;

  const CajaMovimiento({
    required this.id,
    required this.tipo,
    required this.origen,
    required this.medioPago,
    required this.concepto,
    required this.monto,
    required this.usuario,
    required this.createdAt,
    this.referencia,
    this.comprobante,
  });

  factory CajaMovimiento.fromJson(Map<String, dynamic> json) => CajaMovimiento(
        id: json['id'] as String? ?? '',
        tipo: json['tipo'] as String? ?? '',
        origen: json['origen'] as String? ?? '',
        medioPago: json['medioPago'] as String? ?? '',
        concepto: json['concepto'] as String? ?? '',
        monto: (json['monto'] as num?)?.toDouble() ?? 0,
        referencia: json['referencia'] as String?,
        comprobante: json['comprobante'] as String?,
        usuario: (json['usuario'] as Map?)?['username'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class CajaPage<T> {
  final List<T> data;
  final int total;
  final int pagina;
  final int totalPaginas;

  const CajaPage({
    required this.data,
    required this.total,
    required this.pagina,
    required this.totalPaginas,
  });
}

class CajaRepository {
  final ApiClient _api;

  const CajaRepository(this._api);

  Future<List<Map<String, dynamic>>> sedes() async {
    final response = await _api.get(
      '/establecimientos',
      queryParameters: {'pagina': 1, 'limite': 100},
    );
    final json = Map<String, dynamic>.from(response.data as Map);
    return (json['data'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .where((item) => item['activo'] != false)
        .toList();
  }

  Future<CajaSesion?> actual({String? sedeId}) async {
    final response = await _api.get(
      '/caja/actual',
      queryParameters: {if (sedeId != null) 'sedeId': sedeId},
    );
    if (response.data == null) return null;
    return CajaSesion.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<CajaPage<CajaSesion>> historial({
    int pagina = 1,
    String? estado,
    String? sedeId,
  }) async {
    final response = await _api.get(
      '/caja/historial',
      queryParameters: {
        'pagina': pagina,
        'limite': 10,
        if (estado != null) 'estado': estado,
        if (sedeId != null) 'sedeId': sedeId,
      },
    );
    final json = Map<String, dynamic>.from(response.data as Map);
    return CajaPage(
      data: (json['data'] as List? ?? const [])
          .map((item) => CajaSesion.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      pagina: (json['pagina'] as num?)?.toInt() ?? pagina,
      totalPaginas: (json['totalPaginas'] as num?)?.toInt() ?? 1,
    );
  }

  Future<CajaSesion> detalle(String id) async {
    final response = await _api.get('/caja/$id');
    return CajaSesion.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<CajaPage<CajaMovimiento>> movimientos(
    String id, {
    int pagina = 1,
    String? tipo,
  }) async {
    final response = await _api.get(
      '/caja/$id/movimientos',
      queryParameters: {
        'pagina': pagina,
        'limite': 10,
        if (tipo != null) 'tipo': tipo,
      },
    );
    final json = Map<String, dynamic>.from(response.data as Map);
    return CajaPage(
      data: (json['data'] as List? ?? const [])
          .map((item) => CajaMovimiento.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      pagina: (json['pagina'] as num?)?.toInt() ?? pagina,
      totalPaginas: (json['totalPaginas'] as num?)?.toInt() ?? 1,
    );
  }

  Future<void> abrir(Map<double, int> cantidades, {String? sedeId}) async {
    await _api.post(
      '/caja/apertura',
      data: {
        'denominaciones': cajaDenominaciones
            .map((value) => {
                  'denominacion': value,
                  'cantidad': cantidades[value] ?? 0,
                })
            .toList(),
        if (sedeId != null) 'sedeId': sedeId,
      },
    );
  }

  Future<void> registrarMovimiento(
    String id,
    Map<String, dynamic> data,
  ) async {
    await _api.post('/caja/$id/movimientos', data: data);
  }

  Future<void> precuadre(
    String id,
    double montoDeclarado, {
    String? observaciones,
  }) async {
    await _api.post(
      '/caja/$id/precuadre',
      data: {
        'montoDeclarado': montoDeclarado,
        if (observaciones?.trim().isNotEmpty ?? false)
          'observaciones': observaciones!.trim(),
      },
    );
  }

  Future<void> cerrar(
    String id,
    double montoDeclarado, {
    String? observaciones,
  }) async {
    await _api.post(
      '/caja/$id/cierre',
      data: {
        'montoDeclarado': montoDeclarado,
        if (observaciones?.trim().isNotEmpty ?? false)
          'observaciones': observaciones!.trim(),
      },
    );
  }
}
