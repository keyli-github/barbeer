import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/navigation/app_destinations.dart';
import '../../../../core/providers/branding_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/barbeer_wordmark.dart';
import '../../../../core/widgets/sede_scope_selector.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'desktop_shell.dart';

// ─── GlobalKey para abrir el panel "Ver más" ──────────────────────────────────
final shellScaffoldKey = GlobalKey<ScaffoldState>();

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
  List<AppDestination> _visibleModules(AuthState auth) => appDestinations
      .where(
        (destination) => destination.canAccess(
          auth.hasPermission,
          role: auth.user?.rol ?? '',
        ),
      )
      .toList();

  /// Subtítulo que se muestra debajo de BarBeer según la ruta activa
  String _subtitleFor(String path, AuthState auth) {
    if (path.startsWith('/dashboard')) {
      return FormatUtils.roleName(auth.user?.rol ?? '');
    }
    return appDestinationForPath(path)?.label ?? '';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final visible = _visibleModules(auth);
    final subtitle = _subtitleFor(currentPath, auth);
    final logoUrl = ref.watch(brandingProvider).logoUrl;

    if (MediaQuery.sizeOf(context).width >= 1024) {
      return DesktopShell(
        currentPath: currentPath,
        destinations: visible,
        auth: auth,
        onNavigate: context.go,
        onLogout: () => ref.read(authProvider.notifier).logout(),
        headerAction: const SedeScopeSelector(),
        logoUrl: logoUrl,
        child: child,
      );
    }

    const preferredBarPaths = ['/dashboard', '/ventas', '/caja', '/usuarios'];
    final barModules = preferredBarPaths
        .map((path) => visible.where((item) => item.path == path).firstOrNull)
        .whereType<AppDestination>()
        .toList();
    // El panel "Ver más" muestra únicamente los módulos que NO están en la
    // barra inferior (evita duplicados) respetando los permisos del usuario.
    final moreModules = visible
        .where(
          (item) => !barModules.any((barItem) => barItem.path == item.path),
        )
        .toList();
    final showMore = moreModules.isNotEmpty;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.systemUiOverlayStyle(context),
      child: Scaffold(
        key: shellScaffoldKey,
        backgroundColor: context.colors.background,
        // ── Header único para toda la app ─────────────────────────────
        appBar: AppHeader(
          subtitle: subtitle,
          actions: const [SedeScopeSelector(compact: true), _ProfileButton()],
        ),
        // Panel derecho "Ver más"
        endDrawer: showMore
            ? _MorePanel(
                // El panel replica el sidebar responsive de la web pero solo
                // con los módulos que no están en la barra inferior.
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
  final List<AppDestination> barModules;
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
          color: context.colors.navBackground.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: context.colors.border.withValues(alpha: 0.6),
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
                      label: m.navigationLabel,
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
            color: active ? context.colors.primarySurface : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Icon(
                active ? activeIcon : icon,
                key: ValueKey(active),
                size: 22,
                color: active
                    ? context.colors.navActive
                    : context.colors.navInactive,
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            color: active
                ? context.colors.navActive
                : context.colors.navInactive,
          ),
        ),
      ],
    ),
  );
}

// ─── Secciones del panel "Ver más" ───────────────────────────────────────────

class _Section {
  final String title;
  final List<AppDestination> items;
  const _Section({required this.title, required this.items});
}

List<_Section> _buildSections(List<AppDestination> modules) {
  final paths = modules.map((m) => m.path).toSet();

  List<AppDestination> from(List<String> ps) => appDestinations
      .where((m) => ps.contains(m.path) && paths.contains(m.path))
      .toList();

  final op = from(['/ventas', '/caja', '/movimientos', '/cuentas']);
  final inv = from([
    '/productos',
    '/categorias',
    '/inventario',
    '/kardex',
    '/compras',
  ]);
  final pers = from(['/asistencia']);
  final admin = from([
    '/etiquetas',
    '/usuarios',
    '/sucursales',
    '/roles',
    '/permisos',
    '/auditoria',
    '/seguridad',
  ]);
  final classified = {
    ...op,
    ...inv,
    ...pers,
    ...admin,
    ...modules.where(
      (item) => item.path == '/dashboard' || item.path == '/perfil',
    ),
  }.map((m) => m.path).toSet();
  final other = modules.where((m) => !classified.contains(m.path)).toList();

  return [
    if (op.isNotEmpty) _Section(title: 'OPERACIONES', items: op),
    if (inv.isNotEmpty) _Section(title: 'INVENTARIO', items: inv),
    if (pers.isNotEmpty) _Section(title: 'PERSONAL', items: pers),
    if (admin.isNotEmpty) _Section(title: 'ADMINISTRACIÓN', items: admin),
    if (other.isNotEmpty) _Section(title: 'OTROS', items: other),
  ];
}

