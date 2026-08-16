import 'package:flutter/material.dart';

import '../routes/route_paths.dart';

enum AppDestinationSection {
  operations('OPERACIONES'),
  inventory('INVENTARIO'),
  staff('PERSONAL'),
  administration('ADMINISTRACION');

  final String label;
  const AppDestinationSection(this.label);
}

class AppDestination {
  final String path;
  final String label;
  final String title;
  final String? desktopLabel;
  final String shortLabel;
  final IconData icon;
  final IconData activeIcon;
  final AppDestinationSection? section;
  final List<String> permissions;
  final bool showInDesktopSidebar;

  const AppDestination({
    required this.path,
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.title = '',
    this.desktopLabel,
    this.shortLabel = '',
    this.section,
    this.permissions = const [],
    this.showInDesktopSidebar = true,
  });

  bool isActive(String currentPath) =>
      currentPath == path || currentPath.startsWith('$path/');

  bool canAccess(bool Function(String permission) hasPermission) =>
      permissions.isEmpty || permissions.any(hasPermission);

  String get routeTitle => title.isEmpty ? label : title;
  String get desktopNavigationLabel => desktopLabel ?? label;
  String get navigationLabel => shortLabel.isEmpty ? label : shortLabel;
}

const appDestinations = <AppDestination>[
  AppDestination(
    path: RoutePaths.dashboard,
    label: 'Dashboard',
    title: 'Dashboard',
    desktopLabel: 'Dashboard',
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
  ),
  AppDestination(
    path: RoutePaths.ventas,
    label: 'Ventas',
    icon: Icons.shopping_cart_outlined,
    activeIcon: Icons.shopping_cart_rounded,
    section: AppDestinationSection.operations,
    permissions: ['ventas:leer', 'ventas:leer-propias', 'ventas:crear'],
  ),
  AppDestination(
    path: RoutePaths.caja,
    label: 'Cuadre de Caja',
    title: 'Cuadre de Caja',
    shortLabel: 'Caja',
    icon: Icons.account_balance_wallet_outlined,
    activeIcon: Icons.account_balance_wallet_rounded,
    section: AppDestinationSection.operations,
    permissions: ['caja:leer'],
  ),
  AppDestination(
    path: RoutePaths.movimientos,
    label: 'Movimientos',
    icon: Icons.receipt_long_outlined,
    activeIcon: Icons.receipt_long_rounded,
    section: AppDestinationSection.operations,
    permissions: ['caja:leer'],
  ),
  AppDestination(
    path: RoutePaths.productos,
    label: 'Productos',
    icon: Icons.liquor_outlined,
    activeIcon: Icons.liquor_rounded,
    section: AppDestinationSection.inventory,
    permissions: ['productos:leer'],
  ),
  AppDestination(
    path: RoutePaths.categorias,
    label: 'Categorías',
    icon: Icons.category_outlined,
    activeIcon: Icons.category_rounded,
    section: AppDestinationSection.inventory,
    permissions: ['categorias:leer'],
  ),
  AppDestination(
    path: RoutePaths.inventario,
    label: 'Inventario',
    icon: Icons.inventory_2_outlined,
    activeIcon: Icons.inventory_2_rounded,
    section: AppDestinationSection.inventory,
    permissions: ['inventario:leer'],
  ),
  AppDestination(
    path: RoutePaths.kardex,
    label: 'Kardex',
    icon: Icons.swap_vert_outlined,
    activeIcon: Icons.swap_vert_rounded,
    section: AppDestinationSection.inventory,
    permissions: ['kardex:leer'],
  ),
  AppDestination(
    path: RoutePaths.compras,
    label: 'Compras',
    icon: Icons.local_shipping_outlined,
    activeIcon: Icons.local_shipping_rounded,
    section: AppDestinationSection.inventory,
    permissions: ['compras:leer'],
  ),
  AppDestination(
    path: RoutePaths.asistencia,
    label: 'Asistencia',
    icon: Icons.badge_outlined,
    activeIcon: Icons.badge_rounded,
    section: AppDestinationSection.staff,
    // Todo empleado autenticado debe poder abrir el escáner QR. La pantalla
    // muestra la administración completa solo con asistencia:leer.
    permissions: [],
  ),
  AppDestination(
    path: RoutePaths.etiquetas,
    label: 'Etiquetas',
    title: 'Gestión de Etiquetas',
    icon: Icons.payment_outlined,
    activeIcon: Icons.payment_rounded,
    section: AppDestinationSection.administration,
    permissions: ['etiquetas:leer'],
  ),
  AppDestination(
    path: RoutePaths.usuarios,
    label: 'Usuarios',
    icon: Icons.people_outline_rounded,
    activeIcon: Icons.people_rounded,
    section: AppDestinationSection.administration,
    permissions: ['usuarios:leer'],
  ),
  AppDestination(
    path: RoutePaths.sucursales,
    label: 'Sucursales',
    icon: Icons.store_outlined,
    activeIcon: Icons.store_rounded,
    section: AppDestinationSection.administration,
    permissions: ['establecimientos:leer'],
  ),
  AppDestination(
    path: RoutePaths.roles,
    label: 'Roles',
    icon: Icons.admin_panel_settings_outlined,
    activeIcon: Icons.admin_panel_settings_rounded,
    section: AppDestinationSection.administration,
    permissions: ['roles:leer'],
  ),
  AppDestination(
    path: RoutePaths.permisos,
    label: 'Permisos',
    icon: Icons.security_outlined,
    activeIcon: Icons.security_rounded,
    section: AppDestinationSection.administration,
    permissions: ['permisos:leer'],
  ),
  AppDestination(
    path: RoutePaths.auditoria,
    label: 'Auditoria',
    title: 'Auditoria',
    icon: Icons.history_outlined,
    activeIcon: Icons.history_rounded,
    section: AppDestinationSection.administration,
    permissions: ['audit:leer'],
  ),
  AppDestination(
    path: RoutePaths.seguridad,
    label: 'Seguridad',
    icon: Icons.shield_outlined,
    activeIcon: Icons.shield_rounded,
    section: AppDestinationSection.administration,
  ),
  AppDestination(
    path: RoutePaths.perfil,
    label: 'Perfil',
    icon: Icons.person_outline_rounded,
    activeIcon: Icons.person_rounded,
    showInDesktopSidebar: false,
  ),
];

AppDestination? appDestinationForPath(String path) {
  for (final destination in appDestinations) {
    if (destination.isActive(path)) return destination;
  }
  return null;
}
