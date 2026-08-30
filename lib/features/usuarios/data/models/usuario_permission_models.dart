class CatalogPermission {
  final String id;
  final String nombre;
  final String modulo;
  final String descripcion;

  const CatalogPermission({
    required this.id,
    required this.nombre,
    required this.modulo,
    required this.descripcion,
  });

  factory CatalogPermission.fromJson(Map<String, dynamic> j) =>
      CatalogPermission(
        id: j['id'] as String? ?? '',
        nombre: j['nombre'] as String? ?? '',
        modulo: j['modulo'] as String? ?? '',
        descripcion: j['descripcion'] as String? ?? '',
      );
}

class EffectivePermission extends CatalogPermission {
  final bool porRol;
  final bool adicional;
  final bool revocado;
  final bool activo;

  const EffectivePermission({
    required super.id,
    required super.nombre,
    required super.modulo,
    required super.descripcion,
    required this.porRol,
    required this.adicional,
    required this.revocado,
    required this.activo,
  });

  factory EffectivePermission.fromJson(Map<String, dynamic> j) =>
      EffectivePermission(
        id: j['id'] as String? ?? '',
        nombre: j['nombre'] as String? ?? '',
        modulo: j['modulo'] as String? ?? '',
        descripcion: j['descripcion'] as String? ?? '',
        porRol: j['porRol'] as bool? ?? false,
        adicional: j['adicional'] as bool? ?? false,
        revocado: j['revocado'] as bool? ?? false,
        activo: j['activo'] as bool? ?? false,
      );
}

class PermissionUser {
  final String id;
  final String username;
  final String rol;

  const PermissionUser({
    required this.id,
    required this.username,
    required this.rol,
  });

  factory PermissionUser.fromJson(Map<String, dynamic> j) => PermissionUser(
        id: j['id'] as String? ?? '',
        username: j['username'] as String? ?? '',
        rol: j['rol'] as String? ?? '',
      );
}

class UsuarioPermisosResponse {
  final PermissionUser usuario;
  final List<CatalogPermission> permisosPorRol;
  final List<CatalogPermission> permisosAdicionales;
  final List<CatalogPermission> permisosRevocados;
  final List<EffectivePermission> permisosEfectivos;

  const UsuarioPermisosResponse({
    required this.usuario,
    required this.permisosPorRol,
    required this.permisosAdicionales,
    required this.permisosRevocados,
    required this.permisosEfectivos,
  });

  factory UsuarioPermisosResponse.fromJson(Map<String, dynamic> j) =>
      UsuarioPermisosResponse(
        usuario: PermissionUser.fromJson(
            j['usuario'] as Map<String, dynamic>? ?? {}),
        permisosPorRol: _parseList(j['permisosPorRol']),
        permisosAdicionales: _parseList(j['permisosAdicionales']),
        permisosRevocados: _parseList(j['permisosRevocados']),
        permisosEfectivos: (j['permisosEfectivos'] as List? ?? [])
            .map((e) =>
                EffectivePermission.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  static List<CatalogPermission> _parseList(Object? raw) =>
      (raw as List? ?? [])
          .map((e) => CatalogPermission.fromJson(e as Map<String, dynamic>))
          .toList();
}

class ReplacePermissionsPayload {
  final List<String> permisoIds;
  final List<String> permisoIdsRevocados;

  const ReplacePermissionsPayload({
    required this.permisoIds,
    this.permisoIdsRevocados = const [],
  });

  Map<String, dynamic> toJson() => {
        'permisoIds': permisoIds,
        if (permisoIdsRevocados.isNotEmpty)
          'permisoIdsRevocados': permisoIdsRevocados,
      };
}

class PinConfigPayload {
  final String? superadminPin;
  final bool pinAutoGenerate;

  const PinConfigPayload({this.superadminPin, this.pinAutoGenerate = false});

  Map<String, dynamic> toJson() => {
        if (superadminPin != null) 'superadminPin': superadminPin,
        'pinAutoGenerate': pinAutoGenerate,
      };
}

class PinValidationResult {
  final bool success;
  final String? username;

  const PinValidationResult({required this.success, this.username});

  factory PinValidationResult.fromJson(Map<String, dynamic> j) =>
      PinValidationResult(
        success: j['success'] as bool? ?? false,
        username: j['username'] as String?,
      );
}

class StockAdjustPayload {
  final String? sedeId;
  final String tipo;
  final num cantidad;
  final String? referencia;
  final String? superadminPin;

  const StockAdjustPayload({
    this.sedeId,
    required this.tipo,
    required this.cantidad,
    this.referencia,
    this.superadminPin,
  });

  Map<String, dynamic> toJson() => {
        if (sedeId != null) 'sedeId': sedeId,
        'tipo': tipo,
        'cantidad': cantidad,
        if (referencia != null) 'referencia': referencia,
        if (superadminPin != null) 'superadminPin': superadminPin,
      };
}

class StockAdjustResult {
  final String productoId;
  final String sedeId;
  final num stock;
  final String tipo;
  final num cantidad;

  const StockAdjustResult({
    required this.productoId,
    required this.sedeId,
    required this.stock,
    required this.tipo,
    required this.cantidad,
  });

  factory StockAdjustResult.fromJson(Map<String, dynamic> j) =>
      StockAdjustResult(
        productoId: j['productoId'] as String? ?? '',
        sedeId: j['sedeId'] as String? ?? '',
        stock: j['stock'] as num? ?? 0,
        tipo: j['tipo'] as String? ?? '',
        cantidad: j['cantidad'] as num? ?? 0,
      );
}
