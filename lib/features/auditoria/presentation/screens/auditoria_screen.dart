import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_ui_components.dart';

class AuditoriaState {
  final bool isLoading; final String? error;
  final List<Map<String, dynamic>> logs; final int total, page, totalPages;
  final String? accionFilter, entidadFilter, desdeFilter, hastaFilter;
  const AuditoriaState({this.isLoading = false, this.error, this.logs = const [],
      this.total = 0, this.page = 1, this.totalPages = 1,
      this.accionFilter, this.entidadFilter, this.desdeFilter, this.hastaFilter});
  AuditoriaState copyWith({bool? isLoading, String? error, List<Map<String, dynamic>>? logs,
      int? total, int? page, int? totalPages, String? accionFilter, String? entidadFilter,
      String? desdeFilter, String? hastaFilter}) =>
    AuditoriaState(isLoading: isLoading ?? this.isLoading, error: error, logs: logs ?? this.logs,
        total: total ?? this.total, page: page ?? this.page, totalPages: totalPages ?? this.totalPages,
        accionFilter: accionFilter ?? this.accionFilter, entidadFilter: entidadFilter ?? this.entidadFilter,
        desdeFilter: desdeFilter ?? this.desdeFilter, hastaFilter: hastaFilter ?? this.hastaFilter);
}

class AuditoriaNotifier extends StateNotifier<AuditoriaState> {
  final ApiClient _api;
  AuditoriaNotifier(this._api) : super(const AuditoriaState()) { load(); }

  Future<void> load({int page = 1}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final params = <String, dynamic>{'pagina': page, 'limite': 25};
      if (state.accionFilter != null && state.accionFilter!.isNotEmpty) params['accion'] = state.accionFilter;
      if (state.entidadFilter != null && state.entidadFilter!.isNotEmpty) params['entidad'] = state.entidadFilter;
      if (state.desdeFilter != null) params['desde'] = state.desdeFilter;
      if (state.hastaFilter != null) params['hasta'] = state.hastaFilter;
      final r = await _api.get(ApiConstants.audit, queryParameters: params);
      final d = r.data as Map;
      state = state.copyWith(isLoading: false,
          logs: List<Map<String, dynamic>>.from(d['data'] ?? []),
          total: d['total'] as int? ?? 0, page: d['pagina'] as int? ?? 1, totalPages: d['totalPaginas'] as int? ?? 1);
    } catch (e) { state = state.copyWith(isLoading: false, error: e.toString()); }
  }

  void setFilters({String? accion, String? entidad, String? desde, String? hasta}) {
    state = state.copyWith(accionFilter: accion, entidadFilter: entidad, desdeFilter: desde, hastaFilter: hasta);
    load(page: 1);
  }
}

final auditoriaProvider = StateNotifierProvider<AuditoriaNotifier, AuditoriaState>(
    (ref) => AuditoriaNotifier(ApiClient.instance));

class AuditoriaScreen extends ConsumerWidget {
  const AuditoriaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(auditoriaProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundAlt,
      body: SafeArea(bottom: false, child: Column(children: [
        Container(color: AppColors.background, child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: Row(children: [
            const Icon(Icons.history_rounded, color: AppColors.primary, size: 24),
            const SizedBox(width: 10),
            const Expanded(child: Text('Auditoria', style: AppTextStyles.headlineLarge)),
            Text('${state.total} registros', style: AppTextStyles.bodySmall),
            const SizedBox(width: 8),
            IconButton(icon: const Icon(Icons.filter_list_rounded, color: AppColors.primary),
                onPressed: () => _showFilters(context, ref, state)),
          ])),
          if (state.accionFilter != null || state.entidadFilter != null)
            Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Row(children: [
              const Text('Filtros activos: ', style: AppTextStyles.labelSmall),
              if (state.accionFilter != null) _FilterChip(label: state.accionFilter!,
                  onRemove: () => ref.read(auditoriaProvider.notifier).setFilters(entidad: state.entidadFilter)),
              if (state.entidadFilter != null) _FilterChip(label: state.entidadFilter!,
                  onRemove: () => ref.read(auditoriaProvider.notifier).setFilters(accion: state.accionFilter)),
            ])),
        ])),
        Expanded(child: RefreshIndicator(color: AppColors.primary,
          onRefresh: () => ref.read(auditoriaProvider.notifier).load(),
          child: state.isLoading ? const AppLoading()
            : state.error != null ? AppErrorState(message: state.error!, onRetry: () => ref.read(auditoriaProvider.notifier).load())
            : state.logs.isEmpty ? const AppEmptyState(icon: Icons.history_outlined, title: 'Sin registros de auditoria')
            : ListView(children: [
                const SizedBox(height: 8),
                for (final log in state.logs)
                  _LogTile(log: log, onTap: () => _showDetail(context, log)),
                AppPagination(page: state.page, totalPages: state.totalPages, total: state.total,
                    onPageChange: (p) { final s = ref.read(auditoriaProvider); ref.read(auditoriaProvider.notifier).setFilters(accion: s.accionFilter, entidad: s.entidadFilter); }),
                const SizedBox(height: 80),
              ]))),
      ])));
  }

  void _showFilters(BuildContext context, WidgetRef ref, AuditoriaState state) {
    final accionCtrl = TextEditingController(text: state.accionFilter ?? '');
    final entidadCtrl = TextEditingController(text: state.entidadFilter ?? '');
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
        child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Text('Filtrar auditoria', style: AppTextStyles.headlineMedium), const Spacer(),
            IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop())]),
          const SizedBox(height: 16),
          TextField(controller: accionCtrl, decoration: const InputDecoration(labelText: 'Accion (ej: LOGIN_EXITOSO)'),
              textCapitalization: TextCapitalization.characters),
          const SizedBox(height: 12),
          TextField(controller: entidadCtrl, decoration: const InputDecoration(labelText: 'Entidad (ej: Usuario)')),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () { accionCtrl.clear(); entidadCtrl.clear();
                Navigator.of(context).pop(); ref.read(auditoriaProvider.notifier).setFilters(); },
                child: const Text('Limpiar filtros'))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(onPressed: () { Navigator.of(context).pop();
                ref.read(auditoriaProvider.notifier).setFilters(accion: accionCtrl.text.isEmpty ? null : accionCtrl.text,
                    entidad: entidadCtrl.text.isEmpty ? null : entidadCtrl.text); },
                child: const Text('Aplicar'))),
          ]),
        ]))));
  }

  void _showDetail(BuildContext context, Map<String, dynamic> log) {
    AppBottomSheet.show(context: context, title: 'Detalle del evento',
      child: _LogDetail(log: log));
  }
}

