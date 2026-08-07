import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// ─── GlobalKey para abrir el panel "Ver más" ──────────────────────────────────
final shellScaffoldKey = GlobalKey<ScaffoldState>();

// ─── Modelo de item de navegación ────────────────────────────────────────────

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

// ─── Todos los módulos disponibles con su permiso mínimo ─────────────────────

class _Module {
  final String path, label;
  final IconData icon, activeIcon;
  final String? perm; // null = siempre visible
  const _Module({
    required this.path,
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.perm,
  });
}

const _allModules = [
  _Module(
    path: '/dashboard',
    label: 'Inicio',
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
  ),
  _Module(
    path: '/ventas',
    label: 'Ventas',
    icon: Icons.shopping_cart_outlined,
    activeIcon: Icons.shopping_cart_rounded,
    perm: 'ventas:leer', // también aplica si tiene ventas:leer-propias
  ),
  _Module(
    path: '/caja',
    label: 'Caja',
    icon: Icons.account_balance_wallet_outlined,
    activeIcon: Icons.account_balance_wallet_rounded,
    perm: 'caja:leer',
  ),
  _Module(
    path: '/productos',
    label: 'Productos',
    icon: Icons.liquor_outlined,
    activeIcon: Icons.liquor_rounded,
    perm: 'productos:crear',
  ),
  _Module(
    path: '/inventario',
    label: 'Inventario',
    icon: Icons.inventory_2_outlined,
    activeIcon: Icons.inventory_2_rounded,
    perm: 'inventario:leer',
  ),
  _Module(
    path: '/kardex',
    label: 'Kardex',
    icon: Icons.swap_vert_outlined,
    activeIcon: Icons.swap_vert_rounded,
    perm: 'kardex:leer',
  ),
  _Module(
    path: '/compras',
    label: 'Compras',
    icon: Icons.local_shipping_outlined,
    activeIcon: Icons.local_shipping_rounded,
    perm: 'compras:leer',
  ),
  _Module(
    path: '/asistencia',
    label: 'Asistencia',
    icon: Icons.badge_outlined,
    activeIcon: Icons.badge_rounded,
    perm: 'asistencia:leer',
  ),
  _Module(
    path: '/etiquetas',
    label: 'Billeteras',
    icon: Icons.payment_outlined,
    activeIcon: Icons.payment_rounded,
    perm: 'etiquetas:crear',
  ),
  _Module(
    path: '/usuarios',
    label: 'Usuarios',
    icon: Icons.people_outline_rounded,
    activeIcon: Icons.people_rounded,
    perm: 'usuarios:leer',
  ),
  _Module(
    path: '/sucursales',
    label: 'Sucursales',
    icon: Icons.store_outlined,
    activeIcon: Icons.store_rounded,
    perm: 'establecimientos:leer',
  ),
  _Module(
    path: '/roles',
    label: 'Roles',
    icon: Icons.admin_panel_settings_outlined,
    activeIcon: Icons.admin_panel_settings_rounded,
    perm: 'roles:leer',
  ),
  _Module(
    path: '/permisos',
    label: 'Permisos',
    icon: Icons.security_outlined,
    activeIcon: Icons.security_rounded,
    perm: 'permisos:leer',
  ),
  _Module(
    path: '/auditoria',
    label: 'Auditoría',
    icon: Icons.history_outlined,
    activeIcon: Icons.history_rounded,
    perm: 'audit:leer',
  ),
  _Module(
    path: '/perfil',
    label: 'Perfil',
    icon: Icons.person_outline_rounded,
    activeIcon: Icons.person_rounded,
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

  /// Módulos visibles para este usuario según permisos
  List<_Module> _visibleModules(AuthState auth) => _allModules.where((m) {
    if (m.perm == null) return true;
    // Ventas: visible si tiene cualquiera de los dos permisos
    if (m.path == '/ventas') {
      return auth.hasPermission('ventas:leer') ||
          auth.hasPermission('ventas:leer-propias') ||
          auth.hasPermission('ventas:crear');
    }
    return auth.hasPermission(m.perm!);
  }).toList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final visible = _visibleModules(auth);

    // Primeros 3 en el bottom nav; el resto va en "Ver más"
    const maxInBar = 3;
    final barModules = visible.take(maxInBar).toList();
    final moreModules = visible.length > maxInBar
        ? visible.sublist(maxInBar)
        : <_Module>[];
    final showMore = moreModules.isNotEmpty;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        key: shellScaffoldKey,
        backgroundColor: AppColors.background,
        // Panel derecho "Ver más"
        endDrawer: showMore
            ? _MorePanel(
                modules: moreModules,
                current: currentPath,
                auth: auth,
                go: (p) {
                  shellScaffoldKey.currentState?.closeEndDrawer();
                  context.go(p);
                },
                logout: () {
                  shellScaffoldKey.currentState?.closeEndDrawer();
                  ref.read(authProvider.notifier).logout();
                },
              )
            : null,
        endDrawerEnableOpenDragGesture: false,
        body: child,
        bottomNavigationBar: _BottomNavBar(
          current: currentPath,
          barModules: barModules,
          showMore: showMore,
          go: (p) => context.go(p),
          onMoreTap: () {
            HapticFeedback.lightImpact();
            shellScaffoldKey.currentState?.openEndDrawer();
          },
        ),
      ),
    );
  }
}

