import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/navigation/app_nav.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/providers/sede_scope_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart' as spacing;
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_ui_components.dart';
import '../../../../core/widgets/ds_product_image.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../categorias/data/categorias_repository.dart' show Categoria;
import '../../../productos/data/productos_repository.dart' as products;
import '../../../usuarios/data/usuario_admin_repository.dart';
import '../../../usuarios/presentation/widgets/pin_stock_adjust_sheet.dart';
import '../../data/inventario_repository.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final _invRepoProvider = Provider<InventarioRepository>(
  (ref) => InventarioRepository(ApiClient.instance),
);

/// Categorías activas del catálogo — usadas en el filtro de inventario.
final _invCatsProvider = FutureProvider<List<Categoria>>((ref) async {
  return products.ProductosRepository(ApiClient.instance).categorias();
});

class _InvState {
  final List<InventarioItem> items;
  final InventarioResumen? resumen;
  final bool loading;
  final String? error;
  final int page, totalPages, total;
  final String search, estadoFilter, categoriaFilter;

  const _InvState({
    this.items = const [],
    this.resumen,
    this.loading = true,
    this.error,
    this.page = 1,
    this.totalPages = 1,
    this.total = 0,
    this.search = '',
    this.estadoFilter = '',
    this.categoriaFilter = '',
  });

  _InvState copyWith({
    List<InventarioItem>? items,
    InventarioResumen? resumen,
    bool? loading,
    String? error,
    bool clearError = false,
    int? page,
    int? totalPages,
    int? total,
    String? search,
    String? estadoFilter,
    String? categoriaFilter,
  }) => _InvState(
    items: items ?? this.items,
    resumen: resumen ?? this.resumen,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
    page: page ?? this.page,
    totalPages: totalPages ?? this.totalPages,
    total: total ?? this.total,
    search: search ?? this.search,
    estadoFilter: estadoFilter ?? this.estadoFilter,
    categoriaFilter: categoriaFilter ?? this.categoriaFilter,
  );
}

class _InvNotifier extends StateNotifier<_InvState> {
  final InventarioRepository _repo;
  final String? _sedeId;
  Timer? _searchDebounce;
  int _loadGeneration = 0;

  _InvNotifier(this._repo, this._sedeId) : super(const _InvState()) {
    load();
  }

