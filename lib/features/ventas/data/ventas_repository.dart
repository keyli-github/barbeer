import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import 'models/venta_models.dart';
import '../../../core/offline/offline_store.dart';
import '../../../core/errors/app_exception.dart';

const _uuid = Uuid();

typedef ResponsableCajaRequest =
    Future<Response<dynamic>> Function(String? sedeId);
typedef CreateVentaRequest =
    Future<Response<dynamic>> Function(Map<String, dynamic> payload);

class OfflineSaleDraftSaved implements Exception {
  final String idempotencyKey;
  final String message;

  const OfflineSaleDraftSaved({
    required this.idempotencyKey,
    required this.message,
  });

  @override
  String toString() => message;
}

/// Repositorio para el módulo de Ventas.
/// Consume los endpoints del VentasModule y EtiquetasModule del backend.
class VentasRepository {
  final ApiClient _api;
  final OfflineStore? offlineStore;
  final ResponsableCajaRequest? responsableCajaRequest;
  final CreateVentaRequest? createVentaRequest;

  const VentasRepository(
    this._api, {
    this.offlineStore,
    this.responsableCajaRequest,
    this.createVentaRequest,
  });

  // ── Ventas ─────────────────────────────────────────────────────────────────

  /// Genera una nueva idempotencyKey para una venta.
  /// IMPORTANTE: conservar la misma key para reintentos de la misma venta.
  String generateIdempotencyKey() => _uuid.v4();

  /// Crea una venta nueva.
  /// [idempotencyKey] se genera con [generateIdempotencyKey()].
  /// El backend calcula precios y totales; el cliente solo envía productoId + cantidad.
  Future<Venta> crearVenta({required CreateVentaPayload payload}) async {
    final store = offlineStore ?? OfflineStore.instance;
    final scope = await store.scope();
    Map<String, dynamic> recovery = {
      ...payload.json,
      if (payload.manualReviewItems.isNotEmpty)
        '_manualReviewItems': payload.manualReviewItems,
    };
    if (scope != null) {
      final previous = (await store.sales(
        scope,
      )).where((record) => record['id'] == payload.idempotencyKey).firstOrNull;
      if (previous != null) {
        recovery = Map<String, dynamic>.from(previous['payload'] as Map);
        if (previous['status'] == 'SYNCED') {
          throw const ConflictException(
            message:
                'Esta venta ya fue sincronizada. Revisa el historial antes de registrarla nuevamente.',
          );
        }
        const reviewMessage =
            'El intento anterior quedó sin confirmar y no tiene metadata offline verificable. Revisa el historial con un responsable antes de registrarla nuevamente.';
        if (previous['status'] == 'DRAFT') {
          throw OfflineSaleDraftSaved(
            idempotencyKey: payload.idempotencyKey,
            message: previous['error'] as String? ?? reviewMessage,
          );
        }
        await store.record(scope, recovery, 'DRAFT', error: reviewMessage);
        throw OfflineSaleDraftSaved(
          idempotencyKey: payload.idempotencyKey,
          message: reviewMessage,
        );
      }

      Response<dynamic> box;
      try {
        box = await _getResponsableCaja(payload.json['sedeId'] as String?);
      } on NetworkException {
        return _saveManualReviewDraft(
          store: store,
          scope: scope,
          payload: recovery,
          idempotencyKey: payload.idempotencyKey,
          message:
              'No se pudo verificar la caja original sin conexión. El borrador requiere revisión manual y no se enviará automáticamente.',
        );
      }
      recovery = {
        ...payload.json,
        if (payload.manualReviewItems.isNotEmpty)
          '_manualReviewItems': payload.manualReviewItems,
        '_originalCajaId': (box.data as Map?)?['id'],
      };
      if (box.extra['offline'] == true) {
        return _saveManualReviewDraft(
          store: store,
          scope: scope,
          payload: recovery,
          idempotencyKey: payload.idempotencyKey,
          message:
              'La sesión de caja en caché no incluye metadata verificable de dispositivo y hora. El borrador requiere revisión manual y no se enviará automáticamente.',
        );
      }
      await store.record(scope, recovery, 'PENDING');
    }
    try {
      final response = await _postVenta(payload.json);
      final sale = Venta.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      if (scope != null) await store.record(scope, recovery, 'SYNCED');
      return sale;
    } catch (error) {
      if (scope != null && error is NetworkException) {
        return _saveManualReviewDraft(
          store: store,
          scope: scope,
          payload: recovery,
          idempotencyKey: payload.idempotencyKey,
          message:
              'No se recibió confirmación del servidor y falta metadata offline verificable para repetir la venta. Revisa el historial antes de registrarla nuevamente.',
        );
      }
      if (scope != null) {
        await store.record(scope, recovery, 'REVIEW', error: '$error');
      }
      rethrow;
    }
  }

  Future<Response<dynamic>> _getResponsableCaja(String? sedeId) {
    final request = responsableCajaRequest;
    if (request != null) return request(sedeId);
    return _api.get<dynamic>(
      '/caja/responsable',
      queryParameters: {'sedeId': ?sedeId},
    );
  }

  Future<Response<dynamic>> _postVenta(Map<String, dynamic> payload) {
    final request = createVentaRequest;
    if (request != null) return request(payload);
    return _api.post<dynamic>(ApiConstants.ventas, data: payload);
  }

  Future<Never> _saveManualReviewDraft({
    required OfflineStore store,
    required String scope,
    required Map<String, dynamic> payload,
    required String idempotencyKey,
    required String message,
  }) async {
    await store.record(scope, payload, 'DRAFT', error: message);
    throw OfflineSaleDraftSaved(
      idempotencyKey: idempotencyKey,
      message: message,
    );
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

  Future<ComprobanteAnalisis> completarComprobanteManual(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final response = await _api.patch(
      '/ventas/comprobantes/$id/manual',
      data: payload,
    );
    return ComprobanteAnalisis.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<void> validarClaveSuperadmin(String pin) async {
    await _api.post('/ventas/validar-clave', data: {'superadminPin': pin});
  }

  Future<Venta> crearVentaHistorica(
    String cajaId,
    String fecha,
    CreateVentaPayload payload,
  ) async {
    final response = await _api.post(
      '/ventas/sin-luz/$cajaId',
      data: {...payload.json, 'fechaVenta': fecha},
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
      data: {'productoId': productoId, 'precioNuevo': precioNuevo, 'pin': pin},
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
