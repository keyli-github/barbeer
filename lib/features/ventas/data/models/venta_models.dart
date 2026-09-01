// Modelos de datos para el módulo de Ventas y Conciliación.
// Espejo de los DTOs del backend NestJS.

// ─── Etiqueta (billetera digital) ──────────────────────────────────────────

class Etiqueta {
  final String id;
  final String nombre;
  final bool activo;
  final String? sedeId;
  final bool requiereComprobante;
  final bool esSistema;
  final String tipo;
  final int orden;

  /// Backend `personalTipo` — when non-null, staff selection is required.
  final String? personalTipo;

  const Etiqueta({
    required this.id,
    required this.nombre,
    required this.activo,
    this.sedeId,
    required this.requiereComprobante,
    this.esSistema = false,
    this.tipo = 'ENTRADA',
    required this.orden,
    this.personalTipo,
  });

  factory Etiqueta.fromJson(Map<String, dynamic> j) => Etiqueta(
    id: j['id'] as String? ?? '',
    nombre: j['nombre'] as String? ?? '',
    activo: j['activo'] as bool? ?? true,
    sedeId: j['sedeId'] as String?,
    requiereComprobante: j['requiereComprobante'] as bool? ?? true,
    esSistema: j['esSistema'] as bool? ?? false,
    tipo: j['tipo'] as String? ?? 'ENTRADA',
    orden: (j['orden'] as num?)?.toInt() ?? 0,
    personalTipo: j['personalTipo'] as String?,
  );
}

bool isBilleteraEtiqueta(Etiqueta etiqueta) {
  final nombre = etiqueta.nombre.trim().toUpperCase();
  // El tipo (ENTRADA/SALIDA/AMBOS) no se filtra porque el usuario puede haber
  // configurado sus billeteras con tipo SALIDA y aun necesita usarlas para cobrar
  return etiqueta.activo && !etiqueta.esSistema && nombre != 'TOTAL DE VENTAS';
}

// ─── Analisis de comprobante ────────────────────────────────────────────────

class ComprobanteConfianza {
  final double documento;
  final double entidad;
  final double monto;
  final double operacion;
  final double fecha;

  const ComprobanteConfianza({
    required this.documento,
    required this.entidad,
    required this.monto,
    required this.operacion,
    required this.fecha,
  });

  factory ComprobanteConfianza.fromJson(Map<String, dynamic> json) =>
      ComprobanteConfianza(
        documento: (json['documento'] as num?)?.toDouble() ?? 0,
        entidad: (json['entidad'] as num?)?.toDouble() ?? 0,
        monto: (json['monto'] as num?)?.toDouble() ?? 0,
        operacion: (json['operacion'] as num?)?.toDouble() ?? 0,
        fecha: (json['fecha'] as num?)?.toDouble() ?? 0,
      );

  double get promedio => (documento + entidad + monto + operacion + fecha) / 5;
}

class ComprobanteAnalisis {
  final String id;
  final String estado;
  final bool posibleDuplicado;
  final List<String> coincidencias;
  final String? entidad;
  final Etiqueta? etiquetaSugerida;
  final double? monto;
  final String? codigoOperacion;
  final String? codigoSeguridad;
  final String? fechaOperacion;
  final String? horaOperacion;
  final String imagenUrl;
  final String thumbnailUrl;
  final ComprobanteConfianza confianza;
  final List<String> advertencias;
  final DateTime? expiraAt;

  const ComprobanteAnalisis({
    required this.id,
    required this.estado,
    required this.posibleDuplicado,
    required this.coincidencias,
    this.entidad,
    this.etiquetaSugerida,
    this.monto,
    this.codigoOperacion,
    this.codigoSeguridad,
    this.fechaOperacion,
    this.horaOperacion,
    required this.imagenUrl,
    required this.thumbnailUrl,
    required this.confianza,
    required this.advertencias,
    this.expiraAt,
  });

