import 'package:flutter/material.dart';
import '../../../../core/widgets/app_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final sessionListProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final r = await ApiClient.instance.get(ApiConstants.sessions);
  return List<Map<String, dynamic>>.from(r.data ?? []);
});

class PerfilScreen extends ConsumerWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final sessionsAsync = ref.watch(sessionListProvider);
    final username = user?.username ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                120,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Profile card
                  AppCard(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 32,
                              backgroundColor: AppColors.avatarColor(username),
                              child: Text(
                                FormatUtils.initials(username),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    username,
                                    style: AppTextStyles.titleLarge,
                                  ),
                                  const SizedBox(height: 4),
                                  RoleBadge(role: user?.rol ?? ''),
                                  if (user?.sede != null) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.store_rounded,
                                          size: 12,
                                          color: AppColors.textTertiary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          user!.sedeName,
                                          style: AppTextStyles.labelSmall,
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _QuickAction(
                              icon: Icons.lock_reset_rounded,
                              label: 'Cambiar\ncontrasena',
                              onTap: () => context.push(
                                '/cambiar-password?forced=false',
                              ),
                            ),
                            _QuickAction(
                              icon: Icons.devices_rounded,
                              label: 'Mis\nsesiones',
                              onTap: () => _scrollToSessions(context),
                            ),
                            _QuickAction(
                              icon: Icons.logout_rounded,
                              label: 'Cerrar\nsesion',
                              color: AppColors.error,
                              onTap: () => _logout(context, ref),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Account info
                  _SectionHeader(title: 'Informacion de cuenta'),
                  const SizedBox(height: 8),
                  AppCard(
                    child: Column(
                      children: [
                        _InfoRow(label: 'Usuario', value: username),
                        const Divider(height: 1),
                        _InfoRow(
                          label: 'Rol',
                          value: FormatUtils.roleName(user?.rol ?? ''),
                        ),
                        const Divider(height: 1),
                        _InfoRow(
                          label: 'Sede',
                          value: user?.sede == null
                              ? 'Todas las sedes'
                              : user!.sedeName,
                        ),
                        if (user?.createdAt != null &&
                            user!.createdAt.isNotEmpty) ...[
                          const Divider(height: 1),
                          _InfoRow(
                            label: 'Miembro desde',
                            value: user.createdAt.substring(0, 10),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Sessions
                  _SectionHeader(title: 'Sesiones activas'),
                  const SizedBox(height: 8),
                  sessionsAsync.when(
                    loading: () => const AppLoading(),
                    error: (e, _) =>
                        Text('Error: $e', style: AppTextStyles.bodySmall),
                    data: (sessions) => AppCard(
                      child: Column(
                        children: [
                          for (int i = 0; i < sessions.length; i++) ...[
                            _SessionRow(
                              session: sessions[i],
                              onRevoke: sessions[i]['actual'] == true
                                  ? null
                                  : () async {
                                      try {
                                        await ApiClient.instance.delete(
                                          ApiConstants.revokeSession(
                                            sessions[i]['id'] as String,
                                          ),
                                        );
                                        ref.invalidate(sessionListProvider);
                                        if (context.mounted)
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text('Sesion cerrada'),
                                            ),
                                          );
                                      } catch (e) {
                                        if (context.mounted)
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text('Error: $e'),
                                            ),
                                          );
                                      }
                                    },
                            ),
                            if (i < sessions.length - 1)
                              const Divider(height: 1),
                          ],
                          if (sessions
                              .where((s) => s['actual'] != true)
                              .isNotEmpty) ...[
                            const Divider(height: 16),
                            TextButton(
                              onPressed: () async {
                                final ok = await ConfirmDialog.show(
                                  context: context,
                                  title: 'Cerrar otras sesiones',
                                  description:
                                      'Se cerraran todas las sesiones excepto esta.',
                                  confirmLabel: 'Confirmar',
                                  isDanger: true,
                                );
                                if (ok && context.mounted) {
                                  try {
                                    await ApiClient.instance.delete(
                                      ApiConstants.sessions,
                                    );
                                    ref.invalidate(sessionListProvider);
                                    if (context.mounted)
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Sesiones cerradas'),
                                        ),
                                      );
                                  } catch (e) {
                                    if (context.mounted)
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(content: Text('Error: $e')),
                                      );
                                  }
                                }
                              },
                              child: const Text(
                                'Cerrar todas las otras sesiones',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Logout all
                  AppButton(
                    label: 'Cerrar todas las sesiones y salir',
                    isFullWidth: true,
                    variant: AppButtonVariant.danger,
                    onPressed: () async {
                      final ok = await ConfirmDialog.show(
                        context: context,
                        title: 'Cerrar todas las sesiones',
                        description:
                            'Se cerraran todas tus sesiones en todos los dispositivos.',
                        confirmLabel: 'Cerrar todo',
                        isDanger: true,
                      );
                      if (ok && context.mounted)
                        await ref.read(authProvider.notifier).logoutAll();
                    },
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToSessions(BuildContext context) {
    // Simple scroll — in a real app would use a ScrollController
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final ok = await ConfirmDialog.show(
      context: context,
      title: 'Cerrar sesion',
      description: 'Se cerrara tu sesion actual.',
      confirmLabel: 'Cerrar sesion',
      isDanger: true,
    );
    if (ok && context.mounted) await ref.read(authProvider.notifier).logout();
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: c.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: c, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: c,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Text(
      title.toUpperCase(),
      style: AppTextStyles.labelSmall.copyWith(
        letterSpacing: 0.8,
        color: AppColors.textTertiary,
      ),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SessionRow extends StatelessWidget {
  final Map<String, dynamic> session;
  final VoidCallback? onRevoke;
  const _SessionRow({required this.session, this.onRevoke});
  @override
  Widget build(BuildContext context) {
    final device = session['deviceName'] as String? ?? 'Dispositivo';
    final type = session['deviceType'] as String? ?? 'web';
    final ip = session['ip'] as String?;
    final isCurrent = session['actual'] as bool? ?? false;
    DateTime? last;
    try {
      last = DateTime.parse(session['lastUsedAt'] ?? '').toLocal();
    } catch (_) {}

    IconData icon;
    switch (type) {
      case 'android':
        icon = Icons.android_rounded;
      case 'ios':
        icon = Icons.phone_iphone_rounded;
      default:
        icon = Icons.computer_rounded;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isCurrent ? AppColors.primary : AppColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      device,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.successLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Actual',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (ip != null) Text(ip, style: AppTextStyles.labelSmall),
                if (last != null)
                  Text(
                    'Ultima actividad: ${FormatUtils.timeAgo(last)}',
                    style: AppTextStyles.labelSmall,
                  ),
              ],
            ),
          ),
          if (onRevoke != null)
            IconButton(
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: AppColors.error,
              ),
              onPressed: onRevoke,
            ),
        ],
      ),
    );
  }
}
