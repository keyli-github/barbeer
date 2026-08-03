import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_ui_components.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
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
  }) =>
      _KardexState(
        items: items ?? this.items,
        resumen: resumen ?? this.resumen,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        page: page ?? this.page,
        totalPages: totalPages ?? this.totalPages,
        total: total ?? this.total,
        search: search ?? this.search,
        tipoFilter: tipoFilter ?? this.tipoFilter,
      );
}

class _KardexNotifier extends StateNotifier<_KardexState> {
  final KardexRepository _repo;

  _KardexNotifier(this._repo) : super(const _KardexState()) {
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
        ),
        _repo.resumen(
          tipo: state.tipoFilter.isEmpty ? null : state.tipoFilter,
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

  void setSearch(String s) { state = state.copyWith(search: s); load(resetPage: true); }
  void setTipo(String t) { state = state.copyWith(tipoFilter: t); load(resetPage: true); }
  void setPage(int p) { state = state.copyWith(page: p); load(); }
}

final _kardexProvider = StateNotifierProvider<_KardexNotifier, _KardexState>(
  (ref) => _KardexNotifier(ref.watch(_kardexRepoProvider)),
);

// ─── Screen ───────────────────────────────────────────────────────────────────

class KardexScreen extends ConsumerWidget {
  const KardexScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_kardexProvider);
    final notifier = ref.read(_kardexProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.backgroundAlt,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(total: state.total, onSearch: notifier.setSearch, tipoFilter: state.tipoFilter, onTipo: notifier.setTipo),
            if (state.resumen != null && !state.loading) _KpiRow(resumen: state.resumen!),
            const SizedBox(height: 4),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: state.loading
                    ? const AppLoading(key: ValueKey('l'))
                    : state.error != null
                        ? AppErrorState(key: const ValueKey('e'), message: state.error!, onRetry: () => notifier.load())
                        : state.items.isEmpty
                            ? const AppEmptyState(key: ValueKey('empty'), icon: Icons.swap_vert_outlined, title: 'Sin movimientos', description: 'No hay movimientos con los filtros actuales.')
                            : ListView.builder(
                                key: const ValueKey('list'),
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                                itemCount: state.items.length + 1,
                                itemBuilder: (_, i) {
                                  if (i == state.items.length) {
                                    return AppPagination(page: state.page, totalPages: state.totalPages, total: state.total, onPageChange: notifier.setPage);
                                  }
                                  return _MovTile(mov: state.items[i]);
                                },
                              ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatefulWidget {
  final int total;
  final ValueChanged<String> onSearch, onTipo;
  final String tipoFilter;
  const _Header({required this.total, required this.onSearch, required this.tipoFilter, required this.onTipo});

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  final _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: Row(children: [
          const Icon(Icons.swap_vert_rounded, color: AppColors.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Kardex', style: AppTextStyles.headlineLarge),
            Text('${widget.total} movimientos', style: AppTextStyles.labelSmall),
          ])),
        ])),
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: TextField(
          controller: _ctrl, onChanged: widget.onSearch, style: AppTextStyles.bodyMedium,
          decoration: const InputDecoration(hintText: 'Buscar producto...', prefixIcon: Icon(Icons.search_rounded, color: AppColors.textTertiary, size: 18), contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
        )),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(children: [
            for (final t in [('', 'Todos'), ('ENTRADA', 'ENTRADA'), ('SALIDA', 'SALIDA'), ('AJUSTE', 'AJUSTE'), ('TRASLADO', 'TRASLADO')])
              Padding(padding: const EdgeInsets.only(right: 8), child: GestureDetector(
                onTap: () => widget.onTipo(t.$1),
                child: AnimatedContainer(duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: widget.tipoFilter == t.$1 ? AppColors.primarySurface : AppColors.backgroundAlt,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(color: widget.tipoFilter == t.$1 ? AppColors.primaryBorder : AppColors.border),
                  ),
                  child: Text(t.$2, style: TextStyle(fontSize: 12,
                    fontWeight: widget.tipoFilter == t.$1 ? FontWeight.w700 : FontWeight.w500,
                    color: widget.tipoFilter == t.$1 ? AppColors.primary : AppColors.textSecondary))),
              )),
          ]),
        ),
      ]),
    );
  }
}

class _KpiRow extends StatelessWidget {
  final KardexResumen resumen;
  const _KpiRow({required this.resumen});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Row(children: [
      _Chip('Total', '${resumen.totalMovimientos}', AppColors.primary),
      const SizedBox(width: 8),
      _Chip('Entradas', '${resumen.entradas}', AppColors.success),
      const SizedBox(width: 8),
      _Chip('Salidas', '${resumen.salidas}', AppColors.error),
    ]),
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
      decoration: BoxDecoration(color: color.withOpacity(0.09), borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
        Text(label, style: AppTextStyles.labelSmall),
      ]),
    ),
  );
}

class _MovTile extends StatelessWidget {
  final KardexMovimiento mov;
  const _MovTile({required this.mov});

  Color get _color {
    switch (mov.tipo) {
      case 'ENTRADA': return AppColors.success;
      case 'SALIDA': return AppColors.error;
      case 'AJUSTE': return AppColors.warning;
      default: return AppColors.primary;
    }
  }

  IconData get _icon {
    switch (mov.tipo) {
      case 'ENTRADA': return Icons.arrow_downward_rounded;
      case 'SALIDA': return Icons.arrow_upward_rounded;
      case 'AJUSTE': return Icons.tune_rounded;
      default: return Icons.swap_horiz_rounded;
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: AppShadows.card,
      ),
      child: Row(children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(color: _color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(_icon, color: _color, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(mov.producto, style: AppTextStyles.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text('${mov.codigo} · ${mov.referencia}', style: AppTextStyles.labelSmall),
          Text('${mov.fecha} ${mov.hora} · ${mov.usuario}', style: AppTextStyles.labelSmall),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(color: _color.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
            child: Text(mov.tipo, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _color))),
          const SizedBox(height: 4),
          Text('${mov.stockAnterior.toStringAsFixed(0)} → ${mov.stockNuevo.toStringAsFixed(0)}',
            style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          Text('×${mov.cantidad.toStringAsFixed(mov.cantidad % 1 == 0 ? 0 : 1)} ${mov.unidad}', style: AppTextStyles.labelSmall),
        ]),
      ]),
    ),
  );
}
