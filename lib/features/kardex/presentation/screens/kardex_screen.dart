import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/providers/sede_scope_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_ui_components.dart';
import '../../../../core/widgets/ds_product_image.dart';
import '../../data/kardex_repository.dart';

final _kardexRepoProvider = Provider<KardexRepository>(
  (ref) => KardexRepository(ApiClient.instance),
);

class _KardexState {
  final List<KardexMovimiento> items;
  final KardexResumen? resumen;
  final bool loading;
  final String? error;
  final int page, totalPages, total;
  final String search, tipoFilter;
  final String? desde, hasta;

  const _KardexState({
    this.items = const [],
    this.resumen,
    this.loading = true,
    this.error,
    this.page = 1,
    this.totalPages = 1,
    this.total = 0,
    this.search = '',
    this.tipoFilter = '',
    this.desde,
    this.hasta,
  });

  _KardexState copyWith({
    List<KardexMovimiento>? items,
    KardexResumen? resumen,
    bool? loading,
    String? error,
    bool clearError = false,
    int? page,
    int? totalPages,
    int? total,
    String? search,
    String? tipoFilter,
    String? desde,
    String? hasta,
    bool clearDesde = false,
    bool clearHasta = false,
  }) => _KardexState(
    items: items ?? this.items,
    resumen: resumen ?? this.resumen,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
    page: page ?? this.page,
    totalPages: totalPages ?? this.totalPages,
    total: total ?? this.total,
    search: search ?? this.search,
    tipoFilter: tipoFilter ?? this.tipoFilter,
    desde: clearDesde ? null : (desde ?? this.desde),
    hasta: clearHasta ? null : (hasta ?? this.hasta),
  );
}

class _KardexNotifier extends StateNotifier<_KardexState> {
  final KardexRepository _repo;
  final String? _sedeId;

  _KardexNotifier(this._repo, this._sedeId) : super(const _KardexState()) {
    load();
  }

  Future<void> load({bool resetPage = false}) async {
    final p = resetPage ? 1 : state.page;
    state = state.copyWith(loading: true, clearError: true, page: p);
    try {
      final results = await Future.wait([
        _repo.list(
          pagina: p,
          limite: 25,
          q: state.search.isEmpty ? null : state.search,
          tipo: state.tipoFilter.isEmpty ? null : state.tipoFilter,
          desde: state.desde,
          hasta: state.hasta,
          sedeId: _sedeId,
        ),
        _repo.resumen(
          q: state.search.isEmpty ? null : state.search,
          tipo: state.tipoFilter.isEmpty ? null : state.tipoFilter,
          desde: state.desde,
          hasta: state.hasta,
          sedeId: _sedeId,
        ),
      ]);
      final page = results[0] as KardexPage;
      final resumen = results[1] as KardexResumen;
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

  void setTipo(String t) {
    state = state.copyWith(tipoFilter: t);
    load(resetPage: true);
  }

  void setDesde(String? d) {
    state = state.copyWith(desde: d, clearDesde: d == null);
    load(resetPage: true);
  }

  void setHasta(String? h) {
    state = state.copyWith(hasta: h, clearHasta: h == null);
    load(resetPage: true);
  }

  void setPage(int p) {
    state = state.copyWith(page: p);
    load();
  }
}

final _kardexProvider = StateNotifierProvider<_KardexNotifier, _KardexState>(
  (ref) => _KardexNotifier(
    ref.watch(_kardexRepoProvider),
    ref.watch(globalSedeIdProvider),
  ),
);

// ─── Screen ───────────────────────────────────────────────────────────────────

class KardexScreen extends ConsumerWidget {
  const KardexScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_kardexProvider);
    final notifier = ref.read(_kardexProvider.notifier);

    if (MediaQuery.sizeOf(context).width >= 1024) {
      return _buildDesktop(context, state, notifier);
    }

    return Scaffold(
      backgroundColor: context.colors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => notifier.load(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            _Header(
              total: state.total,
              onSearch: notifier.setSearch,
              tipoFilter: state.tipoFilter,
              onTipo: notifier.setTipo,
              desde: state.desde,
              hasta: state.hasta,
              onDesde: notifier.setDesde,
              onHasta: notifier.setHasta,
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
                icon: Icons.swap_vert_outlined,
                title: 'Sin movimientos',
                description: 'No hay movimientos con los filtros actuales.',
              )
            else ...[
              for (final mov in state.items) _MovTile(mov: mov),
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

  Widget _buildDesktop(
    BuildContext context,
    _KardexState state,
    _KardexNotifier notifier,
  ) => Scaffold(
    backgroundColor: context.colors.background,
    body: RefreshIndicator(
      color: AppColors.primary,
      onRefresh: notifier.load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 36),
        children: [
          Text(
            'Kardex de Inventario',
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 27,
              height: 1.1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Historial de movimientos de stock',
            style: TextStyle(color: context.colors.textTertiary, fontSize: 14),
          ),
          if (state.resumen != null && !state.loading) ...[
            const SizedBox(height: 20),
            _DesktopKardexMetrics(resumen: state.resumen!),
          ],
          const SizedBox(height: 20),
          _DesktopKardexFilters(
            tipo: state.tipoFilter,
            desde: state.desde,
            hasta: state.hasta,
            onSearch: notifier.setSearch,
            onTipo: notifier.setTipo,
            onDesde: notifier.setDesde,
            onHasta: notifier.setHasta,
          ),
          const SizedBox(height: 20),
          _DesktopKardexTable(
            state: state,
            onRetry: notifier.load,
            onPage: notifier.setPage,
          ),
        ],
      ),
    ),
  );
}

class _DesktopKardexMetrics extends StatelessWidget {
  final KardexResumen resumen;
  const _DesktopKardexMetrics({required this.resumen});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _DesktopKardexMetric(
        'Total movimientos',
        '${resumen.totalMovimientos}',
        context.colors.textPrimary,
      ),
      _DesktopKardexMetric(
        'Entradas',
        '${resumen.entradas}',
        AppColors.success,
      ),
      _DesktopKardexMetric('Salidas', '${resumen.salidas}', AppColors.error),
      _DesktopKardexMetric(
        'Valor total',
        'S/ ${resumen.valorTotal.toStringAsFixed(2)}',
        AppColors.primary,
      ),
    ],
  );
}

