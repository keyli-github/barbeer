import 'package:flutter/material.dart';

/// Widget que controla la visibilidad basándose en permisos del usuario
/// Centraliza la lógica para evitar duplicación manual en cada pantalla
class PermissionGuard extends StatelessWidget {
  /// Lista de permisos requeridos (cualquiera de ellos permite el acceso)
  final List<String> permissions;

  /// Widget a mostrar si el usuario tiene permiso
  final Widget child;

  /// Widget a mostrar si NO tiene permiso (null = no mostrar nada)
  final Widget? fallback;

  /// Función para verificar si el usuario tiene un permiso específico
  final bool Function(String permission) checkPermission;

  const PermissionGuard({
    super.key,
    required this.permissions,
    required this.child,
    required this.checkPermission,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    // Si tiene al menos uno de los permisos requeridos, mostrar el widget
    final hasPermission = permissions.any((p) => checkPermission(p));

    if (hasPermission) {
      return child;
    }

    // Si no tiene permiso y hay fallback, mostrarlo
    if (fallback != null) {
      return fallback!;
    }

    // Si no tiene permiso y no hay fallback, no mostrar nada
    return const SizedBox.shrink();
  }
}

/// Extensión para simplificar el uso del guard
extension PermissionGuardExtension on Widget {
  /// Envuelve el widget con un PermissionGuard
  Widget guardWithPermissions(
    List<String> permissions,
    bool Function(String) checkPermission, {
    Widget? fallback,
  }) {
    return PermissionGuard(
      permissions: permissions,
      checkPermission: checkPermission,
      fallback: fallback,
      child: this,
    );
  }

  /// Versión simplificada para un solo permiso
  Widget guardWithPermission(
    String permission,
    bool Function(String) checkPermission, {
    Widget? fallback,
  }) {
    return PermissionGuard(
      permissions: [permission],
      checkPermission: checkPermission,
      fallback: fallback,
      child: this,
    );
  }
}

/// Builder condicional basado en permisos
class PermissionBuilder extends StatelessWidget {
  final List<String> permissions;
  final bool Function(String permission) checkPermission;
  final Widget Function(BuildContext context, bool hasPermission) builder;

  const PermissionBuilder({
    super.key,
    required this.permissions,
    required this.checkPermission,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final hasPermission = permissions.any((p) => checkPermission(p));
    return builder(context, hasPermission);
  }
}

/// Servicio helper para verificar permisos (debe ser inyectado donde se necesite)
class PermissionService {
  final Set<String> _userPermissions;

  PermissionService(this._userPermissions);

  /// Verifica si el usuario tiene un permiso específico
  bool hasPermission(String permission) {
    return _userPermissions.contains(permission);
  }

  /// Verifica si el usuario tiene TODOS los permisos especificados
  bool hasAllPermissions(List<String> permissions) {
    return permissions.every((p) => _userPermissions.contains(p));
  }

  /// Verifica si el usuario tiene AL MENOS UNO de los permisos especificados
  bool hasAnyPermission(List<String> permissions) {
    return permissions.any((p) => _userPermissions.contains(p));
  }

  /// Lista todos los permisos del usuario
  Set<String> get allPermissions => _userPermissions;
}

/// Constantes de permisos para evitar strings mágicos
class Permissions {
  Permissions._();

  // Ventas
  static const String ventasCrear = 'ventas:crear';
  static const String ventasLeer = 'ventas:leer';
  static const String ventasEditar = 'ventas:editar';
  static const String ventasEliminar = 'ventas:eliminar';
  static const String ventasAnular = 'ventas:anular';
  static const String ventasConciliar = 'ventas:conciliar';

  // Productos
  static const String productosCrear = 'productos:crear';
  static const String productosLeer = 'productos:leer';
  static const String productosEditar = 'productos:editar';
  static const String productosEliminar = 'productos:eliminar';

  // Categorías
  static const String categoriasCrear = 'categorias:crear';
  static const String categoriasLeer = 'categorias:leer';
  static const String categoriasEditar = 'categorias:editar';
  static const String categoriasEliminar = 'categorias:eliminar';

  // Inventario
  static const String inventarioCrear = 'inventario:crear';
  static const String inventarioLeer = 'inventario:leer';
  static const String inventarioEditar = 'inventario:editar';
  static const String inventarioAjustar = 'inventario:ajustar';

  // Kardex
  static const String kardexLeer = 'kardex:leer';
  static const String kardexExportar = 'kardex:exportar';

  // Compras
  static const String comprasCrear = 'compras:crear';
  static const String comprasLeer = 'compras:leer';
  static const String comprasEditar = 'compras:editar';
  static const String comprasEliminar = 'compras:eliminar';

  // Caja
  static const String cajaAbrir = 'caja:abrir';
  static const String cajaLeer = 'caja:leer';
  static const String cajaCerrar = 'caja:cerrar';
  static const String cajaMovimientos = 'caja:movimientos';

  // Usuarios
  static const String usuariosCrear = 'usuarios:crear';
  static const String usuariosLeer = 'usuarios:leer';
  static const String usuariosEditar = 'usuarios:editar';
  static const String usuariosEliminar = 'usuarios:eliminar';

  // Roles
  static const String rolesCrear = 'roles:crear';
  static const String rolesLeer = 'roles:leer';
  static const String rolesEditar = 'roles:editar';
  static const String rolesEliminar = 'roles:eliminar';

  // Permisos
  static const String permisosLeer = 'permisos:leer';
  static const String permisosAsignar = 'permisos:asignar';

  // Establecimientos
  static const String establecimientosCrear = 'establecimientos:crear';
  static const String establecimientosLeer = 'establecimientos:leer';
  static const String establecimientosEditar = 'establecimientos:editar';
  static const String establecimientosEliminar = 'establecimientos:eliminar';

  // Etiquetas
  static const String etiquetasCrear = 'etiquetas:crear';
  static const String etiquetasLeer = 'etiquetas:leer';
  static const String etiquetasEditar = 'etiquetas:editar';
  static const String etiquetasEliminar = 'etiquetas:eliminar';
  static const String etiquetasDesactivar = 'etiquetas:desactivar';

  // Asistencia
  static const String asistenciaCrear = 'asistencia:crear';
  static const String asistenciaLeer = 'asistencia:leer';
  static const String asistenciaEditar = 'asistencia:editar';

  // Auditoría
  static const String auditLeer = 'audit:leer';
}
