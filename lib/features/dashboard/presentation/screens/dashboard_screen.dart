import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/widgets/app_badge.dart';
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
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: 'Inicio',

        actions: [
          if (user?.sede != null)
            Container(
              margin: EdgeInsets.only(right: AppSpacing.sm),
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusRound),
                border: Border.all(color: AppColors.primaryBorder, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.store_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: AppSpacing.xxs),
                  Text(
                    user!.sedeName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(dashboardProvider.notifier).load(),
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tarjeta de bienvenida compacta
              _WelcomeCard(user: user),
              SizedBox(height: AppSpacing.lg),
              
              // Contenido basado en el estado
              if (dash.isLoading)
                AppLoadingIndicator(message: 'Cargando datos...')
              else if (dash.error != null)
                AppErrorState(
                  title: 'Error al cargar datos',
                  message: dash.error!,
                  onActionPressed: () =>
                      ref.read(dashboardProvider.notifier).load(),
                )
              else if (dash.data != null) ...[
                _StatsGrid(data: dash.data!),
                SizedBox(height: AppSpacing.lg),
                
                if (auth.hasPermission('roles:leer')) ...[
                  _UsersByRole(data: dash.data!),
                  SizedBox(height: AppSpacing.lg),
                ],
                
                if (auth.hasPermission('establecimientos:leer')) ...[
                  _SedesCard(
                    sedes: List<Map<String, dynamic>>.from(
                      dash.data!.sedes,
                    ),
                  ),
                  SizedBox(height: AppSpacing.lg),
                ],
                
                if (auth.hasPermission('audit:leer')) ...[
                  _AuditCard(
                    audit: List<Map<String, dynamic>>.from(
                      dash.data!.audit,
                    ),
                  ),
                  SizedBox(height: AppSpacing.lg),
                ],
                
                _SessionsCard(
                  sessions: List<Map<String, dynamic>>.from(
                    dash.data!.sessions,
                  ),
                ),
              ],
              
              SizedBox(height: AppSpacing.xxxl),
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
    final greet = h < 12
        ? 'Buenos días'
        : h < 18
        ? 'Buenas tardes'
        : 'Buenas noches';
    
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          // Avatar con iniciales
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
            ),
            alignment: Alignment.center,
            child: Text(
              FormatUtils.initials(un),
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          // Información
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greet',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                Text(
                  un,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Badge de rol
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: AppColors.roleColor(role).withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
              border: Border.all(
                color: AppColors.roleColor(role).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              FormatUtils.roleName(role),
              style: TextStyle(
                color: AppColors.roleColor(role),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final DashboardData data;
  const _StatsGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final actUsers = data.users.where((u) => u['activo'] == true).length;
    final actSedes = data.sedes.where((s) => s['activo'] == true).length;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resumen',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Usuarios',
                value: '$actUsers',
                icon: Icons.people_rounded,
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatCard(
                label: 'Sucursales',
                value: '$actSedes',
                icon: Icons.store_rounded,
                color: AppColors.success,
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Sesiones',
                value: '${data.sessions.length}',
                icon: Icons.devices_rounded,
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatCard(
                label: 'Roles',
                value: '${data.roles.length}',
                icon: Icons.admin_panel_settings_rounded,
                color: AppColors.roleSuperadmin,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border: Border.all(color: AppColors.border, width: 1),
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
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: color,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1,
            ),
          ),
          SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
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
    
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bar_chart_rounded,
                color: AppColors.primary,
                size: AppSpacing.iconSM,
              ),
              SizedBox(width: AppSpacing.xs),
              Text(
                'Usuarios por rol',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          for (final e in m.entries) ...[
            Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  SizedBox(
                    width: 85,
                    child: Text(
                      FormatUtils.roleName(e.key),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppColors.backgroundAlt,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: mx > 0 ? e.value / mx : 0.0,
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: AppColors.roleColor(e.key),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text(
                    '${e.value}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.roleColor(e.key),
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
}

class _SedesCard extends StatelessWidget {
  final List<Map<String, dynamic>> sedes;
  const _SedesCard({required this.sedes});

  @override
  Widget build(BuildContext context) {
    if (sedes.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.store_rounded,
                color: AppColors.success,
                size: AppSpacing.iconSM,
              ),
              SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Sucursales',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${sedes.where((s) => s['activo'] == true).length} activas',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          ...sedes.take(4).map((sede) => Padding(
            padding: EdgeInsets.only(top: AppSpacing.xs),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: sede['activo'] == true
                        ? AppColors.success
                        : AppColors.textTertiary,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    sede['nombre'] as String? ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (sede['ruc'] != null)
                  Text(
                    'RUC: ${sede["ruc"]}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _AuditCard extends StatelessWidget {
  final List<Map<String, dynamic>> audit;
  const _AuditCard({required this.audit});

  @override
  Widget build(BuildContext context) {
    if (audit.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.history_rounded,
                color: AppColors.primary,
                size: AppSpacing.iconSM,
              ),
              SizedBox(width: AppSpacing.xs),
              Text(
                'Actividad reciente',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          ...audit.map((log) => _AuditRow(log: log)),
        ],
      ),
    );
  }
}

class _AuditRow extends StatelessWidget {
  final Map<String, dynamic> log;
  const _AuditRow({required this.log});

  @override
  Widget build(BuildContext context) {
    final action = log['accion'] as String? ?? '';
    final username = log['usuario']?['username'] as String? ?? 'Sistema';
    DateTime? dt;
    try {
      dt = DateTime.parse(log['createdAt'] ?? '').toLocal();
    } catch (_) {}
    
    return Padding(
      padding: EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
            ),
            child: Icon(
              Icons.bolt_rounded,
              size: 14,
              color: AppColors.primary,
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.replaceAll('_', ' '),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  username,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            dt != null ? FormatUtils.timeAgo(dt) : '',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionsCard extends StatelessWidget {
  final List<Map<String, dynamic>> sessions;
  const _SessionsCard({required this.sessions});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.devices_rounded,
                color: AppColors.primary,
                size: AppSpacing.iconSM,
              ),
              SizedBox(width: AppSpacing.xs),
              Text(
                'Sesiones activas',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusRound),
                ),
                child: Text(
                  '${sessions.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          if (sessions.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                'Sin sesiones activas',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            ...sessions.take(3).map((session) => Padding(
              padding: EdgeInsets.only(top: AppSpacing.xs),
              child: Row(
                children: [
                  Icon(
                    _getDeviceIcon(session['deviceType'] as String?),
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session['deviceName'] as String? ?? 'Dispositivo',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (session['ip'] != null)
                          Text(
                            session['ip']!,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (session['actual'] == true)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                        border: Border.all(
                          color: AppColors.successBorder,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'Actual',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                ],
              ),
            )),
        ],
      ),
    );
  }

  IconData _getDeviceIcon(String? type) {
    switch (type) {
      case 'android':
        return Icons.android_rounded;
      case 'ios':
        return Icons.phone_iphone_rounded;
      default:
        return Icons.computer_rounded;
    }
  }
}