class _DesktopKardexMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _DesktopKardexMetric(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      height: 92,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: context.colors.textTertiary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

class _DesktopKardexFilters extends StatefulWidget {
  final String tipo;
  final String? desde;
  final String? hasta;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onTipo;
  final ValueChanged<String?> onDesde;
  final ValueChanged<String?> onHasta;

  const _DesktopKardexFilters({
    required this.tipo,
    required this.desde,
    required this.hasta,
    required this.onSearch,
    required this.onTipo,
    required this.onDesde,
    required this.onHasta,
  });

  @override
  State<_DesktopKardexFilters> createState() => _DesktopKardexFiltersState();
}

class _DesktopKardexFiltersState extends State<_DesktopKardexFilters> {
  Future<void> _pick(bool from) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    final value =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    from ? widget.onDesde(value) : widget.onHasta(value);
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 370,
        child: TextField(
          onChanged: widget.onSearch,
          decoration: const InputDecoration(
            hintText: 'Buscar producto, código o referencia...',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final type in const [
                ('', 'Todos'),
                ('ENTRADA', 'Entrada'),
                ('SALIDA', 'Salida'),
                ('AJUSTE', 'Ajuste'),
                ('TRASLADO', 'Traslado'),
                ('SALIDA_VENTA', 'Venta'),
                ('ENTRADA_ANULACION', 'Anulación'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(type.$2),
                    selected: widget.tipo == type.$1,
                    showCheckmark: false,
                    selectedColor: AppColors.primary,
                    onSelected: (_) => widget.onTipo(type.$1),
                  ),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(width: 12),
      OutlinedButton.icon(
        onPressed: () => _pick(true),
        icon: const Icon(Icons.calendar_today_outlined, size: 15),
        label: Text(widget.desde == null ? 'Desde' : widget.desde!),
      ),
      const SizedBox(width: 8),
      OutlinedButton.icon(
        onPressed: () => _pick(false),
        icon: const Icon(Icons.calendar_today_outlined, size: 15),
        label: Text(widget.hasta == null ? 'Hasta' : widget.hasta!),
      ),
    ],
  );
}

class _DesktopKardexTable extends StatelessWidget {
  final _KardexState state;
  final Future<void> Function() onRetry;
  final ValueChanged<int> onPage;

  const _DesktopKardexTable({
    required this.state,
    required this.onRetry,
    required this.onPage,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: context.colors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        const _DesktopKardexRow.header(),
        if (state.loading)
          const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (state.error != null)
          SizedBox(
            height: 180,
            child: AppErrorState(message: state.error!, onRetry: onRetry),
          )
        else if (state.items.isEmpty)
          const SizedBox(
            height: 180,
            child: Center(child: Text('Sin movimientos.')),
          )
        else
          for (final movement in state.items)
            _DesktopKardexRow(movement: movement),
        AppPagination(
          page: state.page,
          totalPages: state.totalPages,
          total: state.total,
          onPageChange: onPage,
        ),
      ],
    ),
  );
}

class _DesktopKardexRow extends StatelessWidget {
  final KardexMovimiento? movement;
  final bool header;
  const _DesktopKardexRow({required this.movement}) : header = false;
  const _DesktopKardexRow.header() : movement = null, header = true;

  @override
  Widget build(BuildContext context) {
    final movement = this.movement;
    final color = movement == null
        ? context.colors.textTertiary
        : kardexIsEntrada(movement.tipo)
        ? AppColors.success
        : kardexIsSalida(movement.tipo)
        ? AppColors.error
        : AppColors.warning;
    Widget cell(
      String text,
      int flex, {
      Color? textColor,
      bool strong = false,
    }) => Expanded(
      flex: flex,
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color:
              textColor ??
              (header
                  ? context.colors.textTertiary
                  : context.colors.textSecondary),
          fontSize: header ? 10 : 12,
          fontWeight: strong || header ? FontWeight.w700 : FontWeight.w500,
          letterSpacing: header ? .5 : 0,
        ),
      ),
    );
    return Container(
      constraints: BoxConstraints(minHeight: header ? 48 : 64),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: header ? context.colors.surfaceAlt : null,
        border: Border(bottom: BorderSide(color: context.colors.divider)),
      ),
      child: Row(
        children: header
            ? [
                cell('ID', 1),
                cell('FECHA', 1),
                cell('HORA', 1),
                cell('PRODUCTO', 2),
                cell('CÓDIGO', 1),
                cell('TIPO', 1),
                cell('CANT.', 1),
                cell('STOCK ANT.', 1),
                cell('STOCK NUEVO', 1),
                cell('VALOR', 1),
                cell('REFERENCIA', 2),
                cell('USUARIO', 1),
              ]
            : [
                cell(
                  movement!.id.length > 8
                      ? movement.id.substring(0, 8)
                      : movement.id,
                  1,
                  textColor: AppColors.primary,
                  strong: true,
                ),
                cell(movement.fecha, 1),
                cell(movement.hora, 1),
                cell(movement.producto, 2, strong: true),
                cell(movement.codigo, 1),
                cell(kardexTipoLabel(movement.tipo), 1, textColor: color),
                cell('${movement.cantidad}', 1, textColor: color, strong: true),
                cell('${movement.stockAnterior}', 1),
                cell('${movement.stockNuevo}', 1, strong: true),
                cell('S/ ${movement.valor.toStringAsFixed(2)}', 1),
                cell(movement.referencia, 2),
                cell(movement.usuario, 1),
              ],
      ),
    );
  }
}

