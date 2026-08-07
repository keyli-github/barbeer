import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final data = ref.watch(dashboardProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(dashboardProvider.notifier).load(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            const SizedBox(height: 8),
            // ── Sede ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _Sede(data: data, ref: ref, auth: auth),
            ),
            const SizedBox(height: 14),
            // ── KPIs ──
            if (!data.loading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _Kpis(data: data, auth: auth),
              )
            else
              _SkeletonKpis(),
            const SizedBox(height: 14),
            // ── Chart ──
            if (!data.loading &&
                (auth.hasPermission('ventas:leer') ||
                    auth.hasPermission('ventas:leer-propias')))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _Chart(data: data),
              ),
            const SizedBox(height: 14),
            // ── Activity ──
            if (data.audit.isNotEmpty) _Activity(audit: data.audit),
          ],
        ),
      ),
    );
  }
}

// ─── Sede selector ────────────────────────────────────────────────────────────

class _Sede extends StatelessWidget {
  final DashboardData data;
  final WidgetRef ref;
  final AuthState auth;
  const _Sede({required this.data, required this.ref, required this.auth});

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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF97316), Color(0xFFEA580C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.brand.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.store_rounded,
                color: Colors.white,
                size: 18,
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
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: abierto
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        abierto ? 'Abierto' : 'Cerrado',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      if (code.isNotEmpty)
                        Text(
                          ' • $code',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (canSelect)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Cambiar',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _pick(BuildContext ctx) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: ctx,
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
              padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Seleccionar sede',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            ListTile(
              dense: true,
              title: const Text('Todas las sedes'),
              trailing: data.selectedSedeId == null
                  ? const Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: AppColors.primary,
                    )
                  : null,
              onTap: () {
                ref.read(dashboardProvider.notifier).selectSede(null);
                Navigator.pop(ctx);
              },
            ),
            ...data.sedes.map(
              (s) => ListTile(
                dense: true,
                title: Text(s.nombre),
                subtitle: Text(s.codigo, style: const TextStyle(fontSize: 11)),
                trailing: data.selectedSedeId == s.id
                    ? const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: AppColors.primary,
                      )
                    : null,
                onTap: () {
                  ref.read(dashboardProvider.notifier).selectSede(s.id);
                  Navigator.pop(ctx);
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

// ─── KPIs 2×2 compactos ────────────────────────────────────────────────────────

class _Kpis extends StatelessWidget {
  final DashboardData data;
  final AuthState auth;
  const _Kpis({required this.data, required this.auth});

  @override
  Widget build(BuildContext context) {
    final items = <_KD>[];
    if (auth.hasPermission('ventas:leer') ||
        auth.hasPermission('ventas:leer-propias')) {
      final p = data.variacionVsAyer;
      items.add(
        _KD(
          Icons.bar_chart_rounded,
          const Color(0xFF2563EB),
          const Color(0xFFEFF6FF),
          'Ventas del día',
          FormatUtils.currency(data.ventasHoy),
          p != 0
              ? '↑ ${p.abs().toStringAsFixed(1)}% vs ayer'
              : '${data.ventasCountHoy} ventas',
          p >= 0,
          '/ventas',
        ),
      );
    }
    if (auth.hasPermission('caja:leer')) {
      items.add(
        _KD(
          Icons.account_balance_wallet_rounded,
          const Color(0xFFFF9500),
          const Color(0xFFFFF8EE),
          'Caja activa',
          data.cajaActual?.isAbierta == true
              ? FormatUtils.currency(data.cajaActual!.montoApertura)
              : 'Cerrada',
          data.cajaActual?.isAbierta == true
              ? 'En ${data.cajaAperturas} apertura${data.cajaAperturas != 1 ? 's' : ''}'
              : 'Sin turno',
          data.cajaActual?.isAbierta == true,
          '/caja',
        ),
      );
    }
    if (auth.hasPermission('inventario:leer')) {
      items.add(
        _KD(
          Icons.inventory_2_rounded,
          data.stockBajo > 0 ? AppColors.error : AppColors.success,
          data.stockBajo > 0 ? AppColors.errorLight : AppColors.successLight,
          'Stock bajo',
          '${data.stockBajo}',
          data.stockBajo > 0 ? 'Ver productos' : 'Todo OK',
          data.stockBajo == 0,
          '/inventario',
        ),
      );
    }
    if (auth.hasPermission('establecimientos:leer') && data.sedesTotal > 0) {
      items.add(
        _KD(
          Icons.store_rounded,
          AppColors.success,
          AppColors.successLight,
          'Sedes activas',
          '${data.sedesActivas} / ${data.sedesTotal}',
          '${(data.sedesActivas / data.sedesTotal * 100).round()}% operativas',
          true,
          '/sucursales',
        ),
      );
    }
    if (items.length < 4 && data.misVentasMes > 0) {
      items.add(
        _KD(
          Icons.calendar_month_rounded,
          AppColors.info,
          AppColors.infoLight,
          'Total mes',
          FormatUtils.currency(data.misTotalesMes),
          '${data.misVentasMes} ventas',
          true,
          '/ventas',
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
              child: _KpiCard(k: k),
            ),
          )
          .toList(),
    );
  }
}

class _KD {
  final IconData icon;
  final Color iconColor, iconBg;
  final String label, value, sub, path;
  final bool subOk;
  const _KD(
    this.icon,
    this.iconColor,
    this.iconBg,
    this.label,
    this.value,
    this.sub,
    this.subOk,
    this.path,
  );
}

class _KpiCard extends StatelessWidget {
  final _KD k;
  const _KpiCard({required this.k});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      HapticFeedback.lightImpact();
      GoRouter.of(context).go(k.path);
    },
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEFF2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icono + label en fila
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: k.iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(k.icon, size: 14, color: k.iconColor),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  k.label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
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
              fontSize: 16,
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
              color: k.sub.contains('Ver')
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
            color: const Color(0xFFF5F6F8),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    ),
  );
}

