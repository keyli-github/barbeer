import '../../../core/network/api_client.dart';

const cajaDenominaciones = <double>[200, 100, 50, 20, 10, 5, 2, 1, 0.2, 0.1];

// ── Resumen V2 ──────────────────────────────────────────────────────────────

class CajaResumenV2 {
  final double totalVentasBruto;
  final double totalAnulaciones;
  final double totalVentasNeto;
  final double totalDigitalBruto;
  final double totalReversDigital;
  final double totalDigitalNeto;
  final double efectivoEsperado;
  final int ventasPendientes;
  final int cantidadVentas;
  final int cantidadAnuladas;
  final List<Map<String, dynamic>> porVendedora;
  final List<Map<String, dynamic>> resumenProductos;
  final List<Map<String, dynamic>> porBilletera;

  const CajaResumenV2({
    required this.totalVentasBruto,
    required this.totalAnulaciones,
    required this.totalVentasNeto,
    required this.totalDigitalBruto,
    required this.totalReversDigital,
    required this.totalDigitalNeto,
    required this.efectivoEsperado,
    required this.ventasPendientes,
    required this.cantidadVentas,
    required this.cantidadAnuladas,
    this.porVendedora = const [],
    this.resumenProductos = const [],
    this.porBilletera = const [],
  });

