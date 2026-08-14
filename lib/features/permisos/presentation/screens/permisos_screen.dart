import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_ui_components.dart';

class PermisosState {
  final bool isLoading;
  final String? error;
  final List<Map<String, dynamic>> permisos;
  final List<Map<String, dynamic>> catalogo;
  final int total, page, totalPages;
  final String? moduleFilter;
  final String searchQuery;
  const PermisosState({
    this.isLoading = false,
    this.error,
    this.permisos = const [],
    this.catalogo = const [],
    this.total = 0,
    this.page = 1,
    this.totalPages = 1,
    this.moduleFilter,
    this.searchQuery = '',
  });
  PermisosState copyWith({
    bool? isLoading,
    String? error,
    List<Map<String, dynamic>>? permisos,
    List<Map<String, dynamic>>? catalogo,
    int? total,
    int? page,
    int? totalPages,
    String? moduleFilter,
    String? searchQuery,
    bool clearModule = false,
  }) => PermisosState(
    isLoading: isLoading ?? this.isLoading,
    error: error,
    permisos: permisos ?? this.permisos,
    catalogo: catalogo ?? this.catalogo,
    total: total ?? this.total,
    page: page ?? this.page,
    totalPages: totalPages ?? this.totalPages,
    moduleFilter: clearModule ? null : (moduleFilter ?? this.moduleFilter),
    searchQuery: searchQuery ?? this.searchQuery,
  );
}

class PermisosNotifier extends StateNotifier<PermisosState> {
  final ApiClient _api;
  PermisosNotifier(this._api) : super(const PermisosState()) {
    load();
  }

  Future<void> load({int page = 1, String? modulo}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final params = <String, dynamic>{'pagina': page, 'limite': 50};
      if (modulo != null) params['modulo'] = modulo;
      final responses = await Future.wait([
        _api.get(ApiConstants.permissions, queryParameters: params),
        _api.get(ApiConstants.permissionsGrouped),
      ]);
      final d = responses[0].data as Map;
      final grouped = responses[1].data;
      final catalogo = <Map<String, dynamic>>[];
      if (grouped is Map) {
        for (final value in grouped.values.whereType<List>()) {
          catalogo.addAll(
            value.whereType<Map>().map(Map<String, dynamic>.from),
          );
        }
      }
      state = state.copyWith(
        isLoading: false,
        permisos: List<Map<String, dynamic>>.from(d['data'] ?? []),
        total: d['total'] as int? ?? 0,
        page: d['pagina'] as int? ?? 1,
        totalPages: d['totalPaginas'] as int? ?? 1,
        catalogo: catalogo,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setModuleFilter(String? modulo) {
    state = state.copyWith(moduleFilter: modulo, clearModule: modulo == null);
    load(page: 1, modulo: modulo);
  }

  void setSearchQuery(String q) => state = state.copyWith(searchQuery: q);
}

final permisosProvider = StateNotifierProvider<PermisosNotifier, PermisosState>(
  (ref) => PermisosNotifier(ApiClient.instance),
);

class PermisosScreen extends ConsumerWidget {
  const PermisosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(permisosProvider);
    final filtered = state.searchQuery.isEmpty
        ? state.permisos
        : state.permisos
              .where(
                (p) =>
                    (p['nombre'] as String? ?? '').toLowerCase().contains(
                      state.searchQuery.toLowerCase(),
                    ) ||
                    (p['descripcion'] as String? ?? '').toLowerCase().contains(
                      state.searchQuery.toLowerCase(),
                    ),
              )
              .toList();

    final modules =
        state.catalogo.map((p) => p['modulo'] as String? ?? '').toSet().toList()
          ..sort();

    return Scaffold(
      backgroundColor: context.colors.background,
      body: Column(
        children: [
          // Header compacto sin título duplicado
          Container(
            color: context.colors.background,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    children: [
                      Text(
                        '${state.total} total',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (state.catalogo.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: _PermissionKpis(catalogo: state.catalogo),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: AppSearchBar(
                    hint: 'Buscar permisos...',
                    onChanged: (q) =>
                        ref.read(permisosProvider.notifier).setSearchQuery(q),
                  ),
                ),
                // Module tabs
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      _ModuleTab(
                        label: 'Todos',
                        selected: state.moduleFilter == null,
                        onTap: () => ref
                            .read(permisosProvider.notifier)
                            .setModuleFilter(null),
                      ),
                      ...modules.map(
                        (m) => _ModuleTab(
                          label: m,
                          selected: state.moduleFilter == m,
                          onTap: () => ref
                              .read(permisosProvider.notifier)
                              .setModuleFilter(
                                state.moduleFilter == m ? null : m,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: state.isLoading
                ? const AppLoading()
                : state.error != null
                ? AppErrorState(
                    message: state.error!,
                    onRetry: () => ref.read(permisosProvider.notifier).load(),
                  )
                : filtered.isEmpty
                ? const AppEmptyState(
                    icon: Icons.security_outlined,
                    title: 'Sin permisos encontrados',
                  )
                : ListView(
                    children: [
                      const SizedBox(height: 8),
                      for (final perm in filtered)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 3,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: context.colors.surface,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                color: context.colors.borderLight,
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        perm['nombre'] as String? ?? '',
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: context.colors.textPrimary,
                                            ),
                                      ),
                                      if ((perm['descripcion'] as String? ?? '')
                                          .isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          perm['descripcion'] as String? ?? '',
                                          style: AppTextStyles.labelSmall,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                PermissionModuleBadge(
                                  module: perm['modulo'] as String? ?? '',
                                ),
                              ],
                            ),
                          ),
                        ),
                      AppPagination(
                        page: state.page,
                        totalPages: state.totalPages,
                        total: state.total,
                        onPageChange: (p) => ref
                            .read(permisosProvider.notifier)
                            .load(page: p, modulo: state.moduleFilter),
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _PermissionKpis extends StatelessWidget {
  final List<Map<String, dynamic>> catalogo;

  const _PermissionKpis({required this.catalogo});

  @override
  Widget build(BuildContext context) {
    final modules = catalogo
        .map((item) => item['modulo'] as String? ?? '')
        .where((item) => item.isNotEmpty)
        .toSet()
        .length;
    final reads = catalogo
        .where((item) => (item['nombre'] as String? ?? '').endsWith(':leer'))
        .length;
    final values = [
      ('Permisos', catalogo.length, AppColors.primary),
      ('Módulos', modules, AppColors.warning),
      ('Lectura', reads, AppColors.info),
      ('Operativos', catalogo.length - reads, AppColors.success),
    ];
    return LayoutBuilder(
      builder: (context, constraints) => GridView.count(
        crossAxisCount: constraints.maxWidth >= 700 ? 4 : 2,
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
                    child: Text(value.$1, style: AppTextStyles.labelSmall),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ModuleTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModuleTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: selected
            ? context.colors.primarySurface
            : context.colors.backgroundAlt,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: selected
              ? context.colors.primaryBorder
              : context.colors.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? AppColors.primary : context.colors.textSecondary,
        ),
      ),
    ),
  );
}
