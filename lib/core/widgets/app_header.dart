import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

/// Header global fijo BarBeer — siempre visible, no se va con scroll.
///
/// En Inicio muestra el rol (Superadmin en naranja).
/// En otras pantallas muestra el nombre del módulo (Ventas, Caja, etc.)
/// Subpantallas: flecha ← + título.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String? subtitle; // Superadmin, Ventas, Caja...
  final bool showBackButton;
  final VoidCallback? onBackTap;
  final List<Widget>? actions;

  const AppHeader({
    super.key,
    this.subtitle,
    this.showBackButton = false,
    this.onBackTap,
    this.actions,
  });

  // Shortcuts para módulos
  const AppHeader.module(String moduleName, {super.key, this.actions})
    : subtitle = moduleName,
      showBackButton = false,
      onBackTap = null;

  const AppHeader.back(String title, {super.key, this.onBackTap, this.actions})
    : subtitle = title,
      showBackButton = true;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // ── Leading ──
                if (showBackButton)
                  _BackBtn(
                    onTap: onBackTap ?? () => Navigator.of(context).pop(),
                  )
                else
                  const SizedBox(width: 4),

                // ── BarBeer + subtítulo ──
                Expanded(
                  child: showBackButton
                      ? Text(
                          subtitle ?? '',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            RichText(
                              text: const TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Bar',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.textPrimary,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'Beer',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.brand,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (subtitle != null)
                              Text(
                                subtitle!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.brand,
                                  height: 1.3,
                                ),
                              ),
                          ],
                        ),
                ),

                // ── Actions ──
                if (actions != null) ...actions!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BackBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _BackBtn({required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      HapticFeedback.lightImpact();
      onTap();
    },
    behavior: HitTestBehavior.opaque,
    child: const SizedBox(
      width: 44,
      height: 44,
      child: Center(
        child: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: AppColors.textPrimary,
        ),
      ),
    ),
  );
}
