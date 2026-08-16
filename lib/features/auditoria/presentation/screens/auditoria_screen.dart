import 'dart:convert';

import 'package:flutter/material.dart';
import '../../../../core/navigation/app_nav.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_ui_components.dart';

String auditUsername(Map<String, dynamic> log) {
  final usuario = log['usuario'];
  if (usuario is Map) {
    return usuario['username'] as String? ?? 'Sistema';
  }
  if (usuario is String && usuario.isNotEmpty) return usuario;
  return log['username'] as String? ?? 'Sistema';
}

class AuditoriaState {
  final bool isLoading;
  final String? error;
  final List<Map<String, dynamic>> logs;
  final int total, page, totalPages;
  final String? accionFilter, entidadFilter, desdeFilter, hastaFilter;
  final Map<String, String> sedeNames;
  const AuditoriaState({
    this.isLoading = false,
    this.error,
    this.logs = const [],
    this.total = 0,
    this.page = 1,
    this.totalPages = 1,
    this.accionFilter,
    this.entidadFilter,
    this.desdeFilter,
    this.hastaFilter,
    this.sedeNames = const {},
  });
  AuditoriaState copyWith({
    bool? isLoading,
    String? error,
    List<Map<String, dynamic>>? logs,
    int? total,
    int? page,
    int? totalPages,
    String? accionFilter,
    String? entidadFilter,
    String? desdeFilter,
    String? hastaFilter,
    Map<String, String>? sedeNames,
  }) => AuditoriaState(
    isLoading: isLoading ?? this.isLoading,
    error: error,
    logs: logs ?? this.logs,
    total: total ?? this.total,
    page: page ?? this.page,
    totalPages: totalPages ?? this.totalPages,
    accionFilter: accionFilter ?? this.accionFilter,
    entidadFilter: entidadFilter ?? this.entidadFilter,
    desdeFilter: desdeFilter ?? this.desdeFilter,
    hastaFilter: hastaFilter ?? this.hastaFilter,
    sedeNames: sedeNames ?? this.sedeNames,
  );
}

class AuditoriaNotifier extends StateNotifier<AuditoriaState> {
  final ApiClient _api;
  AuditoriaNotifier(this._api) : super(const AuditoriaState()) {
    load();
  }

