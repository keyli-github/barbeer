import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../core/navigation/app_nav.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/providers/sede_scope_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_ui_components.dart';
import '../../../../core/widgets/responsive_form.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/data/models/auth_models.dart';
import '../../../productos/data/productos_repository.dart';
import '../../data/compras_repository.dart';

final _comprasRepoProvider = Provider<ComprasRepository>(
  (ref) => ComprasRepository(ApiClient.instance),
);

final _productosRepoProvider = Provider<ProductosRepository>(
  (ref) => ProductosRepository(ApiClient.instance),
);

const double comprasDesktopBreakpoint = 1024;

bool usesComprasDesktopLayout(double width) =>
    width >= comprasDesktopBreakpoint;

enum _DesktopComprasSection { nueva, historial, proveedores }

// ─── Ordenes state ────────────────────────────────────────────────────────────

class _OrdenesState {
  final List<Compra> items;
  final ComprasResumen? resumen;
  final bool loading;
  final String? error;
  final int page, totalPages, total;
  final String estadoFilter;
  final String search;

  const _OrdenesState({
    this.items = const [],
    this.resumen,
    this.loading = true,
    this.error,
    this.page = 1,
    this.totalPages = 1,
    this.total = 0,
    this.estadoFilter = '',
    this.search = '',
  });

  _OrdenesState copyWith({
    List<Compra>? items,
    ComprasResumen? resumen,
    bool? loading,
    String? error,
    bool clearError = false,
    int? page,
    int? totalPages,
    int? total,
    String? estadoFilter,
    String? search,
  }) => _OrdenesState(
    items: items ?? this.items,
    resumen: resumen ?? this.resumen,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
    page: page ?? this.page,
    totalPages: totalPages ?? this.totalPages,
    total: total ?? this.total,
    estadoFilter: estadoFilter ?? this.estadoFilter,
    search: search ?? this.search,
  );
}

class _OrdenesNotifier extends StateNotifier<_OrdenesState> {
  final ComprasRepository _repo;
  final String? _sedeId;
  Timer? _searchDebounce;

  _OrdenesNotifier(this._repo, this._sedeId) : super(const _OrdenesState()) {
    load();
  }

