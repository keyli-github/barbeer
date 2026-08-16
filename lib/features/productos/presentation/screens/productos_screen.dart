import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/navigation/app_nav.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/providers/sede_scope_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_spacing.dart' as spacing;
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../categorias/data/categorias_repository.dart';
import '../../data/productos_repository.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final _repoProvider = Provider<ProductosRepository>(
  (ref) => ProductosRepository(ApiClient.instance),
);

final _categoriasProvider = FutureProvider<List<Categoria>>((ref) async {
  return ref.watch(_repoProvider).categorias();
});

class _ProductosState {
  final List<Producto> items;
  final ProductosResumen? resumen;
  final bool loading;
  final String? error;
  final int page, totalPages, total;
  final String search, categoriaFilter, estadoFilter;

  const _ProductosState({
    this.items = const [],
    this.resumen,
    this.loading = true,
    this.error,
    this.page = 1,
    this.totalPages = 1,
    this.total = 0,
    this.search = '',
    this.categoriaFilter = '',
    this.estadoFilter = '',
  });

  _ProductosState copyWith({
    List<Producto>? items,
    ProductosResumen? resumen,
    bool? loading,
    String? error,
    bool clearError = false,
    int? page,
    int? totalPages,
    int? total,
    String? search,
    String? categoriaFilter,
    String? estadoFilter,
  }) => _ProductosState(
    items: items ?? this.items,
    resumen: resumen ?? this.resumen,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
    page: page ?? this.page,
    totalPages: totalPages ?? this.totalPages,
    total: total ?? this.total,
    search: search ?? this.search,
    categoriaFilter: categoriaFilter ?? this.categoriaFilter,
    estadoFilter: estadoFilter ?? this.estadoFilter,
  );
}

class _ProductosNotifier extends StateNotifier<_ProductosState> {
  final ProductosRepository _repo;
  final String? _sedeId;
  Timer? _searchDebounce;
  int _loadGeneration = 0;

  _ProductosNotifier(this._repo, this._sedeId)
    : super(const _ProductosState()) {
    load();
  }