  factory CajaResumenV2.fromJson(Map<String, dynamic> json) => CajaResumenV2(
    totalVentasBruto: (json['totalVentasBruto'] as num?)?.toDouble() ?? 0,
    totalAnulaciones: (json['totalAnulaciones'] as num?)?.toDouble() ?? 0,
    totalVentasNeto: (json['totalVentasNeto'] as num?)?.toDouble() ?? 0,
    totalDigitalBruto: (json['totalDigitalBruto'] as num?)?.toDouble() ?? 0,
    totalReversDigital: (json['totalReversDigital'] as num?)?.toDouble() ?? 0,
    totalDigitalNeto: (json['totalDigitalNeto'] as num?)?.toDouble() ?? 0,
    efectivoEsperado: (json['efectivoEsperado'] as num?)?.toDouble() ?? 0,
    ventasPendientes: (json['ventasPendientes'] as num?)?.toInt() ?? 0,
    cantidadVentas: (json['cantidadVentas'] as num?)?.toInt() ?? 0,
    cantidadAnuladas: (json['cantidadAnuladas'] as num?)?.toInt() ?? 0,
    porVendedora: (json['porVendedora'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(),
    resumenProductos: (json['resumenProductos'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(),
    porBilletera: (json['porBilletera'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(),
  );
}

/// Resumen V1 legacy (solo lectura histórica).
class CajaResumenV1 {
  final double totalEntradas;
  final double totalSalidas;
  final double saldoEsperado;

  const CajaResumenV1({
    required this.totalEntradas,
    required this.totalSalidas,
    required this.saldoEsperado,
  });

  factory CajaResumenV1.fromJson(Map<String, dynamic> json) => CajaResumenV1(
    totalEntradas: (json['totalEntradas'] as num?)?.toDouble() ?? 0,
    totalSalidas: (json['totalSalidas'] as num?)?.toDouble() ?? 0,
    saldoEsperado: (json['saldoEsperado'] as num?)?.toDouble() ?? 0,
  );
}

/// Resumen parseable de la sesión. El campo `version` determina el tipo.
class CajaResumen {
  final String version; // 'V1' | 'V2'
  final CajaResumenV2? v2;
  final CajaResumenV1? v1;

  const CajaResumen({required this.version, this.v2, this.v1});

  factory CajaResumen.fromJson(Map<String, dynamic> json) {
    final ver = json['version'] as String? ?? 'V1';
    if (ver == 'V2') {
      return CajaResumen(version: 'V2', v2: CajaResumenV2.fromJson(json));
    }
    return CajaResumen(version: 'V1', v1: CajaResumenV1.fromJson(json));
  }

  bool get isV2 => version == 'V2';

  /// Efectivo esperado independiente de la versión.
  double get efectivoEsperado =>
      isV2 ? (v2?.efectivoEsperado ?? 0) : (v1?.saldoEsperado ?? 0);

  int get ventasPendientes => v2?.ventasPendientes ?? 0;
}

// ── Sesión de Caja ──────────────────────────────────────────────────────────

class CajaSesion {
  final String id;
  final String estado;
  final String version; // 'V1' | 'V2'
  final bool cierreForzado;
  final String? motivoCierreForzado;
  final String sedeId;
  final String sede;
  final double montoApertura;
  final DateTime abiertaAt;
  final DateTime? cerradaAt;
  final DateTime? precuadreAt;
  final double? montoDeclaradoPrecuadre;
  final double? saldoEsperadoPrecuadre;
  final double? diferenciaPrecuadre;
  final double? montoDeclaradoCierre;
  final double? saldoEsperadoCierre;
  final double? diferenciaCierre;
  final String? observacionesCierre;
  final String usuarioApertura;
  final CajaResumen? resumen;
  final List<Map<String, dynamic>> denominaciones;

  const CajaSesion({
    required this.id,
    required this.estado,
    required this.version,
    required this.cierreForzado,
    this.motivoCierreForzado,
    required this.sedeId,
    required this.sede,
    required this.montoApertura,
    required this.abiertaAt,
    required this.usuarioApertura,
    required this.denominaciones,
    this.cerradaAt,
    this.precuadreAt,
    this.montoDeclaradoPrecuadre,
    this.saldoEsperadoPrecuadre,
    this.diferenciaPrecuadre,
    this.montoDeclaradoCierre,
    this.saldoEsperadoCierre,
    this.diferenciaCierre,
    this.observacionesCierre,
    this.resumen,
  });

  factory CajaSesion.fromJson(Map<String, dynamic> json) => CajaSesion(
    id: json['id'] as String? ?? '',
    estado: json['estado'] as String? ?? '',
    version: json['version'] as String? ?? 'V1',
    cierreForzado: json['cierreForzado'] as bool? ?? false,
    motivoCierreForzado: json['motivoCierreForzado'] as String?,
    sedeId: json['sedeId'] as String? ?? '',
    sede: json['sede'] is Map
        ? (json['sede'] as Map)['nombre'] as String? ?? ''
        : json['sede'] as String? ?? '',
    montoApertura: (json['montoApertura'] as num?)?.toDouble() ?? 0,
    // abiertaAt puede ser null en sesiones muy antiguas — fallback a epoch
    abiertaAt: json['abiertaAt'] is String
        ? DateTime.tryParse(json['abiertaAt'] as String) ?? DateTime(2020)
        : DateTime(2020),
    cerradaAt: _date(json['cerradaAt']),
    precuadreAt: _date(json['precuadreAt']),
    montoDeclaradoPrecuadre: (json['montoDeclaradoPrecuadre'] as num?)
        ?.toDouble(),
    saldoEsperadoPrecuadre: (json['saldoEsperadoPrecuadre'] as num?)
        ?.toDouble(),
    diferenciaPrecuadre: (json['diferenciaPrecuadre'] as num?)?.toDouble(),
    montoDeclaradoCierre: (json['montoDeclaradoCierre'] as num?)?.toDouble(),
    saldoEsperadoCierre: (json['saldoEsperadoCierre'] as num?)?.toDouble(),
    diferenciaCierre: (json['diferenciaCierre'] as num?)?.toDouble(),
    observacionesCierre: json['observacionesCierre'] as String?,
    usuarioApertura: json['usuarioApertura'] is Map
        ? (json['usuarioApertura'] as Map)['username'] as String? ?? ''
        : json['usuarioApertura'] as String? ?? '',
    resumen: json['resumen'] is Map
        ? CajaResumen.fromJson(
            Map<String, dynamic>.from(json['resumen'] as Map),
          )
        : json['resumen'] is String
        ? null // string inesperado → ignorar
        : null,
    denominaciones: (json['denominaciones'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(),
  );

  static DateTime? _date(dynamic value) =>
      value is String ? DateTime.tryParse(value) : null;

  bool get isV2 => version == 'V2';
  bool get isAbierta => estado == 'ABIERTA';
  bool get isCerrada => estado == 'CERRADA';
}

// ── Movimiento de Caja ──────────────────────────────────────────────────────

class CajaMovimiento {
  final String id;
  final String tipo;
  final String origen;
  final String? medioPago; // null en V2
  final String concepto;
  final double monto;
  final String? ventaId;
  final String? referencia;
  final String? comprobante;
  final String usuario;
  final DateTime createdAt;

  const CajaMovimiento({
    required this.id,
    required this.tipo,
    required this.origen,
    this.medioPago,
    required this.concepto,
    required this.monto,
    this.ventaId,
    required this.usuario,
    required this.createdAt,
    this.referencia,
    this.comprobante,
  });

  factory CajaMovimiento.fromJson(Map<String, dynamic> json) => CajaMovimiento(
    id: json['id'] as String? ?? '',
    tipo: json['tipo'] as String? ?? '',
    origen: json['origen'] as String? ?? '',
    medioPago: json['medioPago'] as String?,
    concepto: json['concepto'] as String? ?? '',
    monto: (json['monto'] as num?)?.toDouble() ?? 0,
    ventaId: json['ventaId'] as String?,
    referencia: json['referencia'] as String?,
    comprobante: json['comprobante'] as String?,
    usuario: json['usuario'] is Map
        ? (json['usuario'] as Map)['username'] as String? ?? ''
        : json['usuario'] as String? ?? '',
    createdAt: json['createdAt'] is String
        ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime(2020)
        : DateTime(2020),
  );
}

// ── Paginación ──────────────────────────────────────────────────────────────

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

// ── Repositorio ─────────────────────────────────────────────────────────────

class CajaRepository {
  final ApiClient _api;
  const CajaRepository(this._api);

  /// Convierte response.data a Map de forma segura.
  /// Si el backend devuelve String (error HTML/texto), retorna mapa vacío.
  static Map<String, dynamic> _toMap(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Future<List<Map<String, dynamic>>> sedes() async {
    final response = await _api.get(
      '/establecimientos',
      queryParameters: {'pagina': 1, 'limite': 100},
    );
    final json = _toMap(response.data);
    return (json['data'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) => item['activo'] != false)
        .toList();
  }

  Future<CajaSesion?> actual({String? sedeId}) async {
    final response = await _api.get(
      '/caja/actual',
      queryParameters: {'sedeId': ?sedeId},
    );
    if (response.data == null || response.data is! Map) return null;
    return CajaSesion.fromJson(_toMap(response.data));
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
        'estado': ?estado,
        'sedeId': ?sedeId,
      },
    );
    final json = CajaRepository._toMap(response.data);
    return CajaPage(
      data: (json['data'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => CajaSesion.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      pagina: (json['pagina'] as num?)?.toInt() ?? pagina,
      totalPaginas: (json['totalPaginas'] as num?)?.toInt() ?? 1,
    );
  }

  Future<CajaSesion> detalle(String id) async {
    final response = await _api.get('/caja/$id');
    return CajaSesion.fromJson(CajaRepository._toMap(response.data));
  }

  Future<CajaPage<CajaMovimiento>> movimientos(
    String id, {
    int pagina = 1,
    String? tipo,
  }) async {
    final response = await _api.get(
      '/caja/$id/movimientos',
      queryParameters: {'pagina': pagina, 'limite': 10, 'tipo': ?tipo},
    );
    final json = CajaRepository._toMap(response.data);
    return CajaPage(
      data: (json['data'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => CajaMovimiento.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      pagina: (json['pagina'] as num?)?.toInt() ?? pagina,
      totalPaginas: (json['totalPaginas'] as num?)?.toInt() ?? 1,
    );
  }

  /// Abre una nueva caja. Siempre crea sesión V2 en el backend.
  Future<CajaSesion> abrir(
    Map<double, int> cantidades, {
    String? sedeId,
  }) async {
    final response = await _api.post(
      '/caja/apertura',
      data: {
        'denominaciones': cajaDenominaciones
            .map(
              (value) => {
                'denominacion': value,
                'cantidad': cantidades[value] ?? 0,
              },
            )
            .toList(),
        'sedeId': ?sedeId,
      },
    );
    return CajaSesion.fromJson(CajaRepository._toMap(response.data));
  }

  /// @deprecated Bloqueado por regla de negocio en V2. Retorna 403/422.
  Future<void> registrarMovimiento(String id, Map<String, dynamic> data) async {
    await _api.post('/caja/$id/movimientos', data: data);
  }

  /// Registra precuadre con el monto declarado.
  Future<CajaSesion> precuadre(String id, double montoDeclarado) async {
    final response = await _api.post(
      '/caja/$id/precuadre',
      data: {'montoDeclarado': montoDeclarado},
    );
    return CajaSesion.fromJson(CajaRepository._toMap(response.data));
  }

  /// Cierre normal (sin ventas pendientes).
  /// Para cierre forzado usar [cerrarForzado].
  Future<CajaSesion> cerrar(
    String id,
    double montoDeclarado, {
    String? observaciones,
  }) async {
    final response = await _api.post(
      '/caja/$id/cierre',
      data: {
        'montoDeclarado': montoDeclarado,
        if (observaciones?.trim().isNotEmpty ?? false)
          'observaciones': observaciones!.trim(),
      },
    );
    return CajaSesion.fromJson(CajaRepository._toMap(response.data));
  }

  /// Cierre forzado con ventas pendientes (ADMIN/SUPERADMIN).
  /// Requiere permiso caja:forzar-cierre.
  Future<CajaSesion> cerrarForzado(
    String id,
    double montoDeclarado, {
    required String motivoForzado,
    String? observaciones,
  }) async {
    final response = await _api.post(
      '/caja/$id/cierre',
      data: {
        'montoDeclarado': montoDeclarado,
        'forzarPendientes': true,
        'motivoForzado': motivoForzado.trim(),
        if (observaciones?.trim().isNotEmpty ?? false)
          'observaciones': observaciones!.trim(),
      },
    );
    return CajaSesion.fromJson(CajaRepository._toMap(response.data));
  }
}