  Future<void> load({bool resetPage = false}) async {
    final p = resetPage ? 1 : state.page;
    state = state.copyWith(loading: true, clearError: true, page: p);
    try {
      final results = await Future.wait([
        _repo.listCompras(
          pagina: p,
          estado: state.estadoFilter.isEmpty ? null : state.estadoFilter,
          q: state.search.isEmpty ? null : state.search,
          sedeId: _sedeId,
        ),
        _repo.resumen(
          estado: state.estadoFilter.isEmpty ? null : state.estadoFilter,
          sedeId: _sedeId,
        ),
      ]);
      final page = results[0] as ComprasPage<Compra>;
      final resumen = results[1] as ComprasResumen;
      state = state.copyWith(
        items: page.data,
        resumen: resumen,
        total: page.total,
        totalPages: page.totalPaginas,
        page: page.pagina,
        loading: false,
      );
    } catch (e) {
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

  void setPage(int p) {
    state = state.copyWith(page: p);
    load();
  }

  Future<void> cambiarEstado(String id, String estado) async {
    await _repo.cambiarEstado(id, estado);
    await load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}

final _ordenesProvider = StateNotifierProvider<_OrdenesNotifier, _OrdenesState>(
  (ref) => _OrdenesNotifier(
    ref.watch(_comprasRepoProvider),
    ref.watch(globalSedeIdProvider),
  ),
);

// ─── Proveedores state ────────────────────────────────────────────────────────

class _ProvsState {
  final List<Proveedor> items;
  final bool loading;
  final String? error;
  final int page, totalPages, total;
  final String search, activo;

  const _ProvsState({
    this.items = const [],
    this.loading = true,
    this.error,
    this.page = 1,
    this.totalPages = 1,
    this.total = 0,
    this.search = '',
    this.activo = '',
  });

  _ProvsState copyWith({
    List<Proveedor>? items,
    bool? loading,
    String? error,
    bool clearError = false,
    int? page,
    int? totalPages,
    int? total,
    String? search,
    String? activo,
  }) => _ProvsState(
    items: items ?? this.items,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
    page: page ?? this.page,
    totalPages: totalPages ?? this.totalPages,
    total: total ?? this.total,
    search: search ?? this.search,
    activo: activo ?? this.activo,
  );
}

class _ProvsNotifier extends StateNotifier<_ProvsState> {
  final ComprasRepository _repo;
  Timer? _debounce;

  _ProvsNotifier(this._repo) : super(const _ProvsState()) {
    load();
  }

  Future<void> load({bool resetPage = false}) async {
    final p = resetPage ? 1 : state.page;
    state = state.copyWith(loading: true, clearError: true, page: p);
    try {
      final page = await _repo.listProveedores(
        pagina: p,
        q: state.search.isEmpty ? null : state.search,
        activo: state.activo.isEmpty ? null : state.activo,
      );
      state = state.copyWith(
        items: page.data,
        total: page.total,
        totalPages: page.totalPaginas,
        page: page.pagina,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void setPage(int p) {
    state = state.copyWith(page: p);
    load();
  }

  void setSearch(String value) {
    state = state.copyWith(search: value);
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => load(resetPage: true),
    );
  }

  void setActivo(String value) {
    state = state.copyWith(activo: value);
    load(resetPage: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final _provsProvider = StateNotifierProvider<_ProvsNotifier, _ProvsState>(
  (ref) => _ProvsNotifier(ref.watch(_comprasRepoProvider)),
);

// ─── Screen ───────────────────────────────────────────────────────────────────

class ComprasScreen extends ConsumerStatefulWidget {
  const ComprasScreen({super.key});

  @override
  ConsumerState<ComprasScreen> createState() => _ComprasScreenState();
}

class _ComprasScreenState extends ConsumerState<ComprasScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  _DesktopComprasSection _desktopSection = _DesktopComprasSection.nueva;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final canCreate = auth.hasPermission('compras:crear');
    final canEdit = auth.hasPermission('compras:editar');
    // Permisos de proveedores alineados con el backend
    final canLeerProveedores = auth.hasPermission('proveedores:leer');
    final canCrearProveedor = auth.hasPermission('proveedores:crear');
    final canEditarProveedor = auth.hasPermission('proveedores:editar');

    if (usesComprasDesktopLayout(MediaQuery.sizeOf(context).width)) {
      return _buildDesktop(
        context,
        canCreate: canCreate,
        canEdit: canEdit,
        canCrearProveedor: canCrearProveedor,
        canEditarProveedor: canEditarProveedor,
      );
    }

    return Scaffold(
      backgroundColor: context.colors.background,
      body: Column(
        children: [
          // Solo tabs, sin título (el header viene del Shell)
          Container(
            color: context.colors.surface,
            child: TabBar(
              controller: _tabs,
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor: context.colors.textSecondary,
              tabs: const [
                Tab(text: 'Órdenes'),
                Tab(text: 'Proveedores'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _OrdenesTab(
                  canEdit: canEdit,
                  onDetail: (id) => _showDetalle(context, id),
                ),
                _ProvsTab(
                  canEdit: canEditarProveedor,
                  onEdit: canLeerProveedores
                      ? (p) => _showEditProveedor(context, p)
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
      // FAB dinámico según tab activo
      floatingActionButton: ListenableBuilder(
        listenable: _tabs,
        builder: (_, _) {
          final showFab = _tabs.index == 0 ? canCreate : canCrearProveedor;
          if (!showFab) return const SizedBox.shrink();
          return FloatingActionButton(
            heroTag: 'compras_fab',
            backgroundColor: AppColors.brand,
            foregroundColor: Colors.white,
            onPressed: _tabs.index == 0
                ? () => _showNuevaOrden(context)
                : () => _showNuevoProveedor(context),
            child: const Icon(Icons.add_rounded),
          );
        },
      ),
    );
  }

  Widget _buildDesktop(
    BuildContext context, {
    required bool canCreate,
    required bool canEdit,
    required bool canCrearProveedor,
    required bool canEditarProveedor,
  }) {
    final sections = <_DesktopComprasSection>[
      if (canCreate) _DesktopComprasSection.nueva,
      _DesktopComprasSection.historial,
      _DesktopComprasSection.proveedores,
    ];
    final active = sections.contains(_desktopSection)
        ? _desktopSection
        : sections.first;

    Widget content;
    switch (active) {
      case _DesktopComprasSection.nueva:
        content = _NuevaOrdenScreen(
          key: const ValueKey('compras-desktop-new-order'),
          repo: ref.read(_comprasRepoProvider),
          productosRepo: ref.read(_productosRepoProvider),
          user: ref.read(authProvider).user!,
          initialSedeId: ref.read(globalSedeIdProvider),
          embedded: true,
          onCreated: () {
            ref.read(_ordenesProvider.notifier).load();
            setState(() => _desktopSection = _DesktopComprasSection.historial);
          },
        );
      case _DesktopComprasSection.historial:
        content = _OrdenesTab(
          desktop: true,
          canEdit: canEdit,
          onDetail: (id) => _showDetalle(context, id),
        );
      case _DesktopComprasSection.proveedores:
        content = _ProvsTab(
          desktop: true,
          canCreate: canCrearProveedor,
          canEdit: canEditarProveedor,
          onCreate: canCrearProveedor
              ? () => _showNuevoProveedor(context)
              : null,
          onEdit: (p) => _showEditProveedor(context, p),
        );
    }

    return Scaffold(
      backgroundColor: context.colors.background,
      body: Column(
        children: [
          _DesktopComprasTabs(
            sections: sections,
            active: active,
            onSelected: (section) => setState(() => _desktopSection = section),
          ),
          Expanded(child: content),
        ],
      ),
    );
  }

  void _showNuevaOrden(BuildContext context) {
    ResponsiveForm.showPage<void>(
      context: context,
      dialogWidth: 960,
      dialogHeight: 800,
      page: _NuevaOrdenScreen(
        repo: ref.read(_comprasRepoProvider),
        productosRepo: ref.read(_productosRepoProvider),
        user: ref.read(authProvider).user!,
        initialSedeId: ref.read(globalSedeIdProvider),
        onCreated: () => ref.read(_ordenesProvider.notifier).load(),
      ),
    );
  }

  void _showNuevoProveedor(BuildContext context) {
    ResponsiveForm.showPage<void>(
      context: context,
      dialogWidth: 620,
      dialogHeight: 680,
      page: _ProveedorScreen(
        repo: ref.read(_comprasRepoProvider),
        onSaved: () => ref.read(_provsProvider.notifier).load(),
      ),
    );
  }

  void _showEditProveedor(BuildContext context, Proveedor p) {
    ResponsiveForm.showPage<void>(
      context: context,
      dialogWidth: 620,
      dialogHeight: 680,
      page: _ProveedorScreen(
        proveedor: p,
        repo: ref.read(_comprasRepoProvider),
        onSaved: () => ref.read(_provsProvider.notifier).load(),
      ),
    );
  }

  void _showDetalle(BuildContext context, String id) {
    AppNav.push(
      context,
      _DetalleOrdenScreen(
        id: id,
        repo: ref.read(_comprasRepoProvider),
        canEdit: ref.read(authProvider).hasPermission('compras:editar'),
        onChanged: () => ref.read(_ordenesProvider.notifier).load(),
      ),
    );
  }
}

class _DesktopComprasTabs extends StatelessWidget {
  const _DesktopComprasTabs({
    required this.sections,
    required this.active,
    required this.onSelected,
  });

  final List<_DesktopComprasSection> sections;
  final _DesktopComprasSection active;
  final ValueChanged<_DesktopComprasSection> onSelected;

  @override
  Widget build(BuildContext context) {
    const data = <_DesktopComprasSection, (IconData, String)>{
      _DesktopComprasSection.nueva: (Icons.add_rounded, 'Nueva orden'),
      _DesktopComprasSection.historial: (
        Icons.assignment_outlined,
        'Historial de órdenes',
      ),
      _DesktopComprasSection.proveedores: (
        Icons.local_shipping_outlined,
        'Proveedores',
      ),
    };

    return Container(
      key: const Key('compras-desktop-tabs'),
      height: 49,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: context.colors.background,
        border: Border(bottom: BorderSide(color: context.colors.border)),
      ),
      child: Row(
        children: [
          for (final section in sections)
            _DesktopComprasTabButton(
              icon: data[section]!.$1,
              label: data[section]!.$2,
              selected: section == active,
              onTap: () => onSelected(section),
            ),
        ],
      ),
    );
  }
}

class _DesktopComprasTabButton extends StatelessWidget {
  const _DesktopComprasTabButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 15,
            color: selected ? AppColors.primary : context.colors.textTertiary,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: selected
                  ? AppColors.primary
                  : context.colors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

class _DesktopOrdenesView extends StatelessWidget {
  final _OrdenesState state;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onEstado;
  final Future<void> Function() onRefresh;
  final ValueChanged<int> onPageChange;
  final ValueChanged<String> onDetail;

  const _DesktopOrdenesView({
    required this.state,
    required this.searchController,
    required this.onSearch,
    required this.onEstado,
    required this.onRefresh,
    required this.onPageChange,
    required this.onDetail,
  });

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: searchController,
                onChanged: onSearch,
                decoration: const InputDecoration(
                  hintText: 'Buscar por orden o proveedor...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: state.estadoFilter,
                items: const [
                  DropdownMenuItem(value: '', child: Text('Todos los estados')),
                  DropdownMenuItem(
                    value: 'PENDIENTE',
                    child: Text('Pendientes'),
                  ),
                  DropdownMenuItem(value: 'RECIBIDA', child: Text('Recibidas')),
                  DropdownMenuItem(
                    value: 'CANCELADA',
                    child: Text('Canceladas'),
                  ),
                ],
                onChanged: (value) => onEstado(value ?? ''),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (state.loading)
          const AppLoading()
        else if (state.error != null)
          AppErrorState(message: state.error!, onRetry: onRefresh)
        else if (state.items.isEmpty)
          const AppEmptyState(
            icon: Icons.shopping_cart_outlined,
            title: 'Sin órdenes',
            description: 'No hay compras guardadas aún.',
          )
        else ...[
          for (final order in state.items)
            _OrdenTile(compra: order, onTap: () => onDetail(order.id)),
          AppPagination(
            page: state.page,
            totalPages: state.totalPages,
            total: state.total,
            onPageChange: onPageChange,
          ),
        ],
      ],
    ),
  );
}

class _DesktopProveedoresView extends StatelessWidget {
  final _ProvsState state;
  final bool canCreate;
  final bool canEdit;
  final VoidCallback? onCreate;
  final ValueChanged<Proveedor>? onEdit;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onActivo;
  final Future<void> Function() onRefresh;
  final ValueChanged<int> onPageChange;

  const _DesktopProveedoresView({
    required this.state,
    required this.canCreate,
    required this.canEdit,
    required this.onCreate,
    required this.onEdit,
    required this.onSearch,
    required this.onActivo,
    required this.onRefresh,
    required this.onPageChange,
  });

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Proveedores', style: AppTextStyles.titleLarge),
        const SizedBox(height: 3),
        Text(
          'Administra la información de tus proveedores.',
          style: AppTextStyles.bodySmall,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                onChanged: onSearch,
                decoration: const InputDecoration(
                  hintText: 'Buscar proveedor...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: state.activo,
                items: const [
                  DropdownMenuItem(value: '', child: Text('Todos')),
                  DropdownMenuItem(value: 'true', child: Text('Activos')),
                  DropdownMenuItem(value: 'false', child: Text('Inactivos')),
                ],
                onChanged: (value) => onActivo(value ?? ''),
              ),
            ),
            if (canCreate) ...[
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nuevo proveedor'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        if (state.loading)
          const AppLoading()
        else if (state.error != null)
          AppErrorState(message: state.error!, onRetry: onRefresh)
        else if (state.items.isEmpty)
          const AppEmptyState(
            icon: Icons.local_shipping_outlined,
            title: 'Sin proveedores',
            description: 'No hay proveedores con los filtros aplicados.',
          )
        else ...[
          for (final provider in state.items)
            _ProvTile(
              prov: provider,
              canEdit: canEdit && onEdit != null,
              onEdit: () => onEdit?.call(provider),
            ),
          AppPagination(
            page: state.page,
            totalPages: state.totalPages,
            total: state.total,
            onPageChange: onPageChange,
          ),
        ],
      ],
    ),
  );
}

// ─── Órdenes Tab ──────────────────────────────────────────────────────────────

class _OrdenesTab extends ConsumerStatefulWidget {
  final bool canEdit;
  final ValueChanged<String> onDetail;
  final bool desktop;
  const _OrdenesTab({
    required this.canEdit,
    required this.onDetail,
    this.desktop = false,
  });

  @override
  ConsumerState<_OrdenesTab> createState() => _OrdenesTabState();
}

class _OrdenesTabState extends ConsumerState<_OrdenesTab> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_ordenesProvider);
    final notifier = ref.read(_ordenesProvider.notifier);

    if (widget.desktop) {
      return _DesktopOrdenesView(
        state: state,
        searchController: _searchCtrl,
        onSearch: notifier.setSearch,
        onEstado: notifier.setEstado,
        onRefresh: notifier.load,
        onPageChange: notifier.setPage,
        onDetail: widget.onDetail,
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => notifier.load(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // ─── Search field (matches web) ───────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: notifier.setSearch,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Buscar por orden o proveedor...',
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: context.colors.textTertiary,
                  size: 20,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                filled: true,
                fillColor: context.colors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: context.colors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: context.colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
          if (state.resumen != null && !state.loading)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  _Chip(
                    'Pendientes',
                    '${state.resumen!.pendientes}',
                    AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                  _Chip(
                    'Recibidas',
                    '${state.resumen!.recibidas}',
                    AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  _Chip(
                    'Total',
                    '${state.resumen!.totalOrdenes}',
                    AppColors.primary,
                  ),
                ],
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                for (final e in [
                  ('', 'Todas'),
                  ('PENDIENTE', 'Pendiente'),
                  ('ENVIADA', 'Enviada'),
                  ('RECIBIDA', 'Recibida'),
                  ('CANCELADA', 'Cancelada'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => notifier.setEstado(e.$1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: state.estadoFilter == e.$1
                              ? AppColors.brand
                              : context.colors.backgroundAlt,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          border: Border.all(
                            color: state.estadoFilter == e.$1
                                ? AppColors.brand
                                : context.colors.border,
                          ),
                        ),
                        child: Text(
                          e.$2,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: state.estadoFilter == e.$1
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: state.estadoFilter == e.$1
                                ? Colors.black
                                : context.colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (state.loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: AppLoading(),
            )
          else if (state.error != null)
            AppErrorState(message: state.error!, onRetry: () => notifier.load())
          else if (state.items.isEmpty)
            const AppEmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Sin órdenes',
            )
          else ...[
            for (final compra in state.items)
              _OrdenTile(
                compra: compra,
                onTap: () => widget.onDetail(compra.id),
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
    );
  }
}

class _Chip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Chip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(label, style: AppTextStyles.labelSmall),
        ],
      ),
    ),
  );
}

class _OrdenTile extends StatelessWidget {
  final Compra compra;
  final VoidCallback onTap;
  const _OrdenTile({required this.compra, required this.onTap});

  Color _statusColor(BuildContext context) {
    switch (compra.estado) {
      case 'RECIBIDA':
        return AppColors.success;
      case 'ENVIADA':
        return AppColors.primary;
      case 'CANCELADA':
        return context.colors.textTertiary;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        compra.orden,
                        style: AppTextStyles.titleMedium,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _statusColor(context).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        compra.estado,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _statusColor(context),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  compra.proveedor,
                  style: AppTextStyles.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${compra.fecha} · ${compra.articulos} items',
                  style: AppTextStyles.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'S/ ${compra.total.toStringAsFixed(2)}',
            style: AppTextStyles.titleMedium.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    ),
  );
}

// ─── Proveedores Tab ──────────────────────────────────────────────────────────

class _ProvsTab extends ConsumerWidget {
  final bool canEdit;
  final bool canCreate;
  final bool desktop;
  final VoidCallback? onCreate;
  final ValueChanged<Proveedor>? onEdit;
  const _ProvsTab({
    required this.canEdit,
    this.onEdit,
    this.canCreate = false,
    this.desktop = false,
    this.onCreate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_provsProvider);
    final notifier = ref.read(_provsProvider.notifier);

    if (desktop) {
      return _DesktopProveedoresView(
        state: state,
        canCreate: canCreate,
        canEdit: canEdit,
        onCreate: onCreate,
        onEdit: onEdit,
        onSearch: notifier.setSearch,
        onActivo: notifier.setActivo,
        onRefresh: notifier.load,
        onPageChange: notifier.setPage,
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => notifier.load(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          LayoutBuilder(
            builder: (_, constraints) {
              final search = TextField(
                key: const Key('proveedores-search'),
                onChanged: notifier.setSearch,
                decoration: const InputDecoration(
                  hintText: 'Buscar proveedor...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              );
              final status = DropdownButtonFormField<String>(
                key: const Key('proveedores-status'),
                initialValue: state.activo,
                decoration: const InputDecoration(labelText: 'Estado'),
                items: const [
                  DropdownMenuItem(value: '', child: Text('Todos')),
                  DropdownMenuItem(value: 'true', child: Text('Activos')),
                  DropdownMenuItem(value: 'false', child: Text('Inactivos')),
                ],
                onChanged: (value) => notifier.setActivo(value ?? ''),
              );
              if (constraints.maxWidth < 600) {
                return Column(
                  children: [search, const SizedBox(height: 8), status],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 2, child: search),
                  const SizedBox(width: 12),
                  Expanded(child: status),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          if (state.loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: AppLoading(),
            )
          else if (state.error != null)
            AppErrorState(message: state.error!, onRetry: () => notifier.load())
          else if (state.items.isEmpty)
            const AppEmptyState(
              icon: Icons.local_shipping_outlined,
              title: 'Sin proveedores',
            )
          else ...[
            for (final prov in state.items)
              _ProvTile(
                prov: prov,
                canEdit: canEdit && onEdit != null,
                onEdit: () => onEdit?.call(prov),
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
    );
  }
}

class _ProvTile extends StatelessWidget {
  final Proveedor prov;
  final bool canEdit;
  final VoidCallback onEdit;
  const _ProvTile({
    required this.prov,
    required this.canEdit,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: AppCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.colors.primarySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.local_shipping_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prov.nombre,
                  style: AppTextStyles.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  prov.activo ? 'Activo' : 'Inactivo',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: prov.activo
                        ? AppColors.success
                        : context.colors.textTertiary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (prov.categoria != null)
                  Text(
                    prov.categoria!,
                    style: AppTextStyles.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (prov.contacto != null)
                  Text(
                    prov.contacto!,
                    style: AppTextStyles.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (prov.telefono != null)
                  Text(
                    prov.telefono!,
                    style: AppTextStyles.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (prov.email != null)
                  Text(
                    prov.email!,
                    style: AppTextStyles.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${prov.ordenes} órdenes', style: AppTextStyles.labelSmall),
              Text(
                'S/ ${prov.total.toStringAsFixed(2)}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (canEdit) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onEdit,
                  child: Text(
                    'Editar',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    ),
  );
}

// ─── Detalle sheet ────────────────────────────────────────────────────────────

// ─── Subpantalla: Detalle de Orden ───────────────────────────────────────────

class _DetalleOrdenScreen extends StatefulWidget {
  final String id;
  final ComprasRepository repo;
  final bool canEdit;
  final VoidCallback onChanged;
  const _DetalleOrdenScreen({
    required this.id,
    required this.repo,
    required this.canEdit,
    required this.onChanged,
  });
  @override
  State<_DetalleOrdenScreen> createState() => _DetalleOrdenScreenState();
}

class _DetalleOrdenScreenState extends State<_DetalleOrdenScreen> {
  Compra? _compra;
  bool _loading = true;
  String? _error;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = await widget.repo.getCompra(widget.id);
      if (mounted) {
        setState(() {
          _compra = c;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _cambiar(String estado) async {
    setState(() => _acting = true);
    try {
      await widget.repo.cambiarEstado(widget.id, estado);
      widget.onChanged();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _acting = false;
          _error = e.toString();
        });
      }
    }
  }

  Color _statusColor(String e) {
    switch (e) {
      case 'RECIBIDA':
        return AppColors.success;
      case 'ENVIADA':
        return AppColors.primary;
      case 'CANCELADA':
        return context.colors.textTertiary;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: SubPageAppBar(
        title: _compra?.orden ?? 'Detalle de orden',
        subtitle: _compra != null
            ? '${_compra!.proveedor} · ${_compra!.fecha}'
            : null,
        actions: _compra != null
            ? [
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(
                      _compra!.estado,
                    ).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _compra!.estado,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _statusColor(_compra!.estado),
                    ),
                  ),
                ),
              ]
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? AppErrorState(message: _error!, onRetry: _load)
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PurchaseTimeline(status: _compra!.estado),
                  const SizedBox(height: 20),
                  Text(
                    'Artículos (${_compra!.articulos})',
                    style: AppTextStyles.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  ...?_compra!.items?.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.producto,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: context.colors.textPrimary,
                                  ),
                                ),
                                Text(
                                  '${item.codigo} · ×${item.cantidad} · S/ ${item.costoUnit.toStringAsFixed(2)} c/u',
                                  style: AppTextStyles.labelSmall,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'S/ ${item.subtotal.toStringAsFixed(2)}',
                            style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                              color: context.colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: AppTextStyles.titleMedium),
                      Text(
                        'S/ ${_compra!.total.toStringAsFixed(2)}',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  if (_compra!.eta?.isNotEmpty == true) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Entrega estimada: ${_compra!.eta}',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                  if (_compra!.notas.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Notas', style: AppTextStyles.titleMedium),
                    const SizedBox(height: 4),
                    Text(_compra!.notas, style: AppTextStyles.bodySmall),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (widget.canEdit) ...[
                    const SizedBox(height: 24),
                    if (_compra!.estado == 'PENDIENTE')
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              label: 'Marcar enviada',
                              onPressed: _acting
                                  ? null
                                  : () => _cambiar('ENVIADA'),
                              variant: AppButtonVariant.outline,
                              isFullWidth: true,
                              height: 48,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: AppButton(
                              label: 'Cancelar',
                              onPressed: _acting
                                  ? null
                                  : () => _cambiar('CANCELADA'),
                              variant: AppButtonVariant.danger,
                              isFullWidth: true,
                              height: 48,
                            ),
                          ),
                        ],
                      ),
                    if (_compra!.estado == 'ENVIADA')
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              label: 'Marcar recibida',
                              onPressed: _acting
                                  ? null
                                  : () => _cambiar('RECIBIDA'),
                              isFullWidth: true,
                              isLoading: _acting,
                              height: 52,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: AppButton(
                              label: 'Cancelar',
                              onPressed: _acting
                                  ? null
                                  : () => _cambiar('CANCELADA'),
                              variant: AppButtonVariant.danger,
                              isFullWidth: true,
                              height: 52,
                            ),
                          ),
                        ],
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _PurchaseTimeline extends StatelessWidget {
  const _PurchaseTimeline({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    const steps = ['PENDIENTE', 'ENVIADA', 'RECIBIDA'];
    final cancelled = status == 'CANCELADA';
    final current = steps.indexOf(status);
    return Row(
      children: [
        for (var index = 0; index < steps.length; index++) ...[
          Expanded(
            child: Column(
              children: [
                Icon(
                  cancelled
                      ? Icons.cancel_rounded
                      : index <= current
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: cancelled
                      ? AppColors.error
                      : index <= current
                      ? AppColors.success
                      : context.colors.textTertiary,
                  size: 20,
                ),
                const SizedBox(height: 4),
                Text(
                  cancelled && index == 0 ? 'CANCELADA' : steps[index],
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: cancelled
                        ? AppColors.error
                        : index <= current
                        ? context.colors.textPrimary
                        : context.colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          if (index < steps.length - 1)
            Expanded(
              child: Divider(
                color: !cancelled && index < current
                    ? AppColors.success
                    : context.colors.border,
              ),
            ),
        ],
      ],
    );
  }
}

// ─── Nueva orden sheet ────────────────────────────────────────────────────────

class _NuevaOrdenScreen extends StatefulWidget {
  final ComprasRepository repo;
  final ProductosRepository productosRepo;
  final UserProfile user;
  final String? initialSedeId;
  final VoidCallback onCreated;
  final bool embedded;
  const _NuevaOrdenScreen({
    super.key,
    required this.repo,
    required this.productosRepo,
    required this.user,
    this.initialSedeId,
    required this.onCreated,
    this.embedded = false,
  });

  @override
  State<_NuevaOrdenScreen> createState() => _NuevaOrdenScreenState();
}

class _NuevaOrdenScreenState extends State<_NuevaOrdenScreen> {
  final _notasCtrl = TextEditingController();
  String _proveedorId = '';
  String _sedeId = '';
  String _productoId = '';
  List<Proveedor> _proveedores = [];
  List<CompraSede> _sedes = [];
  List<Producto> _productos = [];
  final List<_CompraDraftLine> _items = [];
  bool _loading = true, _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sedeId = widget.initialSedeId ?? widget.user.sedeId ?? '';
    _loadOptions();
  }

  @override
  void dispose() {
    _notasCtrl.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _loadOptions() async {
    try {
      final results = await Future.wait<dynamic>([
        widget.repo.listProveedores(limite: 100, activo: 'true'),
        widget.productosRepo.list(limite: 100, activo: 'true'),
        if (widget.user.isSuperAdmin) widget.repo.listSedes(),
      ]);
      if (!mounted) return;
      final proveedores = results[0] as ComprasPage<Proveedor>;
      final productos = results[1] as ProductosPage;
      setState(() {
        _proveedores = proveedores.data
            .where((p) => p.activo && p.id.isNotEmpty)
            .toList();
        _productos = productos.data
            .where((p) => p.activo && p.id.isNotEmpty)
            .toList();
        if (widget.user.isSuperAdmin) {
          _sedes = results[2] as List<CompraSede>;
          if (!_sedes.any((sede) => sede.id == _sedeId)) _sedeId = '';
        }
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _addProduct() {
    if (_productoId.isEmpty) {
      setState(() => _error = 'Selecciona un producto.');
      return;
    }
    if (_items.any((item) => item.producto.id == _productoId)) {
      setState(() => _error = 'Este producto ya fue agregado.');
      return;
    }
    final producto = _productos.firstWhere((p) => p.id == _productoId);
    setState(() {
      _items.add(_CompraDraftLine(producto));
      _productoId = '';
      _error = null;
    });
  }

  void _removeItem(_CompraDraftLine item) {
    setState(() => _items.remove(item));
    item.dispose();
  }

  double get _total =>
      _items.fold(0, (total, line) => total + (line.item?.subtotal ?? 0));

  Future<void> _submit() async {
    if (_proveedorId.isEmpty) {
      setState(() => _error = 'Selecciona un proveedor.');
      return;
    }
    if (_sedeId.isEmpty) {
      setState(() {
        _error = widget.user.isSuperAdmin
            ? 'Selecciona una sede.'
            : 'Tu usuario no tiene una sede asignada.';
      });
      return;
    }
    if (_items.isEmpty) {
      setState(() => _error = 'Agrega al menos un producto.');
      return;
    }
    final items = _items.map((line) => line.item).toList();
    if (items.any((item) => item == null)) {
      setState(() {
        _error =
            'Cantidad, costo unitario y precio de venta deben ser números mayores a 0.';
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repo.createCompra(
        proveedorId: _proveedorId,
        sedeId: _sedeId,
        items: items.cast<CompraCreateItem>(),
        notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
      );
      if (mounted) {
        if (!widget.embedded) Navigator.of(context).pop();
        widget.onCreated();
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
    if (widget.embedded) return _buildEmbedded(context);

    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: const SubPageAppBar(title: 'Nueva orden de compra'),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 80,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else ...[
              if (widget.user.isSuperAdmin) ...[
                DropdownButtonFormField<String>(
                  key: ValueKey('sede-$_sedeId'),
                  initialValue: _sedeId.isEmpty ? null : _sedeId,
                  decoration: _dropdownDecoration('Sede *'),
                  hint: const Text('Seleccionar'),
                  items: _sedes
                      .map(
                        (sede) => DropdownMenuItem(
                          value: sede.id,
                          child: Text(sede.nombre),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _sedeId = value ?? ''),
                ),
                const SizedBox(height: 14),
              ] else
                InputDecorator(
                  decoration: _dropdownDecoration('Sede'),
                  child: Text(
                    widget.user.sedeName.isNotEmpty
                        ? widget.user.sedeName
                        : (_sedeId.isNotEmpty ? 'Sede asignada' : 'Sin sede'),
                    style: AppTextStyles.bodyMedium,
                  ),
                ),
              if (!widget.user.isSuperAdmin) const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                key: ValueKey('proveedor-$_proveedorId'),
                initialValue: _proveedorId.isEmpty ? null : _proveedorId,
                decoration: _dropdownDecoration('Proveedor *'),
                hint: const Text('Seleccionar'),
                items: _proveedores
                    .map(
                      (p) =>
                          DropdownMenuItem(value: p.id, child: Text(p.nombre)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _proveedorId = v ?? ''),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Productos', style: AppTextStyles.titleMedium),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('producto-$_productoId'),
                      initialValue: _productoId.isEmpty ? null : _productoId,
                      isExpanded: true,
                      decoration: _dropdownDecoration('Producto *'),
                      hint: const Text('Seleccionar'),
                      items: _productos
                          .where(
                            (producto) => !_items.any(
                              (item) => item.producto.id == producto.id,
                            ),
                          )
                          .map(
                            (producto) => DropdownMenuItem(
                              value: producto.id,
                              child: Text(
                                '${producto.nombre} · ${producto.codigo}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _productoId = value ?? ''),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: _addProduct,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Agregar'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_items.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  decoration: BoxDecoration(
                    color: context.colors.backgroundAlt,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.shopping_bag_outlined,
                        color: context.colors.textTertiary,
                      ),
                      SizedBox(height: 6),
                      Text('Agrega al menos un producto'),
                    ],
                  ),
                )
              else
                ..._items.map(
                  (item) => _CompraDraftCard(
                    key: ValueKey(item.producto.id),
                    line: item,
                    onChanged: () => setState(() {}),
                    onRemove: () => _removeItem(item),
                  ),
                ),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.colors.primarySurface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: context.colors.primaryBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total', style: AppTextStyles.titleMedium),
                    Text(
                      'S/ ${_total.toStringAsFixed(2)}',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _notasCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Notas',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
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
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Crear orden',
              onPressed: _saving || _loading ? null : _submit,
              isLoading: _saving,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmbedded(BuildContext context) => ColoredBox(
    key: const Key('compras-desktop-new-order-layout'),
    color: context.colors.background,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final editor = _buildEmbeddedEditor(context);
                final summary = _buildEmbeddedSummary(context);
                if (constraints.maxWidth < 900) {
                  return SingleChildScrollView(
                    child: Column(
                      children: [editor, const SizedBox(height: 16), summary],
                    ),
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: SingleChildScrollView(child: editor)),
                    const SizedBox(width: 20),
                    SizedBox(
                      width: 330,
                      child: SingleChildScrollView(child: summary),
                    ),
                  ],
                );
              },
            ),
    ),
  );

  Widget _buildEmbeddedEditor(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (widget.user.isSuperAdmin) ...[
        DropdownButtonFormField<String>(
          key: ValueKey('desktop-sede-$_sedeId'),
          initialValue: _sedeId.isEmpty ? null : _sedeId,
          decoration: _dropdownDecoration('Sede *'),
          hint: const Text('Seleccionar sede'),
          items: _sedes
              .map(
                (sede) =>
                    DropdownMenuItem(value: sede.id, child: Text(sede.nombre)),
              )
              .toList(),
          onChanged: (value) => setState(() => _sedeId = value ?? ''),
        ),
        const SizedBox(height: 14),
      ],
      LayoutBuilder(
        builder: (context, constraints) {
          final provider = DropdownButtonFormField<String>(
            key: ValueKey('desktop-proveedor-$_proveedorId'),
            initialValue: _proveedorId.isEmpty ? null : _proveedorId,
            isExpanded: true,
            decoration: _dropdownDecoration('Proveedor *'),
            hint: const Text('Seleccionar proveedor'),
            items: _proveedores
                .map(
                  (provider) => DropdownMenuItem(
                    value: provider.id,
                    child: Text(
                      provider.nombre,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _proveedorId = value ?? ''),
          );
          final product = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('desktop-producto-$_productoId'),
                  initialValue: _productoId.isEmpty ? null : _productoId,
                  isExpanded: true,
                  decoration: _dropdownDecoration('Seleccionar producto'),
                  hint: const Text('Seleccione un producto para agregar'),
                  items: _productos
                      .where(
                        (producto) => !_items.any(
                          (item) => item.producto.id == producto.id,
                        ),
                      )
                      .map(
                        (producto) => DropdownMenuItem(
                          value: producto.id,
                          child: Text(
                            '${producto.nombre} · ${producto.codigo}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _productoId = value ?? ''),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: _addProduct,
                  icon: const Icon(Icons.add_rounded, size: 17),
                  label: const Text('Agregar'),
                ),
              ),
            ],
          );
          if (constraints.maxWidth < 680) {
            return Column(
              children: [provider, const SizedBox(height: 12), product],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: provider),
              const SizedBox(width: 12),
              Expanded(child: product),
            ],
          );
        },
      ),
      const SizedBox(height: 16),
      Container(
        key: const Key('compras-desktop-order-items'),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: context.colors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: _items.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 46),
                child: Column(
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      size: 30,
                      color: context.colors.textTertiary,
                    ),
                    const SizedBox(height: 10),
                    Text('Lista vacía', style: AppTextStyles.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Seleccione un producto arriba para comenzar.',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    for (final item in _items)
                      _CompraDraftCard(
                        key: ValueKey(item.producto.id),
                        line: item,
                        onChanged: () => setState(() {}),
                        onRemove: () => _removeItem(item),
                      ),
                  ],
                ),
              ),
      ),
    ],
  );

  Widget _buildEmbeddedSummary(BuildContext context) => Container(
    key: const Key('compras-desktop-order-summary'),
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: context.colors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          color: context.colors.backgroundAlt,
          child: const Row(
            children: [
              Icon(Icons.shopping_bag_outlined, size: 17),
              SizedBox(width: 8),
              Text('Resumen de la orden', style: AppTextStyles.titleMedium),
            ],
          ),
        ),
        Divider(height: 1, color: context.colors.border),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Subtotal', style: AppTextStyles.bodySmall),
                  Text(
                    'S/ ${_total.toStringAsFixed(2)}',
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Divider(height: 1, color: context.colors.border),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total', style: AppTextStyles.titleMedium),
                  Text(
                    'S/ ${_total.toStringAsFixed(2)}',
                    style: AppTextStyles.headlineMedium.copyWith(
                      color: AppColors.brand,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _notasCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notas',
                  hintText: 'Notas de la orden...',
                  alignLabelWithHint: true,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ],
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Crear orden',
                onPressed: _saving ? null : _submit,
                isLoading: _saving,
              ),
              const SizedBox(height: 8),
              Text(
                'Se guardará al confirmar.',
                textAlign: TextAlign.center,
                style: AppTextStyles.labelSmall,
              ),
            ],
          ),
        ),
      ],
    ),
  );

  InputDecoration _dropdownDecoration(String label) => InputDecoration(
    labelText: label,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
  );
}

class _CompraDraftLine {
  final Producto producto;
  final TextEditingController cantidad;
  final TextEditingController costoUnit;
  final TextEditingController precioVenta;

  _CompraDraftLine(this.producto)
    : cantidad = TextEditingController(text: '1'),
      costoUnit = TextEditingController(
        text: (producto.precioCosto ?? 0).toStringAsFixed(2),
      ),
      precioVenta = TextEditingController(
        text: producto.precioVenta.toStringAsFixed(2),
      );

  CompraCreateItem? get item => parseCompraCreateItem(
    productoId: producto.id,
    cantidad: cantidad.text,
    costoUnit: costoUnit.text,
    precioVenta: precioVenta.text,
  );

  void dispose() {
    cantidad.dispose();
    costoUnit.dispose();
    precioVenta.dispose();
  }
}

class _CompraDraftCard extends StatelessWidget {
  final _CompraDraftLine line;
  final VoidCallback onChanged, onRemove;

  const _CompraDraftCard({
    super.key,
    required this.line,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: AppCard(
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
                      line.producto.nombre,
                      style: AppTextStyles.titleMedium,
                    ),
                    Text(line.producto.codigo, style: AppTextStyles.labelSmall),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Quitar producto',
                onPressed: onRemove,
                color: AppColors.error,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 380;
              final cantidad = _numberField('Cantidad', line.cantidad);
              final costo = _numberField('Costo unit.', line.costoUnit);
              final precio = _numberField('P. venta', line.precioVenta);
              if (narrow) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: cantidad),
                        const SizedBox(width: 8),
                        Expanded(child: costo),
                      ],
                    ),
                    const SizedBox(height: 8),
                    precio,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: cantidad),
                  const SizedBox(width: 8),
                  Expanded(child: costo),
                  const SizedBox(width: 8),
                  Expanded(child: precio),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Subtotal: S/ ${(line.item?.subtotal ?? 0).toStringAsFixed(2)}',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _numberField(String label, TextEditingController controller) =>
      TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 12,
          ),
        ),
      );
}

// ─── Proveedor sheet ──────────────────────────────────────────────────────────

class _ProveedorScreen extends StatefulWidget {
  final Proveedor? proveedor;
  final ComprasRepository repo;
  final VoidCallback onSaved;
  const _ProveedorScreen({
    this.proveedor,
    required this.repo,
    required this.onSaved,
  });

  @override
  State<_ProveedorScreen> createState() => _ProveedorScreenState();
}

class _ProveedorScreenState extends State<_ProveedorScreen> {
  late TextEditingController _nombreCtrl, _contactoCtrl, _telCtrl, _emailCtrl;
  bool _activo = true, _saving = false;
  String? _error;
  // Categoría: seleccionada del API (igual que en web) o valor libre del proveedor.
  String? _selectedCat;
  List<String> _catOptions = [];
  bool _catsLoading = true;

  @override
  void initState() {
    super.initState();
    final p = widget.proveedor;
    _nombreCtrl = TextEditingController(text: p?.nombre ?? '');
    _contactoCtrl = TextEditingController(text: p?.contacto ?? '');
    _telCtrl = TextEditingController(text: p?.telefono ?? '');
    _emailCtrl = TextEditingController(text: p?.email ?? '');
    _activo = p?.activo ?? true;
    _selectedCat = p?.categoria?.isNotEmpty == true ? p!.categoria : null;
    _loadCats();
  }

  Future<void> _loadCats() async {
    try {
      final cats = await ProductosRepository(ApiClient.instance).categorias();
      if (!mounted) return;
      final nombres = cats.map((c) => c.nombre).toList();
      // Si el proveedor tiene una categoría que no está en la lista, la agregamos.
      if (_selectedCat != null && !nombres.contains(_selectedCat)) {
        nombres.insert(0, _selectedCat!);
      }
      setState(() {
        _catOptions = nombres;
        _catsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _catsLoading = false);
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _contactoCtrl.dispose();
    _telCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nombreCtrl.text.trim().length < 2) {
      setState(() => _error = 'El nombre debe tener al menos 2 caracteres.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.proveedor == null) {
        await widget.repo.createProveedor(
          nombre: _nombreCtrl.text.trim(),
          categoria: _selectedCat?.isNotEmpty == true ? _selectedCat : null,
          contacto: _contactoCtrl.text.trim().isEmpty
              ? null
              : _contactoCtrl.text.trim(),
          telefono: _telCtrl.text.trim().isEmpty ? null : _telCtrl.text.trim(),
          email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        );
      } else {
        await widget.repo.updateProveedor(widget.proveedor!.id, {
          'nombre': _nombreCtrl.text.trim(),
          if (_selectedCat?.isNotEmpty == true) 'categoria': _selectedCat!,
          if (_contactoCtrl.text.trim().isNotEmpty)
            'contacto': _contactoCtrl.text.trim(),
          if (_telCtrl.text.trim().isNotEmpty) 'telefono': _telCtrl.text.trim(),
          if (_emailCtrl.text.trim().isNotEmpty)
            'email': _emailCtrl.text.trim(),
          'activo': _activo,
        });
      }
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
        title: widget.proveedor == null
            ? 'Nuevo proveedor'
            : 'Editar proveedor',
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 80,
        ),
        child: Column(
          children: [
            AppTextField(
              label: 'Nombre *',
              hint: 'Distribuidora XYZ',
              controller: _nombreCtrl,
            ),
            const SizedBox(height: 12),
            // Categoría: dropdown desde el API de categorías de productos
            // (mismo comportamiento que la web).
            DropdownButtonFormField<String?>(
              initialValue: _catOptions.contains(_selectedCat)
                  ? _selectedCat
                  : null,
              decoration: InputDecoration(
                labelText: 'Categoría',
                suffixIcon: _catsLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Sin categoría'),
                ),
                ..._catOptions.map(
                  (cat) =>
                      DropdownMenuItem<String?>(value: cat, child: Text(cat)),
                ),
              ],
              onChanged: _catsLoading
                  ? null
                  : (v) => setState(() => _selectedCat = v),
            ),
            const SizedBox(height: 12),
            AppTextField(label: 'Contacto', controller: _contactoCtrl),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Teléfono',
              controller: _telCtrl,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Email',
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
            ),
            if (widget.proveedor != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(
                    child: Text('Activo', style: AppTextStyles.bodyMedium),
                  ),
                  Switch(
                    value: _activo,
                    onChanged: (v) => setState(() => _activo = v),
                  ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),
            PrimaryButton(
              label: widget.proveedor == null
                  ? 'Crear proveedor'
                  : 'Guardar cambios',
              onPressed: _saving ? null : _submit,
              isLoading: _saving,
            ),
          ],
        ),
      ),
    );
  }
}
