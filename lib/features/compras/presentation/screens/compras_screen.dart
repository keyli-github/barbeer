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
                  canEdit: canEdit,
                  onEdit: (p) => _showEditProveedor(context, p),
                ),
              ],
            ),
          ),
        ],
      ),
      // FAB dinámico según tab activo
      floatingActionButton: canCreate
          ? ListenableBuilder(
              listenable: _tabs,
              builder: (_, _) => FloatingActionButton(
                heroTag: 'compras_fab',
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                onPressed: _tabs.index == 0
                    ? () => _showNuevaOrden(context)
                    : () => _showNuevoProveedor(context),
                child: const Icon(Icons.add_rounded),
              ),
            )
          : null,
    );
  }

  void _showNuevaOrden(BuildContext context) {
    AppNav.push(
      context,
      _NuevaOrdenScreen(
        repo: ref.read(_comprasRepoProvider),
        productosRepo: ref.read(_productosRepoProvider),
        user: ref.read(authProvider).user!,
        initialSedeId: ref.read(globalSedeIdProvider),
        onCreated: () => ref.read(_ordenesProvider.notifier).load(),
      ),
    );
  }

  void _showNuevoProveedor(BuildContext context) {
    AppNav.push(
      context,
      _ProveedorScreen(
        repo: ref.read(_comprasRepoProvider),
        onSaved: () => ref.read(_provsProvider.notifier).load(),
      ),
    );
  }

  void _showEditProveedor(BuildContext context, Proveedor p) {
    AppNav.push(
      context,
      _ProveedorScreen(
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

// ─── Órdenes Tab ──────────────────────────────────────────────────────────────

class _OrdenesTab extends ConsumerStatefulWidget {
  final bool canEdit;
  final ValueChanged<String> onDetail;
  const _OrdenesTab({required this.canEdit, required this.onDetail});

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

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => notifier.load(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
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
                              ? context.colors.primarySurface
                              : context.colors.backgroundAlt,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          border: Border.all(
                            color: state.estadoFilter == e.$1
                                ? context.colors.primaryBorder
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
                                ? AppColors.primary
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
            AppErrorState(
              message: state.error!,
              onRetry: () => notifier.load(),
            )
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
                Text(compra.proveedor, style: AppTextStyles.bodySmall),
                Text(
                  '${compra.fecha} · ${compra.articulos} items',
                  style: AppTextStyles.labelSmall,
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
  final ValueChanged<Proveedor> onEdit;
  const _ProvsTab({required this.canEdit, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_provsProvider);
    final notifier = ref.read(_provsProvider.notifier);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => notifier.load(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
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
            AppErrorState(
              message: state.error!,
              onRetry: () => notifier.load(),
            )
          else if (state.items.isEmpty)
            const AppEmptyState(
              icon: Icons.local_shipping_outlined,
              title: 'Sin proveedores',
            )
          else ...[
            for (final prov in state.items)
              _ProvTile(
                prov: prov,
                canEdit: canEdit,
                onEdit: () => onEdit(prov),
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
                Text(prov.nombre, style: AppTextStyles.titleMedium),
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
                  Text(prov.categoria!, style: AppTextStyles.labelSmall),
                if (prov.contacto != null)
                  Text(prov.contacto!, style: AppTextStyles.labelSmall),
                if (prov.telefono != null)
                  Text(prov.telefono!, style: AppTextStyles.labelSmall),
                if (prov.email != null)
                  Text(prov.email!, style: AppTextStyles.labelSmall),
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
  const _NuevaOrdenScreen({
    required this.repo,
    required this.productosRepo,
    required this.user,
    this.initialSedeId,
    required this.onCreated,
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
        Navigator.of(context).pop();
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
        text: producto.precioCosto.toStringAsFixed(2),
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
              initialValue:
                  _catOptions.contains(_selectedCat) ? _selectedCat : null,
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