  Future<void> load({int page = 1}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final params = <String, dynamic>{'pagina': page, 'limite': 25};
      if (state.accionFilter != null && state.accionFilter!.isNotEmpty)
        params['accion'] = state.accionFilter;
      if (state.entidadFilter != null && state.entidadFilter!.isNotEmpty)
        params['entidad'] = state.entidadFilter;
      if (state.desdeFilter case final value?) {
        final date = auditCivilDate(value);
        if (date != null) params['desde'] = auditApiDate(date);
      }
      if (state.hastaFilter case final value?) {
        final date = auditCivilDate(value);
        if (date != null) {
          params['hasta'] = auditApiDate(date, endOfDay: true);
        }
      }
      final r = await _api.get(ApiConstants.audit, queryParameters: params);
      final d = r.data as Map;
      var sedeNames = state.sedeNames;
      if (sedeNames.isEmpty) {
        try {
          final response = await _api.get(
            ApiConstants.establishments,
            queryParameters: {'pagina': 1, 'limite': 100},
          );
          final sedes = (response.data as Map)['data'] as List? ?? const [];
          sedeNames = {
            for (final sede in sedes.whereType<Map>())
              if (sede['id'] is String && sede['nombre'] is String)
                sede['id'] as String: sede['nombre'] as String,
          };
        } catch (_) {
          // La auditoria sigue siendo util aunque el catalogo no sea accesible.
        }
      }
      state = state.copyWith(
        isLoading: false,
        logs: List<Map<String, dynamic>>.from(d['data'] ?? []),
        total: d['total'] as int? ?? 0,
        page: d['pagina'] as int? ?? 1,
        totalPages: d['totalPaginas'] as int? ?? 1,
        sedeNames: sedeNames,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setFilters({
    String? accion,
    String? entidad,
    String? desde,
    String? hasta,
  }) {
    state = AuditoriaState(
      logs: state.logs,
      total: state.total,
      page: state.page,
      totalPages: state.totalPages,
      accionFilter: accion?.trim().isEmpty == true
          ? null
          : accion?.trim().toUpperCase(),
      entidadFilter: entidad?.trim().isEmpty == true ? null : entidad,
      desdeFilter: desde,
      hastaFilter: hasta,
      sedeNames: state.sedeNames,
    );
    load(page: 1);
  }
}

final auditoriaProvider =
    StateNotifierProvider<AuditoriaNotifier, AuditoriaState>(
      (ref) => AuditoriaNotifier(ApiClient.instance),
    );

class AuditoriaScreen extends ConsumerWidget {
  const AuditoriaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(auditoriaProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(auditoriaProvider.notifier).load(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          children: [
            Row(
              children: [
                Text(
                  '${state.total} registros',
                  style: AppTextStyles.bodySmall,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(
                    Icons.filter_list_rounded,
                    color: AppColors.primary,
                  ),
                  onPressed: () => _showFilters(context, ref, state),
                ),
              ],
            ),
            if (state.accionFilter != null ||
                state.entidadFilter != null ||
                state.desdeFilter != null ||
                state.hastaFilter != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Filtros activos: ',
                      style: AppTextStyles.labelSmall,
                    ),
                    if (state.accionFilter != null)
                      _FilterChip(
                        label: state.accionFilter!,
                        onRemove: () => ref
                            .read(auditoriaProvider.notifier)
                            .setFilters(
                              entidad: state.entidadFilter,
                              desde: state.desdeFilter,
                              hasta: state.hastaFilter,
                            ),
                      ),
                    if (state.entidadFilter != null)
                      _FilterChip(
                        label: state.entidadFilter!,
                        onRemove: () => ref
                            .read(auditoriaProvider.notifier)
                            .setFilters(
                              accion: state.accionFilter,
                              desde: state.desdeFilter,
                              hasta: state.hastaFilter,
                            ),
                      ),
                    if (state.desdeFilter != null)
                      _FilterChip(
                        label: 'Desde ${state.desdeFilter}',
                        onRemove: () => ref
                            .read(auditoriaProvider.notifier)
                            .setFilters(
                              accion: state.accionFilter,
                              entidad: state.entidadFilter,
                              hasta: state.hastaFilter,
                            ),
                      ),
                    if (state.hastaFilter != null)
                      _FilterChip(
                        label: 'Hasta ${state.hastaFilter}',
                        onRemove: () => ref
                            .read(auditoriaProvider.notifier)
                            .setFilters(
                              accion: state.accionFilter,
                              entidad: state.entidadFilter,
                              desde: state.desdeFilter,
                            ),
                      ),
                  ],
                ),
              ),
            if (state.logs.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AuditKpis(total: state.total, logs: state.logs),
              ),
            if (state.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: AppLoading(),
              )
            else if (state.error != null)
              AppErrorState(
                message: state.error!,
                onRetry: () => ref.read(auditoriaProvider.notifier).load(),
              )
            else if (state.logs.isEmpty)
              const AppEmptyState(
                icon: Icons.history_outlined,
                title: 'Sin registros de auditoria',
              )
            else ...[
              for (final log in state.logs)
                _LogTile(
                  log: log,
                  sedeName: state.sedeNames[log['sedeId']],
                  onTap: () => _showDetail(context, {
                    ...log,
                    'sedeNombre': state.sedeNames[log['sedeId']],
                  }),
                ),
              AppPagination(
                page: state.page,
                totalPages: state.totalPages,
                total: state.total,
                onPageChange: (p) => ref
                    .read(auditoriaProvider.notifier)
                    .load(page: p),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showFilters(BuildContext context, WidgetRef ref, AuditoriaState state) {
    final accionCtrl = TextEditingController(text: state.accionFilter ?? '');
    final entidadCtrl = TextEditingController(text: state.entidadFilter ?? '');
    DateTime? desde = auditCivilDate(state.desdeFilter);
    DateTime? hasta = auditCivilDate(state.hastaFilter);
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl),
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Filtrar auditoria',
                      style: AppTextStyles.headlineMedium,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: accionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Accion (ej: LOGIN_EXITOSO)',
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: entidadCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Entidad (ej: Usuario)',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('audit-date-from'),
                        onPressed: () async {
                          final value = await showDatePicker(
                            context: sheetContext,
                            initialDate: desde ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (value != null) {
                            setSheetState(() => desde = value);
                          }
                        },
                        icon: const Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                        ),
                        label: Text(
                          desde == null ? 'Desde' : FormatUtils.date(desde!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('audit-date-to'),
                        onPressed: () async {
                          final value = await showDatePicker(
                            context: sheetContext,
                            initialDate: hasta ?? DateTime.now(),
                            firstDate: desde ?? DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (value != null) {
                            setSheetState(() => hasta = value);
                          }
                        },
                        icon: const Icon(Icons.event_outlined, size: 16),
                        label: Text(
                          hasta == null ? 'Hasta' : FormatUtils.date(hasta!),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          accionCtrl.clear();
                          entidadCtrl.clear();
                          Navigator.of(context).pop();
                          ref.read(auditoriaProvider.notifier).setFilters();
                        },
                        child: const Text('Limpiar filtros'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          ref
                              .read(auditoriaProvider.notifier)
                              .setFilters(
                                accion: accionCtrl.text.isEmpty
                                    ? null
                                    : accionCtrl.text,
                                entidad: entidadCtrl.text.isEmpty
                                    ? null
                                    : entidadCtrl.text,
                                desde: desde == null
                                    ? null
                                    : auditCivilDateString(desde!),
                                hasta: hasta == null
                                    ? null
                                    : auditCivilDateString(hasta!),
                              );
                        },
                        child: const Text('Aplicar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, Map<String, dynamic> log) {
    AppNav.push(context, _LogDetailScreen(log: log));
  }
}

class _LogTile extends StatelessWidget {
  final Map<String, dynamic> log;
  final String? sedeName;
  final VoidCallback onTap;
  const _LogTile({required this.log, this.sedeName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final action = log['accion'] as String? ?? '';
    final username = auditUsername(log);
    final entidad = log['entidad'] as String?;
    final ip = log['ip'] as String?;
    DateTime? dt;
    try {
      dt = DateTime.parse(log['createdAt'] ?? '').toLocal();
    } catch (_) {}

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: context.colors.borderLight, width: 0.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AuditActionBadge(action: action),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 12,
                          color: context.colors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.labelSmall,
                          ),
                        ),
                        if (entidad != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.data_object_rounded,
                            size: 12,
                            color: context.colors.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              entidad!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.labelSmall,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (ip != null)
                      Row(
                        children: [
                          Icon(
                            Icons.language_rounded,
                            size: 12,
                            color: context.colors.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(ip, style: AppTextStyles.labelSmall),
                        ],
                      ),
                    if (sedeName != null)
                      Row(
                        children: [
                          Icon(
                            Icons.store_outlined,
                            size: 12,
                            color: context.colors.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(sedeName!, style: AppTextStyles.labelSmall),
                        ],
                      ),
                  ],
                ),
              ),
              Text(
                dt != null ? FormatUtils.timeAgo(dt) : '',
                style: AppTextStyles.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

DateTime? auditCivilDate(String? value) {
  if (value == null || value.length < 10) return null;
  final parts = value.substring(0, 10).split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  final date = DateTime(year, month, day);
  return date.year == year && date.month == month && date.day == day
      ? date
      : null;
}

String auditCivilDateString(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String auditApiDate(
  DateTime date, {
  bool endOfDay = false,
  Duration? utcOffset,
}) {
  final civilAsUtc = DateTime.utc(
    date.year,
    date.month,
    date.day,
    endOfDay ? 23 : 0,
    endOfDay ? 59 : 0,
    endOfDay ? 59 : 0,
    endOfDay ? 999 : 0,
  );
  return civilAsUtc
      .subtract(utcOffset ?? date.timeZoneOffset)
      .toIso8601String();
}

// ─── Subpantalla: Detalle del evento de auditoría ────────────────────────────

class _LogDetailScreen extends StatelessWidget {
  final Map<String, dynamic> log;
  const _LogDetailScreen({required this.log});

  @override
  Widget build(BuildContext context) {
    final action = log['accion'] as String? ?? '';
    final username = auditUsername(log);
    final entidad = log['entidad'] as String? ?? '';
    final entidadId = log['entidadId'] as String? ?? '';
    final rawIp = log['ip'] as String? ?? '';
    final ip = const ['::1', '127.0.0.1', '::ffff:127.0.0.1'].contains(rawIp)
        ? 'Local'
        : rawIp;
    final ua = log['userAgent'] as String? ?? '';
    final sedeId =
        log['sedeNombre'] as String? ?? log['sedeId'] as String? ?? '';
    final fecha = log['createdAt'] as String? ?? '';
    final detalle = log['detalle'];

    DateTime? dt;
    try {
      dt = DateTime.parse(fecha).toLocal();
    } catch (_) {}

    return Scaffold(
      backgroundColor: context.colors.backgroundAlt,
      appBar: SubPageAppBar(
        title: 'Detalle del evento',
        subtitle: dt != null ? FormatUtils.dateTime(dt) : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        child: Column(
          children: [
            // Badge acción
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.colors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AuditActionBadge(action: action),
                  const SizedBox(height: 10),
                  _ARow('Usuario', username),
                  if (entidad.isNotEmpty) _ARow('Entidad', entidad),
                  if (entidadId.isNotEmpty)
                    _ARow('ID Entidad', entidadId, mono: true),
                  if (ip.isNotEmpty) _ARow('IP', ip),
                  if (sedeId.isNotEmpty) _ARow('Sede', sedeId),
                  if (ua.isNotEmpty) _ARow('User-Agent', ua),
                ],
              ),
            ),
            if (detalle != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.colors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detalle',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.colors.backgroundAlt,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        detalle is Map || detalle is List
                            ? const JsonEncoder.withIndent(
                                '  ',
                              ).convert(detalle)
                            : detalle.toString(),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: context.colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AuditKpis extends StatelessWidget {
  const _AuditKpis({required this.total, required this.logs});

  final int total;
  final List<Map<String, dynamic>> logs;

  @override
  Widget build(BuildContext context) {
    final actions = logs
        .map((log) => log['accion'])
        .whereType<String>()
        .toSet();
    final entities = logs
        .map((log) => log['entidad'])
        .whereType<String>()
        .toSet();
    final users = logs
        .map(auditUsername)
        .where((name) => name.isNotEmpty)
        .toSet();
    final values = [
      ('Registros', total, AppColors.primary),
      ('Acciones', actions.length, AppColors.warning),
      ('Entidades', entities.length, AppColors.info),
      ('Usuarios', users.length, AppColors.success),
    ];
    return GridView.count(
      crossAxisCount: MediaQuery.sizeOf(context).width >= 700 ? 4 : 2,
      childAspectRatio: 2.8,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
          for (final value in values)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: value.$3.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  Text(
                    '${value.$2}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: value.$3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      value.$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelSmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
    );
  }
}

class _ARow extends StatelessWidget {
  final String label, value;
  final bool mono;
  const _ARow(this.label, this.value, {this.mono = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: context.colors.textTertiary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: context.colors.textPrimary,
              fontFamily: mono ? 'monospace' : null,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

class _LogDetail extends StatelessWidget {
  final Map<String, dynamic> log;
  const _LogDetail({required this.log});

  @override
  Widget build(BuildContext context) {
    final items = {
      'Accion': log['accion'] as String? ?? '',
      'Usuario': auditUsername(log),
      'Entidad': log['entidad'] as String? ?? '',
      'ID Entidad': log['entidadId'] as String? ?? '',
      'IP': log['ip'] as String? ?? '',
      'User-Agent': log['userAgent'] as String? ?? '',
      'Sede': log['sedeId'] as String? ?? '',
      'Fecha': log['createdAt'] as String? ?? '',
    };
    final detalle = log['detalle'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in items.entries)
          if (e.value.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    e.key,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: context.colors.textTertiary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    e.value,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: context.colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 12),
          ],
        if (detalle != null) ...[
          const Text('Detalle:', style: AppTextStyles.labelLarge),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.backgroundAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              detalle.toString(),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: context.colors.textPrimary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _FilterChip({required this.label, required this.onRemove});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 6),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: context.colors.primarySurface,
      borderRadius: BorderRadius.circular(100),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: onRemove,
          child: const Icon(
            Icons.close_rounded,
            size: 12,
            color: AppColors.primary,
          ),
        ),
      ],
    ),
  );
}
