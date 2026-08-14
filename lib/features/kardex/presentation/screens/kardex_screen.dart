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

    return Scaffold(
      backgroundColor: context.colors.background,
      body: Column(
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
                      icon: Icons.swap_vert_outlined,
                      title: 'Sin movimientos',
                      description:
                          'No hay movimientos con los filtros actuales.',
                    )
                  : ListView.builder(
                      key: const ValueKey('list'),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
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
                        return _MovTile(mov: state.items[i]);
                      },
                    ),
            ),
          ),
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
    return Container(
      color: context.colors.background,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
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
                              ? context.colors.primarySurface
                              : context.colors.backgroundAlt,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          border: Border.all(
                            color: widget.tipoFilter == t.$1
                                ? context.colors.primaryBorder
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
          // ── Date range filters ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
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
      ),
    );
  }

  Future<void> _pickDate(BuildContext context, {required bool isDesde}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: now,
      locale: const Locale('es', 'PE'),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(
            ctx,
          ).colorScheme.copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
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
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Row(
      children: [
        _Chip('Total', '${resumen.totalMovimientos}', AppColors.primary),
        const SizedBox(width: 8),
        _Chip('Entradas', '${resumen.entradas}', AppColors.success),
        const SizedBox(width: 8),
        _Chip('Salidas', '${resumen.salidas}', AppColors.error),
      ],
    ),
  );
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
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_icon, color: _color, size: 20),
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
                ),
                Text(
                  '${mov.fecha} ${mov.hora} · ${mov.usuario}',
                  style: AppTextStyles.labelSmall,
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
                  color: _color.withOpacity(0.12),
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
            ],
          ),
        ],
      ),
    ),
  );
}
