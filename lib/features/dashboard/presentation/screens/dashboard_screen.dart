import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final dash = ref.watch(dashboardProvider);
    final user = auth.user;

    return Scaffold(
      backgroundColor: AppColors.backgroundAlt,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => ref.read(dashboardProvider.notifier).load(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // App bar
              SliverAppBar(
                floating: true, snap: true,
                backgroundColor: AppColors.background,
                elevation: 0, scrolledUnderElevation: 0,
                leading: Builder(builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu_rounded, color: AppColors.textPrimary),
                  onPressed: () => Scaffold.of(ctx).openDrawer())),
                title: Row(children: [
                  Container(width: 32, height: 32,
                    decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.local_bar_rounded, color: AppColors.primary, size: 18)),
                  const SizedBox(width: 10),
                  const Text('Bar Beer', style: AppTextStyles.appBarTitle),
                ]),
                actions: [
                  if (user?.sede != null) Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      avatar: const Icon(Icons.store_rounded, size: 14, color: AppColors.primary),
                      label: Text(user!.sedeName, style: const TextStyle(fontSize: 11, color: AppColors.primary)),
                      backgroundColor: AppColors.primarySurface,
                      side: const BorderSide(color: AppColors.primaryBorder),
                      padding: EdgeInsets.zero, visualDensity: VisualDensity.compact)),
                ],
              ),
              // Content
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 120),
                sliver: SliverList(delegate: SliverChildListDelegate([
                  _WelcomeCard(user: user),
                  const SizedBox(height: 20),
                  if (dash.isLoading)
                    const AppLoading(message: 'Cargando datos...')
                  else if (dash.error != null)
                    _ErrCard(err: dash.error!, retry: () => ref.read(dashboardProvider.notifier).load())
                  else if (dash.data != null) ...[
                    _StatsRow(data: dash.data!),
                    const SizedBox(height: 20),
                    if (auth.hasPermission('roles:leer')) ...[
                      _UsersByRole(data: dash.data!), const SizedBox(height: 20)],
                    if (auth.hasPermission('establecimientos:leer')) ...[
                      _SedesCard(sedes: List<Map<String, dynamic>>.from(dash.data!.sedes)),
                      const SizedBox(height: 20)],
                    if (auth.hasPermission('audit:leer')) ...[
                      _AuditCard(audit: List<Map<String, dynamic>>.from(dash.data!.audit)),
                      const SizedBox(height: 20)],
                    _SessionsCard(sessions: List<Map<String, dynamic>>.from(dash.data!.sessions)),
                  ],
                ]))),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  final dynamic user;
  const _WelcomeCard({this.user});

  @override
  Widget build(BuildContext context) {
    final un = user?.username ?? '';
    final role = user?.rol ?? '';
    final h = DateTime.now().hour;
    final greet = h < 12 ? 'Buenos dias' : h < 18 ? 'Buenas tardes' : 'Buenas noches';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.primaryDark]),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.button),
      child: Row(children: [
        CircleAvatar(radius: 28, backgroundColor: Colors.white.withOpacity(0.2),
          child: Text(FormatUtils.initials(un),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18))),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$greet,', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(un, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(100)),
            child: Text(FormatUtils.roleName(role),
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600))),
        ])),
        const Icon(Icons.local_bar_rounded, color: Colors.white, size: 32),
      ]));
  }
}

class _StatsRow extends StatelessWidget {
  final DashboardData data;
  const _StatsRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final actUsers = data.users.where((u) => u['activo'] == true).length;
    final actSedes = data.sedes.where((s) => s['activo'] == true).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Resumen', style: AppTextStyles.titleLarge),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: StatCard(label: 'Usuarios activos', value: '$actUsers',
            icon: Icons.people_rounded, iconColor: AppColors.primary)),
        const SizedBox(width: 12),
        Expanded(child: StatCard(label: 'Sucursales', value: '$actSedes',
            icon: Icons.store_rounded, iconColor: AppColors.success)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: StatCard(label: 'Sesiones', value: '${data.sessions.length}',
            icon: Icons.devices_rounded, iconColor: AppColors.accent)),
        const SizedBox(width: 12),
        Expanded(child: StatCard(label: 'Roles', value: '${data.roles.length}',
            icon: Icons.admin_panel_settings_rounded, iconColor: AppColors.roleSuperadmin)),
      ]),
    ]);
  }
}

class _UsersByRole extends StatelessWidget {
  final DashboardData data;
  const _UsersByRole({required this.data});

  @override
  Widget build(BuildContext context) {
    final m = <String, int>{};
    for (final u in data.users) {
      final r = u['rol']?['nombre'] as String? ?? 'Sin rol';
      m[r] = (m[r] ?? 0) + 1;
    }
    if (m.isEmpty) return const SizedBox.shrink();
    final mx = m.values.reduce((a, b) => a > b ? a : b);
    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Icon(Icons.bar_chart_rounded, color: AppColors.primary, size: 20),
        const SizedBox(width: 8), const Text('Usuarios por rol', style: AppTextStyles.titleMedium)]),
      const SizedBox(height: 16),
      for (final e in m.entries) ...[
        Row(children: [
          SizedBox(width: 80, child: Text(FormatUtils.roleName(e.key),
              style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 10),
          Expanded(child: Stack(children: [
            Container(height: 8, decoration: BoxDecoration(color: AppColors.backgroundAlt, borderRadius: BorderRadius.circular(4))),
            FractionallySizedBox(widthFactor: mx > 0 ? e.value / mx : 0.0,
              child: Container(height: 8, decoration: BoxDecoration(
                  color: AppColors.roleColor(e.key), borderRadius: BorderRadius.circular(4)))),
          ])),
          const SizedBox(width: 10),
          Text('${e.value}', style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w700, color: AppColors.roleColor(e.key))),
        ]),
        const SizedBox(height: 10),
      ],
    ]));
  }
}