  Future<void> load({bool resetPage = false}) async {
    final generation = ++_loadGeneration;
    final currentPage = resetPage ? 1 : state.page;
    state = state.copyWith(loading: true, clearError: true, page: currentPage);
    try {
      final results = await Future.wait([
        _repo.list(
          pagina: currentPage,
          limite: 20,
          q: state.search.isEmpty ? null : state.search,
          categoriaId: state.categoriaFilter.isEmpty
              ? null
              : state.categoriaFilter,
          activo: state.estadoFilter.isEmpty ? null : state.estadoFilter,
          sedeId: _sedeId,
        ),
        _repo.resumen(),
      ]);
      final page = results[0] as ProductosPage;
      final resumen = results[1] as ProductosResumen;
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

  void setCategoria(String id) {
    state = state.copyWith(categoriaFilter: id == 'all' ? '' : id);
    load(resetPage: true);
  }

  void setEstado(String v) {
    state = state.copyWith(estadoFilter: v);
    load(resetPage: true);
  }

  void setPage(int p) {
    state = state.copyWith(page: p);
    load();
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    await load();
  }

  Future<void> toggleActivo(Producto p) async {
    await _repo.update(p.id, {'activo': !p.activo});
    await load();
  }

  Future<void> togglePos(Producto product) async {
    await _repo.update(product.id, {'disponiblePos': !product.disponiblePos});
    await load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}

final _productosNotifier =
    StateNotifierProvider<_ProductosNotifier, _ProductosState>(
      (ref) => _ProductosNotifier(
        ref.watch(_repoProvider),
        ref.watch(globalSedeIdProvider),
      ),
    );

// ─── Screen ───────────────────────────────────────────────────────────────────

class ProductosScreen extends ConsumerWidget {
  const ProductosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final state = ref.watch(_productosNotifier);
    final notifier = ref.read(_productosNotifier.notifier);
    final catsAsync = ref.watch(_categoriasProvider);
    final canCreate = auth.hasPermission('productos:crear');
    final canEdit = auth.hasPermission('productos:editar');
    final canDelete = auth.hasPermission('productos:eliminar');
    final desktop = MediaQuery.sizeOf(context).width >= 1024;

    return Scaffold(
      backgroundColor: desktop
          ? context.colors.backgroundAlt
          : context.colors.background,
      // FAB para crear producto
      floatingActionButton: canCreate
          ? FloatingActionButton(
              heroTag: 'prod_fab',
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              onPressed: () => _showForm(context, ref, null),
              child: const Icon(Icons.add_rounded),
            )
          : null,
      body: Column(
        children: [
          // ─── Filtros ────────────────────────────────────────
          _FiltersSection(
            search: state.search,
            onSearch: notifier.setSearch,
            estadoFilter: state.estadoFilter,
            onEstado: notifier.setEstado,
          ),
          // ─── Categorías ─────────────────────────────────────
          catsAsync.when(
            data: (cats) => _CatStrip(
              cats: cats,
              selected: state.categoriaFilter,
              onSelect: notifier.setCategoria,
            ),
            loading: () => const SizedBox(height: 40),
            error: (_, _) => const SizedBox.shrink(),
          ),
          // ─── KPIs ───────────────────────────────────────────
          if (state.resumen != null && !state.loading)
            _KpiRow(resumen: state.resumen!),
          const SizedBox(height: AppSpacing.xs),
          // ─── Grid de productos ──────────────────────────────
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: state.loading
                  ? AppLoadingIndicator(key: ValueKey('loading'))
                  : state.error != null
                  ? AppErrorState(
                      key: ValueKey('error'),
                      message: state.error!,
                      onActionPressed: () => notifier.load(),
                    )
                  : state.items.isEmpty
                  ? AppEmptyState(
                      key: ValueKey('empty'),
                      icon: Icons.inventory_2_outlined,
                      title: 'Sin productos',
                      message: 'No hay productos con los filtros actuales.',
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = desktop
                            ? (constraints.maxWidth / 230).floor().clamp(3, 6)
                            : 2;
                        return Column(
                          children: [
                            Expanded(
                              child: GridView.builder(
                                key: ValueKey('grid'),
                                padding: EdgeInsets.all(AppSpacing.md),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: columns,
                                      childAspectRatio: desktop ? 0.68 : 0.56,
                                      crossAxisSpacing: AppSpacing.sm,
                                      mainAxisSpacing: AppSpacing.sm,
                                    ),
                                itemCount: state.items.length,
                                itemBuilder: (_, i) => _ProductCard(
                                  product: state.items[i],
                                  canEdit: canEdit,
                                  canDelete: canDelete,
                                  onOpen: () => _showProductDetail(
                                    context,
                                    ref,
                                    state.items[i],
                                  ),
                                  onEdit: () =>
                                      _showForm(context, ref, state.items[i]),
                                  onToggleActivo: () =>
                                      notifier.toggleActivo(state.items[i]),
                                  onTogglePos: () =>
                                      notifier.togglePos(state.items[i]),
                                  onDelete: () async {
                                    final ok = await ConfirmationDialog.show(
                                      context: context,
                                      title: 'Dar de baja producto',
                                      message:
                                          '¿Dar de baja "${state.items[i].nombre}"? Podrás reactivarlo después.',
                                      confirmText: 'Dar de baja',
                                      isDestructive: true,
                                      icon: Icons.delete_outline,
                                    );
                                    if (ok) {
                                      await notifier.delete(state.items[i].id);
                                    }
                                  },
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                AppSpacing.md,
                                0,
                                AppSpacing.md,
                                AppSpacing.md,
                              ),
                              child: AppPagination(
                                page: state.page,
                                totalPages: state.totalPages,
                                total: state.total,
                                onPageChange: notifier.setPage,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showProductDetail(
    BuildContext context,
    WidgetRef ref,
    Producto product,
  ) {
    final canEdit = ref.read(authProvider).hasPermission('productos:editar');
    final canDelete = ref
        .read(authProvider)
        .hasPermission('productos:eliminar');
    // rootNavigator: true → se muestra ENCIMA del Shell (sin bottom nav)
    AppNav.push(
      context,
      _ProductDetailScreen(
        product: product,
        canEdit: canEdit,
        canDelete: canDelete,
        onEdit: () async => AppNav.push(
          context,
          _ProductFormScreen(
            product: product,
            cats: ref.read(_categoriasProvider).value ?? [],
            onSaved: () => ref.read(_productosNotifier.notifier).load(),
            repo: ref.read(_repoProvider),
            canManageImage: canEdit,
          ),
        ),
        onToggle: () async {
          await ref.read(_repoProvider).toggle(product.id, !product.activo);
          ref.read(_productosNotifier.notifier).load();
        },
        onDelete: () async {
          await ref.read(_repoProvider).delete(product.id);
          ref.read(_productosNotifier.notifier).load();
        },
      ),
    );
  }

  void _showForm(BuildContext context, WidgetRef ref, Producto? product) {
    // Crear nuevo producto → subpantalla completa
    AppNav.push(
      context,
      _ProductFormScreen(
        product: product,
        cats: ref.read(_categoriasProvider).value ?? [],
        onSaved: () => ref.read(_productosNotifier.notifier).load(),
        repo: ref.read(_repoProvider),
        canManageImage: ref
            .read(authProvider)
            .hasPermission('productos:editar'),
      ),
    );
  }
}

// ─── Filters Section ──────────────────────────────────────────────────────────

class _FiltersSection extends StatefulWidget {
  final String search;
  final ValueChanged<String> onSearch;
  final String estadoFilter;
  final ValueChanged<String> onEstado;

  const _FiltersSection({
    required this.search,
    required this.onSearch,
    required this.estadoFilter,
    required this.onEstado,
  });

  @override
  State<_FiltersSection> createState() => _FiltersSectionState();
}

class _FiltersSectionState extends State<_FiltersSection> {
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ctrl.text = widget.search;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colors.background,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        children: [
          // Campo de búsqueda
          TextField(
            controller: _ctrl,
            onChanged: widget.onSearch,
            style: TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o código...',
              prefixIcon: Icon(
                Icons.search_rounded,
                color: context.colors.textTertiary,
                size: 20,
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              filled: true,
              fillColor: context.colors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  spacing.AppSpacing.radiusMD,
                ),
                borderSide: BorderSide(color: context.colors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  spacing.AppSpacing.radiusMD,
                ),
                borderSide: BorderSide(color: context.colors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  spacing.AppSpacing.radiusMD,
                ),
                borderSide: BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          // Filtro de estado (dropdown compacto, mismo comportamiento que los chips)
          _EstadoDropdown(
            value: widget.estadoFilter,
            onChanged: widget.onEstado,
          ),
        ],
      ),
    );
  }
}

class _EstadoDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _EstadoDropdown({required this.value, required this.onChanged});

  static const _opciones = [
    ('', 'Todos'),
    ('true', 'Activos'),
    ('false', 'Inactivos'),
  ];

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      key: const ValueKey('productos-estado-filter'),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        prefixIcon: Icon(
          Icons.filter_alt_outlined,
          size: 18,
          color: context.colors.textTertiary,
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 0),
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
        child: DropdownButton<String>(
          key: const ValueKey('productos-estado-dropdown'),
          value: value.isEmpty ? '' : value,
          isDense: true,
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: context.colors.textTertiary,
          ),
          style: TextStyle(fontSize: 14, color: context.colors.textPrimary),
          items: _opciones
              .map(
                (e) => DropdownMenuItem(
                  value: e.$1,
                  child: Text(e.$2, style: const TextStyle(fontSize: 14)),
                ),
              )
              .toList(),
          onChanged: (v) => onChanged(v ?? ''),
        ),
      ),
    );
  }
}

// ─── Categorías strip ─────────────────────────────────────────────────────────

class _CatStrip extends StatelessWidget {
  final List<Categoria> cats;
  final String selected;
  final ValueChanged<String> onSelect;
  const _CatStrip({
    required this.cats,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colors.background,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Row(
          children: [
            _Chip(
              label: 'Todos',
              selected: selected.isEmpty || selected == 'all',
              onTap: () => onSelect('all'),
            ),
            ...cats.map(
              (c) => _Chip(
                label: c.nombre,
                selected: selected == c.id,
                onTap: () => onSelect(c.id),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
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

// ─── KPIs ─────────────────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  final ProductosResumen resumen;
  const _KpiRow({required this.resumen});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          _KpiChip('Activos', '${resumen.activos}', AppColors.success),
          SizedBox(width: AppSpacing.xs),
          _KpiChip('En venta', '${resumen.enPos}', AppColors.primary),
          SizedBox(width: AppSpacing.xs),
          _KpiChip(
            'Margen',
            '${resumen.margenPromedio.toStringAsFixed(0)}%',
            AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _KpiChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _KpiChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(spacing.AppSpacing.radiusSM),
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
          Text(
            label,
            style: TextStyle(fontSize: 11, color: context.colors.textTertiary),
          ),
        ],
      ),
    ),
  );
}

// ─── Product Card — compacto, sin overflow ────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final Producto product;
  final bool canEdit, canDelete;
  final VoidCallback onOpen, onEdit, onToggleActivo, onTogglePos, onDelete;

  const _ProductCard({
    required this.product,
    required this.canEdit,
    required this.canDelete,
    required this.onOpen,
    required this.onEdit,
    required this.onToggleActivo,
    required this.onTogglePos,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final marginColor = product.margin >= 40
        ? AppColors.success
        : product.margin >= 20
        ? AppColors.warning
        : AppColors.error;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.borderLight),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─ Imagen cuadrada (proporción fija)
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(11),
                ),
                child: AspectRatio(
                  aspectRatio: 1.2,
                  child: DSProductImage(
                    imageUrl: product.imagenUrl,
                    productName: product.nombre,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
              ),
              if (canEdit || canDelete)
                Positioned(
                  right: 4,
                  top: 4,
                  child: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'pos') onTogglePos();
                      if (value == 'active') onToggleActivo();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      if (canEdit)
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Editar'),
                        ),
                      if (canEdit)
                        PopupMenuItem(
                          value: 'pos',
                          child: Text(
                            product.disponiblePos
                                ? 'Ocultar de venta'
                                : 'Mostrar en venta',
                          ),
                        ),
                      if (canEdit)
                        PopupMenuItem(
                          value: 'active',
                          child: Text(
                            product.activo ? 'Desactivar' : 'Activar',
                          ),
                        ),
                      if (canDelete && product.activo)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Dar de baja'),
                        ),
                    ],
                    icon: const Icon(Icons.more_vert_rounded),
                  ),
                ),
            ],
          ),
          // ─ Info compacta (se expande para llenar el espacio restante)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.categoria,
                    style: TextStyle(
                      fontSize: 10,
                      color: context.colors.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Expanded(
                    child: Text(
                      product.nombre,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    product.codigo,
                    style: TextStyle(
                      fontSize: 10,
                      color: context.colors.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (product.descripcion?.isNotEmpty == true)
                    Text(
                      product.descripcion!,
                      style: TextStyle(
                        fontSize: 9,
                        color: context.colors.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'S/ ${product.precioVenta.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: marginColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${product.margin.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: marginColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.stockDisponible == null
                              ? 'Stock sin configurar'
                              : 'Stock ${product.stockDisponible}',
                          style: TextStyle(
                            fontSize: 9,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ),
                      Text(
                        product.disponiblePos ? 'VENTA' : 'NO POS',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: product.disponiblePos
                              ? AppColors.success
                              : context.colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  // Estado inactivo
                  if (!product.activo) ...[
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.textTertiary.withValues(
                          alpha: 0.1,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Inactivo',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // ─ Ver detalle: control único y claro para abrir el detalle
          GestureDetector(
            onTap: onOpen,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: context.colors.borderLight),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.visibility_outlined,
                    size: 14,
                    color: context.colors.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Ver detalle',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textSecondary,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: context.colors.textTertiary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Subpantalla: Detalle de Producto ────────────────────────────────────────

class _ProductDetailScreen extends ConsumerStatefulWidget {
  final Producto product;
  final bool canEdit, canDelete;
  final Future<void> Function() onEdit;
  final VoidCallback onToggle, onDelete;

  const _ProductDetailScreen({
    required this.product,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  ConsumerState<_ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<_ProductDetailScreen> {
  late Producto _product;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    _refresh();
  }

  /// Refresca el detalle desde `GET /productos/:id` usando la sede global,
  /// para que stock/costo coincidan siempre con la web y el listado.
  Future<void> _refresh() async {
    final sedeId = ref.read(globalSedeIdProvider);
    try {
      final fresh = await ref
          .read(_repoProvider)
          .getById(widget.product.id, sedeId: sedeId);
      if (mounted) setState(() => _product = fresh);
    } catch (_) {
      // Mantiene los datos del listado si el refetch falla.
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = _product;
    final marginColor = product.margin >= 40
        ? AppColors.success
        : product.margin >= 20
        ? AppColors.warning
        : AppColors.error;

    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: context.colors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Detalle de producto',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
        actions: [
          if (widget.canEdit)
            IconButton(
              icon: Icon(
                Icons.settings_outlined,
                size: 20,
                color: context.colors.textSecondary,
              ),
              onPressed: () async {
                await widget.onEdit();
                if (mounted) await _refresh();
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─ Imagen + info principal
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: DSProductImage(
                    imageUrl: product.imagenUrl,
                    productName: product.nombre,
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge activo
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: product.activo
                              ? context.colors.successLight
                              : context.colors.errorLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: product.activo
                                    ? AppColors.success
                                    : AppColors.error,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              product.activo ? 'Activo' : 'Inactivo',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: product.activo
                                    ? AppColors.success
                                    : AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        product.nombre,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: context.colors.textPrimary,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.categoria,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'SKU: ${product.codigo}',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'S/ ${product.precioVenta.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Margen: ${product.margin.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: marginColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ─ Acciones rápidas
            if (widget.canEdit)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onEdit(); // fire-and-forget: abre el form desde la lista
                      },
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Editar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: context.colors.primaryBorder),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onToggle();
                      },
                      icon: Icon(
                        product.activo
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 16,
                      ),
                      label: Text(product.activo ? 'Desactivar' : 'Activar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.colors.textSecondary,
                        side: BorderSide(color: context.colors.border),
                      ),
                    ),
                  ),
                ],
              ),
            if (widget.canDelete) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      useRootNavigator: true,
                      builder: (_) => AlertDialog(
                        title: const Text('Eliminar producto'),
                        content: Text('¿Eliminar ${product.nombre}?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.error,
                            ),
                            child: const Text('Eliminar'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      widget.onDelete();
                    }
                  },
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Eliminar producto'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ─ Info general
            _InfoSection('Información general', [
              _InfoRow('Categoría', product.categoria),
              if (product.presentacion != null)
                _InfoRow('Presentación', product.presentacion!),
              _InfoRow(
                'Costo unitario',
                'S/ ${product.precioCosto.toStringAsFixed(2)}',
              ),
              _InfoRow(
                'Stock disponible',
                product.stockDisponible == null
                    ? 'Sin configurar'
                    : '${product.stockDisponible}',
              ),
            ]),

            if (product.descripcion?.isNotEmpty == true) ...[
              const SizedBox(height: 16),
              _InfoSection('Descripción', [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    product.descripcion!,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.colors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _InfoSection(this.title, this.children);
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: context.colors.textPrimary,
        ),
      ),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.borderLight),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          children: children
              .expand(
                (w) => [
                  w,
                  if (w != children.last)
                    Divider(height: 1, color: context.colors.surfaceAlt),
                ],
              )
              .toList(),
        ),
      ),
    ],
  );
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
            ),
          ),
        ),
      ],
    ),
  );
}

// ─── Formulario ───────────────────────────────────────────────────────────────

// ─── Subpantalla: Formulario de Producto ─────────────────────────────────────

class _ProductFormScreen extends StatefulWidget {
  final Producto? product;
  final List<Categoria> cats;
  final VoidCallback onSaved;
  final ProductosRepository repo;
  final bool canManageImage;
  const _ProductFormScreen({
    this.product,
    required this.cats,
    required this.onSaved,
    required this.repo,
    required this.canManageImage,
  });

