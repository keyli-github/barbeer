import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/providers/sede_scope_provider.dart';
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

    return Scaffold(
      backgroundColor: context.colors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(dashboardProvider.notifier).load(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: desktop ? 32 : 120),
          children: [
            const SizedBox(height: 14),
            // ── Saludo ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _Greeting(auth: auth),
            ),
            const SizedBox(height: 14),
            // ── Mi Asistencia (non-SUPERADMIN, desktop) ──
            if (auth.user != null &&
                auth.user!.nivel < 100 &&
                !auth.user!.isSuperAdmin)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: _MyAttendanceCard(auth: auth),
              ),
            if (data.cajaConDiferencia != null &&
                auth.hasPermission('caja:leer'))
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: _CashDifferenceAlert(session: data.cajaConDiferencia!),
              ),
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
            if (!data.loading && _showVisualAnalysis(auth)) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Análisis visual',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (auth.hasPermission('ventas:leer') ||
                  auth.hasPermission('ventas:leer-propias')) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _SalesSummary(data: data),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _Chart(data: data),
                ),
              ],
              if (auth.hasPermission('kardex:leer')) ...[
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _KardexChart(data: data.kardexSemana),
                ),
              ],
              if (_showDonuts(auth)) ...[
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _DonutSections(data: data, auth: auth),
                ),
              ],
            ],
            if (data.sedes.isNotEmpty || data.audit.isNotEmpty) ...[
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    if (data.sedes.isNotEmpty &&
                        auth.hasPermission('establecimientos:leer'))
                      _SedesCard(sedes: data.sedes),
                    if (data.sedes.isNotEmpty && data.audit.isNotEmpty)
                      const SizedBox(height: 14),
                    if (data.audit.isNotEmpty) _Activity(audit: data.audit),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _showDonuts(AuthState auth) =>
      auth.hasPermission('inventario:leer') ||
      auth.hasPermission('asistencia:leer') ||
      auth.hasPermission('compras:leer') ||
      auth.hasPermission('roles:leer');

  bool _showVisualAnalysis(AuthState auth) =>
      auth.hasPermission('ventas:leer') ||
      auth.hasPermission('ventas:leer-propias') ||
      auth.hasPermission('kardex:leer') ||
      _showDonuts(auth);
}

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting, ${user?.username ?? 'Usuario'}',
          style: TextStyle(
            fontSize: 22,
            height: 1.15,
            fontWeight: FontWeight.w800,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${FormatUtils.roleName(user?.rol ?? '')} · '
          '${user?.isSuperAdmin == true ? 'Acceso global' : user?.sedeName ?? 'Sin sede'}',
          style: TextStyle(fontSize: 14, color: context.colors.textTertiary),
        ),
      ],
    );
  }
}

/// "Mi Asistencia" card — shown to non-admin employees (nivel < 100).
/// Matches the web dashboard's attendance section that lets employees
/// see their attendance status and navigate to mark attendance.
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

class _SalesSummary extends StatelessWidget {
  final DashboardData data;