// ─── Barra de navegación inferior flotante ────────────────────────────────────

class _BottomNavBar extends StatelessWidget {
  final String current;
  final List<_Module> barModules;
  final bool showMore;
  final ValueChanged<String> go;
  final VoidCallback onMoreTap;

  const _BottomNavBar({
    required this.current,
    required this.barModules,
    required this.showMore,
    required this.go,
    required this.onMoreTap,
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
              children: [
                // Módulos del bar
                ...barModules.map((m) {
                  final active = current.startsWith(m.path);
                  return Expanded(
                    child: _NavBarItem(
                      label: m.label,
                      icon: m.icon,
                      activeIcon: m.activeIcon,
                      active: active,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        go(m.path);
                      },
                    ),
                  );
                }),
                // Botón Ver más
                if (showMore)
                  Expanded(
                    child: _NavBarItem(
                      label: 'Ver más',
                      icon: Icons.grid_view_outlined,
                      activeIcon: Icons.grid_view_rounded,
                      active: false,
                      onTap: onMoreTap,
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

class _NavBarItem extends StatelessWidget {
  final String label;
  final IconData icon, activeIcon;
  final bool active;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
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
                active ? activeIcon : icon,
                key: ValueKey(active),
                size: 22,
                color: active ? AppColors.navActive : AppColors.navInactive,
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            color: active ? AppColors.navActive : AppColors.navInactive,
          ),
        ),
      ],
    ),
  );
}

// ─── Panel derecho "Ver más" ──────────────────────────────────────────────────

class _MorePanel extends StatelessWidget {
  final List<_Module> modules;
  final String current;
  final AuthState auth;
  final ValueChanged<String> go;
  final VoidCallback logout;

  const _MorePanel({
    required this.modules,
    required this.current,
    required this.auth,
    required this.go,
    required this.logout,
  });

  @override
  Widget build(BuildContext context) {
    final user = auth.user;
    final un = user?.username ?? '';
    final rol = user?.rol ?? '';

    return Drawer(
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          bottomLeft: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── Cabecera usuario ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  // Avatar
                  _Avatar(username: un),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          un,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        _RoleBadge(rol),
                      ],
                    ),
                  ),
                  // Botón cerrar panel
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),

            // ── Grid de módulos ──────────────────────────────────────────
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                padding: const EdgeInsets.all(16),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.0,
                children: modules.map((m) {
                  final active = current.startsWith(m.path);
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      go(m.path);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.primarySurface
                            : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(14),
                        border: active
                            ? Border.all(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                width: 1.5,
                              )
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            active ? m.activeIcon : m.icon,
                            size: 26,
                            color: active
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            m.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: active
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const Divider(height: 1, color: AppColors.border),

            // ── Cerrar sesión ────────────────────────────────────────────
            InkWell(
              onTap: logout,
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

// ─── Widgets auxiliares ───────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String username;
  const _Avatar({required this.username});
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
  const _RoleBadge(this.role);
  @override
  Widget build(BuildContext context) {
    final color = AppColors.roleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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
