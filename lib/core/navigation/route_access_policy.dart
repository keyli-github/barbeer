import '../routes/route_paths.dart';

class RouteAccessRule {
  final Set<String> roles;
  final Set<String> anyPermissions;

  const RouteAccessRule({
    this.roles = const {},
    this.anyPermissions = const {},
  });
  const RouteAccessRule.any(this.anyPermissions) : roles = const {};
  const RouteAccessRule.role(this.roles) : anyPermissions = const {};
  const RouteAccessRule.both(this.roles, this.anyPermissions);

  bool allows({required String role, required Iterable<String> permissions}) {
    final normalizedRole = role.toUpperCase();
    return (roles.isEmpty || roles.contains(normalizedRole)) &&
        (anyPermissions.isEmpty || permissions.any(anyPermissions.contains));
  }
}

class RouteAccessPolicy {
  RouteAccessPolicy._();

  static const _rules = <String, RouteAccessRule>{
    RoutePaths.dashboard: RouteAccessRule(),
    RoutePaths.perfil: RouteAccessRule(),
    RoutePaths.changePassword: RouteAccessRule(),
    RoutePaths.seguridad: RouteAccessRule(),
    RoutePaths.asistencia: RouteAccessRule(),
    RoutePaths.ventas: RouteAccessRule.any({
      'ventas:leer',
      'ventas:leer-propias',
      'ventas:crear',
    }),
    RoutePaths.caja: RouteAccessRule.any({'caja:leer'}),
    RoutePaths.movimientos: RouteAccessRule.any({'caja:leer'}),
    RoutePaths.productos: RouteAccessRule.any({'productos:leer'}),
    RoutePaths.categorias: RouteAccessRule.any({'categorias:leer'}),
    RoutePaths.inventario: RouteAccessRule.any({'inventario:leer'}),
    RoutePaths.kardex: RouteAccessRule.any({'kardex:leer'}),
    RoutePaths.compras: RouteAccessRule.any({'compras:leer'}),
    RoutePaths.etiquetas: RouteAccessRule.any({'etiquetas:leer'}),
    RoutePaths.usuarios: RouteAccessRule.any({'usuarios:leer'}),
    RoutePaths.sucursales: RouteAccessRule.any({'establecimientos:leer'}),
    RoutePaths.roles: RouteAccessRule.any({'roles:leer'}),
    RoutePaths.permisos: RouteAccessRule.any({'permisos:leer'}),
    RoutePaths.auditoria: RouteAccessRule.any({'audit:leer'}),
    RoutePaths.cuentas: RouteAccessRule.both(
      {'SUPERADMIN', 'ADMIN'},
      {'cuentas:leer'},
    ),
    RoutePaths.reportes: RouteAccessRule.role({'SUPERADMIN'}),
    RoutePaths.respaldos: RouteAccessRule.any({'respaldos:gestionar'}),
    RoutePaths.importaciones: RouteAccessRule.any({'importaciones:ejecutar'}),
  };

  static const _entryPaths = {RoutePaths.splash, RoutePaths.login};

  static String _path(String location) => Uri.parse(location).path;

  static RouteAccessRule? ruleFor(String location) {
    final path = _path(location);
    for (final entry in _rules.entries) {
      if (path == entry.key || path.startsWith('${entry.key}/')) {
        return entry.value;
      }
    }
    return null;
  }

  static bool isProtected(String location) {
    final path = _path(location);
    return !_entryPaths.contains(path) && path != RoutePaths.noAutorizado;
  }

  static bool canAccess(
    String location, {
    required String role,
    required Iterable<String> permissions,
  }) =>
      ruleFor(location)?.allows(role: role, permissions: permissions) ?? false;
}

enum AuthGateState {
  unresolved,
  authenticating,
  unauthenticated,
  authenticated,
}

String? routeGuardRedirect({
  required AuthGateState gate,
  required String currentPath,
  String? pendingLocation,
  required String role,
  required Iterable<String> permissions,
}) {
  switch (gate) {
    case AuthGateState.unresolved:
      return currentPath == RoutePaths.splash ? null : RoutePaths.splash;
    case AuthGateState.authenticating:
      return currentPath == RoutePaths.login ? null : RoutePaths.splash;
    case AuthGateState.unauthenticated:
      return currentPath == RoutePaths.login ? null : RoutePaths.login;
    case AuthGateState.authenticated:
      if (currentPath == RoutePaths.noAutorizado) return null;
      final entering = RouteAccessPolicy._entryPaths.contains(currentPath);
      final target = entering
          ? pendingLocation ?? RoutePaths.dashboard
          : currentPath;
      final allowed = RouteAccessPolicy.canAccess(
        target,
        role: role,
        permissions: permissions,
      );
      return allowed ? (entering ? target : null) : RoutePaths.noAutorizado;
  }
}
