import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/app_destinations.dart';
import '../../../../core/providers/theme_mode_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/widgets/barbeer_wordmark.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Texto sobre pildora naranja — replica `--primary-foreground` de la web.
const Color _onActive = Color(0xFF111118);

/// Color naranja con contraste AA para acentos sobre el sidebar:
/// replica `--primary-text` (#ea580c claro / #fb923c oscuro).
Color _primaryText(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? AppColors.primaryLight
        : AppColors.primaryDark;

class DesktopShell extends ConsumerStatefulWidget {
  final Widget child;
  final String currentPath;
  final List<AppDestination> destinations;
  final AuthState auth;
  final ValueChanged<String> onNavigate;
  final VoidCallback onLogout;
  final Widget? headerAction;
  final String? logoUrl;

  const DesktopShell({
    super.key,
    required this.child,
    required this.currentPath,
    required this.destinations,
    required this.auth,
    required this.onNavigate,
    required this.onLogout,
    this.headerAction,
    this.logoUrl,
  });

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final destination = appDestinationForPath(widget.currentPath);
    final title = destination?.routeTitle ?? 'BarBeer';
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      backgroundColor: context.colors.backgroundAlt,
      body: Row(
        children: [
          AnimatedContainer(
            key: const Key('desktop-sidebar'),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: _collapsed ? 68 : 272,
            color: context.colors.navBackground,
            child: _Sidebar(
              collapsed: _collapsed,
              currentPath: widget.currentPath,
              destinations: widget.destinations,
              auth: widget.auth,
              onToggle: () => setState(() => _collapsed = !_collapsed),
              onNavigate: widget.onNavigate,
              logoUrl: widget.logoUrl,
            ),
          ),
          VerticalDivider(width: 1, thickness: 1, color: context.colors.border),
          Expanded(
            child: Column(
              children: [
                Container(
                  key: const Key('desktop-header'),
                  height: 56,
                  color: context.colors.surface,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: context.colors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (widget.headerAction != null) ...[
                        widget.headerAction!,
                        const SizedBox(width: 8),
                      ],
                      _ThemeToggleButton(
                        isDark: isDark,
                        onToggle: () {
                          ref.read(themeModeProvider.notifier).setMode(
                            isDark ? ThemeMode.light : ThemeMode.dark,
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      _UserMenu(
                        auth: widget.auth,
                        onProfile: () => widget.onNavigate('/perfil'),
                        onLogout: widget.onLogout,
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: context.colors.border),
                Expanded(
                  child: ColoredBox(
                    key: const Key('desktop-content'),
                    color: context.colors.backgroundAlt,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1440),
                          child: SizedBox.expand(child: widget.child),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Theme toggle button matching web's bordered Sun/Moon toggle in header.
class _ThemeToggleButton extends StatelessWidget {
  final bool isDark;
  final VoidCallback onToggle;

  const _ThemeToggleButton({required this.isDark, required this.onToggle});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: isDark ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro',
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.colors.border),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              key: ValueKey(isDark),
              size: 17,
              color: context.colors.textSecondary,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Menu de usuario del header — replica el dropdown del header web:
/// avatar naranja + usuario, con "Ver perfil" y "Cerrar sesión".
class _UserMenu extends StatelessWidget {
  final AuthState auth;
  final VoidCallback onProfile;
  final VoidCallback onLogout;

  const _UserMenu({
    required this.auth,
    required this.onProfile,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final username = auth.user?.username ?? 'Usuario';
    final role = FormatUtils.roleName(auth.user?.rol ?? '');
    final initial = username.isEmpty ? '?' : username[0].toUpperCase();

    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(context.colors.surface),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        elevation: WidgetStatePropertyAll(8),
        shadowColor: WidgetStatePropertyAll(const Color(0x33000000)),
        padding: WidgetStatePropertyAll(
          const EdgeInsets.symmetric(vertical: 6),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: context.colors.border),
          ),
        ),
      ),
      menuChildren: [
        SizedBox(
          width: 220,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      role,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _primaryText(context),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: context.colors.border),
              _UserMenuItem(
                icon: Icons.person_outline_rounded,
                label: 'Ver perfil',
                color: context.colors.textPrimary,
                onTap: onProfile,
              ),
              _UserMenuItem(
                icon: Icons.logout_rounded,
                label: 'Cerrar sesión',
                color: AppColors.error,
                onTap: onLogout,
              ),
            ],
          ),
        ),
      ],
      builder: (context, controller, _) => Tooltip(
        message: 'Menú de usuario',
        child: InkWell(
          onTap: () => controller.isOpen
              ? controller.close()
              : controller.open(),
          borderRadius: BorderRadius.circular(8),
          hoverColor: context.colors.surfaceAlt,
          child: Container(
            height: 36,
            padding: const EdgeInsets.only(left: 6, right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DesktopAvatar(initial: initial, size: 28, fontSize: 12),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 128),
                  child: Text(
                    username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: context.colors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _UserMenuItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    hoverColor: context.colors.surfaceAlt,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          Icon(icon, size: 16, color: context.colors.textSecondary),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );
}

class _Sidebar extends StatefulWidget {
  final bool collapsed;
  final String currentPath;
  final List<AppDestination> destinations;
  final AuthState auth;
  final VoidCallback onToggle;
  final ValueChanged<String> onNavigate;
  final String? logoUrl;

  const _Sidebar({
    required this.collapsed,
    required this.currentPath,
    required this.destinations,
    required this.auth,
    required this.onToggle,
    required this.onNavigate,
    this.logoUrl,
  });

  @override
  State<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<_Sidebar> {
  /// Sobreescrituras del usuario sobre el estado de cada acordeon:
  /// null = seguir la seccion activa (igual que `expandedOverrides` de la web).
  final Map<AppDestinationSection, bool> _overrides = {};

  AppDestinationSection? get _activeSection =>
      appDestinationForPath(widget.currentPath)?.section;

  bool _isOpen(AppDestinationSection section) =>
      _overrides[section] ?? section == _activeSection;

  void _toggle(AppDestinationSection section) {
    setState(() => _overrides[section] = !_isOpen(section));
  }

  @override
  Widget build(BuildContext context) {
    final navDestinations = widget.destinations
        .where((destination) => destination.showInDesktopSidebar)
        .toList();
    final root = navDestinations
        .where((destination) => destination.section == null)
        .toList();
    final sections = AppDestinationSection.values
        .map(
          (section) => (
            section: section,
            items: navDestinations
                .where((destination) => destination.section == section)
                .toList(),
          ),
        )
        .where((entry) => entry.items.isNotEmpty)
        .toList();

    return SafeArea(
      child: Column(
        children: [
          _SidebarHeader(
            collapsed: widget.collapsed,
            logoUrl: widget.logoUrl,
            onToggle: widget.onToggle,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              children: [
                // Logo — solo cuando colapsado, igual que la web
                if (widget.collapsed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Center(
                      child: _SidebarLogo(logoUrl: widget.logoUrl, size: 32),
                    ),
                  ),
                ...root.map(
                  (destination) => _SidebarItem(
                    destination: destination,
                    active: destination.isActive(widget.currentPath),
                    collapsed: widget.collapsed,
                    iconSize: 18,
                    onTap: () => widget.onNavigate(destination.path),
                  ),
                ),
                if (!widget.collapsed && root.isNotEmpty)
                  Divider(
                    height: 17,
                    indent: 4,
                    endIndent: 4,
                    color: context.colors.border,
                  ),
                for (final entry in sections)
                  if (entry.items.length == 1)
                    _SingleItemSection(
                      section: entry.section,
                      item: entry.items.first,
                      active: entry.items.first.isActive(widget.currentPath),
                      collapsed: widget.collapsed,
                      onTap: () => widget.onNavigate(entry.items.first.path),
                    )
                  else
                    _AccordionSection(
                      section: entry.section,
                      items: entry.items,
                      active: entry.items.any(
                        (item) => item.isActive(widget.currentPath),
                      ),
                      collapsed: widget.collapsed,
                      open: _isOpen(entry.section),
                      currentPath: widget.currentPath,
                      onToggleSection: () {
                        if (widget.collapsed) widget.onToggle();
                        _toggle(entry.section);
                      },
                      onTapItem: widget.onNavigate,
                    ),
              ],
            ),
          ),
          Divider(height: 1, color: context.colors.border),
          _ProfileFooter(
            collapsed: widget.collapsed,
            active: widget.currentPath.startsWith('/perfil'),
            auth: widget.auth,
            onProfile: () => widget.onNavigate('/perfil'),
          ),
        ],
      ),
    );
  }
}

/// Cabecera del sidebar: wordmark + toggle cuando expandido, toggle centrado
/// cuando colapsado (igual que la web).
class _SidebarHeader extends StatelessWidget {
  final bool collapsed;
  final String? logoUrl;
  final VoidCallback onToggle;

  const _SidebarHeader({
    required this.collapsed,
    required this.logoUrl,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final icon = collapsed
        ? Icons.keyboard_double_arrow_right_rounded
        : Icons.keyboard_double_arrow_left_rounded;

    return SizedBox(
      height: collapsed ? 56 : 72,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: collapsed ? 0 : 16,
          vertical: collapsed ? 12 : 16,
        ),
        child: Row(
          mainAxisAlignment: collapsed
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            if (!collapsed) ...[
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BarBeerWordmark(fontSize: 18),
                    const SizedBox(height: 3),
                    Text(
                      'ERP SYSTEM',
                      style: TextStyle(
                        color: context.colors.textTertiary,
                        fontSize: 9,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ],
            IconButton(
              key: const Key('desktop-sidebar-toggle'),
              tooltip: collapsed
                  ? 'Expandir navegación'
                  : 'Contraer navegación',
              onPressed: onToggle,
              icon: Icon(
                icon,
                size: collapsed ? 18 : 15,
                color: context.colors.navInactive,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Seccion de un solo item: etiqueta + enlace directo (sin acordeon),
/// igual que el grupo PERSONAL de la web.
class _SingleItemSection extends StatelessWidget {
  final AppDestinationSection section;
  final AppDestination item;
  final bool active;
  final bool collapsed;
  final VoidCallback onTap;

  const _SingleItemSection({
    required this.section,
    required this.item,
    required this.active,
    required this.collapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (!collapsed)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
          child: Text(
            section.label,
            style: TextStyle(
              color: context.colors.navInactive,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
      _SidebarItem(
        destination: item,
        active: active,
        collapsed: collapsed,
        iconSize: 18,
        onTap: onTap,
      ),
    ],
  );
}

/// Seccion con acordeon: header (icono + etiqueta + chevron) y sub-items con
/// barra vertical, igual que la web.
class _AccordionSection extends StatelessWidget {
  final AppDestinationSection section;
  final List<AppDestination> items;
  final bool active;
  final bool collapsed;
  final bool open;
  final String currentPath;
  final VoidCallback onToggleSection;
  final ValueChanged<String> onTapItem;

  const _AccordionSection({
    required this.section,
    required this.items,
    required this.active,
    required this.collapsed,
    required this.open,
    required this.currentPath,
    required this.onToggleSection,
    required this.onTapItem,
  });

  @override
  Widget build(BuildContext context) {
    final isOpen = open;
    final textColor = active
        ? _primaryText(context)
        : context.colors.navInactive;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Tooltip(
            message: collapsed ? section.label : '',
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: onToggleSection,
                borderRadius: BorderRadius.circular(8),
                hoverColor: context.colors.surfaceAlt,
                child: Container(
                  height: collapsed ? 40 : 36,
                  padding: EdgeInsets.symmetric(
                    horizontal: collapsed ? 0 : 12,
                  ),
                  child: Row(
                    mainAxisAlignment: collapsed
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                    children: [
                      Icon(
                        section.icon,
                        size: collapsed ? 18 : 14,
                        color: textColor,
                      ),
                      if (!collapsed) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            section.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        AnimatedRotation(
                          turns: isOpen ? 0.5 : 0,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: context.colors.navInactive,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (!collapsed)
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: isOpen
                  ? Column(
                      children: items
                          .map(
                            (item) => _SidebarItem(
                              destination: item,
                              active: item.isActive(currentPath),
                              collapsed: false,
                              iconSize: 16,
                              showBar: true,
                              onTap: () => onTapItem(item.path),
                            ),
                          )
                          .toList(),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ),
      ],
    );
  }
}

/// Item base de navegacion (Dashboard, seccion de un item y sub-item).
class _SidebarItem extends StatelessWidget {
  final AppDestination destination;
  final bool active;
  final bool collapsed;
  final double iconSize;
  final bool showBar;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.destination,
    required this.active,
    required this.collapsed,
    this.iconSize = 18,
    this.showBar = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final idle = context.colors.navInactive;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Tooltip(
        message: collapsed ? destination.desktopNavigationLabel : '',
        child: Material(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            hoverColor: active ? Colors.transparent : context.colors.surfaceAlt,
            child: Container(
              height: 40,
              padding: EdgeInsets.symmetric(
                horizontal: collapsed ? 0 : 12,
              ),
              alignment: collapsed ? Alignment.center : Alignment.centerLeft,
              child: Row(
                mainAxisAlignment: collapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  if (showBar)
                    Container(
                      width: 2,
                      height: 16,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.primary
                            : context.colors.border,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  Icon(
                    active ? destination.activeIcon : destination.icon,
                    size: iconSize,
                    color: active ? _onActive : idle,
                  ),
                  if (!collapsed) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        destination.desktopNavigationLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: active ? _onActive : idle,
                          fontSize: 14,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pie del sidebar: acceso directo al perfil (avatar + usuario + rol).
class _ProfileFooter extends StatelessWidget {
  final bool collapsed;
  final bool active;
  final AuthState auth;
  final VoidCallback onProfile;

  const _ProfileFooter({
    required this.collapsed,
    required this.active,
    required this.auth,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    final username = auth.user?.username ?? 'Usuario';
    final role = FormatUtils.roleName(auth.user?.rol ?? '');
    final initial = username.isEmpty ? '?' : username[0].toUpperCase();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onProfile,
        hoverColor: context.colors.surfaceAlt,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(collapsed ? 12 : 16),
          child: collapsed
              ? Center(
                  child: Tooltip(
                    message: username,
                    child: _DesktopAvatar(initial: initial),
                  ),
                )
              : Row(
                  children: [
                    _DesktopAvatar(initial: initial),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.colors.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            role,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _primaryText(context),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _DesktopAvatar extends StatelessWidget {
  final String initial;
  final double size;
  final double fontSize;

  const _DesktopAvatar({
    required this.initial,
    this.size = 36,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: AppColors.primary,
      shape: BoxShape.circle,
    ),
    child: Text(
      initial,
      style: TextStyle(
        color: _onActive,
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _SidebarLogo extends StatelessWidget {
  final String? logoUrl;
  final double size;

  const _SidebarLogo({required this.logoUrl, required this.size});

  @override
  Widget build(BuildContext context) {
    final fallback = 'assets/images/barbeer_Log.png';
    return logoUrl == null
        ? Image.asset(fallback, width: size, height: size, fit: BoxFit.contain)
        : Image.network(
            logoUrl!,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Image.asset(
              fallback,
              width: size,
              height: size,
              fit: BoxFit.contain,
            ),
          );
  }
}