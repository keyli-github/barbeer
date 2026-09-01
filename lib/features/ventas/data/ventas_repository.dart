import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
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
  Future<Venta> crearVenta({required CreateVentaPayload payload}) async {
    final response = await _api.post(ApiConstants.ventas, data: payload.json);
    return Venta.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<ComprobanteAnalisis> analizarComprobante({
    required Uint8List bytes,
    required String filename,
    String? sedeId,
  }) async {
    final response = await _api.postMultipart(
      ApiConstants.analizarComprobante,
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: _imageMediaType(filename),
        ),
        'sedeId': ?sedeId,
      }),
      receiveTimeout: const Duration(seconds: 150),
      sendTimeout: const Duration(seconds: 150),
    );
    return ComprobanteAnalisis.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<void> cancelarComprobanteAnalisis(String id) =>
      _api.delete(ApiConstants.comprobanteAnalisis(id));

  /// Lista todas las ventas de la sede (CAJERO, ADMIN, SUPERADMIN).
  Future<({List<Venta> data, int total, int totalPaginas})> listVentas({
    int pagina = 1,
    int limite = 20,
    String? estado,
    String? vendedoraId,
    String? cajaSesionId,
    String? sedeId,
  }) async {
    final response = await _api.get(
      ApiConstants.ventas,
      queryParameters: {
        'pagina': pagina,
        'limite': limite,
        'estado': ?estado,
        'vendedoraId': ?vendedoraId,
        'cajaSesionId': ?cajaSesionId,
        'sedeId': ?sedeId,
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
    String? cajaSesionId,
  }) async {
    final response = await _api.get(
      ApiConstants.misVentas,
      queryParameters: {
        'pagina': pagina,
        'limite': limite,
        'estado': ?estado,
        'cajaSesionId': ?cajaSesionId,
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
    // Singular (legacy, backward compat).
    String? comprobanteAnalisisId,
    // Plural (preferred when ≥1 comprobante).
    List<String>? comprobanteAnalisisIds,
    String? codigoOperacion,
    // Diferencia cubierta en efectivo (vuelto).
    bool? pagoRestoEfectivo,
  }) async {
    final useIds =
        comprobanteAnalisisIds != null && comprobanteAnalisisIds.isNotEmpty;
    final response = await _api.patch(
      ApiConstants.conciliarVenta(id),
      data: {
        'estado': estado,
        'etiquetaId': ?etiquetaId,
        if (useIds)
          'comprobanteAnalisisIds': comprobanteAnalisisIds
        else
          'comprobanteAnalisisId': ?comprobanteAnalisisId,
        if (!useIds &&
            comprobanteAnalisisId == null &&
            codigoOperacion != null &&
            codigoOperacion.isNotEmpty)
          'codigoOperacion': codigoOperacion,
        if (pagoRestoEfectivo == true) 'pagoRestoEfectivo': true,
      },
    );
    return Venta.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  /// Solicita autorización de precio (PIN de SUPERADMIN).
  /// Retorna el token que debe incluirse en [CreateVentaPayload.precioAuthTokens].
  Future<String> autorizarPrecio({
    required String productoId,
    required double precioNuevo,
    required String pin,
  }) async {
    final response = await _api.post(
      ApiConstants.autorizarPrecio,
      data: {
        'productoId': productoId,
        'precioNuevo': precioNuevo,
        'pin': pin,
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return data['token'] as String;
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
        'sedeId': ?sedeId,
      },
    );
    final json = Map<String, dynamic>.from(response.data as Map);
    return (json['data'] as List? ?? [])
        .map((e) => Etiqueta.fromJson(Map<String, dynamic>.from(e as Map)))
        .where(isBilleteraEtiqueta)
        .toList();
  }

  Future<List<VendedorVenta>> listVendedores({required String sedeId}) async {
    final response = await _api.get(
      ApiConstants.users,
      queryParameters: {'pagina': 1, 'limite': 100, 'sedeId': sedeId},
    );
    final json = Map<String, dynamic>.from(response.data as Map);
    return (json['data'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => VendedorVenta.fromJson(Map<String, dynamic>.from(item)))
        .where((user) => user.id.isNotEmpty)
        .toList();
  }

  /// Lista todas las billeteras (activas e inactivas) para ADMIN.
  Future<List<Etiqueta>> listEtiquetas({String? sedeId}) async {
    final response = await _api.get(
      ApiConstants.etiquetas,
      queryParameters: {'pagina': 1, 'limite': 50, 'sedeId': ?sedeId},
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
        'sedeId': ?sedeId,
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
        'nombre': ?nombre,
        'requiereComprobante': ?requiereComprobante,
        'orden': ?orden,
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

MediaType _imageMediaType(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.png')) return MediaType('image', 'png');
  if (lower.endsWith('.webp')) return MediaType('image', 'webp');
  return MediaType('image', 'jpeg');
}