  factory ComprobanteAnalisis.fromJson(Map<String, dynamic> json) {
    final etiqueta = json['etiquetaSugerida'];
    return ComprobanteAnalisis(
      id: json['id'] as String? ?? '',
      estado: json['estado'] as String? ?? 'REVISION',
      posibleDuplicado: json['posibleDuplicado'] as bool? ?? false,
      coincidencias: (json['coincidencias'] as List? ?? const [])
          .whereType<String>()
          .toList(),
      entidad: json['entidad'] as String?,
      etiquetaSugerida: etiqueta is Map
          ? Etiqueta.fromJson(Map<String, dynamic>.from(etiqueta))
          : null,
      monto: (json['monto'] as num?)?.toDouble(),
      codigoOperacion: json['codigoOperacion'] as String?,
      codigoSeguridad: json['codigoSeguridad'] as String?,
      fechaOperacion: json['fechaOperacion'] as String?,
      horaOperacion: json['horaOperacion'] as String?,
      imagenUrl: json['imagenUrl'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      confianza: ComprobanteConfianza.fromJson(
        Map<String, dynamic>.from(json['confianza'] as Map? ?? const {}),
      ),
      advertencias: (json['advertencias'] as List? ?? const [])
          .whereType<String>()
          .toList(),
      expiraAt: DateTime.tryParse(json['expiraAt'] as String? ?? ''),
    );
  }

  bool get esApto => estado == 'APTO' && !posibleDuplicado;
  bool get expirado => expiraAt?.isBefore(DateTime.now()) ?? false;

  /// El monto del comprobante supera el total a cobrar (bloquea la venta).
  bool montoExcede(double total) =>
      monto != null && (monto! * 100).round() > (total * 100).round();

  /// El monto del comprobante es menor al total (pago parcial: NO bloquea).
  bool montoEsMenor(double total) =>
      monto != null && (monto! * 100).round() < (total * 100).round();

  /// Coincide exactamente (a céntimos) con el total.
  bool montoCoincide(double total) =>
      monto != null && (monto! * 100).round() == (total * 100).round();
}

String? comprobanteAnalysisError({
  required ComprobanteAnalisis? analysis,
  required double total,
  required bool required,
  String? selectedEtiquetaId,
}) {
  if (analysis == null) {
    return required
        ? 'Analiza el comprobante requerido por esta billetera'
        : null;
  }
  if (analysis.posibleDuplicado) return 'Posible comprobante duplicado';
  if (analysis.expirado) {
    return 'El análisis expiró. Selecciona nuevamente el comprobante.';
  }
  if (!analysis.esApto) {
    return 'El comprobante requiere revisión y no permite continuar';
  }
  // Regla de negocio compartida con web y backend: solo bloquea si el monto
  // del comprobante SUPERA el total. Un monto menor es un pago parcial válido.
  if (analysis.montoExcede(total)) {
    return 'El monto del comprobante supera el total a cobrar';
  }
  if (analysis.monto == null) {
    return 'El comprobante tiene datos incompletos. Selecciona otro comprobante.';
  }
  // Si la IA identificó una billetera distinta a la seleccionada, bloquea.
  // Sin sugerencia, la billetera manual seleccionada es válida (igual que el backend).
  if (selectedEtiquetaId != null &&
      analysis.etiquetaSugerida != null &&
      analysis.etiquetaSugerida!.id != selectedEtiquetaId) {
    return 'La billetera analizada no coincide con la seleccionada';
  }
  return null;
}

// ─── Conciliación ──────────────────────────────────────────────────────────

enum EstadoConciliacion { pendiente, efectivo, billetera }

EstadoConciliacion parseEstadoConciliacion(String? value) {
  switch (value?.toUpperCase()) {
    case 'EFECTIVO':
      return EstadoConciliacion.efectivo;
    case 'BILLETERA':
      return EstadoConciliacion.billetera;
    default:
      return EstadoConciliacion.pendiente;
  }
}

String estadoConciliacionLabel(EstadoConciliacion e) {
  switch (e) {
    case EstadoConciliacion.pendiente:
      return 'Pendiente';
    case EstadoConciliacion.efectivo:
      return 'Efectivo';
    case EstadoConciliacion.billetera:
      return 'Billetera';
  }
}

class ConciliacionVenta {
  final String id;
  final EstadoConciliacion estado;
  final String? etiquetaId;
  final String? etiquetaNombre;
  final double? monto;
  final String? comprobante;
  final String? codigoOperacion;
  final String? clasificadaAt;
  final String? metodoPagoPendiente;
  final bool pagoRestoEfectivo;

  const ConciliacionVenta({
    required this.id,
    required this.estado,
    this.etiquetaId,
    this.etiquetaNombre,
    this.monto,
    this.comprobante,
    this.codigoOperacion,
    this.clasificadaAt,
    this.metodoPagoPendiente,
    this.pagoRestoEfectivo = false,
  });

