import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/providers/sede_scope_provider.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with WidgetsBindingObserver {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pollTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => ref.read(dashboardProvider.notifier).load(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(dashboardProvider.notifier).load();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final data = ref.watch(dashboardProvider);
    final desktop = MediaQuery.sizeOf(context).width >= 1024;

    return Scaffold(
      backgroundColor: desktop ? const Color(0xFFFAFAFA) : Colors.white,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(dashboardProvider.notifier).load(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: desktop ? 32 : 120),
          children: [
            const SizedBox(height: 8),
            // ── Sede ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _Sede(data: data, ref: ref, auth: auth),
            ),
            const SizedBox(height: 14),
            if (data.errors.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: _DashboardErrors(errors: data.errors),
              ),
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
    final nombre =
        data.selectedSedeId == null && auth.user?.isSuperAdmin == true
        ? 'Todas las sedes'
        : data.selectedSede?.nombre ?? auth.user?.sede ?? 'Sin sede';
    final abierto = data.cajaActual?.isAbierta ?? false;
    final code = data.selectedSede?.codigoSede ?? '';

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
      useRootNavigator: true,
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
                ref.read(globalSedeIdProvider.notifier).select(null);
                Navigator.pop(ctx);
              },
            ),
            ...data.sedes.map(
              (s) => ListTile(
                dense: true,
                title: Text(s.nombre),
                subtitle: Text(
                  s.codigoSede,
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: data.selectedSedeId == s.id
                    ? const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: AppColors.primary,
                      )
                    : null,
                onTap: () {
                  ref.read(globalSedeIdProvider.notifier).select(s.id);
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
    String value(String key, String loaded) =>
        data.hasError(key) ? '—' : loaded;
    String detail(String key, String loaded) =>
        data.hasError(key) ? 'No disponible' : loaded;
    if (auth.hasPermission('ventas:leer') ||
        auth.hasPermission('ventas:leer-propias')) {
      final p = data.variacionVsAyer;
      items.add(
        _KD(
          Icons.bar_chart_rounded,
          const Color(0xFF2563EB),
          const Color(0xFFEFF6FF),
          'Ventas del día',
          value('ventas', FormatUtils.currency(data.ventasHoy)),
          detail(
            'ventas',
            p != 0
                ? '↑ ${p.abs().toStringAsFixed(1)}% vs ayer'
                : '${data.ventasCountHoy} ventas',
          ),
          !data.hasError('ventas') && p >= 0,
          '/ventas',
        ),
      );
    }
    if (auth.hasPermission('caja:leer')) {
      final caja = data.cajaActual;
      final expectedCash = caja?.resumen?.efectivoEsperado;
      final netSales = caja?.resumen?.v2?.totalVentasNeto;
      final allSedes =
          auth.user?.isSuperAdmin == true && data.selectedSedeId == null;
      items.add(
        _KD(
          Icons.account_balance_wallet_rounded,
          const Color(0xFFFF9500),
          const Color(0xFFFFF8EE),
          'Caja activa',
          data.hasError('caja')
              ? '—'
              : allSedes
              ? 'Selecciona sede'
              : caja?.isAbierta == true
              ? FormatUtils.currency(expectedCash ?? caja!.montoApertura)
              : 'Cerrada',
          detail(
            'caja',
            allSedes
                ? 'Requiere una sede concreta'
                : caja?.isAbierta == true
                ? '${FormatUtils.currency(netSales ?? 0)} ventas netas'
                : 'Sin turno abierto',
          ),
          caja?.isAbierta == true && !data.hasError('caja'),
          '/caja',
        ),
      );
    }
    if (auth.hasPermission('productos:leer')) {
      items.add(
        _KD(
          Icons.liquor_rounded,
          AppColors.primary,
          AppColors.primarySurface,
          'Productos',
          value('productos', '${data.productos?.total ?? 0}'),
          detail('productos', '${data.productos?.activos ?? 0} activos'),
          !data.hasError('productos'),
          '/productos',
        ),
      );
    }
    if (auth.hasPermission('categorias:leer')) {
      items.add(
        _KD(
          Icons.category_rounded,
          const Color(0xFF7C3AED),
          const Color(0xFFF5F3FF),
          'Categorías',
          value('categorias', '${data.categoriasTotal ?? 0}'),
          detail('categorias', 'Catálogo global'),
          !data.hasError('categorias'),
          '/categorias',
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
          value('inventario', '${data.inventario?.totalItems ?? 0}'),
          detail('inventario', '${data.stockBajo} con alerta'),
          !data.hasError('inventario') && data.stockBajo == 0,
          '/inventario',
        ),
      );
    }
    if (auth.hasPermission('kardex:leer')) {
      items.add(
        _KD(
          Icons.swap_vert_rounded,
          const Color(0xFF0284C7),
          const Color(0xFFF0F9FF),
          'Kardex',
          value('kardex', '${data.kardex?.totalMovimientos ?? 0}'),
          detail(
            'kardex',
            '${data.kardex?.entradas ?? 0} ent · ${data.kardex?.salidas ?? 0} sal',
          ),
          !data.hasError('kardex'),
          '/kardex',
        ),
      );
    }
    if (auth.hasPermission('establecimientos:leer')) {
      items.add(
        _KD(
          Icons.store_rounded,
          AppColors.success,
          AppColors.successLight,
          'Sedes activas',
          value('sedes', '${data.sedesActivas} / ${data.sedesTotal}'),
          detail('sedes', 'Sedes operativas'),
          !data.hasError('sedes'),
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
    if (auth.hasPermission('compras:leer')) {
      items.add(
        _KD(
          Icons.local_shipping_rounded,
          const Color(0xFF7C3AED),
          const Color(0xFFF5F3FF),
          'Compras pend.',
          value('compras', '${data.comprasPendientes}'),
          detail('compras', FormatUtils.currency(data.comprasMontoTotal)),
          !data.hasError('compras') && data.comprasPendientes == 0,
          '/compras',
        ),
      );
    }
    if (auth.hasPermission('asistencia:leer')) {
      items.add(
        _KD(
          Icons.badge_rounded,
          const Color(0xFF059669),
          const Color(0xFFECFDF5),
          'Asistencia hoy',
          value(
            'asistencia',
            '${data.asistenciaPresentes} / ${data.asistenciaTotal}',
          ),
          detail(
            'asistencia',
            '${data.asistenciaTardanzas} tard · ${data.asistenciaAusentes} aus',
          ),
          !data.hasError('asistencia'),
          '/asistencia',
        ),
      );
    }
    if (auth.hasPermission('roles:leer')) {
      items.addAll([
        _KD(
          Icons.people_rounded,
          AppColors.textPrimary,
          AppColors.backgroundAlt,
          'Usuarios',
          value('roles', '${data.usuariosTotal ?? 0}'),
          detail('roles', '${data.rolesTotal ?? 0} roles activos'),
          !data.hasError('roles'),
          '/usuarios',
        ),
        _KD(
          Icons.shield_rounded,
          AppColors.textPrimary,
          AppColors.backgroundAlt,
          'Roles',
          value('roles', '${data.rolesTotal ?? 0}'),
          detail('roles', 'Niveles de acceso'),
          !data.hasError('roles'),
          '/roles',
        ),
      ]);
    }
    items.add(
      _KD(
        Icons.devices_rounded,
        AppColors.textPrimary,
        AppColors.backgroundAlt,
        'Sesiones',
        value('sesiones', '${data.sesionesTotal ?? 0}'),
        detail('sesiones', 'Dispositivos conectados'),
        !data.hasError('sesiones'),
        '/perfil',
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = MediaQuery.sizeOf(context).width >= 1024;
        final columns = desktop ? 4 : 2;
        const gap = 10.0;
        final cardWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items
              .map(
                (k) => SizedBox(
                  width: cardWidth,
                  height: desktop ? 104 : null,
                  child: _KpiCard(k: k),
                ),
              )
              .toList(),
        );
      },
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
    child: LayoutBuilder(
      builder: (context, constraints) {
        final desktop = MediaQuery.sizeOf(context).width >= 1024;
        final columns = desktop ? 4 : 2;
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: List.generate(
            4,
            (_) => Container(
              width: width,
              height: desktop ? 104 : 80,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6F8),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _DashboardErrors extends StatelessWidget {
  final Map<String, String> errors;

  const _DashboardErrors({required this.errors});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.errorLight,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.error_outline_rounded, size: 17, color: AppColors.error),
            SizedBox(width: 7),
            Text(
              'Algunos datos no se pudieron actualizar',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        for (final error in errors.entries.take(3))
          Text(
            '${error.key}: ${error.value}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AppColors.error),
          ),
      ],
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
  String? _lastScope;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _lastScope = ref.read(globalSedeIdProvider);
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
    final scope = ref.watch(globalSedeIdProvider);
    if (_initialized && scope != _lastScope) {
      _lastScope = scope;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(dashboardProvider.notifier).loadChartForPeriod(_period);
        }
      });
    }
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
    final safeVals = vals.isEmpty ? List<double>.filled(7, 0) : vals;
    final safeLabels = labels.isEmpty ? _defaultLabels() : labels;
    final maxVal = safeVals.fold(0.0, (m, v) => v > m ? v : m);
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
                        if (i < 0 || i >= safeLabels.length)
                          return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            safeLabels[i],
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
                  safeVals.length,
                  (i) => BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: safeVals[i],
                        // Última barra siempre más oscura (hoy o período más reciente)
                        color: i == safeVals.length - 1
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: 0.25),
                        width: safeVals.length <= 7
                            ? 24
                            : safeVals.length <= 12
                            ? 18
                            : 14,
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
          final usuario = log['usuario'];
          final user = usuario is Map
              ? usuario['username'] as String? ?? 'Sistema'
              : log['username'] as String? ??
                    (usuario is String ? usuario : 'Sistema');
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