  @override
  State<_ProductFormScreen> createState() => _ProductFormState();
}

class _ProductFormState extends State<_ProductFormScreen> {
  final _nombreCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _ventaCtrl = TextEditingController();
  final _costoCtrl = TextEditingController();
  Uint8List? _imageBytes;
  String? _imageFilename;
  bool _removeExistingImage = false;
  String _categoriaId = '';
  bool _posEnabled = false, _activo = true, _saving = false;
  String? _error;
  final _creationSession = ProductCreationSession();

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    if (p != null) {
      _nombreCtrl.text = p.nombre;
      _descCtrl.text = p.descripcion ?? '';
      _ventaCtrl.text = p.precioVenta.toString();
      _costoCtrl.text = p.precioCosto.toString();
      _categoriaId = p.categoriaId;
      _posEnabled = p.disponiblePos;
      _activo = p.activo;
    } else if (widget.cats.isNotEmpty) {
      _categoriaId = widget.cats.first.id;
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descCtrl.dispose();
    _ventaCtrl.dispose();
    _costoCtrl.dispose();
    super.dispose();
  }

  double get _margin {
    final v = double.tryParse(_ventaCtrl.text) ?? 0;
    final c = double.tryParse(_costoCtrl.text) ?? 0;
    return v > 0 ? (v - c) / v * 100 : 0;
  }

