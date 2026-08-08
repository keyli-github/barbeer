import 'package:flutter/material.dart';
import '../../../../core/navigation/app_nav.dart';
import '../../../../core/widgets/app_header.dart';
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
import '../../data/compras_repository.dart';

final _comprasRepoProvider = Provider<ComprasRepository>(
  (ref) => ComprasRepository(ApiClient.instance),
);

// ─── Ordenes state ────────────────────────────────────────────────────────────

class _OrdenesState {
  final List<Compra> items;
  final ComprasResumen? resumen;
  final bool loading;
  final String? error;
  final int page, totalPages, total;
  final String estadoFilter;

  const _OrdenesState({
    this.items = const [],
    this.resumen,
    this.loading = true,
    this.error,
    this.page = 1,
    this.totalPages = 1,
    this.total = 0,
    this.estadoFilter = '',
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
  }) => _OrdenesState(
    items: items ?? this.items,
    resumen: resumen ?? this.resumen,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
    page: page ?? this.page,
    totalPages: totalPages ?? this.totalPages,
    total: total ?? this.total,
    estadoFilter: estadoFilter ?? this.estadoFilter,
  );
}

class _OrdenesNotifier extends StateNotifier<_OrdenesState> {
  final ComprasRepository _repo;

  _OrdenesNotifier(this._repo) : super(const _OrdenesState()) {
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
        ),
        _repo.resumen(
          estado: state.estadoFilter.isEmpty ? null : state.estadoFilter,
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
}

final _ordenesProvider = StateNotifierProvider<_OrdenesNotifier, _OrdenesState>(
  (ref) => _OrdenesNotifier(ref.watch(_comprasRepoProvider)),
);

// ─── Proveedores state ────────────────────────────────────────────────────────

class _ProvsState {
  final List<Proveedor> items;
  final bool loading;
  final String? error;
  final int page, totalPages, total;

  const _ProvsState({
    this.items = const [],
    this.loading = true,
    this.error,
    this.page = 1,
    this.totalPages = 1,
    this.total = 0,
  });

  _ProvsState copyWith({
    List<Proveedor>? items,
    bool? loading,
    String? error,
    bool clearError = false,
    int? page,
    int? totalPages,
    int? total,
  }) => _ProvsState(
    items: items ?? this.items,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
    page: page ?? this.page,
    totalPages: totalPages ?? this.totalPages,
    total: total ?? this.total,
  );
}

class _ProvsNotifier extends StateNotifier<_ProvsState> {
  final ComprasRepository _repo;

  _ProvsNotifier(this._repo) : super(const _ProvsState()) {
    load();
  }

