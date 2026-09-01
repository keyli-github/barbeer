import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../caja/data/caja_repository.dart';
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
    final horizontalPadding = desktop ? 24.0 : 20.0;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(dashboardProvider.notifier).load(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: desktop ? 32 : 24),
          children: [
            SizedBox(height: desktop ? 10 : 14),
            // ── Greeting ──
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: _Greeting(auth: auth),
            ),
            const SizedBox(height: 14),
            // ── Cash difference alert (conditional) ──
            if (data.cajaConDiferencia != null &&
                auth.hasPermission('caja:leer'))
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  0,
                  horizontalPadding,
                  14,
                ),
                child: _CashDifferenceAlert(session: data.cajaConDiferencia!),
              ),
            // ── Mi Asistencia (non-admin only) ──
            if (auth.user != null &&
                auth.user!.nivel < 100 &&
                !auth.user!.isSuperAdmin)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  0,
                  horizontalPadding,
                  14,
                ),
                child: _MyAttendanceCard(auth: auth),
              ),
            // ── Errors ──
            if (data.errors.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  0,
                  horizontalPadding,
                  14,
                ),
                child: _DashboardErrors(errors: data.errors),
              ),
            // ── KPI cards grid ──
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: DashboardKpis(data: data, auth: auth),
            ),
            const SizedBox(height: 14),
            // ── Recent Activity (conditional, audit:leer) ──
            if (data.audit.isNotEmpty && auth.hasPermission('audit:leer'))
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: DashboardRecentActivity(audit: data.audit),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Greeting ─────────────────────────────────────────────────────────────────

class _Greeting extends StatelessWidget {
  final AuthState auth;

