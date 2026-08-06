import 'package:uuid/uuid.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import 'models/venta_models.dart';

const _uuid = Uuid();

/// Repositorio para el módulo de Ventas.
/// Consume los endpoints del VentasModule y EtiquetasModule del backend.
class VentasRepository {
  final ApiClient _api;
  const VentasRepository(this._api);

  // ── Ventas ─────────────────────────────────────────────────────────────────

  /// Genera una nueva idempotencyKey para una venta.
  /// IMPORTANTE: conservar la misma key para reintentos de la misma venta.
  String generateIdempotencyKey() => _uuid.v4();

  /// Crea una venta nueva.
  /// [idempotencyKey] se genera con [generateIdempotencyKey()].
  /// El backend calcula precios y totales; el cliente solo envía productoId + cantidad.
  Future<Venta> crearVenta({
    required String idempotencyKey,
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await _api.post(
      ApiConstants.ventas,
      data: {'idempotencyKey': idempotencyKey, 'items': items},
    );
    return Venta.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  /// Lista todas las ventas de la sede (CAJERO, ADMIN, SUPERADMIN).
  Future<({List<Venta> data, int total, int totalPaginas})> listVentas({
    int pagina = 1,
    int limite = 20,
    String? estado,
    String? vendedoraId,
    String? cajaSesionId,
  }) async {
    final response = await _api.get(
      ApiConstants.ventas,
      queryParameters: {
        'pagina': pagina,
        'limite': limite,
        if (estado != null) 'estado': estado,
        if (vendedoraId != null) 'vendedoraId': vendedoraId,
        if (cajaSesionId != null) 'cajaSesionId': cajaSesionId,
      },
    );
    final json = Map<String, dynamic>.from(response.data as Map);
    return (
      data: (json['data'] as List? ?? [])
          .map((e) => Venta.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      totalPaginas: (json['totalPaginas'] as num?)?.toInt() ?? 1,
    );
  }

  /// Lista las ventas propias de la vendedora autenticada.
  Future<({List<Venta> data, int total, int totalPaginas})> listMisVentas({
    int pagina = 1,
    int limite = 20,
    String? estado,
  }) async {
    final response = await _api.get(
      ApiConstants.misVentas,
      queryParameters: {
        'pagina': pagina,
        'limite': limite,
        if (estado != null) 'estado': estado,
      },
    );
    final json = Map<String, dynamic>.from(response.data as Map);
    return (
      data: (json['data'] as List? ?? [])
          .map((e) => Venta.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      totalPaginas: (json['totalPaginas'] as num?)?.toInt() ?? 1,
    );
  }

  /// Obtiene detalle de una venta.
  Future<Venta> getVenta(String id) async {
    final response = await _api.get(ApiConstants.venta(id));
    return Venta.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  /// Anula una venta (solo caja ABIERTA, permiso ventas:anular).
  Future<Venta> anularVenta(String id, {required String motivo}) async {
    final response = await _api.post(
      ApiConstants.anularVenta(id),
      data: {'motivo': motivo},
    );
    return Venta.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  /// Clasifica el pago de una venta (PENDIENTE → EFECTIVO o BILLETERA).
  Future<Venta> conciliarVenta(
    String id, {
    required String estado,
    String? etiquetaId,
    String? comprobante,
    String? codigoOperacion,
  }) async {
    final response = await _api.patch(
      ApiConstants.conciliarVenta(id),
      data: {
        'estado': estado,
        if (etiquetaId != null) 'etiquetaId': etiquetaId,
        if (comprobante != null && comprobante.isNotEmpty)
          'comprobante': comprobante,
        if (codigoOperacion != null && codigoOperacion.isNotEmpty)
          'codigoOperacion': codigoOperacion,
      },
    );
    return Venta.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  // ── Etiquetas ──────────────────────────────────────────────────────────────

  /// Lista las billeteras digitales activas.
  Future<List<Etiqueta>> listEtiquetasActivas({String? sedeId}) async {
    final response = await _api.get(
      ApiConstants.etiquetas,
      queryParameters: {
        'pagina': 1,
        'limite': 50,
        'soloActivas': true,
        if (sedeId != null) 'sedeId': sedeId,
      },
    );
    final json = Map<String, dynamic>.from(response.data as Map);
    return (json['data'] as List? ?? [])
        .map((e) => Etiqueta.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Lista todas las billeteras (activas e inactivas) para ADMIN.
  Future<List<Etiqueta>> listEtiquetas({String? sedeId}) async {
    final response = await _api.get(
      ApiConstants.etiquetas,
      queryParameters: {
        'pagina': 1,
        'limite': 50,
        if (sedeId != null) 'sedeId': sedeId,
      },
    );
    final json = Map<String, dynamic>.from(response.data as Map);
    return (json['data'] as List? ?? [])
        .map((e) => Etiqueta.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Crea una billetera digital.
  Future<Etiqueta> createEtiqueta({
    required String nombre,
    bool requiereComprobante = true,
    int orden = 0,
    String? sedeId,
  }) async {
    final response = await _api.post(
      ApiConstants.etiquetas,
      data: {
        'nombre': nombre,
        'requiereComprobante': requiereComprobante,
        'orden': orden,
        if (sedeId != null) 'sedeId': sedeId,
      },
    );
    return Etiqueta.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  /// Edita una billetera digital.
  Future<Etiqueta> updateEtiqueta(
    String id, {
    String? nombre,
    bool? requiereComprobante,
    int? orden,
  }) async {
    final response = await _api.patch(
      ApiConstants.etiqueta(id),
      data: {
        if (nombre != null) 'nombre': nombre,
        if (requiereComprobante != null)
          'requiereComprobante': requiereComprobante,
        if (orden != null) 'orden': orden,
      },
    );
    return Etiqueta.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  /// Activa/desactiva una billetera digital.
  Future<Etiqueta> toggleEtiqueta(String id, {required bool activo}) async {
    final response = await _api.patch(
      ApiConstants.etiquetaEstado(id),
      data: {'activo': activo},
    );
    return Etiqueta.fromJson(Map<String, dynamic>.from(response.data as Map));
  }
}