  Future<void> load({bool resetPage = false}) async {
    final p = resetPage ? 1 : state.page;
    state = state.copyWith(loading: true, clearError: true, page: p);
    try {
      final page = await _repo.listProveedores(pagina: p, activo: 'true');
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
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Solo tabs, sin título (el header viene del Shell)
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabs,
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
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
              builder: (_, __) => FloatingActionButton(
                heroTag: 'compras_fab',
                backgroundColor: AppColors.primary,
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

class _OrdenesTab extends ConsumerWidget {
  final bool canEdit;
  final ValueChanged<String> onDetail;
  const _OrdenesTab({required this.canEdit, required this.onDetail});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_ordenesProvider);
    final notifier = ref.read(_ordenesProvider.notifier);

    return Column(
      children: [
        if (state.resumen != null && !state.loading)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: state.estadoFilter == e.$1
                            ? AppColors.primarySurface
                            : AppColors.backgroundAlt,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(
                          color: state.estadoFilter == e.$1
                              ? AppColors.primaryBorder
                              : AppColors.border,
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
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: state.loading
                ? const AppLoading(key: ValueKey('l'))
                : state.error != null
                ? AppErrorState(
                    key: const ValueKey('e'),
                    message: state.error!,
                    onRetry: () => notifier.load(),
                  )
                : state.items.isEmpty
                ? const AppEmptyState(
                    key: ValueKey('empty'),
                    icon: Icons.shopping_cart_outlined,
                    title: 'Sin órdenes',
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
                      return _OrdenTile(
                        compra: state.items[i],
                        onTap: () => onDetail(state.items[i].id),
                      );
                    },
                  ),
          ),
        ),
      ],
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

class _OrdenTile extends StatelessWidget {
  final Compra compra;
  final VoidCallback onTap;
  const _OrdenTile({required this.compra, required this.onTap});

  Color get _statusColor {
    switch (compra.estado) {
      case 'RECIBIDA':
        return AppColors.success;
      case 'ENVIADA':
        return AppColors.primary;
      case 'CANCELADA':
        return AppColors.textTertiary;
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
                        color: _statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        compra.estado,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _statusColor,
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

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: state.loading
          ? const AppLoading(key: ValueKey('l'))
          : state.error != null
          ? AppErrorState(
              key: const ValueKey('e'),
              message: state.error!,
              onRetry: () => notifier.load(),
            )
          : state.items.isEmpty
          ? const AppEmptyState(
              key: ValueKey('empty'),
              icon: Icons.local_shipping_outlined,
              title: 'Sin proveedores',
            )
          : ListView.builder(
              key: const ValueKey('list'),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
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
                return _ProvTile(
                  prov: state.items[i],
                  canEdit: canEdit,
                  onEdit: () => onEdit(state.items[i]),
                );
              },
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
              color: AppColors.primarySurface,
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
                if (prov.categoria != null)
                  Text(prov.categoria!, style: AppTextStyles.labelSmall),
                if (prov.telefono != null)
                  Text(prov.telefono!, style: AppTextStyles.labelSmall),
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
      if (mounted)
        setState(() {
          _compra = c;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  Future<void> _cambiar(String estado) async {
    setState(() => _acting = true);
    try {
      await widget.repo.cambiarEstado(widget.id, estado);
      widget.onChanged();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted)
        setState(() {
          _acting = false;
          _error = e.toString();
        });
    }
  }

  Color _statusColor(String e) {
    switch (e) {
      case 'RECIBIDA':
        return AppColors.success;
      case 'ENVIADA':
        return AppColors.primary;
      case 'CANCELADA':
        return AppColors.textTertiary;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  '${item.codigo} · ×${item.cantidad}',
                                  style: AppTextStyles.labelSmall,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'S/ ${item.subtotal.toStringAsFixed(2)}',
                            style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
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
                      AppButton(
                        label: 'Marcar recibida',
                        onPressed: _acting ? null : () => _cambiar('RECIBIDA'),
                        isFullWidth: true,
                        isLoading: _acting,
                        height: 52,
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}

// ─── Nueva orden sheet ────────────────────────────────────────────────────────

class _NuevaOrdenScreen extends StatefulWidget {
  final ComprasRepository repo;
  final VoidCallback onCreated;
  const _NuevaOrdenScreen({required this.repo, required this.onCreated});

  @override
  State<_NuevaOrdenScreen> createState() => _NuevaOrdenScreenState();
}

class _NuevaOrdenScreenState extends State<_NuevaOrdenScreen> {
  final _etaCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  String _proveedorId = '';
  List<Proveedor> _proveedores = [];
  bool _loadingProvs = true, _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProvs();
  }

  @override
  void dispose() {
    _etaCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProvs() async {
    try {
      final p = await widget.repo.listProveedores(limite: 100, activo: 'true');
      if (mounted)
        setState(() {
          _proveedores = p.data;
          _loadingProvs = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loadingProvs = false);
    }
  }

  Future<void> _submit() async {
    if (_proveedorId.isEmpty) {
      setState(() => _error = 'Selecciona un proveedor.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repo.createCompra(
        proveedorId: _proveedorId,
        items: [],
        eta: _etaCtrl.text.trim().isEmpty ? null : _etaCtrl.text.trim(),
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
      backgroundColor: Colors.white,
      appBar: const SubPageAppBar(title: 'Nueva orden de compra'),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 80,
        ),
        child: Column(
          children: [
            if (_loadingProvs)
              const Center(child: CircularProgressIndicator())
            else
              DropdownButtonFormField<String>(
                value: _proveedorId.isEmpty ? null : _proveedorId,
                decoration: InputDecoration(
                  labelText: 'Proveedor *',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                hint: const Text('Seleccionar'),
                items: _proveedores
                    .map(
                      (p) =>
                          DropdownMenuItem(value: p.id, child: Text(p.nombre)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _proveedorId = v ?? ''),
              ),
            const SizedBox(height: 14),
            TextField(
              controller: _etaCtrl,
              keyboardType: TextInputType.datetime,
              decoration: InputDecoration(
                labelText: 'Fecha estimada (YYYY-MM-DD)',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
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
              onPressed: _saving ? null : _submit,
              isLoading: _saving,
            ),
          ],
        ),
      ),
    );
  }
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
  late TextEditingController _nombreCtrl,
      _catCtrl,
      _contactoCtrl,
      _telCtrl,
      _emailCtrl;
  bool _activo = true, _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.proveedor;
    _nombreCtrl = TextEditingController(text: p?.nombre ?? '');
    _catCtrl = TextEditingController(text: p?.categoria ?? '');
    _contactoCtrl = TextEditingController(text: p?.contacto ?? '');
    _telCtrl = TextEditingController(text: p?.telefono ?? '');
    _emailCtrl = TextEditingController(text: p?.email ?? '');
    _activo = p?.activo ?? true;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _catCtrl.dispose();
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
          categoria: _catCtrl.text.trim().isEmpty ? null : _catCtrl.text.trim(),
          contacto: _contactoCtrl.text.trim().isEmpty
              ? null
              : _contactoCtrl.text.trim(),
          telefono: _telCtrl.text.trim().isEmpty ? null : _telCtrl.text.trim(),
          email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        );
      } else {
        await widget.repo.updateProveedor(widget.proveedor!.id, {
          'nombre': _nombreCtrl.text.trim(),
          if (_catCtrl.text.trim().isNotEmpty)
            'categoria': _catCtrl.text.trim(),
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
      backgroundColor: Colors.white,
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
            AppTextField(
              label: 'Categoría',
              hint: 'Licores, cervezas...',
              controller: _catCtrl,
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
