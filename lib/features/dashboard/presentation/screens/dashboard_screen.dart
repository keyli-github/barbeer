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

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final data = ref.watch(dashboardProvider);
    final user = auth.user;

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(dashboardProvider.notifier).load(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 12,
            bottom: 120,
          ),
          children: [
            // ── Header BarBeer + Superadmin ────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: RichText(
                text: TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Bar',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const TextSpan(
                      text: 'Beer',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.brand,
                        letterSpacing: -0.5,
                      ),
                    ),
                    TextSpan(
                      text: '\n${FormatUtils.roleName(user?.rol ?? '')}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.roleColor(user?.rol ?? ''),
                        height: 1.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Sede selector compacto ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _SedeSelector(data: data, ref: ref, auth: auth),
            ),

            const SizedBox(height: 12),

            // ── KPIs 2×2 compactos ────────────────────────────────────────
            if (!data.loading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _CompactKpis(data: data, auth: auth, ctx: context),
              )
            else
              _SkeletonKpis(),

            const SizedBox(height: 16),

            // ── Gráfica ventas con filtro ─────────────────────────────────
            if (!data.loading &&
                (auth.hasPermission('ventas:leer') ||
                    auth.hasPermission('ventas:leer-propias')))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _ChartSection(data: data),
              ),

            const SizedBox(height: 16),

            // ── Actividad reciente (4 items + ver más) ────────────────────
            if (data.audit.isNotEmpty) _ActivitySection(audit: data.audit),

            const SizedBox(height: 16),

            // ── Accesos rápidos ───────────────────────────────────────────
            _QuickRow(auth: auth),
          ],
        ),
      ),
    );
  }
}

// ─── Sede selector ────────────────────────────────────────────────────────────

class _SedeSelector extends StatelessWidget {
  final DashboardData data;
  final WidgetRef ref;
  final AuthState auth;
  const _SedeSelector({
    required this.data,
    required this.ref,
    required this.auth,
  });

  bool get canSelect =>
      auth.user?.isSuperAdmin == true && data.sedes.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final nombre = data.selectedSede?.nombre ?? auth.user?.sede ?? 'Sin sede';
    final abierto = data.cajaActual?.isAbierta ?? false;
    final code = data.selectedSede?.codigo ?? '';