  factory ConciliacionVenta.fromJson(Map<String, dynamic> j) =>
      ConciliacionVenta(
        id: j['id'] as String? ?? '',
        estado: parseEstadoConciliacion(j['estado'] as String?),
        etiquetaId: j['etiquetaId'] as String?,
        etiquetaNombre: (j['etiqueta'] as Map?)?['nombre'] as String?,
        monto: (j['monto'] as num?)?.toDouble(),
        comprobante: j['comprobante'] as String?,
        codigoOperacion: j['codigoOperacion'] as String?,
        clasificadaAt: j['clasificadaAt'] as String?,
        metodoPagoPendiente: j['metodoPagoPendiente'] as String?,
        pagoRestoEfectivo: j['pagoRestoEfectivo'] as bool? ?? false,
      );
}

// ─── Venta Item ────────────────────────────────────────────────────────────

class VentaItem {
  final String id;
  final String productoId;
  final String? productoNombre;
  final String? productoCodigo;
  final int cantidad;
  final double precioUnitario;
  final double subtotal;

  const VentaItem({
    required this.id,
    required this.productoId,
    this.productoNombre,
    this.productoCodigo,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
  });

  factory VentaItem.fromJson(Map<String, dynamic> j) => VentaItem(
    id: j['id'] as String? ?? '',
    productoId: j['productoId'] as String? ?? '',
    productoNombre: (j['producto'] as Map?)?['nombre'] as String?,
    productoCodigo: (j['producto'] as Map?)?['codigo'] as String?,
    cantidad: (j['cantidad'] as num?)?.toInt() ?? 0,
    precioUnitario: (j['precioUnitario'] as num?)?.toDouble() ?? 0,
    subtotal: (j['subtotal'] as num?)?.toDouble() ?? 0,
  );
}

// ─── Venta ─────────────────────────────────────────────────────────────────

enum EstadoVenta { activa, anulada }

EstadoVenta parseEstadoVenta(String? value) => value?.toUpperCase() == 'ANULADA'
    ? EstadoVenta.anulada
    : EstadoVenta.activa;

class Venta {
  final String id;
  final String codigo;
  final String cajaSesionId;
  final String sedeId;
  final String? vendedoraUsername;
  final String? registradaPorUsername;
  final double total;
  final bool hasAuthoritativeTotal;
  final EstadoVenta estado;
  final String? motivoAnulacion;
  final String? anuladaAt;
  final double? recargoMonto;
  final String? recargoMotivo;
  final String? cuentaId;
  final String? cuentaNombre;
  final double? cuentaMonto;
  final ConciliacionVenta? conciliacion;
  final List<ConciliacionVenta> conciliaciones;
  final List<ComprobanteAnalisis> comprobantesAnalisis;
  final List<VentaItem> items;
  final String createdAt;

  const Venta({
    required this.id,
    required this.codigo,
    required this.cajaSesionId,
    required this.sedeId,
    this.vendedoraUsername,
    this.registradaPorUsername,
    required this.total,
    this.hasAuthoritativeTotal = true,
    required this.estado,
    this.motivoAnulacion,
    this.anuladaAt,
    this.recargoMonto,
    this.recargoMotivo,
    this.cuentaId,
    this.cuentaNombre,
    this.cuentaMonto,
    this.conciliacion,
    this.conciliaciones = const [],
    this.comprobantesAnalisis = const [],
    required this.items,
    required this.createdAt,
  });

