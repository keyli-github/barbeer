import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final data = ref.watch(dashboardProvider);
    final user = auth.user;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(dashboardProvider.notifier).load(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Header fijo con logo y avatar ──
            SliverToBoxAdapter(
              child: _DashHeader(user: user, data: data),
            ),

            // ── Selector de sede ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: _SedeCard(data: data, ref: ref, auth: auth),
              ),
            ),

            // ── KPI Grid 2×2 ──
            if (!data.loading)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                sliver: SliverToBoxAdapter(
                  child: _KpiGrid(data: data, auth: auth, context: context),
                ),
              )
            else
              SliverToBoxAdapter(child: _KpiSkeleton()),

            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),

            // ── Gráfica de ventas ──
            if (!data.loading &&
                (auth.hasPermission('ventas:leer') ||
                    auth.hasPermission('ventas:leer-propias')))
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                sliver: SliverToBoxAdapter(child: _SalesChart(data: data)),
              ),

            // ── Actividad reciente ──
            if (data.audit.isNotEmpty)
              SliverToBoxAdapter(child: _RecentActivity(audit: data.audit)),

            // ── Accesos rápidos ──
            SliverToBoxAdapter(child: _QuickAccess(auth: auth)),

            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _DashHeader extends StatelessWidget {
  final dynamic user;
  final DashboardData data;
  const _DashHeader({required this.user, required this.data});

  @override
  Widget build(BuildContext context) {
    final un = user?.username ?? '';
    final rol = user?.rol ?? '';
    final top = MediaQuery.of(context).padding.top;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(AppSpacing.md, top + 12, AppSpacing.md, 12),
      child: Row(
        children: [
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
                const SizedBox(height: 2),
                // Badge de rol naranja
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.roleColor(rol).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    FormatUtils.roleName(rol),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.roleColor(rol),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Avatar del usuario (foto o iniciales)
          _UserAvatar(username: un),
        ],
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final String username;
  const _UserAvatar({required this.username});
  @override
  Widget build(BuildContext context) {
    final color = AppColors.avatarColor(username);
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';
    return GestureDetector(
      onTap: () => GoRouter.of(context).go('/perfil'),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Center(
          child: Text(
            initial,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Selector de sede ─────────────────────────────────────────────────────────

class _SedeCard extends StatelessWidget {
  final DashboardData data;
  final WidgetRef ref;
  final AuthState auth;
  const _SedeCard({required this.data, required this.ref, required this.auth});

  bool get canSelectSede =>
      auth.user?.isSuperAdmin == true && data.sedes.isNotEmpty;

  String get sedeName {
    if (data.selectedSede != null) return data.selectedSede!.nombre;
    if (auth.user?.sede != null) return auth.user!.sede!;
    return 'Sin sede asignada';
  }

  String get sedeCode {
    if (data.selectedSede != null) return data.selectedSede!.codigo;
    return '';
  }

  bool get cajaAbierta => data.cajaActual?.isAbierta ?? false;

  void _showSedePicker(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SedePickerSheet(
        sedes: data.sedes,
        selectedId: data.selectedSedeId,
        onSelect: (id) {
          ref.read(dashboardProvider.notifier).selectSede(id);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: canSelectSede ? () => _showSedePicker(context) : null,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 0.75),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            // Icono sede
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.store_rounded,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sedeName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: cajaAbierta
                              ? AppColors.success
                              : AppColors.textTertiary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        cajaAbierta ? 'Abierto' : 'Cerrado',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: cajaAbierta
                              ? AppColors.success
                              : AppColors.textTertiary,
                        ),
                      ),
                      if (sedeCode.isNotEmpty) ...[
                        const Text(
                          ' • ',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        Text(
                          sedeCode,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (canSelectSede)
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.textTertiary,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Picker de sedes ──────────────────────────────────────────────────────────

class _SedePickerSheet extends StatelessWidget {
  final List<DashboardSede> sedes;
  final String? selectedId;
  final ValueChanged<String?> onSelect;
  const _SedePickerSheet({
    required this.sedes,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Seleccionar sede',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          // Opción "Todas"
          _SedeOption(
            name: 'Todas las sedes',
            code: '',
            active: true,
            selected: selectedId == null,
            onTap: () => onSelect(null),
          ),
          ...sedes.map(
            (s) => _SedeOption(
              name: s.nombre,
              code: s.codigo,
              active: s.activo,
              selected: selectedId == s.id,
              onTap: () => onSelect(s.id),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}

class _SedeOption extends StatelessWidget {
  final String name, code;
  final bool active, selected;
  final VoidCallback onTap;
  const _SedeOption({
    required this.name,
    required this.code,
    required this.active,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (code.isNotEmpty)
                  Text(
                    'ID $code',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: active ? AppColors.success : AppColors.textTertiary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          if (selected)
            const Icon(Icons.check_rounded, color: AppColors.primary, size: 20),
        ],
      ),
    ),
  );
}

// ─── KPI Grid 2×2 ─────────────────────────────────────────────────────────────

class _KpiGrid extends StatelessWidget {
  final DashboardData data;
  final AuthState auth;
  final BuildContext context;
  const _KpiGrid({
    required this.data,
    required this.auth,
    required this.context,
  });

  @override
  Widget build(BuildContext context) {
    final cards = <_KpiCardData>[];

    // Ventas del día — visible si puede leer ventas
    if (auth.hasPermission('ventas:leer') ||
        auth.hasPermission('ventas:leer-propias')) {
      final pct = data.variacionVsAyer;
      cards.add(
        _KpiCardData(
          label: 'Ventas del día',
          value: FormatUtils.currency(data.ventasHoy),
          sub: pct != 0
              ? '${pct >= 0 ? '↑' : '↓'} ${pct.abs().toStringAsFixed(1)}% vs ayer'
              : '${data.ventasCountHoy} transacciones',
          subPositive: pct >= 0,
          icon: Icons.bar_chart_rounded,
          iconColor: AppColors.primary,
          iconBg: AppColors.primarySurface,
          onTap: () => GoRouter.of(context).go('/ventas'),
        ),
      );
    }

    // Caja activa
    if (auth.hasPermission('caja:leer')) {
      cards.add(
        _KpiCardData(
          label: 'Caja activa',
          value: data.cajaActual?.isAbierta == true
              ? FormatUtils.currency(data.cajaActual!.montoApertura)
              : 'Cerrada',
          sub: data.cajaActual?.isAbierta == true
              ? 'Apertura: ${FormatUtils.currency(data.cajaActual!.montoApertura)}'
              : 'Sin turno abierto',
          subPositive: data.cajaActual?.isAbierta == true,
          icon: Icons.account_balance_wallet_rounded,
          iconColor: const Color(0xFFFF9500),
          iconBg: const Color(0xFFFFF3E0),
          onTap: () => GoRouter.of(context).go('/caja'),
        ),
      );
    }

    // Stock bajo
    if (auth.hasPermission('inventario:leer')) {
      cards.add(
        _KpiCardData(
          label: 'Stock bajo',
          value: '${data.stockBajo}',
          sub: data.stockBajo > 0 ? 'Ver productos' : 'Todo en orden',
          subPositive: data.stockBajo == 0,
          subAction: data.stockBajo > 0
              ? () => GoRouter.of(context).go('/inventario')
              : null,
          icon: Icons.inventory_2_rounded,
          iconColor: data.stockBajo > 0 ? AppColors.error : AppColors.success,
          iconBg: data.stockBajo > 0
              ? AppColors.errorLight
              : AppColors.successLight,
          onTap: () => GoRouter.of(context).go('/inventario'),
        ),
      );
    }

    // Sedes activas
    if (auth.hasPermission('establecimientos:leer') && data.sedesTotal > 0) {
      final pct = data.sedesTotal > 0
          ? (data.sedesActivas / data.sedesTotal * 100).round()
          : 0;
      cards.add(
        _KpiCardData(
          label: 'Sedes activas',
          value: '${data.sedesActivas} / ${data.sedesTotal}',
          sub: '$pct% operativas',
          subPositive: pct >= 80,
          icon: Icons.store_rounded,
          iconColor: AppColors.success,
          iconBg: AppColors.successLight,
          onTap: () => GoRouter.of(context).go('/sucursales'),
        ),
      );
    }

    // Mis ventas del mes (vendedora/cajero sin los otros permisos)
    if (cards.length < 2 &&
        (auth.hasPermission('ventas:leer-propias') ||
            auth.hasPermission('ventas:leer'))) {
      cards.add(
        _KpiCardData(
          label: 'Total del mes',
          value: FormatUtils.currency(data.misTotalesMes),
          sub: '${data.misVentasMes} ventas',
          subPositive: true,
          icon: Icons.calendar_month_rounded,
          iconColor: AppColors.info,
          iconBg: AppColors.infoLight,
          onTap: () => GoRouter.of(context).go('/ventas'),
        ),
      );
    }

    if (cards.isEmpty) return const SizedBox.shrink();

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.55,
      children: cards.map((c) => _KpiCard(card: c)).toList(),
    );
  }
}

class _KpiCardData {
  final String label, value, sub;
  final bool subPositive;
  final VoidCallback? subAction;
  final IconData icon;
  final Color iconColor, iconBg;
  final VoidCallback? onTap;
  const _KpiCardData({
    required this.label,
    required this.value,
    required this.sub,
    required this.subPositive,
    this.subAction,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    this.onTap,
  });
}

class _KpiCard extends StatelessWidget {
  final _KpiCardData card;
  const _KpiCard({required this.card});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      HapticFeedback.lightImpact();
      card.onTap?.call();
    },
    child: Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.75),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: card.iconBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(card.icon, color: card.iconColor, size: 17),
              ),
              const Spacer(),
              const Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: AppColors.textTertiary,
              ),
            ],
          ),
          const Spacer(),
          Text(
            card.label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            card.value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          GestureDetector(
            onTap: card.subAction,
            child: Text(
              card.sub,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: card.subAction != null
                    ? AppColors.primary
                    : (card.subPositive ? AppColors.success : AppColors.error),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ),
  );
}

class _KpiSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    child: GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.55,
      children: List.generate(
        4,
        (_) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 0.75),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Bone(w: 32, h: 32, r: 9),
              const Spacer(),
              _Bone(w: 80, h: 10),
              const SizedBox(height: 4),
              _Bone(w: 100, h: 16),
              const SizedBox(height: 4),
              _Bone(w: 60, h: 10),
            ],
          ),
        ),
      ),
    ),
  );
}

// ─── Gráfica ventas 7 días ────────────────────────────────────────────────────

class _SalesChart extends StatelessWidget {
  final DashboardData data;
  const _SalesChart({required this.data});

  static const _days = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  List<String> _labels() {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return _days[d.weekday - 1];
    });
  }

  @override
  Widget build(BuildContext context) {
    final vals = data.ventasSemana;
    final maxVal = vals.fold(0.0, (m, v) => v > m ? v : m);
    final labels = _labels();
    final pct = data.variacionSemana;
    final total = data.totalSemana;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.75),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ventas últimos 7 días',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      FormatUtils.currency(total),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (pct != 0)
                      Row(
                        children: [
                          Icon(
                            pct >= 0
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            size: 12,
                            color: pct >= 0
                                ? AppColors.success
                                : AppColors.error,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${pct.abs().toStringAsFixed(1)}% vs semana anterior',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: pct >= 0
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Gráfica
          SizedBox(
            height: 140,
            child: BarChart(
              BarChartData(
                maxY: maxVal == 0 ? 100 : maxVal * 1.25,
                minY: 0,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxVal == 0 ? 50 : maxVal * 1.25 / 3,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: Color(0xFFF3F4F6), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= 7) return const SizedBox.shrink();
                        final isToday = i == 6;
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            labels[i],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isToday
                                  ? FontWeight.w800
                                  : FontWeight.w400,
                              color: isToday
                                  ? AppColors.primary
                                  : AppColors.textTertiary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(7, (i) {
                  final isToday = i == 6;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: vals[i],
                        color: isToday
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: 0.25),
                        width: 28,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(7),
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxVal == 0 ? 100 : maxVal * 1.25,
                          color: const Color(0xFFF5F6FA),
                        ),
                      ),
                    ],
                  );
                }),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.textPrimary,
                    getTooltipItem: (_, __, rod, ___) => BarTooltipItem(
                      'S/ ${rod.toY.toStringAsFixed(0)}',
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Actividad reciente ───────────────────────────────────────────────────────

class _RecentActivity extends StatelessWidget {
  final List<Map<String, dynamic>> audit;
  const _RecentActivity({required this.audit});

  static IconData _icon(String accion) {
    if (accion.contains('COMPRA')) return Icons.local_shipping_rounded;
    if (accion.contains('STOCK') || accion.contains('INVENTARIO'))
      return Icons.warning_amber_rounded;
    if (accion.contains('CAJA') || accion.contains('APERTURA'))
      return Icons.account_balance_wallet_rounded;
    if (accion.contains('VENTA')) return Icons.shopping_cart_rounded;
    if (accion.contains('USUARIO')) return Icons.person_rounded;
    return Icons.history_rounded;
  }

  static Color _color(String accion) {
    if (accion.contains('ELIMINAR') || accion.contains('CRITICO'))
      return AppColors.error;
    if (accion.contains('STOCK') || accion.contains('ALERTA'))
      return AppColors.warning;
    if (accion.contains('CREAR') || accion.contains('APERTURA'))
      return AppColors.success;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Actividad reciente',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              if (context.findAncestorWidgetOfExactType<ConsumerWidget>() !=
                  null)
                GestureDetector(
                  onTap: () => GoRouter.of(context).go('/auditoria'),
                  child: const Text(
                    'Ver todo',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 0.75),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              children: audit.take(5).toList().asMap().entries.map((e) {
                final i = e.key;
                final log = e.value;
                final accion = log['accion'] as String? ?? '';
                final user = log['username'] as String? ?? '';
                final ts = log['createdAt'] as String?;
                DateTime? dt;
                try {
                  dt = ts != null ? DateTime.parse(ts) : null;
                } catch (_) {}
                final color = _color(accion);

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(_icon(accion), color: color, size: 18),
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
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  user,
                                  style: const TextStyle(
                                    fontSize: 11,
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
                                fontSize: 10.5,
                                color: AppColors.textTertiary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (i < (audit.take(5).length - 1))
                      const Divider(
                        height: 1,
                        indent: 64,
                        color: AppColors.borderLight,
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Accesos rápidos ──────────────────────────────────────────────────────────

class _QuickAccess extends StatelessWidget {
  final AuthState auth;
  const _QuickAccess({required this.auth});

  @override
  Widget build(BuildContext context) {
    final items = <_QA>[];
    if (auth.hasPermission('ventas:leer') ||
        auth.hasPermission('ventas:leer-propias'))
      items.add(
        _QA(
          'Ventas',
          Icons.shopping_cart_rounded,
          AppColors.primary,
          '/ventas',
        ),
      );
    if (auth.hasPermission('productos:crear'))
      items.add(
        _QA('Productos', Icons.liquor_rounded, AppColors.brand, '/productos'),
      );
    if (auth.hasPermission('inventario:leer'))
      items.add(
        _QA(
          'Inventario',
          Icons.inventory_2_rounded,
          AppColors.success,
          '/inventario',
        ),
      );
    if (auth.hasPermission('caja:leer'))
      items.add(
        _QA(
          'Arqueo',
          Icons.account_balance_wallet_rounded,
          const Color(0xFFFF9500),
          '/caja',
        ),
      );
    if (auth.hasPermission('kardex:leer'))
      items.add(
        _QA('Kardex', Icons.swap_vert_rounded, AppColors.info, '/kardex'),
      );
    if (auth.hasPermission('compras:leer'))
      items.add(
        _QA(
          'Compras',
          Icons.local_shipping_rounded,
          AppColors.warning,
          '/compras',
        ),
      );

    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Accesos rápidos',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: items
                .take(5)
                .map(
                  (a) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: items.indexOf(a) < items.take(5).length - 1
                            ? 10
                            : 0,
                      ),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          GoRouter.of(context).go(a.path);
                        },
                        child: Column(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: a.color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: a.color.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                              child: Icon(a.icon, color: a.color, size: 24),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              a.label,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _QA {
  final String label, path;
  final IconData icon;
  final Color color;
  const _QA(this.label, this.icon, this.color, this.path);
}

// ─── Widget auxiliar ──────────────────────────────────────────────────────────

class _Bone extends StatelessWidget {
  final double w, h;
  final double r;
  const _Bone({required this.w, required this.h, this.r = 6});
  @override
  Widget build(BuildContext context) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: const Color(0xFFEEEFF1),
      borderRadius: BorderRadius.circular(r),
    ),
  );
}