  Future<void> load({bool resetPage = false}) async {
    final generation = ++_loadGeneration;
    final p = resetPage ? 1 : state.page;
    state = state.copyWith(loading: true, clearError: true, page: p);
    try {
      final results = await Future.wait([
        _repo.list(
          pagina: p,
          limite: 20,
          q: state.search.isEmpty ? null : state.search,
          estado: state.estadoFilter.isEmpty ? null : state.estadoFilter,
          categoriaId: state.categoriaFilter.isEmpty
              ? null
              : state.categoriaFilter,
          sedeId: _sedeId,
        ),
        _repo.resumen(sedeId: _sedeId),
      ]);
      final page = results[0] as InventarioPage;
      final resumen = results[1] as InventarioResumen;
      if (generation != _loadGeneration) return;
      state = state.copyWith(
        items: page.data,
        resumen: resumen,
        total: page.total,
        totalPages: page.totalPaginas,
        page: page.pagina,
        loading: false,
      );
    } catch (e) {
      if (generation != _loadGeneration) return;
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void setSearch(String s) {
    state = state.copyWith(search: s);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => load(resetPage: true),
    );
  }

  void setEstado(String v) {
    state = state.copyWith(estadoFilter: v);
    load(resetPage: true);
  }

  void setCategoria(String id) {
    state = state.copyWith(categoriaFilter: id);
    load(resetPage: true);
  }

  void setPage(int p) {
    state = state.copyWith(page: p);
    load();
  }

  Future<void> ajustar(
    InventarioItem item,
    String tipo,
    double cantidad,
    String? ref,
  ) async {
    await _repo.ajustar(
      item.id,
      tipo: tipo,
      cantidad: cantidad,
      referencia: ref,
    );
    await load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}

final _invProvider = StateNotifierProvider<_InvNotifier, _InvState>(
  (ref) => _InvNotifier(
    ref.watch(_invRepoProvider),
    ref.watch(globalSedeIdProvider),
  ),
);

// ─── Screen ───────────────────────────────────────────────────────────────────

class InventarioScreen extends ConsumerWidget {
  const InventarioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final state = ref.watch(_invProvider);
    final notifier = ref.read(_invProvider.notifier);
    final catsAsync = ref.watch(_invCatsProvider);
    // Permisos alineados con el backend:
    // inventario:configurar → configurar parámetros de stock (min/max/etc.)
    // inventario:ajustar-stock → ajustar stock y registrar en kardex
    final canConfigure =
        auth.hasPermission('inventario:configurar') &&
        auth.hasPermission('productos:leer') &&
        (auth.user?.isSuperAdmin != true ||
            auth.hasPermission('establecimientos:leer'));
    final canAjustarStock = auth.hasPermission('inventario:ajustar-stock');
    final selectedSedeId = ref.watch(globalSedeIdProvider);
    final desktop = MediaQuery.sizeOf(context).width >= 1024;

    return Scaffold(
      backgroundColor: context.colors.background,
      floatingActionButton: canConfigure && !desktop
          ? FloatingActionButton.extended(
              heroTag: 'inventario_config_fab',
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              onPressed: () => _showConfig(context, ref),
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Configurar'),
            )
          : null,
      body: desktop
          ? InventarioDesktopView(
              resumen: state.resumen,
              items: state.items,
              loading: state.loading,
              error: state.error,
              page: state.page,
              totalPages: state.totalPages,
              total: state.total,
              estadoFilter: state.estadoFilter,
              categoriaFilter: state.categoriaFilter,
              categories: catsAsync.valueOrNull ?? const [],
              canCreate: canConfigure,
              canConfigure: canConfigure,
              canAdjust:
                  canAjustarStock &&
                  (auth.user?.isSuperAdmin != true || selectedSedeId != null),
              onRefresh: () => notifier.load(),
              onRetry: () => notifier.load(),
              onSearch: notifier.setSearch,
              onEstado: notifier.setEstado,
              onCategoria: notifier.setCategoria,
              onPageChange: notifier.setPage,
              onConfigureInventory: () => _showConfig(context, ref),
              onConfigureItem: (item) => _showConfig(context, ref, item: item),
              onAdjustItem: (item) => _showAdjust(context, ref, item),
            )
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => notifier.load(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _SearchBar(
                    onSearch: notifier.setSearch,
                    estadoFilter: state.estadoFilter,
                    onEstado: notifier.setEstado,
                    categoriaFilter: state.categoriaFilter,
                    onCategoria: notifier.setCategoria,
                    cats: catsAsync.valueOrNull ?? const [],
                  ),
                  if (state.resumen != null && !state.loading)
                    _KpiRow(resumen: state.resumen!),
                  const SizedBox(height: 4),
                  if (state.loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: AppLoading(),
                    )
                  else if (state.error != null)
                    AppErrorState(
                      message: state.error!,
                      onRetry: () => notifier.load(),
                    )
                  else if (state.items.isEmpty)
                    const AppEmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'Sin productos en inventario',
                    )
                  else ...[
                    for (final item in state.items)
                      _InventarioTile(
                        item: item,
                        canEdit: canConfigure,
                        canConfigure: canConfigure,
                        canAdjust:
                            canAjustarStock &&
                            (auth.user?.isSuperAdmin != true ||
                                selectedSedeId != null),
                        onConfigure: () =>
                            _showConfig(context, ref, item: item),
                        onAdjust: () => _showAdjust(context, ref, item),
                      ),
                    AppPagination(
                      page: state.page,
                      totalPages: state.totalPages,
                      total: state.total,
                      onPageChange: notifier.setPage,
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  void _showAdjust(BuildContext context, WidgetRef ref, InventarioItem item) {
    final auth = ref.read(authProvider);
    AppNav.push(
      context,
      _PinAdjustWrapper(
        item: item,
        isSuperAdmin: auth.user?.isSuperAdmin == true,
        sedeId: ref.read(globalSedeIdProvider),
        onSaved: () => ref.read(_invProvider.notifier).load(),
        repo: ref.read(_invRepoProvider),
      ),
    );
  }

  void _showConfig(
    BuildContext context,
    WidgetRef ref, {
    InventarioItem? item,
  }) {
    AppNav.push(
      context,
      _InventoryConfigScreen(
        item: item,
        auth: ref.read(authProvider),
        selectedSedeId: ref.read(globalSedeIdProvider),
        sedes: ref.read(sedeScopeOptionsProvider).valueOrNull ?? const [],
        repo: ref.read(_invRepoProvider),
        onSaved: () => ref.read(_invProvider.notifier).load(),
      ),
    );
  }
}

class InventarioDesktopView extends StatelessWidget {
  final InventarioResumen? resumen;
  final List<InventarioItem> items;
  final bool loading;
  final String? error;
  final int page, totalPages, total;
  final String estadoFilter, categoriaFilter;
  final List<Categoria> categories;
  final bool canCreate, canConfigure, canAdjust;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry, onConfigureInventory;
  final ValueChanged<String> onSearch, onEstado, onCategoria;
  final ValueChanged<int> onPageChange;
  final ValueChanged<InventarioItem> onConfigureItem, onAdjustItem;

  const InventarioDesktopView({
    super.key,
    required this.resumen,
    required this.items,
    required this.loading,
    required this.error,
    required this.page,
    required this.totalPages,
    required this.total,
    required this.estadoFilter,
    required this.categoriaFilter,
    required this.categories,
    required this.canCreate,
    required this.canConfigure,
    required this.canAdjust,
    required this.onRefresh,
    required this.onRetry,
    required this.onConfigureInventory,
    required this.onSearch,
    required this.onEstado,
    required this.onCategoria,
    required this.onPageChange,
    required this.onConfigureItem,
    required this.onAdjustItem,
  });

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    color: AppColors.primary,
    onRefresh: onRefresh,
    child: ListView(
      key: const Key('inventario-desktop-view'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: resumen == null
                  ? const SizedBox(height: 76)
                  : _InventoryDesktopKpis(resumen: resumen!),
            ),
            if (canCreate) ...[
              const SizedBox(width: 16),
              SizedBox(
                height: 42,
                child: FilledButton.icon(
                  key: const Key('inventario-configure-all'),
                  onPressed: onConfigureInventory,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.settings_outlined, size: 17),
                  label: const Text(
                    'Configurar inventario',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 18),
        _InventoryDesktopFilters(
          estadoFilter: estadoFilter,
          categoriaFilter: categoriaFilter,
          categories: categories,
          onSearch: onSearch,
          onEstado: onEstado,
          onCategoria: onCategoria,
        ),
        const SizedBox(height: 16),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 80),
            child: AppLoading(),
          )
        else if (error != null)
          AppErrorState(message: error!, onRetry: onRetry)
        else if (items.isEmpty)
          const AppEmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'Sin productos en inventario',
          )
        else ...[
          _InventoryDesktopTable(
            items: items,
            canConfigure: canConfigure,
            canAdjust: canAdjust,
            onConfigure: onConfigureItem,
            onAdjust: onAdjustItem,
          ),
          AppPagination(
            page: page,
            totalPages: totalPages,
            total: total,
            onPageChange: onPageChange,
          ),
        ],
      ],
    ),
  );
}

class _InventoryDesktopKpis extends StatelessWidget {
  final InventarioResumen resumen;

  const _InventoryDesktopKpis({required this.resumen});

  @override
  Widget build(BuildContext context) => Row(
    children:
        [
              _DesktopInventoryKpi(
                'Total productos',
                '${resumen.totalItems}',
                null,
              ),
              const SizedBox(width: 10),
              _DesktopInventoryKpi(
                'Estado crítico',
                '${resumen.critico}',
                AppColors.error,
              ),
              const SizedBox(width: 10),
              _DesktopInventoryKpi(
                'En alerta',
                '${resumen.alerta}',
                AppColors.warning,
              ),
              const SizedBox(width: 10),
              _DesktopInventoryKpi(
                'Valor inventario',
                'S/ ${resumen.valorTotal.toStringAsFixed(2)}',
                AppColors.success,
              ),
            ]
            .map((child) => child is SizedBox ? child : Expanded(child: child))
            .toList(),
  );
}

class _DesktopInventoryKpi extends StatelessWidget {
  final String label, value;
  final Color? color;

  const _DesktopInventoryKpi(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Container(
    height: 76,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: context.colors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: context.colors.textTertiary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color ?? context.colors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
          ),
        ),
      ],
    ),
  );
}

