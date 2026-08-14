import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_loading.dart';

class SecuritySessionsRepository {
  final ApiClient _api;

  const SecuritySessionsRepository(this._api);

  Future<List<Map<String, dynamic>>> list() async {
    final response = await _api.get(ApiConstants.sessions);
    return List<Map<String, dynamic>>.from(response.data ?? []);
  }

  Future<void> revoke(String id) => _api.delete(ApiConstants.revokeSession(id));

  Future<void> revokeOthers() => _api.delete(ApiConstants.sessions);
}

final securitySessionsRepositoryProvider = Provider<SecuritySessionsRepository>(
  (ref) => SecuritySessionsRepository(ApiClient.instance),
);

final securitySessionsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  return ref.watch(securitySessionsRepositoryProvider).list();
});

class SeguridadScreen extends ConsumerWidget {
  const SeguridadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(securitySessionsProvider);
    return Scaffold(
      backgroundColor: context.colors.background,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(securitySessionsProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            Text(
              'Protección de cuenta',
              style: AppTextStyles.headlineMedium.copyWith(
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Revisa tus dispositivos conectados y cierra accesos que no reconozcas.',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 16),
            sessions.when(
              loading: () => const AppLoading(),
              error: (error, _) => AppCard(
                child: Column(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 8),
                    Text('No se pudieron cargar las sesiones: $error'),
                    TextButton(
                      onPressed: () => ref.invalidate(securitySessionsProvider),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
              data: (items) => _SessionsContent(
                sessions: items,
                onChanged: () => ref.invalidate(securitySessionsProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionsContent extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> sessions;
  final VoidCallback onChanged;

  const _SessionsContent({required this.sessions, required this.onChanged});

  @override
  ConsumerState<_SessionsContent> createState() => _SessionsContentState();
}

class _SessionsContentState extends ConsumerState<_SessionsContent> {
  String? _loadingAction;

  @override
  Widget build(BuildContext context) {
    final current = widget.sessions
        .where((item) => item['actual'] == true)
        .firstOrNull;
    final others = widget.sessions
        .where((item) => item['actual'] != true)
        .toList();
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _Metric(
                label: 'Activas',
                value: '${widget.sessions.length}',
                icon: Icons.devices_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Metric(
                label: 'Otros equipos',
                value: '${others.length}',
                icon: Icons.laptop_rounded,
                color: AppColors.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dispositivos conectados',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: context.colors.textPrimary,
                          ),
                        ),
                        Text(
                          current?['deviceName'] as String? ??
                              'Sesión actual protegida',
                          style: AppTextStyles.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  if (others.isNotEmpty)
                    TextButton.icon(
                      key: const Key('close-other-sessions'),
                      onPressed: _loadingAction == null ? _closeOthers : null,
                      icon: _loadingAction == 'others'
                          ? const SizedBox.square(
                              dimension: 15,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.logout_rounded, size: 15),
                      label: const Text('Cerrar otras'),
                    ),
                ],
              ),
              const Divider(height: 20),
              if (widget.sessions.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: Text('No hay sesiones activas.')),
                )
              else
                for (
                  var index = 0;
                  index < widget.sessions.length;
                  index++
                ) ...[
                  _SessionTile(
                    session: widget.sessions[index],
                    loading:
                        _loadingAction ==
                        'session:${widget.sessions[index]['id']}',
                    onClose:
                        widget.sessions[index]['actual'] == true ||
                            _loadingAction != null
                        ? null
                        : () => _closeSession(widget.sessions[index]),
                  ),
                  if (index < widget.sessions.length - 1)
                    Divider(height: 1, color: context.colors.divider),
                ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: context.colors.successLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Contraseña segura', style: AppTextStyles.titleMedium),
                    Text(
                      '6-72 caracteres, una minúscula y un número.',
                      style: AppTextStyles.labelSmall,
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => context.push('/cambiar-password?forced=false'),
                child: const Text('Cambiar'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _closeSession(Map<String, dynamic> session) async {
    final ok = await ConfirmDialog.show(
      context: context,
      title: 'Cerrar sesión',
      description:
          'Se cerrará el acceso de ${session['deviceName'] ?? 'este dispositivo'}.',
      confirmLabel: 'Cerrar sesión',
      isDanger: true,
    );
    if (!ok) return;
    final action = 'session:${session['id']}';
    if (_loadingAction != null || !mounted) return;
    setState(() => _loadingAction = action);
    try {
      await ref
          .read(securitySessionsRepositoryProvider)
          .revoke(session['id'] as String);
      if (!mounted) return;
      widget.onChanged();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sesión cerrada')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cerrar la sesión: $error')),
      );
    } finally {
      if (mounted && _loadingAction == action) {
        setState(() => _loadingAction = null);
      }
    }
  }

  Future<void> _closeOthers() async {
    final ok = await ConfirmDialog.show(
      context: context,
      title: 'Cerrar otras sesiones',
      description:
          'Se cerrarán todas las sesiones excepto la de este dispositivo.',
      confirmLabel: 'Cerrar sesiones',
      isDanger: true,
    );
    if (!ok) return;
    if (_loadingAction != null || !mounted) return;
    setState(() => _loadingAction = 'others');
    try {
      await ref.read(securitySessionsRepositoryProvider).revokeOthers();
      if (!mounted) return;
      widget.onChanged();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Otras sesiones cerradas')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cerrar las sesiones: $error')),
      );
    } finally {
      if (mounted && _loadingAction == 'others') {
        setState(() => _loadingAction = null);
      }
    }
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: context.colors.borderLight),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w800, color: color),
            ),
            Text(label, style: AppTextStyles.labelSmall),
          ],
        ),
      ],
    ),
  );
}

class _SessionTile extends StatelessWidget {
  final Map<String, dynamic> session;
  final VoidCallback? onClose;
  final bool loading;

  const _SessionTile({
    required this.session,
    this.onClose,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final actual = session['actual'] as bool? ?? false;
    final type = session['deviceType'] as String?;
    final date = DateTime.tryParse(
      session['lastUsedAt'] as String? ?? session['createdAt'] as String? ?? '',
    );
    final icon = type == 'android'
        ? Icons.android_rounded
        : type == 'ios'
        ? Icons.phone_iphone_rounded
        : Icons.computer_rounded;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: actual ? AppColors.success : AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        session['deviceName'] as String? ?? 'Dispositivo',
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.colors.textPrimary,
                        ),
                      ),
                    ),
                    if (actual) ...[
                      const SizedBox(width: 6),
                      const Text(
                        'ACTUAL',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  [
                    session['ip'] as String?,
                    if (date != null) FormatUtils.dateTime(date.toLocal()),
                  ].whereType<String>().join(' · '),
                  style: AppTextStyles.labelSmall,
                ),
              ],
            ),
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (onClose != null)
            IconButton(
              tooltip: 'Cerrar sesión',
              onPressed: onClose,
              icon: const Icon(
                Icons.logout_rounded,
                size: 18,
                color: AppColors.error,
              ),
            ),
        ],
      ),
    );
  }
}
