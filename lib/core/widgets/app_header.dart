import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'drawer_scope.dart';

/// AppHeader unificado para toda la aplicación BarBeer
///
/// - Pantallas principales (isMainScreen=true): logo BarBeer + hamburger si hay drawer
/// - Subpantallas: flecha atrás + título + acciones
///
/// El hamburger detecta el drawer via [DrawerScope] (propagado desde ShellScreen),
/// no via Scaffold.maybeOf — esto garantiza que funcione aunque la pantalla
/// tenga su propio Scaffold interno (sin drawer).
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final bool showBackButton;
  final VoidCallback? onBackTap;
  final List<Widget>? actions;
  final Widget? leading;
  final Color? backgroundColor;
  final bool showShadow;
  final bool centerTitle;
  final bool isMainScreen;

  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showBackButton = false,
    this.onBackTap,
    this.actions,
    this.leading,
    this.backgroundColor,
    this.showShadow = false,
    this.centerTitle = false,
    this.isMainScreen = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: showShadow ? AppColors.border : Colors.transparent,
            width: 0.75,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Row(
              children: [
                // ── Leading ──────────────────────────────────────────────
                _buildLeading(context),

                // ── Título ───────────────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: isMainScreen ? _buildBrandTitle() : _buildTitle(),
                  ),
                ),

                // ── Acciones ─────────────────────────────────────────────
                if (actions != null)
                  ...actions!.map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: a,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeading(BuildContext context) {
    if (leading != null) return leading!;

    // Subpantalla → flecha atrás
    if (showBackButton) {
      return _HeaderBtn(
        icon: Icons.arrow_back_ios_new_rounded,
        onTap: onBackTap ?? () => Navigator.of(context).pop(),
      );
    }

    // Pantalla principal → hamburger via DrawerScope
    final scope = DrawerScope.maybeOf(context);
    if (scope != null && scope.hasDrawer) {
      return _HeaderBtn(
        icon: Icons.menu_rounded,
        onTap: () {
          HapticFeedback.lightImpact();
          scope.openDrawer();
        },
      );
    }

    return const SizedBox(width: 8);
  }

  Widget _buildBrandTitle() {
    return Row(
      children: [
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Bar',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              TextSpan(
                text: 'Beer',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.brand,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.brand,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTitle() {
    if (subtitle != null) {
      return Column(
        crossAxisAlignment: centerTitle
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      );
    }
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.3,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ─── Botón de header compacto (hamburger / flecha) ────────────────────────────

class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Icon(icon, size: 22, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
