import 'package:flutter/material.dart';

import '../../../../core/navigation/app_destinations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/widgets/barbeer_wordmark.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class DesktopShell extends StatefulWidget {
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
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final destination = appDestinationForPath(widget.currentPath);
    final title = destination?.routeTitle ?? 'BarBeer';

    return Scaffold(
      backgroundColor: context.colors.backgroundAlt,
      body: Row(
        children: [
          AnimatedContainer(
            key: const Key('desktop-sidebar'),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: _collapsed ? 68 : 272,
            color: context.colors.surface,
            child: _Sidebar(
              collapsed: _collapsed,
              currentPath: widget.currentPath,
              destinations: widget.destinations,
              auth: widget.auth,
              onToggle: () => setState(() => _collapsed = !_collapsed),
              onNavigate: widget.onNavigate,
              onLogout: widget.onLogout,
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
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: context.colors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (widget.headerAction != null) widget.headerAction!,
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

class _Sidebar extends StatelessWidget {
  final bool collapsed;
  final String currentPath;
  final List<AppDestination> destinations;
  final AuthState auth;
  final VoidCallback onToggle;
  final ValueChanged<String> onNavigate;
  final VoidCallback onLogout;
  final String? logoUrl;

  const _Sidebar({
    required this.collapsed,
    required this.currentPath,
    required this.destinations,
    required this.auth,
    required this.onToggle,
    required this.onNavigate,
    required this.onLogout,
    this.logoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final sidebarDestinations = destinations
        .where((destination) => destination.showInDesktopSidebar)
        .toList();
    final dashboard = sidebarDestinations
        .where((destination) => destination.section == null)
        .toList();

    return SafeArea(
      child: Column(
        children: [
          SizedBox(
            height: 64,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: collapsed ? 12 : 16),
              child: Row(
                mainAxisAlignment: collapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  logoUrl == null
                      ? Image.asset(
                          'assets/images/barbeer_Log.png',
                          width: 38,
                          height: 38,
                          fit: BoxFit.contain,
                        )
                      : Image.network(
                          logoUrl!,
                          width: 38,
                          height: 38,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Image.asset(
                            'assets/images/barbeer_Log.png',
                            width: 38,
                            height: 38,
                            fit: BoxFit.contain,
                          ),
                        ),
                  if (!collapsed) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BarBeerWordmark(fontSize: 18),
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
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Align(
              alignment: collapsed ? Alignment.center : Alignment.centerRight,
              child: IconButton(
                key: const Key('desktop-sidebar-toggle'),
                tooltip: collapsed
                    ? 'Expandir navegacion'
                    : 'Contraer navegacion',
                onPressed: onToggle,
                icon: Icon(
                  collapsed
                      ? Icons.keyboard_double_arrow_right_rounded
                      : Icons.keyboard_double_arrow_left_rounded,
                  size: 18,
                  color: context.colors.textSecondary,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              children: [
                ...dashboard.map(
                  (destination) => _DestinationTile(
                    destination: destination,
                    active: destination.isActive(currentPath),
                    collapsed: collapsed,
                    onTap: () => onNavigate(destination.path),
                  ),
                ),
                if (!collapsed) const Divider(height: 20),
                for (final section in AppDestinationSection.values) ...[
                  if (sidebarDestinations.any(
                    (destination) => destination.section == section,
                  )) ...[
                    if (!collapsed)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 5),
                        child: Text(
                          section.label,
                          style: TextStyle(
                            color: context.colors.textTertiary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ...sidebarDestinations
                        .where((destination) => destination.section == section)
                        .map(
                          (destination) => _DestinationTile(
                            destination: destination,
                            active: destination.isActive(currentPath),
                            collapsed: collapsed,
                            onTap: () => onNavigate(destination.path),
                          ),
                        ),
                  ],
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          _ProfileArea(
            collapsed: collapsed,
            active: currentPath.startsWith('/perfil'),
            auth: auth,
            onProfile: () => onNavigate('/perfil'),
            onLogout: onLogout,
          ),
        ],
      ),
    );
  }
}

class _DestinationTile extends StatelessWidget {
  final AppDestination destination;
  final bool active;
  final bool collapsed;
  final VoidCallback onTap;

  const _DestinationTile({
    required this.destination,
    required this.active,
    required this.collapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Tooltip(
      message: collapsed ? destination.desktopNavigationLabel : '',
      child: Material(
        color: active ? context.colors.brand : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: SizedBox(
            height: 44,
            child: Row(
              mainAxisAlignment: collapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                if (!collapsed) const SizedBox(width: 12),
                Icon(
                  active ? destination.activeIcon : destination.icon,
                  size: 19,
                  color: active
                      ? Theme.of(context).colorScheme.onSecondary
                      : context.colors.textSecondary,
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      destination.desktopNavigationLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: active
                            ? Theme.of(context).colorScheme.onSecondary
                            : context.colors.textSecondary,
                        fontSize: 14,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ProfileArea extends StatelessWidget {
  final bool collapsed;
  final bool active;
  final AuthState auth;
  final VoidCallback onProfile;
  final VoidCallback onLogout;

  const _ProfileArea({
    required this.collapsed,
    required this.active,
    required this.auth,
    required this.onProfile,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final username = auth.user?.username ?? 'Usuario';
    final role = FormatUtils.roleName(auth.user?.rol ?? '');
    final initial = username.isEmpty ? '?' : username[0].toUpperCase();

    return Padding(
      padding: EdgeInsets.all(collapsed ? 8 : 12),
      child: collapsed
          ? Column(
              children: [
                Tooltip(
                  message: username,
                  child: InkWell(
                    onTap: onProfile,
                    borderRadius: BorderRadius.circular(24),
                    child: _DesktopAvatar(initial: initial, active: active),
                  ),
                ),
                const SizedBox(height: 6),
                IconButton(
                  tooltip: 'Cerrar sesion',
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout_rounded, size: 19),
                  color: AppColors.error,
                ),
              ],
            )
          : Row(
              children: [
                InkWell(
                  onTap: onProfile,
                  borderRadius: BorderRadius.circular(24),
                  child: _DesktopAvatar(initial: initial, active: active),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: onProfile,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.colors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          role,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.brand,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar sesion',
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout_rounded, size: 19),
                  color: AppColors.error,
                ),
              ],
            ),
    );
  }
}

class _DesktopAvatar extends StatelessWidget {
  final String initial;
  final bool active;

  const _DesktopAvatar({required this.initial, required this.active});

  @override
  Widget build(BuildContext context) => Container(
    width: 38,
    height: 38,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.brand,
      shape: BoxShape.circle,
      border: active
          ? Border.all(color: context.colors.textPrimary, width: 2)
          : null,
    ),
    child: Text(
      initial,
      style: const TextStyle(
        color: Color(0xFF191511),
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}