// ─── Gráfica con selector de periodo ──────────────────────────────────────────

class _Chart extends ConsumerStatefulWidget {
  final DashboardData data;
  const _Chart({required this.data});
  @override
  ConsumerState<_Chart> createState() => _ChartState();
}

class _ChartState extends ConsumerState<_Chart> {
  String _period = '7D';
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      // Inicializa con 7D por defecto
      ref.read(dashboardProvider.notifier).loadChartForPeriod('7D');
    }
  }

  List<String> _defaultLabels() {
    const dn = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    final now = DateTime.now();
    return List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return dn[d.weekday - 1];
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(dashboardProvider);
    // Para 7D usamos datos del estado base; para otros usamos chartPoints
    final vals = _period == '7D' && data.chartPoints.isEmpty
        ? data.ventasSemana
        : data.chartPoints;
    final labels = _period == '7D' && data.chartLabels.isEmpty
        ? _defaultLabels()
        : data.chartLabels;
    final total = _period == '7D' && data.chartPoints.isEmpty
        ? data.totalSemana
        : data.chartTotal;
    final prevTotal = _period == '7D' && data.chartPoints.isEmpty
        ? data.ventasSemanaAnterior
        : data.chartPrevTotal;
    final pct = prevTotal > 0 ? ((total - prevTotal) / prevTotal) * 100 : 0.0;
    final maxVal = vals.fold(0.0, (m, v) => v > m ? v : m);
    final loading = data.chartLoading;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEFF2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + selector periodo
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ventas ${_period == '7D' ? 'últimos 7 días' : _period}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              _PeriodSelector(
                value: _period,
                onChanged: (v) {
                  setState(() => _period = v);
                  ref.read(dashboardProvider.notifier).loadChartForPeriod(v);
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          loading
              ? const SizedBox(
                  height: 30,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                )
              : Text(
                  FormatUtils.currency(total),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
          if (pct != 0 && !loading)
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
          const SizedBox(height: 14),
          SizedBox(
            height: 120,
            child: BarChart(
              BarChartData(
                maxY: maxVal == 0 ? 100 : maxVal * 1.3,
                minY: 0,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxVal == 0 ? 50 : maxVal * 1.3 / 3,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: Color(0xFFF0F1F3), strokeWidth: 0.7),
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
                            : AppColors.primary.withValues(alpha: 0.25),
                        width: 24,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxVal == 0 ? 100 : maxVal * 1.3,
                          color: const Color(0xFFF5F6FA),
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

class _PeriodSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _PeriodSelector({required this.value, required this.onChanged});

  static const _options = ['7D', '1M', '3M', '6M', '1A'];

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    onSelected: onChanged,
    offset: const Offset(0, 36),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    itemBuilder: (_) => _options
        .map(
          (o) => PopupMenuItem(
            value: o,
            height: 36,
            child: Text(
              o,
              style: TextStyle(
                fontSize: 13,
                fontWeight: value == o ? FontWeight.w700 : FontWeight.w400,
                color: value == o ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ),
        )
        .toList(),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDDFE3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 2),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 14,
            color: AppColors.textTertiary,
          ),
        ],
      ),
    ),
  );
}

// ─── Actividad reciente — 4 items + ver más ──────────────────────────────────

class _Activity extends StatelessWidget {
  final List<Map<String, dynamic>> audit;
  const _Activity({required this.audit});

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
        const SizedBox(height: 10),
        ...audit.take(4).map((log) {
          final accion = log['accion'] as String? ?? '';
          final user = log['username'] as String? ?? '';
          final ts = log['createdAt'] as String?;
          DateTime? dt;
          try {
            dt = ts != null ? DateTime.parse(ts) : null;
          } catch (_) {}
          final c = _color(accion);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_icon(accion), size: 16, color: c),
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

  static IconData _icon(String a) {
    if (a.contains('COMPRA')) return Icons.local_shipping_rounded;
    if (a.contains('STOCK')) return Icons.warning_rounded;
    if (a.contains('CAJA')) return Icons.account_balance_wallet_rounded;
    if (a.contains('VENTA')) return Icons.shopping_cart_rounded;
    return Icons.history_rounded;
  }

  static Color _color(String a) {
    if (a.contains('ELIMINAR')) return AppColors.error;
    if (a.contains('STOCK')) return AppColors.warning;
    if (a.contains('CREAR')) return AppColors.success;
    return AppColors.primary;
  }
}
