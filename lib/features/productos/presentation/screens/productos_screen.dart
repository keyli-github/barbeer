import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_ui_components.dart';
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

  _ProductosNotifier(this._repo) : super(const _ProductosState()) {
    load();
  }

  Future<void> load({bool resetPage = false}) async {
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
        ),
        _repo.resumen(),
      ]);
      final page = results[0] as ProductosPage;
      final resumen = results[1] as ProductosResumen;
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
    load(resetPage: true);
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
}

final _productosNotifier =
    StateNotifierProvider<_ProductosNotifier, _ProductosState>(
      (ref) => _ProductosNotifier(ref.watch(_repoProvider)),
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

    return Scaffold(
      backgroundColor: AppColors.backgroundAlt,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ─── Header ────────────────────────────────────────
            _Header(
              total: state.total,
              onSearch: notifier.setSearch,
              onEstado: notifier.setEstado,
              estadoFilter: state.estadoFilter,
              canCreate: canCreate,
              onNew: () => _showForm(context, ref, null),
            ),
            // ─── Categorías ─────────────────────────────────────
            catsAsync.when(
              data: (cats) => _CatStrip(
                cats: cats,
                selected: state.categoriaFilter,
                onSelect: notifier.setCategoria,
              ),
              loading: () => const SizedBox(height: 40),
              error: (_, __) => const SizedBox.shrink(),
            ),
            // ─── KPIs ───────────────────────────────────────────
            if (state.resumen != null && !state.loading)
              _KpiRow(resumen: state.resumen!),
            const SizedBox(height: 4),
            // ─── Lista ──────────────────────────────────────────
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: state.loading
                    ? const AppLoading(key: ValueKey('loading'))
                    : state.error != null
                    ? AppErrorState(
                        key: const ValueKey('error'),
                        message: state.error!,
                        onRetry: () => notifier.load(),
                      )
                    : state.items.isEmpty
                    ? const AppEmptyState(
                        key: ValueKey('empty'),
                        icon: Icons.local_bar_outlined,
                        title: 'Sin productos',
                        description:
                            'No hay productos con los filtros actuales.',
                      )
                    : ListView.builder(
                        key: const ValueKey('list'),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        itemCount: state.items.length + 1,
                        itemBuilder: (_, i) {
                          if (i == state.items.length) {
                            return AppPagination(
                              page: state.page,
                              totalPages: state.totalPages,
                              total: state.total,
                              onPageChange: notifier.setPage,
                            );
                          }
                          return _ProductTile(
                            product: state.items[i],
                            canEdit: canEdit,
                            canDelete: canDelete,
                            onEdit: () =>
                                _showForm(context, ref, state.items[i]),
                            onToggle: () =>
                                notifier.toggleActivo(state.items[i]),
                            onDelete: () async {
                              final ok = await ConfirmDialog.show(
                                context: context,
                                title: 'Eliminar producto',
                                description:
                                    '¿Eliminar "${state.items[i].nombre}"? Esta acción no se puede deshacer.',
                                confirmLabel: 'Eliminar',
                                isDanger: true,
                              );
                              if (ok) await notifier.delete(state.items[i].id);
                            },
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showForm(BuildContext context, WidgetRef ref, Producto? product) {
    final cats = ref.read(_categoriasProvider).value ?? [];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ProductForm(
        product: product,
        categorias: cats,
        onSaved: () => ref.read(_productosNotifier.notifier).load(),
        repo: ref.read(_repoProvider),
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatefulWidget {
  final int total;
  final ValueChanged<String> onSearch, onEstado;
  final String estadoFilter;
  final bool canCreate;
  final VoidCallback onNew;
  const _Header({
    required this.total,
    required this.onSearch,
    required this.onEstado,
    required this.estadoFilter,
    required this.canCreate,
    required this.onNew,
  });

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.local_bar_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Productos',
                        style: AppTextStyles.headlineLarge,
                      ),
                      Text(
                        '${widget.total} en catálogo',
                        style: AppTextStyles.labelSmall,
                      ),
                    ],
                  ),
                ),
                if (widget.canCreate)
                  FilledButton.icon(
                    onPressed: widget.onNew,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Nuevo'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _ctrl,
              onChanged: widget.onSearch,
              style: AppTextStyles.bodyMedium,
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre o código...',
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppColors.textTertiary,
                  size: 18,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                for (final e in [
                  ('', 'Todos'),
                  ('true', 'Activos'),
                  ('false', 'Inactivos'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => widget.onEstado(e.$1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: widget.estadoFilter == e.$1
                              ? AppColors.primarySurface
                              : AppColors.backgroundAlt,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          border: Border.all(
                            color: widget.estadoFilter == e.$1
                                ? AppColors.primaryBorder
                                : AppColors.border,
                          ),
                        ),
                        child: Text(
                          e.$2,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: widget.estadoFilter == e.$1
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: widget.estadoFilter == e.$1
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
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
      color: AppColors.background,
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
        color: selected ? AppColors.primarySurface : AppColors.backgroundAlt,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: selected ? AppColors.primaryBorder : AppColors.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? AppColors.primary : AppColors.textSecondary,
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          _KpiChip('Activos', '${resumen.activos}', AppColors.success),
          const SizedBox(width: 8),
          _KpiChip('Para venta', '${resumen.enPos}', AppColors.accent),
          const SizedBox(width: 8),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
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

// ─── Tile ─────────────────────────────────────────────────────────────────────

class _ProductTile extends StatelessWidget {
  final Producto product;
  final bool canEdit, canDelete;
  final VoidCallback onEdit, onToggle, onDelete;
  const _ProductTile({
    required this.product,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final marginColor = product.margin >= 40
        ? AppColors.success
        : product.margin >= 20
        ? AppColors.warning
        : AppColors.error;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.local_bar_rounded,
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
                    product.nombre,
                    style: AppTextStyles.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${product.categoria} · ${product.codigo}',
                    style: AppTextStyles.labelSmall,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'S/ ${product.precioVenta.toStringAsFixed(2)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: marginColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${product.margin.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: marginColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (product.activo
                                ? AppColors.success
                                : AppColors.textTertiary)
                            .withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    product.activo ? 'Activo' : 'Inactivo',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: product.activo
                          ? AppColors.success
                          : AppColors.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                if (canEdit || canDelete)
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      size: 16,
                      color: AppColors.textTertiary,
                    ),
                    onSelected: (v) {
                      if (v == 'edit') onEdit();
                      if (v == 'toggle') onToggle();
                      if (v == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      if (canEdit) ...[
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Editar'),
                        ),
                        PopupMenuItem(
                          value: 'toggle',
                          child: Text(
                            product.activo ? 'Desactivar' : 'Activar',
                          ),
                        ),
                      ],
                      if (canDelete)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            'Eliminar',
                            style: TextStyle(color: AppColors.error),
                          ),
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

// ─── Formulario ───────────────────────────────────────────────────────────────

class _ProductForm extends StatefulWidget {
  final Producto? product;
  final List<Categoria> categorias;
  final VoidCallback onSaved;
  final ProductosRepository repo;
  const _ProductForm({
    this.product,
    required this.categorias,
    required this.onSaved,
    required this.repo,
  });

  @override
  State<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<_ProductForm> {
  final _codigoCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _ventaCtrl = TextEditingController();
  final _costoCtrl = TextEditingController();
  final _unidadCtrl = TextEditingController();
  String _categoriaId = '';
  bool _posEnabled = false, _activo = true, _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    if (p != null) {
      _codigoCtrl.text = p.codigo;
      _nombreCtrl.text = p.nombre;
      _descCtrl.text = p.descripcion ?? '';
      _ventaCtrl.text = p.precioVenta.toString();
      _costoCtrl.text = p.precioCosto.toString();
      _unidadCtrl.text = p.unidad;
      _categoriaId = p.categoriaId;
      _posEnabled = p.disponiblePos;
      _activo = p.activo;
    } else if (widget.categorias.isNotEmpty) {
      _categoriaId = widget.categorias.first.id;
    }
  }

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _nombreCtrl.dispose();
    _descCtrl.dispose();
    _ventaCtrl.dispose();
    _costoCtrl.dispose();
    _unidadCtrl.dispose();
    super.dispose();
  }

  double get _margin {
    final v = double.tryParse(_ventaCtrl.text) ?? 0;
    final c = double.tryParse(_costoCtrl.text) ?? 0;
    return v > 0 ? (v - c) / v * 100 : 0;
  }

  Future<void> _submit() async {
    final nombre = _nombreCtrl.text.trim();
    final codigo = _codigoCtrl.text.trim();
    final venta = double.tryParse(_ventaCtrl.text);
    final costo = double.tryParse(_costoCtrl.text);

    if (nombre.isEmpty ||
        codigo.isEmpty ||
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
        await widget.repo.create(
          codigo: codigo,
          nombre: nombre,
          categoriaId: _categoriaId,
          precioVenta: venta,
          precioCosto: costo,
          descripcion: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          unidad: _unidadCtrl.text.trim().isEmpty
              ? null
              : _unidadCtrl.text.trim(),
          disponiblePos: _posEnabled,
          activo: _activo,
        );
      } else {
        await widget.repo.update(widget.product!.id, {
          'nombre': nombre,
          'categoriaId': _categoriaId,
          'precioVenta': venta,
          'precioCosto': costo,
          if (_descCtrl.text.trim().isNotEmpty)
            'descripcion': _descCtrl.text.trim(),
          'unidad': _unidadCtrl.text.trim().isEmpty
              ? 'un'
              : _unidadCtrl.text.trim(),
          'disponiblePos': _posEnabled,
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
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(
              children: [
                Text(
                  widget.product == null ? 'Nuevo producto' : 'Editar producto',
                  style: AppTextStyles.headlineMedium,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.product == null)
                    AppTextField(
                      label: 'Código *',
                      hint: 'Ej. CKT001',
                      controller: _codigoCtrl,
                    ),
                  if (widget.product == null) const SizedBox(height: 14),
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
                  Text(
                    'Categoría *',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _categoriaId.isEmpty ? null : _categoriaId,
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
                    items: widget.categorias
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.nombre),
                          ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundAlt,
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
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'Unidad (Ej. botella, kg)',
                    hint: 'un',
                    controller: _unidadCtrl,
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
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  PrimaryButton(
                    label: widget.product == null
                        ? 'Crear producto'
                        : 'Guardar cambios',
                    onPressed: _saving ? null : _submit,
                    isLoading: _saving,
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