class _InventoryDesktopFilters extends StatefulWidget {
  final String estadoFilter, categoriaFilter;
  final List<Categoria> categories;
  final ValueChanged<String> onSearch, onEstado, onCategoria;

  const _InventoryDesktopFilters({
    required this.estadoFilter,
    required this.categoriaFilter,
    required this.categories,
    required this.onSearch,
    required this.onEstado,
    required this.onCategoria,
  });

  @override
  State<_InventoryDesktopFilters> createState() =>
      _InventoryDesktopFiltersState();
}

class _InventoryDesktopFiltersState extends State<_InventoryDesktopFilters> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 290,
        height: 40,
        child: TextField(
          key: const Key('inventario-desktop-search'),
          controller: _searchController,
          onChanged: widget.onSearch,
          decoration: InputDecoration(
            hintText: 'Buscar por nombre o código...',
            prefixIcon: Icon(
              Icons.search_rounded,
              size: 18,
              color: context.colors.textTertiary,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _CatChip(
                label: 'Todos',
                selected: widget.categoriaFilter.isEmpty,
                onTap: () => widget.onCategoria(''),
              ),
              for (final category in widget.categories)
                _CatChip(
                  label: category.nombre,
                  selected: widget.categoriaFilter == category.id,
                  onTap: () => widget.onCategoria(category.id),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: 126,
        child: _FilterDropdown<String>(
          key: const ValueKey('inventario-desktop-estado'),
          value: widget.estadoFilter,
          label: 'Estado',
          items: const [
            ('', 'Todos'),
            ('OK', 'OK'),
            ('ALERTA', 'Alerta'),
            ('CRITICO', 'Crítico'),
          ],
          onChanged: widget.onEstado,
        ),
      ),
    ],
  );
}