  const _SalesSummary({required this.data});

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        'VENTAS HOY',
        FormatUtils.currency(data.ventasHoy),
        '${data.ventasCountHoy} transacciones',
        AppColors.brand,
      ),
      (
        'TOTAL DEL MES',
        FormatUtils.currency(data.misTotalesMes),
        'Mes en curso',
        AppColors.success,
      ),
      (
        'TICKET PROMEDIO HOY',
        data.ventasCountHoy == 0
            ? '—'
            : FormatUtils.currency(data.ventasHoy / data.ventasCountHoy),
        'Por venta',
        context.colors.textPrimary,
      ),
    ];
    return Column(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          _DashboardSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  items[index].$1,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: context.colors.textTertiary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  items[index].$2,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: items[index].$4,
                  ),
                ),
                Text(
                  items[index].$3,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          if (index < items.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

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
      backgroundColor: ctx.colors.surface,
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
                color: ctx.colors.border,
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
          'Caja',
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
          context.colors.primarySurface,
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
          data.stockBajo > 0
              ? context.colors.errorLight
              : context.colors.successLight,
          'Inventario',
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
    if (auth.hasPermission('compras:leer')) {
      items.add(
        _KD(
          Icons.local_shipping_rounded,
          const Color(0xFF7C3AED),
          const Color(0xFFF5F3FF),
          'Compras',
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
          'Asistencia',
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
          context.colors.textPrimary,
          context.colors.backgroundAlt,
          'Usuarios',
          value('roles', '${data.usuariosTotal ?? 0}'),
          detail('roles', '${data.rolesTotal ?? 0} roles activos'),
          !data.hasError('roles'),
          '/usuarios',
        ),
        _KD(
          Icons.shield_rounded,
          context.colors.textPrimary,
          context.colors.backgroundAlt,
          'Roles',
          value('roles', '${data.rolesTotal ?? 0}'),
          detail('roles', 'Niveles de acceso'),
          !data.hasError('roles'),
          '/roles',
        ),
      ]);
    }
    if (auth.hasPermission('establecimientos:leer')) {
      items.add(
        _KD(
          Icons.store_rounded,
          AppColors.success,
          context.colors.successLight,
          'Sedes activas',
          value('sedes', '${data.sedesActivas}'),
          detail('sedes', 'de ${data.sedesTotal} total'),
          !data.hasError('sedes'),
          '/sucursales',
        ),
      );
    }
    items.add(
      _KD(
        Icons.devices_rounded,
        context.colors.textPrimary,
        context.colors.backgroundAlt,
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
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 11),
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
              Expanded(
                child: Text(
                  k.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9.5,
                    letterSpacing: 1.1,
                    color: context.colors.textTertiary,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(k.icon, size: 14, color: context.colors.textTertiary),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            k.value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: k.iconColor,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            k.sub,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
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
                color: context.colors.backgroundAlt,
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
      color: context.colors.errorLight,
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
    final safeVals = vals.isEmpty ? List<double>.filled(7, 0) : vals;
    final safeLabels = labels.isEmpty ? _defaultLabels() : labels;
    final maxVal = safeVals.fold(0.0, (m, v) => v > m ? v : m);
    final loading = data.chartLoading;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ventas — últimos 7 días',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
          Text(
            'Total en soles por día (barra más oscura = hoy)',
            style: TextStyle(fontSize: 11, color: context.colors.textTertiary),
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          const SizedBox(height: 14),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: maxVal == 0 ? 100 : maxVal * 1.3,
                minY: 0,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxVal == 0 ? 50 : maxVal * 1.3 / 3,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: context.colors.border,
                    strokeWidth: 0.8,
                    dashArray: [4, 4],
                  ),
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
                        style: TextStyle(
                          fontSize: 9,
                          color: context.colors.textTertiary,
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
                                  : context.colors.textTertiary,
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
                          color: context.colors.surfaceAlt,
                        ),
                      ),
                    ],
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => context.colors.textPrimary,
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
                color: value == o
                    ? AppColors.primary
                    : context.colors.textPrimary,
              ),
            ),
          ),
        )
        .toList(),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(width: 2),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 14,
            color: context.colors.textTertiary,
          ),
        ],
      ),
    ),
  );
}

class _KardexChart extends StatelessWidget {
  final List<DashboardKardexPoint> data;

  const _KardexChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final points = data.isEmpty
        ? List.generate(
            7,
            (index) => DashboardKardexPoint(label: '', entradas: 0, salidas: 0),
          )
        : data;
    final maxValue = points.fold<double>(
      0,
      (max, point) => [
        max,
        point.entradas.toDouble(),
        point.salidas.toDouble(),
      ].reduce((a, b) => a > b ? a : b),
    );