class _Header extends StatefulWidget {
  final int total;
  final ValueChanged<String> onSearch, onTipo;
  final String tipoFilter;
  final String? desde, hasta;
  final ValueChanged<String?> onDesde, onHasta;
  const _Header({
    required this.total,
    required this.onSearch,
    required this.tipoFilter,
    required this.onTipo,
    required this.desde,
    required this.hasta,
    required this.onDesde,
    required this.onHasta,
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
          child: TextField(
            controller: _ctrl,
            onChanged: widget.onSearch,
            style: AppTextStyles.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Buscar producto...',
              prefixIcon: Icon(
                Icons.search_rounded,
                color: context.colors.textTertiary,
                size: 18,
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              for (final t in [
                ('', 'Todos'),
                ('ENTRADA', 'ENTRADA'),
                ('SALIDA', 'SALIDA'),
                ('AJUSTE', 'AJUSTE'),
                ('TRASLADO', 'TRASLADO'),
                ('SALIDA_VENTA', 'VENTA'),
                ('ENTRADA_ANULACION', 'ANULACIÓN'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => widget.onTipo(t.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: widget.tipoFilter == t.$1
                            ? AppColors.brand
                            : context.colors.backgroundAlt,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(
                          color: widget.tipoFilter == t.$1
                              ? AppColors.brand
                              : context.colors.border,
                        ),
                      ),
                      child: Text(
                        t.$2,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: widget.tipoFilter == t.$1
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: widget.tipoFilter == t.$1
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
        // ── Date range filters ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: _DateChip(
                  label: 'Desde',
                  value: widget.desde,
                  onPick: () => _pickDate(context, isDesde: true),
                  onClear: () => widget.onDesde(null),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DateChip(
                  label: 'Hasta',
                  value: widget.hasta,
                  onPick: () => _pickDate(context, isDesde: false),
                  onClear: () => widget.onHasta(null),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate(BuildContext context, {required bool isDesde}) async {
    final now = DateTime.now();
    // La causa del fallo era `locale: Locale('es', 'PE')` cuando la app no
    // tiene flutter_localizations configurado — lo que producía la pantalla
    // blanca. Se elimina el parámetro y se deja que Flutter use el locale
    // del sistema, lo que siempre funciona sin delegates adicionales.
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: now,
      builder: (ctx, child) {
        // Aplicar color de marca al picker respetando el tema claro/oscuro.
        final base = Theme.of(ctx);
        return Theme(
          data: base.copyWith(
            colorScheme: base.colorScheme.copyWith(
              primary: AppColors.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null || !mounted) return;
    final formatted =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    if (isDesde) {
      widget.onDesde(formatted);
    } else {
      widget.onHasta(formatted);
    }
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _DateChip({
    required this.label,
    required this.value,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;
    return GestureDetector(
      onTap: onPick,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: hasValue
              ? context.colors.primarySurface
              : context.colors.backgroundAlt,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: hasValue
                ? context.colors.primaryBorder
                : context.colors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 14,
              color: hasValue ? AppColors.primary : context.colors.textTertiary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                hasValue ? _formatDisplay(value!) : label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: hasValue ? FontWeight.w600 : FontWeight.w500,
                  color: hasValue
                      ? AppColors.primary
                      : context.colors.textTertiary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasValue)
              GestureDetector(
                onTap: onClear,
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: context.colors.textTertiary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDisplay(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}

class _KpiRow extends StatelessWidget {
  final KardexResumen resumen;
  const _KpiRow({required this.resumen});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4),
    child: LayoutBuilder(
      builder: (_, constraints) => GridView.count(
        crossAxisCount: constraints.maxWidth >= 720 ? 4 : 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: constraints.maxWidth >= 720 ? 1.9 : 1.6,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _Chip('Total', '${resumen.totalMovimientos}', AppColors.primary),
          _Chip('Entradas', '${resumen.entradas}', AppColors.success),
          _Chip('Salidas', '${resumen.salidas}', AppColors.error),
          _Chip(
            'Valor total',
            'S/ ${resumen.valorTotal.toStringAsFixed(2)}',
            AppColors.warning,
          ),
        ],
      ),
    ),
  );
}

class _Chip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Chip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: color.withValues(alpha: 0.20)),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.labelSmall,
        ),
      ],
    ),
  );
}

class _MovTile extends StatelessWidget {
  final KardexMovimiento mov;
  const _MovTile({required this.mov});

  Color get _color {
    switch (mov.tipo) {
      case 'ENTRADA':
      case 'ENTRADA_ANULACION':
        return AppColors.success;
      case 'SALIDA':
      case 'SALIDA_VENTA':
        return AppColors.error;
      case 'AJUSTE':
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  IconData get _icon {
    switch (mov.tipo) {
      case 'ENTRADA':
      case 'ENTRADA_ANULACION':
        return Icons.arrow_downward_rounded;
      case 'SALIDA':
        return Icons.arrow_upward_rounded;
      case 'SALIDA_VENTA':
        return Icons.shopping_cart_outlined;
      case 'AJUSTE':
        return Icons.tune_rounded;
      default:
        return Icons.swap_horiz_rounded;
    }
  }

  bool get _isEntrada => kardexIsEntrada(mov.tipo);

  bool get _isSalida => kardexIsSalida(mov.tipo);

  String get _label => kardexTipoLabel(mov.tipo);

  String get _cantidad {
    final amount = mov.cantidad.abs().toStringAsFixed(
      mov.cantidad % 1 == 0 ? 0 : 1,
    );
    final sign = _isEntrada ? '+' : (_isSalida ? '-' : '');
    return '$sign$amount ${mov.unidad}';
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.colors.borderLight),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          // ─ Imagen del producto con indicador de tipo superpuesto
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              children: [
                DSProductImageSquare(
                  imageUrl: mov.imagenUrl,
                  size: 44,
                  radius: 10,
                  productName: mov.producto,
                ),
                // Indicador de tipo (entrada/salida/ajuste) en esquina inferior
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: _color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.colors.surface,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(_icon, color: Colors.white, size: 9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mov.producto,
                  style: AppTextStyles.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${mov.codigo} · ${mov.referencia}',
                  style: AppTextStyles.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${mov.fecha} ${mov.hora} · ${mov.usuario}',
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _color,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${mov.stockAnterior.toStringAsFixed(0)} → ${mov.stockNuevo.toStringAsFixed(0)}',
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary,
                ),
              ),
              Text(_cantidad, style: AppTextStyles.labelSmall),
              Text(
                'S/ ${mov.valor.toStringAsFixed(2)}',
                style: AppTextStyles.labelSmall.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