  factory Venta.fromJson(Map<String, dynamic> j) => Venta(
    id: j['id'] as String? ?? '',
    codigo: j['codigo'] as String? ?? '',
    cajaSesionId: j['cajaSesionId'] as String? ?? '',
    sedeId: j['sedeId'] as String? ?? '',
    vendedoraUsername: (j['vendedora'] as Map?)?['username'] as String?,
    registradaPorUsername: (j['registradaPor'] as Map?)?['username'] as String?,
    total: (j['total'] as num?)?.toDouble() ?? 0,
    hasAuthoritativeTotal: j['total'] is num,
    estado: parseEstadoVenta(j['estado'] as String?),
    motivoAnulacion: j['motivoAnulacion'] as String?,
    anuladaAt: j['anuladaAt'] as String?,
    recargoMonto: (j['recargoMonto'] as num?)?.toDouble(),
    recargoMotivo: j['recargoMotivo'] as String?,
    cuentaId: j['cuentaId'] as String?,
    cuentaNombre: (j['cuenta'] as Map?)?['nombre'] as String?,
    cuentaMonto: (j['cuentaMonto'] as num?)?.toDouble(),
    conciliacion: j['conciliacion'] is Map
        ? ConciliacionVenta.fromJson(
            Map<String, dynamic>.from(j['conciliacion'] as Map),
          )
        : null,
    conciliaciones: (j['conciliaciones'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => ConciliacionVenta.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(),
    comprobantesAnalisis: (j['comprobantesAnalisis'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) =>
              ComprobanteAnalisis.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(),
    items: (j['items'] as List? ?? const [])
        .map(
          (item) => VentaItem.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    createdAt: j['createdAt'] as String? ?? '',
  );

  bool get isAnulada => estado == EstadoVenta.anulada;
  bool get isPendiente => conciliacion?.estado == EstadoConciliacion.pendiente;
}

/// Returns true when the recargo amount should be surfaced to the user.
/// Recargo is hidden when a sale is annulled — the charge becomes void
/// server-side and showing it would mislead the operator.
bool ventaHasVisibleRecargo(Venta v) => !v.isAnulada && v.recargoMonto != null;

class VendedorVenta {
  final String id;
  final String username;
  final String rol;

  const VendedorVenta({
    required this.id,
    required this.username,
    required this.rol,
  });

  factory VendedorVenta.fromJson(Map<String, dynamic> j) => VendedorVenta(
    id: j['id'] as String? ?? '',
    username: j['username'] as String? ?? '',
    rol: (j['rol'] as Map?)?['nombre'] as String? ?? '',
  );
}

/// Immutable value retained after ambiguous failures for an exact retry.
class CreateVentaPayload {
  final Map<String, dynamic> json;

  CreateVentaPayload({
    required String idempotencyKey,
    required List<Map<String, dynamic>> items,
    String? sedeId,
    String? vendedoraId,
    required EstadoConciliacion estadoConciliacion,
    String? etiquetaId,
    String? comprobante,
    String? codigoOperacion,
    // Singular kept for backward compat; prefer ids when sending ≥1 comprobante.
    String? comprobanteAnalisisId,
    // Plural: overrides singular when non-empty (aligns with web client).
    List<String>? comprobanteAnalisisIds,
    double? recargoMonto,
    String? recargoMotivo,
    String? cuentaId,
    double? cuentaMonto,
    // Método cuando se guarda PENDIENTE (EFECTIVO o BILLETERA).
    String? metodoPagoPendiente,
    // Diferencia de billetera cubierta en efectivo (vuelto).
    bool? pagoRestoEfectivo,
    // Tokens de autorización para precios customizados por no-SUPERADMIN.
    List<String>? precioAuthTokens,
  }) : json = Map.unmodifiable({
         'idempotencyKey': idempotencyKey,
         'items': List.unmodifiable(
           items.map((item) => Map<String, dynamic>.unmodifiable(item)),
         ),
         'sedeId': ?sedeId,
         'vendedoraId': ?vendedoraId,
         'estadoConciliacion': estadoConciliacion.name.toUpperCase(),
         'etiquetaId': ?etiquetaId,
         // Use plural when available (supports multiple receipts).
         if (comprobanteAnalisisIds != null && comprobanteAnalisisIds.isNotEmpty)
           'comprobanteAnalisisIds': List.unmodifiable(comprobanteAnalisisIds)
         else if (comprobanteAnalisisId != null)
           'comprobanteAnalisisId': comprobanteAnalisisId,
         if (comprobanteAnalisisId == null &&
             (comprobanteAnalisisIds == null ||
                 comprobanteAnalisisIds.isEmpty)) ...{
           'comprobante': ?comprobante,
           'codigoOperacion': ?codigoOperacion,
         },
         'recargoMonto': ?recargoMonto,
         'recargoMotivo': ?recargoMotivo,
         'cuentaId': ?cuentaId,
         'cuentaMonto': ?cuentaMonto,
         'metodoPagoPendiente': ?metodoPagoPendiente,
         if (pagoRestoEfectivo == true) 'pagoRestoEfectivo': true,
         if (precioAuthTokens != null && precioAuthTokens.isNotEmpty)
           'precioAuthTokens': List.unmodifiable(precioAuthTokens),
       });

  String get idempotencyKey => json['idempotencyKey'] as String;
}