// ─── Panel derecho "Ver más" ──────────────────────────────────────────────────

class _MorePanel extends StatefulWidget {
  final List<AppDestination> modules;
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
  State<_MorePanel> createState() => _MorePanelState();
}

class _MorePanelState extends State<_MorePanel> {
  late Map<String, bool> _expanded;

  @override
  void initState() {
    super.initState();
    final currentSection = appDestinationForPath(
      widget.current,
    )?.section?.label;
    _expanded = {
      'OPERACIONES': currentSection == 'OPERACIONES',
      'INVENTARIO': currentSection == 'INVENTARIO',
      'PERSONAL': currentSection == 'PERSONAL',
      'ADMINISTRACIÓN': currentSection == 'ADMINISTRACION',
      'OTROS': currentSection == null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.auth.user;
    final un = user?.username ?? '';
    final rol = user?.rol ?? '';
    final sections = _buildSections(widget.modules);

    return Drawer(
      backgroundColor: context.colors.navBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          bottomLeft: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── Marca + botón de cierre ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 16, 14),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BarBeerWordmark(fontSize: 21),
                        SizedBox(height: 2),
                        Text(
                          'ERP SYSTEM',
                          style: TextStyle(
                            fontSize: 9,
                            letterSpacing: 1.4,
                            color: Color(0xFF7E839E),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: context.colors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Secciones con animación ──────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                children: [
                  ...sections.map((sec) {
                    final isOpen = _expanded[sec.title] ?? false;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _expanded[sec.title] = !isOpen);
                          },
                          splashColor: Colors.transparent,
                          highlightColor: context.colors.primarySurface,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 12, 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    sec.title,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: context.colors.textSecondary
                                          .withValues(alpha: 0.55),
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                AnimatedRotation(
                                  turns: isOpen ? 0.5 : 0,
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOutCubic,
                                  child: Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 18,
                                    color: context.colors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                          child: isOpen
                              ? Column(
                                  children: sec.items.map((module) {
                                    final active = widget.current.startsWith(
                                      module.path,
                                    );
                                    return _PanelItem(
                                      module: module,
                                      active: active,
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        widget.go(module.path);
                                      },
                                    );
                                  }).toList(),
                                )
                              : const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 2),
                      ],
                    );
                  }),
                ],
              ),
            ),

            Divider(height: 1, color: context.colors.border),

            // ── Usuario (enlace al perfil) + Logout ─────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  // Igual que el sidebar web: el área del usuario es un
                  // acceso directo al perfil.
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => widget.go('/perfil'),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            children: [
                              _Avatar(username: un),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      un,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: context.colors.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    _RoleBadge(rol),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.logout,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: context.colors.errorLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: AppColors.error,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _PanelItem extends StatelessWidget {
  final AppDestination module;
  final bool active;
  final VoidCallback onTap;
  const _PanelItem({
    required this.module,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
    child: Material(
      color: active ? AppColors.brand : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 2,
                height: 16,
                margin: const EdgeInsets.only(right: 10),
                color: active
                    ? Colors.black
                    : context.colors.border.withValues(alpha: 0.8),
              ),
              Icon(
                active ? module.activeIcon : module.icon,
                size: 20,
                color: active ? Colors.black : context.colors.textTertiary,
              ),
              const SizedBox(width: 12),
              Text(
                module.label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? Colors.black : context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ─── Botón de perfil en el header móvil ──────────────────────────────────────
// Replica el menú de usuario del header web: acceso directo a /perfil.

class _ProfileButton extends ConsumerWidget {
  const _ProfileButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final username = ref.watch(authProvider).user?.username ?? '';
    final color = AppColors.avatarColor(username);
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Tooltip(
        message: 'Perfil',
        child: GestureDetector(
          key: const Key('header-profile-button'),
          onTap: () {
            HapticFeedback.lightImpact();
            context.go('/perfil');
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ),
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