    return _DashboardSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Movimientos de inventario',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
          Text(
            'Últimos 7 días — Entradas vs Salidas',
            style: TextStyle(fontSize: 11, color: context.colors.textTertiary),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (points.length - 1).toDouble(),
                minY: 0,
                maxY: maxValue == 0 ? 3 : maxValue * 1.35,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: maxValue == 0 ? 1 : maxValue / 3,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: context.colors.border,
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, _) => Text(
                        value.toStringAsFixed(0),
                        style: TextStyle(
                          fontSize: 9,
                          color: context.colors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (value, _) {
                        final index = value.toInt();
                        if (index < 0 || index >= points.length) {
                          return const SizedBox();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 7),
                          child: Text(
                            points[index].label,
                            style: TextStyle(
                              fontSize: 10,
                              color: context.colors.textTertiary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  _line(
                    points,
                    (point) => point.entradas,
                    const Color(0xFF2563EB),
                  ),
                  _line(points, (point) => point.salidas, AppColors.brand),
                ],
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              _LegendDot(label: 'Entradas', color: Color(0xFF2563EB)),
              SizedBox(width: 18),
              _LegendDot(label: 'Salidas', color: AppColors.brand),
            ],
          ),
        ],
      ),
    );
  }

  LineChartBarData _line(
    List<DashboardKardexPoint> points,
    int Function(DashboardKardexPoint) value,
    Color color,
  ) => LineChartBarData(
    isCurved: true,
    barWidth: 2.5,
    color: color,
    dotData: const FlDotData(show: false),
    belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.12)),
    spots: List.generate(
      points.length,
      (index) => FlSpot(index.toDouble(), value(points[index]).toDouble()),
    ),
  );
}

class _DonutSections extends StatelessWidget {
  final DashboardData data;
  final AuthState auth;

  const _DonutSections({required this.data, required this.auth});

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[];
    final inventory = data.inventario;
    if (auth.hasPermission('inventario:leer') && inventory != null) {
      cards.add(
        _DonutCard(
          title: 'Estado del inventario',
          subtitle:
              'Valor total: ${FormatUtils.currency(inventory.valorTotal)}',
          center: '${inventory.totalItems}',
          centerLabel: 'ÍTEMS',
          values: [
            _DonutValue('OK', inventory.ok, AppColors.success),
            _DonutValue('Alerta', inventory.alerta, AppColors.brand),
            _DonutValue('Crítico', inventory.critico, AppColors.error),
          ],
        ),
      );
    }
    if (auth.hasPermission('asistencia:leer') && data.asistenciaTotal > 0) {
      cards.add(
        _DonutCard(
          title: 'Asistencia de hoy',
          subtitle: DateFormat('yyyy-MM-dd').format(DateTime.now()),
          center: '${data.asistenciaTotal}',
          centerLabel: 'EMPLEADOS',
          values: [
            _DonutValue(
              'Presente',
              data.asistenciaPresentes,
              AppColors.success,
            ),
            _DonutValue('Tardanza', data.asistenciaTardanzas, AppColors.brand),
            _DonutValue('Ausente', data.asistenciaAusentes, AppColors.error),
            _DonutValue(
              'Día libre',
              data.asistenciaDiaLibre,
              context.colors.textTertiary,
            ),
          ],
        ),
      );
    }
    final purchases = data.compras;
    if (auth.hasPermission('compras:leer') && purchases != null) {
      final others =
          (purchases.totalOrdenes - purchases.pendientes - purchases.recibidas)
              .clamp(0, purchases.totalOrdenes);
      cards.add(
        _DonutCard(
          title: 'Órdenes de compra',
          subtitle:
              '${FormatUtils.currency(purchases.montoPendiente)} pendiente de pago',
          center: '${purchases.totalOrdenes}',
          centerLabel: 'ÓRDENES',
          values: [
            _DonutValue('Pendiente', purchases.pendientes, AppColors.brand),
            _DonutValue('Recibida', purchases.recibidas, AppColors.success),
            _DonutValue('Otras', others, context.colors.textTertiary),
          ],
        ),
      );
    }
    if (auth.hasPermission('roles:leer') && data.usuariosPorRol.isNotEmpty) {
      cards.add(_RolesCard(values: data.usuariosPorRol));
    }