class _InventoryDesktopTable extends StatelessWidget {
  final List<InventarioItem> items;
  final bool canConfigure, canAdjust;
  final ValueChanged<InventarioItem> onConfigure, onAdjust;

  const _InventoryDesktopTable({
    required this.items,
    required this.canConfigure,
    required this.canAdjust,
    required this.onConfigure,
    required this.onAdjust,
  });

  Color _statusColor(InventarioItem item) => item.estado == 'CRITICO'
      ? AppColors.error
      : item.estado == 'ALERTA'
      ? AppColors.warning
      : AppColors.success;

  String _number(double value) => value.toStringAsFixed(value % 1 == 0 ? 0 : 1);

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('inventario-desktop-table'),
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: context.colors.border),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.sizeOf(context).width - 320,
          ),
          child: DataTable(
            headingRowHeight: 42,
            dataRowMinHeight: 58,
            dataRowMaxHeight: 58,
            horizontalMargin: 14,
            columnSpacing: 18,
            headingRowColor: WidgetStatePropertyAll(
              context.colors.backgroundAlt,
            ),
            columns: const [
              DataColumn(label: Text('Producto')),
              DataColumn(label: Text('Categoría')),
              DataColumn(label: Text('Stock')),
              DataColumn(label: Text('Min/Máx')),
              DataColumn(label: Text('Estado')),
              DataColumn(label: Text('Costo')),
              DataColumn(label: Text('Ubicación')),
              DataColumn(label: Text('Acciones')),
            ],
            rows: [
              for (final item in items)
                DataRow(
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 190,
                        child: Row(
                          children: [
                            DSProductImageSquare(
                              imageUrl: item.imagenUrl,
                              size: 34,
                              radius: 8,
                              productName: item.producto,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.producto,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    item.codigo,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: context.colors.textTertiary,
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        item.categoria,
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 118,
                        child: Row(
                          children: [
                            Text(
                              _number(item.stock),
                              style: TextStyle(
                                color: _statusColor(item),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: item.max > 0
                                      ? (item.stock / item.max).clamp(0.0, 1.0)
                                      : 0,
                                  minHeight: 5,
                                  backgroundColor: context.colors.backgroundAlt,
                                  valueColor: AlwaysStoppedAnimation(
                                    _statusColor(item),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${_number(item.min)}/${item.max > 0 ? _number(item.max) : 'Sin objetivo'}',
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataCell(_InventoryStatusBadge(item: item)),
                    DataCell(
                      Text(
                        'S/ ${item.costo.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 130),
                        child: Text(
                          item.ubicacion.isEmpty ? '—' : item.ubicacion,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (canConfigure)
                            OutlinedButton(
                              key: ValueKey('inventario-configure-${item.id}'),
                              onPressed: () => onConfigure(item),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 32),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                              ),
                              child: const Text('Configurar'),
                            ),
                          if (canConfigure && canAdjust)
                            const SizedBox(width: 7),
                          if (canAdjust)
                            OutlinedButton(
                              key: ValueKey('inventario-adjust-${item.id}'),
                              onPressed: () => onAdjust(item),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.brand,
                                side: BorderSide(
                                  color: AppColors.brand.withValues(alpha: .35),
                                ),
                                minimumSize: const Size(0, 32),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                              ),
                              child: const Text('Ajustar'),
                            ),
                          if (!canConfigure && !canAdjust)
                            Text(
                              '—',
                              style: TextStyle(
                                color: context.colors.textTertiary,
                              ),
                            ),
                        ],
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

class _InventoryStatusBadge extends StatelessWidget {
  final InventarioItem item;

  const _InventoryStatusBadge({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = item.estado == 'CRITICO'
        ? AppColors.error
        : item.estado == 'ALERTA'
        ? AppColors.warning
        : AppColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: .28)),
      ),
      child: Text(
        item.estado,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ─── PIN-authorized stock adjustment wrapper ─────────────────────────────────

class _PinAdjustWrapper extends StatelessWidget {
  final InventarioItem item;
  final bool isSuperAdmin;
  final String? sedeId;
  final VoidCallback onSaved;
  final InventarioRepository repo;

  const _PinAdjustWrapper({
    required this.item,
    required this.isSuperAdmin,
    required this.sedeId,
    required this.onSaved,
    required this.repo,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajuste de stock')),
      body: PinStockAdjustSheet(
        productId: item.productoId,
        productName: item.producto,
        currentStock: item.stock,
        sedeId: item.sedeId.isNotEmpty ? item.sedeId : sedeId,
        isSuperAdmin: isSuperAdmin,
        repo: UsuarioAdminRepository(ApiClient.instance),
        onSaved: onSaved,
      ),
    );
  }
}

// ─── Barra de búsqueda + filtros ──────────────────────────────────────────────

class _SearchBar extends StatefulWidget {
  final ValueChanged<String> onSearch, onEstado, onCategoria;
  final String estadoFilter, categoriaFilter;
  final List<Categoria> cats;

  const _SearchBar({
    required this.onSearch,
    required this.estadoFilter,
    required this.onEstado,
    required this.categoriaFilter,
    required this.onCategoria,
    required this.cats,
  });

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 1024;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─ Buscador
          TextField(
            controller: _ctrl,
            onChanged: widget.onSearch,
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o código...',
              prefixIcon: Icon(
                Icons.search_rounded,
                color: context.colors.textTertiary,
                size: 18,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // ─ Filtros: Estado dropdown + Categoría (chips on desktop, dropdown on mobile)
          Row(
            children: [
              // Estado
              Expanded(
                child: _FilterDropdown<String>(
                  key: const ValueKey('inv-estado-drop'),
                  value: widget.estadoFilter,
                  label: 'Estado',
                  items: const [
                    ('', 'Todos'),
                    ('OK', 'OK'),
                    ('ALERTA', 'Alerta'),
                    ('CRITICO', 'Crítico'),
                  ],
                  onChanged: widget.onEstado,
                ),
              ),
              if (!desktop) ...[
                const SizedBox(width: 8),
                // Categoría dropdown (mobile only)
                Expanded(
                  child: _FilterDropdown<String>(
                    key: const ValueKey('inv-cat-drop'),
                    value: widget.categoriaFilter,
                    label: 'Categoría',
                    items: [
                      ('', 'Todas'),
                      for (final c in widget.cats) (c.id, c.nombre),
                    ],
                    onChanged: widget.onCategoria,
                  ),
                ),
              ],
            ],
          ),
          // ─ Category chips (desktop only — matches web horizontal tab style)
          if (desktop && widget.cats.isNotEmpty) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _CatChip(
                    label: 'Todos',
                    selected: widget.categoriaFilter.isEmpty,
                    onTap: () => widget.onCategoria(''),
                  ),
                  for (final c in widget.cats)
                    _CatChip(
                      label: c.nombre,
                      selected: widget.categoriaFilter == c.id,
                      onTap: () => widget.onCategoria(c.id),
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

/// Dropdown compacto reutilizable para filtros de inventario.
class _FilterDropdown<T extends Object> extends StatelessWidget {
  final T value;
  final String label;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;

  const _FilterDropdown({
    super.key,
    required this.value,
    required this.label,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      labelText: label,
      labelStyle: TextStyle(fontSize: 11, color: context.colors.textTertiary),
      filled: true,
      fillColor: context.colors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(spacing.AppSpacing.radiusMD),
        borderSide: BorderSide(color: context.colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(spacing.AppSpacing.radiusMD),
        borderSide: BorderSide(color: context.colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(spacing.AppSpacing.radiusMD),
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        isDense: true,
        isExpanded: true,
        borderRadius: BorderRadius.circular(10),
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 18,
          color: context.colors.textTertiary,
        ),
        style: TextStyle(fontSize: 13, color: context.colors.textPrimary),
        items: items
            .map(
              (e) => DropdownMenuItem<T>(
                value: e.$1,
                child: Text(
                  e.$2,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    ),
  );
}

/// Horizontal category chip for desktop inventory filter (matches web).
class _CatChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CatChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? context.colors.primarySurface
              : context.colors.backgroundAlt,
          borderRadius: BorderRadius.circular(20),
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
            color: selected ? AppColors.brand : context.colors.textSecondary,
          ),
        ),
      ),
    ),
  );
}

// ─── KPIs ─────────────────────────────────────────────────────────────────────
class _KpiRow extends StatelessWidget {
  final InventarioResumen resumen;
  const _KpiRow({required this.resumen});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 4),
    child: LayoutBuilder(
      builder: (_, constraints) {
        final compact = constraints.maxWidth < 360;
        final columns = compact
            ? 1
            : constraints.maxWidth >= 720
            ? 4
            : 2;
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: compact
              ? 4.5
              : constraints.maxWidth >= 720
              ? 2.5
              : 2.2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _Chip(
              'Total productos',
              '${resumen.totalItems}',
              AppColors.primary,
            ),
            _Chip('Estado crítico', '${resumen.critico}', AppColors.error),
            _Chip('En alerta', '${resumen.alerta}', AppColors.warning),
            _Chip(
              'Valor inventario',
              'S/ ${resumen.valorTotal.toStringAsFixed(2)}',
              AppColors.success,
            ),
          ],
        );
      },
    ),
  );
}

class _Chip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Chip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        Text(
          label,
          style: AppTextStyles.labelSmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}

class _InventarioTile extends StatelessWidget {
  final InventarioItem item;
  final bool canEdit, canConfigure, canAdjust;
  final VoidCallback onConfigure, onAdjust;
  const _InventarioTile({
    required this.item,
    required this.canEdit,
    required this.canConfigure,
    required this.canAdjust,
    required this.onConfigure,
    required this.onAdjust,
  });

  Color get _statusColor => item.estado == 'CRITICO'
      ? AppColors.error
      : item.estado == 'ALERTA'
      ? AppColors.warning
      : AppColors.success;

  @override
  Widget build(BuildContext context) {
    final pct = item.max > 0 ? (item.stock / item.max).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: context.colors.borderLight),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // ─ Imagen del producto
                DSProductImageSquare(
                  imageUrl: item.imagenUrl,
                  size: 48,
                  radius: 10,
                  productName: item.producto,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.producto,
                        style: AppTextStyles.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${item.codigo} · ${item.categoria}',
                        style: AppTextStyles.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.estado,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stock: ${item.stock.toStringAsFixed(item.stock % 1 == 0 ? 0 : 1)} ${item.unidad}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _statusColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct.toDouble(),
                          minHeight: 5,
                          backgroundColor: context.colors.background,
                          valueColor: AlwaysStoppedAnimation(_statusColor),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Min ${item.min.toStringAsFixed(0)} · ${item.max > 0 ? 'Max ${item.max.toStringAsFixed(0)}' : 'Sin objetivo'} · ${item.ubicacion}',
                        style: AppTextStyles.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Costo: S/ ${item.costo.toStringAsFixed(2)}',
                        style: AppTextStyles.labelSmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (canEdit)
                  Column(
                    children: [
                      if (canConfigure)
                        TextButton(
                          onPressed: onConfigure,
                          child: const Text('Configurar'),
                        ),
                      TextButton(
                        onPressed: canAdjust ? onAdjust : null,
                        child: const Text('Ajustar'),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryConfigScreen extends StatefulWidget {
  final InventarioItem? item;
  final AuthState auth;
  final String? selectedSedeId;
  final List<SedeScopeOption> sedes;
  final InventarioRepository repo;
  final VoidCallback onSaved;

  const _InventoryConfigScreen({
    this.item,
    required this.auth,
    required this.selectedSedeId,
    required this.sedes,
    required this.repo,
    required this.onSaved,
  });

  @override
  State<_InventoryConfigScreen> createState() => _InventoryConfigScreenState();
}

class _InventoryConfigScreenState extends State<_InventoryConfigScreen> {
  late final TextEditingController _minCtrl;
  late final TextEditingController _maxCtrl;
  late final TextEditingController _locationCtrl;
  List<products.Producto> _products = const [];
  String? _productoId;
  String? _sedeId;
  bool _loading = false;
  bool _saving = false;
  String? _error;

  bool get _isSuperAdmin => widget.auth.user?.isSuperAdmin == true;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _productoId = item?.productoId;
    _sedeId = item?.sedeId.isNotEmpty == true
        ? item!.sedeId
        : widget.selectedSedeId;
    final exactItem = item?.sedeId.isNotEmpty == true;
    _minCtrl = TextEditingController(text: '${exactItem ? item!.min : 0}');
    _maxCtrl = TextEditingController(text: '${exactItem ? item!.max : 0}');
    _locationCtrl = TextEditingController(
      text: exactItem ? item!.ubicacion : '',
    );
    if (item == null) _loadProducts();
  }

  Future<void> _loadExistingConfiguration() async {
    final productoId = _productoId;
    final sedeId = _sedeId;
    if (productoId == null ||
        productoId.isEmpty ||
        (_isSuperAdmin && (sedeId == null || sedeId.isEmpty))) {
      return;
    }
    setState(() => _loading = true);
    try {
      final page = await widget.repo.list(
        pagina: 1,
        limite: 1,
        productoId: productoId,
        sedeId: _isSuperAdmin ? sedeId : null,
      );
      if (!mounted) return;
      final existing = page.data.firstOrNull;
      setState(() {
        _minCtrl.text = '${existing?.min ?? 0}';
        _maxCtrl.text = '${existing?.max ?? 0}';
        _locationCtrl.text = existing?.ubicacion ?? '';
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadProducts() async {
    setState(() => _loading = true);
    try {
      final repository = products.ProductosRepository(ApiClient.instance);
      final first = await repository.list(
        pagina: 1,
        limite: 100,
        activo: 'true',
      );
      final loaded = [...first.data];
      for (var page = 2; page <= first.totalPaginas; page++) {
        final next = await repository.list(
          pagina: page,
          limite: 100,
          activo: 'true',
        );
        loaded.addAll(next.data);
      }
      if (mounted) setState(() => _products = loaded);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final min = double.tryParse(_minCtrl.text.trim());
    final max = double.tryParse(_maxCtrl.text.trim());
    if (_productoId == null || _productoId!.isEmpty) {
      setState(() => _error = 'Selecciona un producto.');
      return;
    }
    if (_isSuperAdmin && (_sedeId == null || _sedeId!.isEmpty)) {
      setState(() => _error = 'Selecciona una sede.');
      return;
    }
    if (min == null || min < 0) {
      setState(() => _error = 'El stock mínimo debe ser mayor o igual a 0.');
      return;
    }
    if (max == null || max < 0 || (max != 0 && max < min)) {
      setState(
        () =>
            _error = 'El objetivo debe ser 0 o mayor o igual al stock mínimo.',
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repo.upsert(
        productoId: _productoId!,
        sedeId: _isSuperAdmin ? _sedeId : null,
        stockMin: min,
        stockMax: max,
        ubicacion: _locationCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSaved();
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final productLocked = item != null;
    final sedeLocked = item?.sedeId.isNotEmpty == true;

    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: SubPageAppBar(
        title: item == null ? 'Agregar al inventario' : 'Configurar inventario',
        subtitle: 'Mínimos, objetivo y ubicación',
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _productoId,
            decoration: const InputDecoration(labelText: 'Producto'),
            items: [
              if (item != null)
                DropdownMenuItem(
                  value: item.productoId,
                  child: Text(item.producto),
                ),
              if (!productLocked)
                for (final product in _products)
                  DropdownMenuItem(
                    value: product.id,
                    child: Text(product.nombre),
                  ),
            ],
            onChanged: productLocked || _loading
                ? null
                : (value) {
                    setState(() => _productoId = value);
                    _loadExistingConfiguration();
                  },
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_isSuperAdmin) ...[
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _sedeId,
              decoration: const InputDecoration(labelText: 'Sede'),
              items: [
                if (sedeLocked &&
                    !widget.sedes.any((sede) => sede.id == _sedeId))
                  DropdownMenuItem(
                    value: _sedeId,
                    child: const Text('Sede actual'),
                  ),
                for (final sede in widget.sedes)
                  DropdownMenuItem(value: sede.id, child: Text(sede.nombre)),
              ],
              onChanged: sedeLocked
                  ? null
                  : (value) {
                      setState(() => _sedeId = value);
                      _loadExistingConfiguration();
                    },
            ),
            if (widget.sedes.isEmpty && !sedeLocked)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'No hay sedes activas disponibles. Recarga e intenta de nuevo.',
                  style: TextStyle(fontSize: 12, color: AppColors.error),
                ),
              ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Stock mínimo'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _maxCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Objetivo de reposición',
                    helperText: '0 = sin objetivo',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _locationCtrl,
            decoration: const InputDecoration(
              labelText: 'Ubicación',
              hintText: 'Ej. Almacén A, estante 3',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(fontSize: 13, color: AppColors.error),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _saving || _loading ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Guardar configuración'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdjustSheet extends StatefulWidget {
  final InventarioItem item;
  final VoidCallback onSaved;
  final InventarioRepository repo;
  const _AdjustSheet({
    required this.item,
    required this.onSaved,
    required this.repo,
  });

  @override
  State<_AdjustSheet> createState() => _AdjustSheetState();
}

class _AdjustSheetState extends State<_AdjustSheet> {
  String _tipo = 'ENTRADA';
  final _cantCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _cantCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final cant = double.tryParse(_cantCtrl.text);
    if (cant == null ||
        (_tipo != 'AJUSTE' && cant <= 0) ||
        (_tipo == 'AJUSTE' && cant < 0)) {
      setState(() => _error = 'Cantidad inválida.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repo.ajustar(
        widget.item.id,
        tipo: _tipo,
        cantidad: cant,
        referencia: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSaved();
      }
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: SubPageAppBar(
        title: 'Ajuste de stock',
        subtitle: '${widget.item.producto} · Stock: ${widget.item.stock}',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Resumen del producto ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.colors.backgroundAlt,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: context.colors.borderLight),
              ),
              child: Row(
                children: [
                  DSProductImageSquare(
                    imageUrl: widget.item.imagenUrl,
                    size: 52,
                    radius: 12,
                    productName: widget.item.producto,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.producto,
                          style: AppTextStyles.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.item.codigo} · ${widget.item.categoria}',
                          style: AppTextStyles.labelSmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Stock actual: ${widget.item.stock.toStringAsFixed(widget.item.stock % 1 == 0 ? 0 : 1)} ${widget.item.unidad} · '
                          'Min ${widget.item.min.toStringAsFixed(0)} · '
                          '${widget.item.max > 0 ? 'Max ${widget.item.max.toStringAsFixed(0)}' : 'Sin objetivo'}',
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // ── Selector de tipo de ajuste ──────────────────────────────────
            Row(
              children: [
                for (final t in [
                  ('ENTRADA', 'Entrada'),
                  ('SALIDA', 'Salida'),
                  ('AJUSTE', 'Conteo'),
                ])
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: t.$1 == 'AJUSTE' ? 0 : 8),
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _tipo = t.$1;
                          _error = null;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: _tipo == t.$1
                                ? context.colors.primarySurface
                                : context.colors.backgroundAlt,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _tipo == t.$1
                                  ? context.colors.primaryBorder
                                  : context.colors.border,
                            ),
                          ),
                          child: Text(
                            t.$2,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _tipo == t.$1
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: _tipo == t.$1
                                  ? AppColors.primary
                                  : context.colors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            // ── Cantidad ────────────────────────────────────────────────────
            TextField(
              controller: _cantCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(
                  fontSize: 22,
                  color: context.colors.textDisabled,
                ),
                labelText: _tipo == 'AJUSTE' ? 'Conteo físico' : 'Cantidad',
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 10),
            // ── Referencia ──────────────────────────────────────────────────
            TextField(
              controller: _refCtrl,
              decoration: const InputDecoration(
                labelText: 'Referencia (opcional)',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _confirm,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Confirmar ajuste'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