  Future<void> _submit() async {
    final nombre = _nombreCtrl.text.trim();
    final venta = double.tryParse(_ventaCtrl.text);
    final costo = double.tryParse(_costoCtrl.text);

    if (nombre.isEmpty ||
        _categoriaId.isEmpty ||
        venta == null ||
        costo == null) {
      setState(() => _error = 'Completa todos los campos obligatorios.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.product == null) {
        await _creationSession.submit(
          create: () => widget.repo.create(
            nombre: nombre,
            categoriaId: _categoriaId,
            precioVenta: venta,
            precioCosto: costo,
            descripcion: _descCtrl.text.trim().isEmpty
                ? null
                : _descCtrl.text.trim(),
            disponiblePos: _posEnabled,
            activo: _activo,
          ),
          uploadImage: (id) async {
            if (_imageBytes == null) return;
            await widget.repo.uploadImage(
              id,
              bytes: _imageBytes!,
              filename: _imageFilename!,
            );
          },
        );
      } else {
        await widget.repo.update(widget.product!.id, {
          'nombre': nombre,
          'categoriaId': _categoriaId,
          'precioVenta': venta,
          'precioCosto': costo,
          if (_descCtrl.text.trim().isNotEmpty)
            'descripcion': _descCtrl.text.trim(),
          'disponiblePos': _posEnabled,
          'activo': _activo,
        });
        if (_imageBytes != null) {
          await widget.repo.uploadImage(
            widget.product!.id,
            bytes: _imageBytes!,
            filename: _imageFilename!,
          );
        } else if (_removeExistingImage) {
          await widget.repo.deleteImage(widget.product!.id);
        }
      }
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSaved();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _creationSession.createdId != null && widget.product == null
            ? 'El producto ya fue creado, pero la imagen no se pudo subir. '
                  'El reintento solo subirá la imagen; los demás campos no se reenviarán.'
            : e.toString();
      });
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    final file = result?.files.single;
    if (file == null || file.bytes == null || !mounted) return;
    if (file.bytes!.lengthInBytes > 5 * 1024 * 1024) {
      setState(() => _error = 'La imagen no debe superar 5 MB.');
      return;
    }
    setState(() {
      _imageBytes = file.bytes;
      _imageFilename = file.name;
      _removeExistingImage = false;
      _error = null;
    });
  }