    return GestureDetector(
      onTap: canSelect ? () => _pick(context) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFECEDF0)),
        ),
        child: Row(
          children: [
            // Icono sede
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
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: abierto
                              ? AppColors.success
                              : AppColors.textTertiary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        abierto ? 'Abierto' : 'Cerrado',
                        style: TextStyle(
                          fontSize: 11,
                          color: abierto
                              ? AppColors.success
                              : AppColors.textTertiary,
                        ),
                      ),
                      if (code.isNotEmpty)
                        Text(
                          ' • $code',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (canSelect)
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: AppColors.textTertiary,
              ),
          ],
        ),
      ),
    );
  }

  void _pick(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
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
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Seleccionar sede',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            // Opción "Todas"
            _SedeOpt(
              name: 'Todas las sedes',
              selected: data.selectedSedeId == null,
              onTap: () {
                ref.read(dashboardProvider.notifier).selectSede(null);
                Navigator.pop(context);
              },
            ),
            ...data.sedes.map(
              (s) => _SedeOpt(
                name: s.nombre,
                code: s.codigo,
                active: s.activo,
                selected: data.selectedSedeId == s.id,
                onTap: () {
                  ref.read(dashboardProvider.notifier).selectSede(s.id);
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _SedeOpt extends StatelessWidget {
  final String name;
  final String? code;
  final bool active, selected;
  final VoidCallback onTap;
  const _SedeOpt({
    required this.name,
    this.code,
    this.active = true,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 15,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          if (code != null)
            Text(
              code!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
          const SizedBox(width: 8),
          if (selected)
            const Icon(Icons.check_rounded, size: 18, color: AppColors.primary),
        ],
      ),
    ),
  );
}

// ─── KPIs 2×2 compactos ───────────────────────────────────────────────────────

class _CompactKpis extends StatelessWidget {
  final DashboardData data;
  final AuthState auth;
  final BuildContext ctx;
  const _CompactKpis({
    required this.data,
    required this.auth,
    required this.ctx,
  });

  @override
  Widget build(BuildContext context) {
    final items = <_K>[];

    if (auth.hasPermission('ventas:leer') ||
        auth.hasPermission('ventas:leer-propias')) {
      final pct = data.variacionVsAyer;
      items.add(
        _K(
          icon: Icons.bar_chart_rounded,
          iconColor: AppColors.primary,
          label: 'Ventas del día',
          value: FormatUtils.currency(data.ventasHoy),
          sub: pct != 0
              ? '↑ ${pct.abs().toStringAsFixed(1)}% vs ayer'
              : '${data.ventasCountHoy} ventas',
          subOk: pct >= 0,
          path: '/ventas',
        ),
      );
    }
    if (auth.hasPermission('caja:leer')) {
      items.add(
        _K(
          icon: Icons.account_balance_wallet_rounded,
          iconColor: const Color(0xFFFF9500),
          label: 'Caja activa',
          value: data.cajaActual?.isAbierta == true
              ? FormatUtils.currency(data.cajaActual!.montoApertura)
              : 'Cerrada',
          sub: data.cajaActual?.isAbierta == true
              ? 'En ${data.cajaAperturas} apertura${data.cajaAperturas != 1 ? 's' : ''}'
              : 'Sin turno',
          subOk: data.cajaActual?.isAbierta == true,
          path: '/caja',
        ),
      );
    }
    if (auth.hasPermission('inventario:leer')) {
      items.add(
        _K(
          icon: Icons.inventory_2_rounded,
          iconColor: data.stockBajo > 0 ? AppColors.error : AppColors.success,
          label: 'Stock bajo',
          value: '${data.stockBajo}',
          sub: data.stockBajo > 0 ? 'Ver productos' : 'Todo OK',
          subOk: data.stockBajo == 0,
          path: '/inventario',
        ),
      );
    }
    if (auth.hasPermission('establecimientos:leer') && data.sedesTotal > 0) {
      items.add(
        _K(
          icon: Icons.store_rounded,
          iconColor: AppColors.success,
          label: 'Sedes activas',
          value: '${data.sedesActivas} / ${data.sedesTotal}',
          sub:
              '${(data.sedesActivas / data.sedesTotal * 100).round()}% operativas',
          subOk: true,
          path: '/sucursales',
        ),
      );
    }
    // Vendedora/cajero: total mes
    if (items.length < 4 && data.misVentasMes > 0) {
      items.add(
        _K(
          icon: Icons.calendar_month_rounded,
          iconColor: AppColors.info,
          label: 'Total mes',
          value: FormatUtils.currency(data.misTotalesMes),
          sub: '${data.misVentasMes} ventas',
          subOk: true,
          path: '/ventas',
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items
          .take(4)
          .map(
            (k) => SizedBox(
              width: (MediaQuery.of(context).size.width - 50) / 2,
              child: _KpiTile(k: k, ctx: ctx),
            ),
          )
          .toList(),
    );
  }
}

class _K {
  final IconData icon;
  final Color iconColor;
  final String label, value, sub, path;
  final bool subOk;
  const _K({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.sub,
    required this.subOk,
    required this.path,
  });
}

class _KpiTile extends StatelessWidget {
  final _K k;
  final BuildContext ctx;
  const _KpiTile({required this.k, required this.ctx});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      HapticFeedback.lightImpact();
      GoRouter.of(ctx).go(k.path);
    },
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFECEDF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(k.icon, size: 18, color: k.iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  k.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            k.value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            k.sub,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: k.sub.startsWith('Ver')
                  ? AppColors.primary
                  : (k.subOk ? AppColors.success : AppColors.error),
            ),
            maxLines: 1,
          ),
        ],
      ),
    ),
  );
}

