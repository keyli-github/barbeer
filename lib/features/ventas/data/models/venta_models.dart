// Modelos de datos para el módulo de Ventas y Conciliación.
// Espejo de los DTOs del backend NestJS.

// ─── Etiqueta (billetera digital) ──────────────────────────────────────────

class Etiqueta {
  final String id;
  final String nombre;
  final bool activo;
  final String? sedeId;
  final bool requiereComprobante;
  final String tipo;
  final int orden;

  const Etiqueta({
    required this.id,
    required this.nombre,
    required this.activo,
    this.sedeId,
    required this.requiereComprobante,
    this.tipo = 'ENTRADA',
    required this.orden,
  });

  factory Etiqueta.fromJson(Map<String, dynamic> j) => Etiqueta(
    id: j['id'] as String? ?? '',
    nombre: j['nombre'] as String? ?? '',
    activo: j['activo'] as bool? ?? true,
    sedeId: j['sedeId'] as String?,
    requiereComprobante: j['requiereComprobante'] as bool? ?? true,
    tipo: j['tipo'] as String? ?? 'ENTRADA',
    orden: (j['orden'] as num?)?.toInt() ?? 0,
  );
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

  const ConciliacionVenta({
    required this.id,
    required this.estado,
    this.etiquetaId,
    this.etiquetaNombre,
    this.monto,
    this.comprobante,
    this.codigoOperacion,
    this.clasificadaAt,
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
  final double total;
  final EstadoVenta estado;
  final String? motivoAnulacion;
  final String? anuladaAt;
  final double? recargoMonto;
  final String? recargoMotivo;
  final ConciliacionVenta? conciliacion;
  final List<VentaItem> items;
  final String createdAt;

  const Venta({
    required this.id,
    required this.codigo,
    required this.cajaSesionId,
    required this.sedeId,
    this.vendedoraUsername,
    required this.total,
    required this.estado,
    this.motivoAnulacion,
    this.anuladaAt,
    this.recargoMonto,
    this.recargoMotivo,
    this.conciliacion,
    required this.items,
    required this.createdAt,
  });

  factory Venta.fromJson(Map<String, dynamic> j) => Venta(
    id: j['id'] as String? ?? '',
    codigo: j['codigo'] as String? ?? '',
    cajaSesionId: j['cajaSesionId'] as String? ?? '',
    sedeId: j['sedeId'] as String? ?? '',
    vendedoraUsername: (j['vendedora'] as Map?)?['username'] as String?,
    total: (j['total'] as num?)?.toDouble() ?? 0,
    estado: parseEstadoVenta(j['estado'] as String?),
    motivoAnulacion: j['motivoAnulacion'] as String?,
    anuladaAt: j['anuladaAt'] as String?,
    recargoMonto: (j['recargoMonto'] as num?)?.toDouble(),
    recargoMotivo: j['recargoMotivo'] as String?,
    conciliacion: j['conciliacion'] is Map
        ? ConciliacionVenta.fromJson(
            Map<String, dynamic>.from(j['conciliacion'] as Map),
          )
        : null,
    items: (j['items'] as List? ?? const [])
        .map(
          (item) => VentaItem.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    createdAt: j['createdAt'] as String? ?? '',
  );

  bool get isAnulada => estado == EstadoVenta.anulada;
  bool get isPendiente => conciliacion?.estado == EstadoConciliacion.pendiente;
  double get subtotalSinRecargo => total - (recargoMonto ?? 0);
}

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
    double? recargoMonto,
    String? recargoMotivo,
  }) : json = Map.unmodifiable({
         'idempotencyKey': idempotencyKey,
         'items': List.unmodifiable(
           items.map((item) => Map<String, dynamic>.unmodifiable(item)),
         ),
         'sedeId': ?sedeId,
         'vendedoraId': ?vendedoraId,
         'estadoConciliacion': estadoConciliacion.name.toUpperCase(),
         'etiquetaId': ?etiquetaId,
         'comprobante': ?comprobante,
         'codigoOperacion': ?codigoOperacion,
         'recargoMonto': ?recargoMonto,
         'recargoMotivo': ?recargoMotivo,
       });

  String get idempotencyKey => json['idempotencyKey'] as String;
}
