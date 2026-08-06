import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// ─── Modelos de navegación ────────────────────────────────────────────────────

class _NavItem {
  final String path, label;
  final IconData icon, activeIcon;
  const _NavItem({
    required this.path,
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

class _DItem {
  final String path, label;
  final IconData icon;
  final String? perm;
  const _DItem({
    required this.path,
    required this.label,
    required this.icon,
    this.perm,
  });
}

class _DSec {
  final String title;
  final List<_DItem> items;
  const _DSec({required this.title, required this.items});
}

// ─── Estructura del drawer ────────────────────────────────────────────────────

const _drawerSections = [
  _DSec(
    title: 'PRINCIPAL',
    items: [
      _DItem(path: '/dashboard', label: 'Inicio', icon: Icons.home_rounded),
    ],
  ),
  _DSec(
    title: 'VENTAS Y CAJA',
    items: [
      _DItem(
        path: '/ventas',
        label: 'Ventas',
        icon: Icons.shopping_cart_rounded,
      ),
      _DItem(
        path: '/caja',
        label: 'Caja',
        icon: Icons.account_balance_wallet_rounded,
        perm: 'caja:leer',
      ),
    ],
  ),
  _DSec(
    title: 'INVENTARIO',
    items: [
      _DItem(
        path: '/productos',
        label: 'Productos',
        icon: Icons.liquor_rounded,
        perm: 'productos:crear',
      ),
      _DItem(
        path: '/inventario',
        label: 'Inventario',
        icon: Icons.inventory_2_rounded,
        perm: 'inventario:leer',
      ),
      _DItem(
        path: '/kardex',
        label: 'Kardex',
        icon: Icons.swap_vert_rounded,
        perm: 'kardex:leer',
      ),
      _DItem(
        path: '/compras',
        label: 'Compras',
        icon: Icons.local_shipping_rounded,
        perm: 'compras:leer',
      ),
    ],
  ),
  _DSec(
    title: 'PERSONAL',
    items: [
      _DItem(
        path: '/asistencia',
        label: 'Asistencia',
        icon: Icons.badge_rounded,
        perm: 'asistencia:leer',
      ),
    ],
  ),
  _DSec(
    title: 'ADMINISTRACIÓN',
    items: [
      _DItem(
        path: '/etiquetas',
        label: 'Billeteras',
        icon: Icons.payment_rounded,
        perm: 'etiquetas:crear',
      ),
      _DItem(
        path: '/usuarios',
        label: 'Usuarios',
        icon: Icons.people_rounded,
        perm: 'usuarios:leer',
      ),
      _DItem(
        path: '/sucursales',
        label: 'Sucursales',
        icon: Icons.store_rounded,
        perm: 'establecimientos:leer',
      ),
      _DItem(
        path: '/roles',
        label: 'Roles',
        icon: Icons.admin_panel_settings_rounded,
        perm: 'roles:leer',
      ),
      _DItem(
        path: '/permisos',
        label: 'Permisos',
        icon: Icons.security_rounded,
        perm: 'permisos:leer',
      ),
      _DItem(
        path: '/auditoria',
        label: 'Auditoría',
        icon: Icons.history_rounded,
        perm: 'audit:leer',
      ),
    ],
  ),
];

// ─── Bottom nav base (siempre visible) ───────────────────────────────────────

const _baseNav = [
  _NavItem(
    path: '/dashboard',
    label: 'Inicio',
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
  ),
  _NavItem(
    path: '/ventas',
    label: 'Ventas',
    icon: Icons.shopping_cart_outlined,
    activeIcon: Icons.shopping_cart_rounded,
  ),
];

// ─── Shell principal ──────────────────────────────────────────────────────────

class ShellScreen extends ConsumerWidget {
  final Widget child;
  final String currentPath;

  const ShellScreen({
    super.key,
    required this.child,
    required this.currentPath,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final navItems = _buildNav(auth);
    final showDrawer = _countDrawerItems(auth) > 4;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        drawer: showDrawer
            ? _AppDrawer(
                current: currentPath,
                auth: auth,
                go: (p) => context.go(p),
                logout: () => ref.read(authProvider.notifier).logout(),
              )
            : null,
        drawerEnableOpenDragGesture: showDrawer,
        body: child,
        bottomNavigationBar: _BottomNavBar(
          current: currentPath,
          go: (p) => context.go(p),
          items: navItems,
          showDrawer: showDrawer,
        ),
      ),
    );
  }

  // Construye el nav dinámico según permisos
  List<_NavItem> _buildNav(AuthState auth) {
    final items = <_NavItem>[..._baseNav];

    // Cajero → Caja en nav
    if (auth.hasPermission('caja:leer') &&
        !auth.hasPermission('inventario:leer')) {
      items.add(
        const _NavItem(
          path: '/caja',
          label: 'Caja',
          icon: Icons.account_balance_wallet_outlined,
          activeIcon: Icons.account_balance_wallet_rounded,
        ),
      );
    }

    // Admin/Superadmin → Inventario en nav
    if (auth.hasPermission('inventario:leer')) {
      items.insert(
        2,
        const _NavItem(
          path: '/inventario',
          label: 'Stock',
          icon: Icons.inventory_2_outlined,
          activeIcon: Icons.inventory_2_rounded,
        ),
      );
    }

    // Perfil al final
    items.add(
      const _NavItem(
        path: '/perfil',
        label: 'Perfil',
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
      ),
    );

    // Más... si hay drawer
    // (el drawer ya actúa como el "Más" de las referencias)

    return items;
  }

  int _countDrawerItems(AuthState auth) {
    int count = 0;
    for (final sec in _drawerSections) {
      for (final item in sec.items) {
        if (item.perm == null || auth.hasPermission(item.perm!)) count++;
      }
    }
    return count;
  }
}

// ─── Barra de navegación inferior flotante ────────────────────────────────────

class _BottomNavBar extends StatelessWidget {
  final String current;
  final ValueChanged<String> go;
  final List<_NavItem> items;
  final bool showDrawer;

  const _BottomNavBar({
    required this.current,
    required this.go,
    required this.items,
    required this.showDrawer,
  });

  @override
  Widget build(BuildContext context) {
    final bot = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, bottom: bot + 12),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: AppColors.border.withValues(alpha: 0.6),
            width: 0.75,
          ),
          boxShadow: AppShadows.nav,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: items
                  .map(
                    (item) => _NavBarItem(
                      item: item,
                      active: current.startsWith(item.path),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        go(item.path);
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final _NavItem item;
  final bool active;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.item,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: active ? 52 : 36,
              height: 30,
              decoration: BoxDecoration(
                color: active
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    active ? item.activeIcon : item.icon,
                    key: ValueKey(active),
                    size: 22,
                    color: active ? AppColors.navActive : AppColors.navInactive,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                color: active ? AppColors.navActive : AppColors.navInactive,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Drawer lateral ───────────────────────────────────────────────────────────

class _AppDrawer extends StatelessWidget {
  final String current;
  final AuthState auth;
  final ValueChanged<String> go;
  final VoidCallback logout;

  const _AppDrawer({
    required this.current,
    required this.auth,
    required this.go,
    required this.logout,
  });

  @override
  Widget build(BuildContext context) {
    final u = auth.user;
    final un = u?.username ?? '';
    final rol = u?.rol ?? '';

    return Drawer(
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── Header del drawer ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo BarBeer
                  Row(
                    children: [
                      Image.asset(
                        'assets/images/barbeerLogo.png',
                        width: 32,
                        height: 32,
                        errorBuilder: (_, __, ___) => Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.brandSurface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.local_bar_rounded,
                            color: AppColors.brand,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      RichText(
                        text: const TextSpan(
                          children: [
                            TextSpan(
                              text: 'Bar',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            TextSpan(
                              text: 'Beer',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.brand,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Avatar + info
                  Row(
                    children: [
                      _DrawerAvatar(username: un),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              un,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            _RoleBadge(role: rol),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(color: AppColors.border, height: 1),

            // ── Menú ──────────────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final sec in _drawerSections) ...[
                    // Solo mostrar sección si tiene items visibles
                    if (sec.items.any(
                      (i) => i.perm == null || auth.hasPermission(i.perm!),
                    )) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                        child: Text(
                          sec.title,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textTertiary,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      for (final item in sec.items)
                        if (item.perm == null || auth.hasPermission(item.perm!))
                          _DrawerItem(
                            item: item,
                            active: current.startsWith(item.path),
                            onTap: () {
                              Navigator.of(context).pop();
                              go(item.path);
                            },
                          ),
                    ],
                  ],
                ],
              ),
            ),

            Divider(color: AppColors.border, height: 1),

            // ── Logout ────────────────────────────────────────────────────
            InkWell(
              onTap: () {
                Navigator.of(context).pop();
                logout();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.errorLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: AppColors.error,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Cerrar sesión',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _DrawerAvatar extends StatelessWidget {
  final String username;
  const _DrawerAvatar({required this.username});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.avatarColor(username);
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.roleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final _DItem item;
  final bool active;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.item,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: Material(
        color: active ? AppColors.primarySurface : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: active ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: active ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