class _SkeletonKpis extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(
        4,
        (_) => Container(
          width: (MediaQuery.of(context).size.width - 50) / 2,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    ),
  );
}

// ─── Gráfica con filtro de periodo ────────────────────────────────────────────

class _ChartSection extends StatelessWidget {
  final DashboardData data;
  const _ChartSection({required this.data});

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
    final total = data.totalSemana;
    final pct = data.variacionSemana;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFECEDF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Ventas últimos 7 días',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              // Selector de periodo (visual — solo 7D activo por ahora)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE0E2E6)),
                ),
                child: const Text(
                  '7D',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Total
          Text(
            FormatUtils.currency(total),
            style: const TextStyle(
              fontSize: 20,
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
                  size: 11,
                  color: pct >= 0 ? AppColors.success : AppColors.error,
                ),
                Text(
                  ' ${pct.abs().toStringAsFixed(1)}% vs semana anterior',
                  style: TextStyle(
                    fontSize: 11,
                    color: pct >= 0 ? AppColors.success : AppColors.error,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          // Barras
          SizedBox(
            height: 110,
            child: BarChart(
              BarChartData(
                maxY: maxVal == 0 ? 100 : maxVal * 1.3,
                minY: 0,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxVal == 0 ? 50 : maxVal * 1.3 / 3,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: Color(0xFFECEDF0), strokeWidth: 0.7),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (v, _) => Text(
                        v >= 1000
                            ? '${(v / 1000).toStringAsFixed(0)}K'
                            : v.toStringAsFixed(0),
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
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
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            labels[i],
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: i == 6
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: i == 6
                                  ? AppColors.primary
                                  : AppColors.textTertiary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(
                  7,
                  (i) => BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: vals[i],
                        color: i == 6
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: 0.22),
                        width: 24,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxVal == 0 ? 100 : maxVal * 1.3,
                          color: const Color(0xFFF0F1F3),
                        ),
                      ),
                    ],
                  ),
                ),
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
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Actividad reciente (4 items max + ver más) ───────────────────────────────

class _ActivitySection extends StatelessWidget {
  final List<Map<String, dynamic>> audit;
  const _ActivitySection({required this.audit});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Actividad reciente',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (audit.length > 4)
              GestureDetector(
                onTap: () => GoRouter.of(context).go('/auditoria'),
                child: const Text(
                  'Ver todo',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ...audit.take(4).map((log) {
          final accion = log['accion'] as String? ?? '';
          final user = log['username'] as String? ?? '';
          final ts = log['createdAt'] as String?;
          DateTime? dt;
          try {
            dt = ts != null ? DateTime.parse(ts) : null;
          } catch (_) {}
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _actIcon(accion),
                    size: 15,
                    color: _actColor(accion),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        accion,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        user,
                        style: const TextStyle(
                          fontSize: 10,
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
                      fontSize: 10,
                      color: AppColors.textTertiary,
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    ),
  );

  static IconData _actIcon(String a) {
    if (a.contains('COMPRA')) return Icons.local_shipping_rounded;
    if (a.contains('STOCK')) return Icons.warning_rounded;
    if (a.contains('CAJA')) return Icons.account_balance_wallet_rounded;
    if (a.contains('VENTA')) return Icons.shopping_cart_rounded;
    return Icons.history_rounded;
  }

  static Color _actColor(String a) {
    if (a.contains('ELIMINAR')) return AppColors.error;
    if (a.contains('STOCK')) return AppColors.warning;
    if (a.contains('CREAR')) return AppColors.success;
    return AppColors.primary;
  }
}

// ─── Accesos rápidos ──────────────────────────────────────────────────────────

class _QuickRow extends StatelessWidget {
  final AuthState auth;
  const _QuickRow({required this.auth});
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
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Accesos rápidos',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: items
                .take(4)
                .map(
                  (a) => Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        GoRouter.of(context).go(a.path);
                      },
                      child: Column(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: a.color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(a.icon, color: a.color, size: 22),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            a.label,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
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