  const _Greeting({required this.auth});

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Buenos días'
        : hour < 19
        ? 'Buenas tardes'
        : 'Buenas noches';
    final user = auth.user;
    final desktop = MediaQuery.sizeOf(context).width >= 1024;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting, ${user?.username ?? 'Usuario'}',
          style: TextStyle(
            fontSize: desktop ? 24 : 22,
            height: 1.15,
            fontWeight: FontWeight.w800,
            color: context.colors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: desktop ? 5 : 4),
        Text(
          '${FormatUtils.roleName(user?.rol ?? '')} · '
          '${user?.isSuperAdmin == true ? 'Acceso global' : user?.sedeName ?? 'Sin sede'}',
          style: TextStyle(fontSize: 14, color: context.colors.textTertiary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ─── Cash Difference Alert ────────────────────────────────────────────────────

class _CashDifferenceAlert extends StatelessWidget {
  final CajaSesion session;

  const _CashDifferenceAlert({required this.session});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.brand.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.brand.withValues(alpha: 0.35)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.warning_amber_rounded,
          size: 20,
          color: AppColors.brand,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Diferencia en caja detectada',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: context.colors.textTertiary,
                  ),
                  children: [
                    const TextSpan(text: 'La última sesión cerrada en '),
                    TextSpan(
                      text: session.sede,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const TextSpan(text: ' tiene una diferencia de '),
                    TextSpan(
                      text: FormatUtils.currency(
                        (session.diferenciaCierre ?? 0).abs(),
                      ),
                      style: const TextStyle(
                        color: AppColors.brand,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const TextSpan(text: '. Revisa el cierre.'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () => GoRouter.of(context).go('/caja'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          ),
          child: const Text('Ver caja', style: TextStyle(fontSize: 11)),
        ),
      ],
    ),
  );
}

// ─── My Attendance Card ───────────────────────────────────────────────────────

class _MyAttendanceCard extends ConsumerWidget {
  final AuthState auth;
  const _MyAttendanceCard({required this.auth});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.badge_rounded,
                  color: AppColors.brand,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mi Asistencia',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    Text(
                      'Registra tu asistencia del día',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => GoRouter.of(context).go('/asistencia'),
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: const Text('Marcar Asistencia'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── KPI Cards Grid ───────────────────────────────────────────────────────────

class DashboardKpis extends StatelessWidget {
  final DashboardData data;
  final AuthState auth;
  const DashboardKpis({super.key, required this.data, required this.auth});

  @override
  Widget build(BuildContext context) {
    final items = <_KD>[];
    String value(String key, String loaded) =>
        data.hasError(key) ? '—' : loaded;
    String detail(String key, String loaded) =>
        data.hasError(key) ? 'No disponible' : loaded;

    final superadmin = auth.user?.isSuperAdmin == true;
    if (superadmin) {
      final summary = data.cajaActual?.resumen?.v2;
      final needsSede = data.selectedSedeId == null;
      final cashDetail = needsSede
          ? 'Elige una sede en el encabezado'
          : data.cajaActual == null
          ? 'Sin turno abierto'
          : 'Turno de caja actual';
      String money(double? amount) =>
          needsSede ? 'Selecciona sede' : FormatUtils.currency(amount ?? 0);
      String number(num? amount) =>
          needsSede ? 'Selecciona sede' : '${amount ?? 0}';
      items.addAll([
        _KD(
          icon: Icons.point_of_sale,
          label: 'Ventas totales',
          value: money(summary?.totalVentasNeto),
          detail: cashDetail,
          valueColor: AppColors.success,
          path: '/ventas',
        ),
        _KD(
          icon: Icons.inventory_2_outlined,
          label: 'Costo de productos vendidos',
          value: money(summary?.costoProductosVendidos),
          detail: cashDetail,
          valueColor: AppColors.warning,
          path: '/productos',
        ),
        _KD(
          icon: Icons.trending_up,
          label: 'Utilidad bruta',
          value: money(summary?.utilidadBruta),
          detail: 'Ventas menos costo de productos',
          valueColor: AppColors.success,
          path: '/ventas',
        ),
        _KD(
          icon: Icons.sell_outlined,
          label: 'Unidades vendidas',
          value: number(summary?.unidadesVendidas),
          detail: cashDetail,
          valueColor: context.colors.textPrimary,
          path: '/ventas',
        ),
        _KD(
          icon: Icons.trending_down,
          label: 'Otros gastos',
          value: money(summary?.otrosGastos),
          detail: 'Salidas manuales del cuadre de caja',
          valueColor: AppColors.error,
          path: '/movimientos',
        ),
        _KD(
          icon: Icons.account_balance,
          label: 'Utilidad neta',
          value: money(summary?.utilidadNeta),
          detail: 'Utilidad bruta menos otros gastos',
          valueColor: AppColors.success,
          path: '/caja',
        ),
        _KD(
          icon: Icons.percent,
          label: 'Margen neto',
          value: needsSede
              ? 'Selecciona sede'
              : '${(summary?.margenNeto ?? 0).toStringAsFixed(1)}%',
          detail: 'Utilidad neta sobre ventas totales',
          valueColor: AppColors.success,
          path: '/caja',
        ),
      ]);
    }

    // 1. Caja
    if (!superadmin && auth.hasPermission('caja:leer')) {
      final caja = data.cajaActual;
      final expectedCash = caja?.resumen?.efectivoEsperado;
      final allSedes =
          auth.user?.isSuperAdmin == true && data.selectedSedeId == null;
      final isOpen = caja?.isAbierta == true && !data.hasError('caja');
      items.add(
        _KD(
          icon: Icons.account_balance_wallet_rounded,
          label: 'Caja',
          value: data.hasError('caja')
              ? '—'
              : allSedes
              ? 'Selecciona sede'
              : caja?.isAbierta == true
              ? FormatUtils.currency(expectedCash ?? caja!.montoApertura)
              : 'Cerrada',
          detail: detail(
            'caja',
            allSedes
                ? 'Requiere una sede concreta'
                : caja?.isAbierta == true
                ? 'Turno activo'
                : 'Sin turno abierto',
          ),
          valueColor: isOpen ? AppColors.success : context.colors.textTertiary,
          path: '/caja',
        ),
      );
    }

    // 2. Productos
    if (!superadmin && auth.hasPermission('productos:leer')) {
      items.add(
        _KD(
          icon: Icons.liquor_rounded,
          label: 'Productos',
          value: value('productos', '${data.productos?.total ?? 0}'),
          detail: detail(
            'productos',
            '${data.productos?.activos ?? 0} activos',
          ),
          valueColor: AppColors.brand,
          path: '/productos',
        ),
      );
    }

    // 3. Compras
    if (!superadmin && auth.hasPermission('compras:leer')) {
      items.add(
        _KD(
          icon: Icons.local_shipping_rounded,
          label: 'Compras',
          value: value('compras', '${data.comprasPendientes}'),
          detail: detail(
            'compras',
            FormatUtils.currency(data.comprasMontoTotal),
          ),
          valueColor: AppColors.brand,
          path: '/compras',
        ),
      );
    }

    // 4. Asistencia
    if (!superadmin && auth.hasPermission('asistencia:leer')) {
      items.add(
        _KD(
          icon: Icons.badge_rounded,
          label: 'Asistencia',
          value: value(
            'asistencia',
            '${data.asistenciaPresentes} / ${data.asistenciaTotal}',
          ),
          detail: detail(
            'asistencia',
            '${data.asistenciaTardanzas} tard · ${data.asistenciaAusentes} aus',
          ),
          valueColor: AppColors.success,
          path: '/asistencia',
        ),
      );
    }

    // 5. Usuarios
    if (!superadmin && auth.hasPermission('roles:leer')) {
      items.add(
        _KD(
          icon: Icons.people_rounded,
          label: 'Usuarios',
          value: value('roles', '${data.usuariosTotal ?? 0}'),
          detail: detail('roles', '${data.rolesTotal ?? 0} roles activos'),
          valueColor: context.colors.textPrimary,
          path: '/usuarios',
        ),
      );
    }

    // 6. Notificaciones (audit log count)
    if (!superadmin && auth.hasPermission('audit:leer')) {
      items.add(
        _KD(
          icon: Icons.notifications_rounded,
          label: 'Notificaciones',
          value: '${data.audit.length}',
          detail: 'Actividad reciente',
          valueColor: context.colors.textTertiary,
          path: '/auditoria',
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1024
            ? 3
            : width >= 600
            ? 2
            : 1;
        final gap = width >= 1024 ? 14.0 : 10.0;
        final cardWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items
              .map(
                (k) => SizedBox(
                  width: cardWidth,
                  child: _KpiCard(k: k, loading: data.loading),
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
  final String label;
  final String value;
  final String detail;
  final Color valueColor;
  final String path;

  const _KD({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    required this.valueColor,
    required this.path,
  });
}

class _KpiCard extends StatelessWidget {
  final _KD k;
  final bool loading;
  const _KpiCard({required this.k, required this.loading});

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 1024;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        GoRouter.of(context).go(k.path);
      },
      child: Container(
        padding: EdgeInsets.fromLTRB(
          desktop ? 16 : 14,
          12,
          desktop ? 16 : 14,
          11,
        ),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(desktop ? 14 : 12),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    k.label.toUpperCase(),
                    style: TextStyle(
                      fontSize: desktop ? 10 : 9,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  k.icon,
                  size: desktop ? 14 : 12,
                  color: context.colors.textTertiary,
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (loading)
              Container(
                key: const Key('dashboard-kpi-value-skeleton'),
                width: 88,
                height: 19,
                decoration: BoxDecoration(
                  color: context.colors.backgroundAlt,
                  borderRadius: BorderRadius.circular(5),
                ),
              )
            else
              Text(
                k.value,
                style: TextStyle(
                  fontSize: desktop ? 17 : 16,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                  color: k.valueColor,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 2),
            Text(
              k.detail,
              style: TextStyle(
                fontSize: desktop ? 11 : 10,
                color: context.colors.textTertiary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Dashboard Errors ─────────────────────────────────────────────────────────

class _DashboardErrors extends StatelessWidget {
  final Map<String, String> errors;

  const _DashboardErrors({required this.errors});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: context.colors.errorLight,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 17,
              color: AppColors.error,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                'Algunos datos no se pudieron actualizar',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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

// ─── Recent Activity — 8 items ────────────────────────────────────────────────

class DashboardRecentActivity extends StatelessWidget {
  final List<Map<String, dynamic>> audit;
  const DashboardRecentActivity({super.key, required this.audit});

  @override
  Widget build(BuildContext context) => _DashboardSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.list_alt_outlined,
              size: 15,
              color: context.colors.textTertiary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Actividad reciente',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
            ),
            if (audit.isNotEmpty)
              InkWell(
                onTap: () => GoRouter.of(context).go('/auditoria'),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Ver todo',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 13,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        ...audit.take(8).map((log) {
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
          final entity = log['entidad'] as String?;
          final metadata = [
            if (entity?.isNotEmpty == true) entity!,
            user,
            if (dt != null) FormatUtils.timeAgo(dt),
          ].join(' · ');
          final color = _color(accion);
          return Container(
            constraints: const BoxConstraints(minHeight: 47),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: context.colors.border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        accion.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        metadata,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: context.colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    ),
  );

  static Color _color(String a) {
    if (a.contains('ELIMINAR')) return AppColors.error;
    if (a.contains('STOCK')) return AppColors.warning;
    if (a.contains('CREAR')) return AppColors.success;
    return AppColors.primary;
  }
}

// ─── Dashboard Surface (reusable container) ───────────────────────────────────

class _DashboardSurface extends StatelessWidget {
  final Widget child;

  const _DashboardSurface({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: context.colors.border),
    ),
    child: child,
  );
}