class _SedesCard extends StatelessWidget {
  final List<Map<String, dynamic>> sedes;
  const _SedesCard({required this.sedes});

  @override
  Widget build(BuildContext context) {
    if (sedes.isEmpty) return const SizedBox.shrink();
    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Icon(Icons.store_rounded, color: AppColors.success, size: 20),
        const SizedBox(width: 8),
        const Expanded(child: Text('Sucursales', style: AppTextStyles.titleMedium)),
        Text('${sedes.where((s) => s['activo'] == true).length} activas', style: AppTextStyles.bodySmall)]),
      const SizedBox(height: 12),
      for (int i = 0; i < sedes.length && i < 4; i++) ...[
        Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(
              color: sedes[i]['activo'] == true ? AppColors.success : AppColors.textTertiary,
              shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(child: Text(sedes[i]['nombre'] as String? ?? '',
              style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w500, color: AppColors.textPrimary))),
          if (sedes[i]['ruc'] != null)
            Text('RUC: ${sedes[i]["ruc"]}', style: AppTextStyles.labelSmall),
        ])),
        if (i < 3 && i < sedes.length - 1) const Divider(height: 4),
      ],
    ]));
  }
}

class _AuditCard extends StatelessWidget {
  final List<Map<String, dynamic>> audit;
  const _AuditCard({required this.audit});

  @override
  Widget build(BuildContext context) {
    if (audit.isEmpty) return const SizedBox.shrink();
    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Icon(Icons.history_rounded, color: AppColors.primary, size: 20),
        const SizedBox(width: 8), const Text('Actividad reciente', style: AppTextStyles.titleMedium)]),
      const SizedBox(height: 12),
      for (int i = 0; i < audit.length; i++) ...[
        _ARow(log: audit[i]),
        if (i < audit.length - 1) const Divider(height: 1),
      ],
    ]));
  }
}

class _ARow extends StatelessWidget {
  final Map<String, dynamic> log;
  const _ARow({required this.log});

  @override
  Widget build(BuildContext context) {
    final action = log['accion'] as String? ?? '';
    final username = log['usuario']?['username'] as String? ?? 'Sistema';
    DateTime? dt;
    try { dt = DateTime.parse(log['createdAt'] ?? '').toLocal(); } catch (_) {}
    return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [
      Container(width: 32, height: 32,
          decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(9)),
          child: const Icon(Icons.bolt_rounded, size: 16, color: AppColors.primary)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(action.replaceAll('_', ' '),
            style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
        Text(username, style: AppTextStyles.labelSmall),
      ])),
      Text(dt != null ? FormatUtils.timeAgo(dt) : '', style: AppTextStyles.labelSmall),
    ]));
  }
}

class _SessionsCard extends StatelessWidget {
  final List<Map<String, dynamic>> sessions;
  const _SessionsCard({required this.sessions});

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Icon(Icons.devices_rounded, color: AppColors.accent, size: 20),
        const SizedBox(width: 8), const Text('Sesiones activas', style: AppTextStyles.titleMedium),
        const Spacer(), CountBadge(count: sessions.length, color: AppColors.primary)]),
      const SizedBox(height: 12),
      if (sessions.isEmpty) const Text('Sin sesiones activas', style: AppTextStyles.bodyMedium)
      else for (int i = 0; i < sessions.length && i < 3; i++) ...[
        Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
          Icon(_icon(sessions[i]['deviceType'] as String?), size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(sessions[i]['deviceName'] as String? ?? 'Dispositivo',
                style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
            if (sessions[i]['ip'] != null) Text(sessions[i]['ip']!, style: AppTextStyles.labelSmall),
          ])),
          if (sessions[i]['actual'] == true) Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(100)),
            child: const Text('Esta sesion',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.success))),
        ])),
      ],
    ]));

  IconData _icon(String? t) {
    switch (t) {
      case 'android': return Icons.android_rounded;
      case 'ios': return Icons.phone_iphone_rounded;
      default: return Icons.computer_rounded;
    }
  }
}

class _ErrCard extends StatelessWidget {
  final String err;
  final VoidCallback retry;
  const _ErrCard({required this.err, required this.retry});

  @override
  Widget build(BuildContext context) => AppCard(child: Column(children: [
    const Icon(Icons.wifi_off_rounded, color: AppColors.error, size: 40),
    const SizedBox(height: 12),
    const Text('Error al cargar datos', style: AppTextStyles.titleMedium),
    const SizedBox(height: 8),
    Text(err, style: AppTextStyles.bodySmall, textAlign: TextAlign.center),
    const SizedBox(height: 16),
    ElevatedButton.icon(onPressed: retry,
        icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Reintentar')),
  ]));
}
