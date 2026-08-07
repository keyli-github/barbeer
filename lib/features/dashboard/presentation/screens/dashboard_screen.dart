import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/widgets/ds_card.dart';
import '../../../../core/widgets/ds_states.dart';
import '../../../../core/widgets/ds_list_tile.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../caja/presentation/providers/caja_provider.dart';
import '../providers/dashboard_provider.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final rol = user?.rol.toUpperCase() ?? '';

    return Scaffold(
      backgroundColor: AppColors.backgroundAlt,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(dashboardProvider.notifier).load(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _SliverHeader(user: user),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),

            // Contenido por rol
            if (rol == 'SUPERADMIN' || rol == 'ADMIN')
              _AdminContent(rol: rol, ref: ref, auth: auth)
            else if (rol == 'CAJERO')
              _CajeroContent(ref: ref, auth: auth)
            else
              _VendedoraContent(ref: ref, auth: auth),

            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }
}

// ─── Header Sliver ───────────────────────────────────────────────────────────

class _SliverHeader extends StatelessWidget {
  final dynamic user;
  const _SliverHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    final un = user?.username ?? '';
    final rol = user?.rol ?? '';
    final sede = user?.sede;

    return SliverToBoxAdapter(
      child: Container(
        color: AppColors.background,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          MediaQuery.of(context).padding.top + AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Row(
          children: [
            // Avatar
            Builder(
              builder: (ctx) {
                final color = AppColors.avatarColor(un);
                final initial = un.isNotEmpty ? un[0].toUpperCase() : '?';
                return Container(
                  width: 44,
                  height: 44,
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
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo BarBeer
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'Bar',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            height: 1.1,
                          ),
                        ),
                        TextSpan(
                          text: 'Beer',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.brand,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      _RolTag(rol),
                      if (sede != null) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            sede,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Botón perfil
            _HeaderAction(
              icon: Icons.person_outline_rounded,
              onTap: () => GoRouter.of(context).go('/perfil'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RolTag extends StatelessWidget {
  final String rol;
  const _RolTag(this.rol);
  @override
  Widget build(BuildContext context) {
    final color = AppColors.roleColor(rol);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        rol.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderAction({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      HapticFeedback.lightImpact();
      onTap();
    },
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: AppColors.textSecondary),
    ),
  );
}

// ─── ADMIN / SUPERADMIN ───────────────────────────────────────────────────────

class _AdminContent extends StatelessWidget {
  final String rol;
  final WidgetRef ref;
  final AuthState auth;
  const _AdminContent({
    required this.rol,
    required this.ref,
    required this.auth,
  });

  @override
  Widget build(BuildContext context) {
    final dash = ref.watch(dashboardProvider);

    if (dash.isLoading)
      return const SliverToBoxAdapter(child: DSSkeletonList(count: 6));
    if (dash.error != null && dash.data == null) {
      return SliverToBoxAdapter(
        child: DSErrorState(
          message: dash.error,
          onRetry: () => ref.read(dashboardProvider.notifier).load(),
        ),
      );
    }

    final data = dash.data;
    final sedes = data?.sedes ?? [];
    final users = data?.users ?? [];
    final audit = data?.audit ?? [];

    final sedesActivas = sedes.where((s) => s['activo'] == true).length;
    final usersActivos = users.where((u) => u['activo'] == true).length;

    return SliverList(
      delegate: SliverChildListDelegate([
        // ── KPIs ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: DSStatCard(
                  label: 'Sedes activas',
                  value: '$sedesActivas',
                  icon: Icons.store_rounded,
                  iconColor: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: DSStatCard(
                  label: 'Usuarios activos',
                  value: '$usersActivos',
                  icon: Icons.people_rounded,
                  iconColor: AppColors.success,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // ── Accesos rápidos ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: _QuickActions(auth: auth),
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Sedes recientes ───────────────────────────────────────────────
        if (sedes.isNotEmpty) ...[
          _SectionTitle(
            'Sedes',
            action: 'Ver todas',
            onAction: auth.hasPermission('establecimientos:leer')
                ? () => GoRouter.of(context).go('/sucursales')
                : null,
          ),
          ...sedes.take(3).map((s) => _SedeRow(sede: s)),
          const SizedBox(height: AppSpacing.md),
        ],

        // ── Actividad reciente ────────────────────────────────────────────
        if (audit.isNotEmpty) ...[
          _SectionTitle(
            'Actividad reciente',
            action: 'Ver todo',
            onAction: auth.hasPermission('audit:leer')
                ? () => GoRouter.of(context).go('/auditoria')
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: DSCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: audit.take(5).toList().asMap().entries.map((e) {
                  final i = e.key;
                  final log = e.value as Map;
                  return Column(
                    children: [
                      _AuditRow(log: log),
                      if (i < (audit.take(5).length - 1))
                        const Divider(height: 1, indent: 56),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

// ─── CAJERO ──────────────────────────────────────────────────────────────────

class _CajeroContent extends StatelessWidget {
  final WidgetRef ref;
  final AuthState auth;
  const _CajeroContent({required this.ref, required this.auth});

  @override
  Widget build(BuildContext context) {
    final cajaState = ref.watch(cajaProvider);
    final actual = cajaState.actual;

    return SliverList(
      delegate: SliverChildListDelegate([
        // ── Estado de caja ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: _CajaStatusCard(actual: actual, loading: cajaState.isLoading),
        ),
        const SizedBox(height: AppSpacing.sm),

        // ── Accesos rápidos cajero ────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: _QuickActions(auth: auth),
        ),
        const SizedBox(height: AppSpacing.md),

        // ── KPIs si hay caja abierta ──────────────────────────────────────
        if (actual != null && actual.resumen != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: DSStatCard(
                    label: 'Ventas neto',
                    value: FormatUtils.currency(
                      actual.resumen!.v2?.totalVentasNeto ?? 0,
                    ),
                    icon: Icons.receipt_rounded,
                    iconColor: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: DSStatCard(
                    label: 'Pendientes',
                    value: '${actual.resumen!.ventasPendientes}',
                    icon: Icons.pending_actions_rounded,
                    iconColor: actual.resumen!.ventasPendientes > 0
                        ? AppColors.warning
                        : AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: DSStatCard(
                    label: 'Efectivo esperado',
                    value: FormatUtils.currency(
                      actual.resumen!.efectivoEsperado,
                    ),
                    icon: Icons.payments_rounded,
                    iconColor: AppColors.success,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: DSStatCard(
                    label: 'Digital neto',
                    value: FormatUtils.currency(
                      actual.resumen!.v2?.totalDigitalNeto ?? 0,
                    ),
                    icon: Icons.phone_android_rounded,
                    iconColor: AppColors.info,
                  ),
                ),
              ],
            ),
          ),
        ],
      ]),
    );
  }
}

// ─── VENDEDORA ────────────────────────────────────────────────────────────────

class _VendedoraContent extends StatelessWidget {
  final WidgetRef ref;
  final AuthState auth;
  const _VendedoraContent({required this.ref, required this.auth});

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildListDelegate([
        // ── Acceso rápido: nueva venta ────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              GoRouter.of(context).go('/ventas');
            },
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF1D4ED8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Text(
                    'Nueva venta',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // ── Mis ventas rápido ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: _QuickActions(auth: auth),
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Estado vacío con guía ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: DSCard(
            child: Column(
              children: [
                Icon(
                  Icons.storefront_rounded,
                  size: 48,
                  color: AppColors.primary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Registra ventas fácilmente',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Usa el botón "Nueva venta" o ve a la sección Ventas desde la barra inferior.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

// ─── Widgets auxiliares ───────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const _SectionTitle(this.title, {this.action, this.onAction});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      0,
      AppSpacing.md,
      AppSpacing.xs,
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ),
        if (action != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              action!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ),
      ],
    ),
  );
}

class _SedeRow extends StatelessWidget {
  final Map sede;
  const _SedeRow({required this.sede});
  @override
  Widget build(BuildContext context) {
    final activo = sede['activo'] == true;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: DSCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.store_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sede['nombre'] as String? ?? '—',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    sede['codigo'] as String? ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (activo ? AppColors.success : AppColors.textTertiary)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                activo ? 'Activa' : 'Inactiva',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: activo ? AppColors.success : AppColors.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditRow extends StatelessWidget {
  final Map log;
  const _AuditRow({required this.log});
  @override
  Widget build(BuildContext context) {
    final accion = log['accion'] as String? ?? '';
    final usuario = log['username'] as String? ?? '';
    final ts = log['createdAt'] as String?;
    DateTime? dt;
    try {
      dt = ts != null ? DateTime.parse(ts) : null;
    } catch (_) {}
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.history_rounded,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  accion,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  usuario,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          if (dt != null)
            Text(
              FormatUtils.timeAgo(dt),
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
        ],
      ),
    );
  }
}

class _CajaStatusCard extends StatelessWidget {
  final dynamic actual;
  final bool loading;
  const _CajaStatusCard({required this.actual, required this.loading});
  @override
  Widget build(BuildContext context) {
    if (loading) return const DSSkeleton(height: 80, radius: 14);
    final abierta = actual != null;
    return DSCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (abierta ? AppColors.success : AppColors.textTertiary)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              abierta
                  ? Icons.account_balance_wallet_rounded
                  : Icons.wallet_rounded,
              color: abierta ? AppColors.success : AppColors.textTertiary,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  abierta ? 'Caja abierta' : 'Caja cerrada',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: abierta
                        ? AppColors.success
                        : AppColors.textSecondary,
                  ),
                ),
                if (abierta && actual.apertura != null)
                  Text(
                    'Apertura: ${FormatUtils.currency(actual.apertura!)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final AuthState auth;
  const _QuickActions({required this.auth});

  @override
  Widget build(BuildContext context) {
    final actions = <_QA>[];

    if (auth.hasPermission('ventas:leer') ||
        auth.hasPermission('ventas:leer-propias'))
      actions.add(
        _QA(
          'Ventas',
          Icons.shopping_cart_rounded,
          AppColors.primary,
          '/ventas',
        ),
      );
    if (auth.hasPermission('caja:leer'))
      actions.add(
        _QA(
          'Caja',
          Icons.account_balance_wallet_rounded,
          AppColors.success,
          '/caja',
        ),
      );
    if (auth.hasPermission('productos:crear'))
      actions.add(
        _QA('Productos', Icons.liquor_rounded, AppColors.brand, '/productos'),
      );
    if (auth.hasPermission('inventario:leer'))
      actions.add(
        _QA(
          'Inventario',
          Icons.inventory_2_rounded,
          AppColors.info,
          '/inventario',
        ),
      );
    if (auth.hasPermission('usuarios:leer'))
      actions.add(
        _QA('Usuarios', Icons.people_rounded, AppColors.warning, '/usuarios'),
      );

    if (actions.isEmpty) return const SizedBox.shrink();

    return Row(
      children: actions
          .take(4)
          .map(
            (a) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: actions.indexOf(a) < actions.take(4).length - 1
                      ? 8
                      : 0,
                ),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    GoRouter.of(context).go(a.path);
                  },
                  child: Container(
                    height: 72,
                    decoration: BoxDecoration(
                      color: a.color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
                      border: Border.all(
                        color: a.color.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(a.icon, color: a.color, size: 24),
                        const SizedBox(height: 4),
                        Text(
                          a.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: a.color,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _QA {
  final String label, path;
  final IconData icon;
  final Color color;
  const _QA(this.label, this.icon, this.color, this.path);
}