    return Column(
      children: [
        for (var index = 0; index < cards.length; index++) ...[
          cards[index],
          if (index < cards.length - 1) const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _DonutValue {
  final String label;
  final int value;
  final Color color;

  const _DonutValue(this.label, this.value, this.color);
}

class _DonutCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String center;
  final String centerLabel;
  final List<_DonutValue> values;

  const _DonutCard({
    required this.title,
    required this.subtitle,
    required this.center,
    required this.centerLabel,
    required this.values,
  });

  @override
  Widget build(BuildContext context) {
    final visible = values.where((item) => item.value > 0).toList();
    return _DashboardSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: context.colors.textTertiary),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    startDegreeOffset: -90,
                    sectionsSpace: 3,
                    centerSpaceRadius: 56,
                    sections: visible.isEmpty
                        ? [
                            PieChartSectionData(
                              value: 1,
                              color: context.colors.surfaceAlt,
                              radius: 23,
                              showTitle: false,
                            ),
                          ]
                        : visible
                              .map(
                                (item) => PieChartSectionData(
                                  value: item.value.toDouble(),
                                  color: item.color,
                                  radius: 23,
                                  showTitle: false,
                                ),
                              )
                              .toList(),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      center,
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    Text(
                      centerLabel,
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.1,
                        color: context.colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: values
                .map(
                  (item) => _LegendDot(
                    label: '${item.label} ${item.value}',
                    color: item.color,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _RolesCard extends StatelessWidget {
  final Map<String, int> values;

  const _RolesCard({required this.values});

  @override
  Widget build(BuildContext context) {
    final max = values.values.fold<int>(1, (a, b) => a > b ? a : b);
    return _DashboardSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Usuarios por rol',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
          Text(
            '${values.values.fold<int>(0, (sum, value) => sum + value)} usuarios en total',
            style: TextStyle(fontSize: 11, color: context.colors.textTertiary),
          ),
          const SizedBox(height: 16),
          for (final entry in values.entries) ...[
            Row(
              children: [
                SizedBox(
                  width: 92,
                  child: Text(
                    FormatUtils.roleName(entry.key),
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.textTertiary,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: entry.value / max,
                      minHeight: 12,
                      color: const Color(0xFF2563EB),
                      backgroundColor: context.colors.surfaceAlt,
                    ),
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: Text(
                    '${entry.value}',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _SedesCard extends StatelessWidget {
  final List<DashboardSede> sedes;

  const _SedesCard({required this.sedes});

  @override
  Widget build(BuildContext context) => _DashboardSurface(
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Sedes',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => GoRouter.of(context).go('/sucursales'),
              child: const Text('Gestionar →'),
            ),
          ],
        ),
        for (var index = 0; index < sedes.take(6).length; index++) ...[
          if (index > 0) Divider(height: 1, color: context.colors.border),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sedes[index].nombre,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      Text(
                        sedes[index].direccion ?? 'Sin dirección',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${sedes[index].usuarios}',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.textTertiary,
                  ),
                ),
                const SizedBox(width: 9),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: sedes[index].activo
                        ? AppColors.success
                        : context.colors.textTertiary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

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

class _LegendDot extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendDot({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(
        label,
        style: TextStyle(fontSize: 11, color: context.colors.textTertiary),
      ),
    ],
  );
}

// ─── Actividad reciente — 4 items + ver más ──────────────────────────────────

class _Activity extends StatelessWidget {
  final List<Map<String, dynamic>> audit;
  const _Activity({required this.audit});

  @override
  Widget build(BuildContext context) => _DashboardSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
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
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        user,
                        style: TextStyle(
                          fontSize: 10,
                          color: context.colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (dt != null)
                  Text(
                    FormatUtils.timeAgo(dt),
                    style: TextStyle(
                      fontSize: 10,
                      color: context.colors.textTertiary,
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
