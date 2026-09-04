import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_ui_components.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

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
      final params = <String, dynamic>{'pagina': page, 'limite': 25};
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
    // Guard de permiso — igual que en web (permisos:leer)
    final auth = ref.watch(authProvider);
    if (!auth.hasPermission('permisos:leer')) {
      return Scaffold(
        backgroundColor: context.colors.background,
        body: const Center(
          child: AppEmptyState(
            icon: Icons.lock_outline_rounded,
            title: 'Sin acceso',
            description: 'No tienes permiso para ver los permisos del sistema.',
          ),
        ),
      );
    }
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
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(permisosProvider.notifier).load(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${state.total} total',
                    style: AppTextStyles.bodySmall,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.go('/roles'),
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  label: const Text('Configurar roles'),
                ),
              ],
            ),
            if (state.catalogo.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
                child: _PermissionKpis(catalogo: state.catalogo),
              ),
            AppSearchBar(
              hint: 'Buscar permisos...',
              onChanged: (q) =>
                  ref.read(permisosProvider.notifier).setSearchQuery(q),
            ),
            const SizedBox(height: 8),
            // Module tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
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
                          .setModuleFilter(state.moduleFilter == m ? null : m),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (state.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: AppLoading(),
              )
            else if (state.error != null)
              AppErrorState(
                message: state.error!,
                onRetry: () => ref.read(permisosProvider.notifier).load(),
              )
            else if (filtered.isEmpty)
              const AppEmptyState(
                icon: Icons.security_outlined,
                title: 'Sin permisos encontrados',
              )
            else ...[
              for (final perm in filtered)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                perm['nombre'] as String? ?? '',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: context.colors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if ((perm['descripcion'] as String? ?? '')
                                  .isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  perm['descripcion'] as String? ?? '',
                                  style: AppTextStyles.labelSmall,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        PermissionModuleBadge(
                          module: perm['modulo'] as String? ?? '',
                        ),
                        const SizedBox(width: 6),
                        _ActionBadge(
                          action: _permissionAction(
                            perm['nombre'] as String? ?? '',
                          ),
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
            ],
          ],
        ),
      ),
    );
  }
}

String _permissionAction(String name) {
  final separator = name.indexOf(':');
  return separator < 0 ? name : name.substring(separator + 1);
}

class _ActionBadge extends StatelessWidget {
  const _ActionBadge({required this.action});

  final String action;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: context.colors.backgroundAlt,
      borderRadius: BorderRadius.circular(AppRadius.full),
      border: Border.all(color: context.colors.border),
    ),
    child: Text(
      action.toUpperCase(),
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        color: context.colors.textSecondary,
      ),
    ),
  );
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
        color: selected ? AppColors.brand : context.colors.backgroundAlt,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: selected ? AppColors.brand : context.colors.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? Colors.black : context.colors.textSecondary,
        ),
      ),
    ),
  );
}
