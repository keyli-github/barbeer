import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// AppHeader unificado para toda la aplicación BarBeer
///
/// Pantallas principales: logo BarBeer + subtítulo de rol + hamburger (si hay drawer)
/// Subpantallas: flecha atrás + título + acciones
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
  final bool isMainScreen; // true = muestra logo BarBeer en lugar del título

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
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                // ── Leading ──────────────────────────────────────────────
                _buildLeading(context),

                // ── Título ───────────────────────────────────────────────
                Expanded(
                  child: isMainScreen ? _buildBrandTitle() : _buildTitle(),
                ),

                // ── Acciones ─────────────────────────────────────────────
                if (actions != null)
                  ...actions!.map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(left: 4),
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

    if (showBackButton) {
      return IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: AppColors.textPrimary,
        ),
        onPressed: onBackTap ?? () => Navigator.of(context).pop(),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      );
    }

    // Hamburger — solo visible si el Scaffold tiene drawer
    return Builder(
      builder: (ctx) {
        final scaffold = Scaffold.maybeOf(ctx);
        final hasDrawer = scaffold?.hasDrawer ?? false;
        if (!hasDrawer) return const SizedBox(width: 4);
        return IconButton(
          icon: const Icon(
            Icons.menu_rounded,
            size: 22,
            color: AppColors.textPrimary,
          ),
          onPressed: () => scaffold!.openDrawer(),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        );
      },
    );
  }

  // Logo "BarBeer" estilo referencia
  Widget _buildBrandTitle() {
    return Row(
      children: [
        const SizedBox(width: 4),
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

  // Título normal para pantallas secundarias
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