class _LogTile extends StatelessWidget {
  final Map<String, dynamic> log; final VoidCallback onTap;
  const _LogTile({required this.log, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final action = log['accion'] as String? ?? '';
    final username = log['usuario']?['username'] as String? ?? 'Sistema';
    final entidad = log['entidad'] as String?;
    final ip = log['ip'] as String?;
    DateTime? dt;
    try { dt = DateTime.parse(log['createdAt'] ?? '').toLocal(); } catch (_) {}

    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: GestureDetector(onTap: onTap, child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.borderLight, width: 0.5)),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AuditActionBadge(action: action),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.person_outline_rounded, size: 12, color: AppColors.textTertiary),
              const SizedBox(width: 4), Text(username, style: AppTextStyles.labelSmall),
              if (entidad != null) ...[const SizedBox(width: 8),
                const Icon(Icons.data_object_rounded, size: 12, color: AppColors.textTertiary),
                const SizedBox(width: 4), Text(entidad, style: AppTextStyles.labelSmall)],
            ]),
            if (ip != null) Row(children: [
              const Icon(Icons.language_rounded, size: 12, color: AppColors.textTertiary),
              const SizedBox(width: 4), Text(ip, style: AppTextStyles.labelSmall),
            ]),
          ])),
          Text(dt != null ? FormatUtils.timeAgo(dt) : '', style: AppTextStyles.labelSmall),
        ]))));
  }
}

class _LogDetail extends StatelessWidget {
  final Map<String, dynamic> log;
  const _LogDetail({required this.log});

  @override
  Widget build(BuildContext context) {
    final items = {
      'Accion': log['accion'] as String? ?? '',
      'Usuario': log['usuario']?['username'] as String? ?? 'Sistema',
      'Entidad': log['entidad'] as String? ?? '',
      'ID Entidad': log['entidadId'] as String? ?? '',
      'IP': log['ip'] as String? ?? '',
      'User-Agent': log['userAgent'] as String? ?? '',
      'Sede': log['sedeId'] as String? ?? '',
      'Fecha': log['createdAt'] as String? ?? '',
    };
    final detalle = log['detalle'];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final e in items.entries) if (e.value.isNotEmpty) ...[
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 100, child: Text(e.key, style: AppTextStyles.labelLarge.copyWith(color: AppColors.textTertiary))),
          Expanded(child: Text(e.value, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary))),
        ]),
        const Divider(height: 12),
      ],
      if (detalle != null) ...[
        const Text('Detalle:', style: AppTextStyles.labelLarge),
        const SizedBox(height: 6),
        Container(width: double.infinity, padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.backgroundAlt, borderRadius: BorderRadius.circular(8)),
          child: SelectableText(detalle.toString(),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppColors.textPrimary))),
      ],
    ]);
  }
}

class _FilterChip extends StatelessWidget {
  final String label; final VoidCallback onRemove;
  const _FilterChip({required this.label, required this.onRemove});
  @override Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(right: 6),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(100)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
      const SizedBox(width: 4),
      GestureDetector(onTap: onRemove, child: const Icon(Icons.close_rounded, size: 12, color: AppColors.primary)),
    ]));
}