  void _removeImage() {
    setState(() {
      _imageBytes = null;
      _imageFilename = null;
      _removeExistingImage = widget.product?.imagenUrl != null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: SubPageAppBar(
        title: widget.product == null ? 'Nuevo producto' : 'Editar producto',
        actions: [
          if (!_saving)
            TextButton(
              onPressed: _submit,
              child: const Text(
                'Guardar',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 80,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              label: 'Nombre *',
              hint: 'Nombre del producto',
              controller: _nombreCtrl,
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Descripción',
              hint: 'Opcional',
              controller: _descCtrl,
              maxLines: 2,
            ),
            const SizedBox(height: 14),
            if (widget.canManageImage) ...[
              Text(
                'Imagen del producto',
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Stack(
                children: [
                  InkWell(
                    key: const Key('product-image-picker'),
                    onTap: _saving ? null : _pickImage,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Container(
                      width: double.infinity,
                      height: 150,
                      decoration: BoxDecoration(
                        color: context.colors.backgroundAlt,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: context.colors.border,
                          style: BorderStyle.solid,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _imageBytes != null
                          ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                          : !_removeExistingImage &&
                                widget.product?.imagenUrl != null
                          ? DSProductImage(
                              imageUrl: widget.product!.imagenUrl,
                              productName: _nombreCtrl.text,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: 150,
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_outlined,
                                  color: context.colors.textTertiary,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Seleccionar JPG, PNG o WEBP',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.colors.textSecondary,
                                  ),
                                ),
                                Text(
                                  'Máximo 5 MB',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: context.colors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  if (_imageBytes != null ||
                      (!_removeExistingImage &&
                          widget.product?.imagenUrl != null))
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton.filled(
                        key: const Key('product-image-remove'),
                        tooltip: 'Quitar imagen',
                        onPressed: _saving ? null : _removeImage,
                        icon: const Icon(Icons.close_rounded, size: 17),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
            ],
            Text(
              'Categoría *',
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _categoriaId.isEmpty ? null : _categoriaId,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              hint: const Text('Seleccionar categoría'),
              items: widget.cats
                  .map(
                    (c) => DropdownMenuItem(value: c.id, child: Text(c.nombre)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _categoriaId = v ?? ''),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'Precio venta (S/) *',
                    hint: '0.00',
                    controller: _ventaCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    label: 'Costo (S/) *',
                    hint: '0.00',
                    controller: _costoCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: context.colors.backgroundAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Text(
                    'Margen estimado: ',
                    style: AppTextStyles.bodySmall,
                  ),
                  Text(
                    '${_margin.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _margin >= 40
                          ? AppColors.success
                          : _margin >= 20
                          ? AppColors.warning
                          : AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SwitchRow(
              label: 'Disponible para venta',
              value: _posEnabled,
              onChanged: (v) => setState(() => _posEnabled = v),
            ),
            _SwitchRow(
              label: 'Producto activo',
              value: _activo,
              onChanged: (v) => setState(() => _activo = v),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ],
            const SizedBox(height: 24),
            PrimaryButton(
              text: widget.product == null
                  ? _creationSession.createdId == null
                        ? 'Crear producto'
                        : _imageBytes == null
                        ? 'Finalizar sin imagen'
                        : 'Reintentar imagen'
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

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
      Switch(value: value, onChanged: onChanged),
    ],
  );
}
