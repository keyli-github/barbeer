import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/widgets/ds_card.dart';
import '../../../../core/widgets/ds_inputs.dart';
import '../../../../core/widgets/ds_list_tile.dart';
import '../../../../core/widgets/ds_states.dart';
import '../../../../core/widgets/ds_product_image.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/venta_models.dart';
import '../providers/ventas_provider.dart';
import 'conciliar_venta_sheet.dart';
import 'venta_detail_sheet.dart';

class HistorialVentasView extends ConsumerStatefulWidget {
  const HistorialVentasView({super.key});
  @override
  ConsumerState<HistorialVentasView> createState() => _HistorialState();
}

class _HistorialState extends ConsumerState<HistorialVentasView> {
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final useMis = !canReadAllVentas(ref.read(authProvider));
      ref.read(ventasListProvider(useMis).notifier).load();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool get _useMis => !canReadAllVentas(ref.read(authProvider));
  Future<void> _refresh() =>
      ref.read(ventasListProvider(_useMis).notifier).refresh();

  void _openDetail(Venta v) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => VentaDetailSheet(venta: v, onChanged: _refresh),
  );

  void _openConciliar(Venta v) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ConciliarVentaSheet(venta: v, onDone: _refresh),
  );

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final state = ref.watch(ventasListProvider(_useMis));
    final canConciliarV = canConciliar(auth);
    final canAnularV = canAnularVenta(auth);

    // Filtro local de búsqueda
    final ventas = state.ventas.where((v) {
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      return v.codigo.toLowerCase().contains(q) ||
          (v.vendedoraUsername?.toLowerCase().contains(q) ?? false);
    }).toList();

    return Column(
      children: [
        // ── Buscador + filtros ──────────────────────────────────────────
        _FiltersBar(
          ctrl: _searchCtrl,
          currentFilter: state.filterEstado,
          onSearch: (v) => setState(() => _search = v),
          onFilter: (e) =>
              ref.read(ventasListProvider(_useMis).notifier).load(estado: e),
          total: state.total,
        ),

        // ── KPIs compactos (solo si hay datos) ──────────────────────────
        if (ventas.isNotEmpty) _KpiRow(ventas: ventas),

        // ── Lista ───────────────────────────────────────────────────────
        Expanded(
          child: state.loading && state.ventas.isEmpty
              ? const DSSkeletonList(count: 6)
              : state.error != null && state.ventas.isEmpty
              ? DSErrorState(message: state.error, onRetry: _refresh)
              : ventas.isEmpty
              ? DSEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: _search.isNotEmpty ? 'Sin resultados' : 'Sin ventas',
                  message: _search.isNotEmpty
                      ? 'No hay ventas que coincidan con "$_search"'
                      : 'No hay ventas registradas aún.',
                  actionLabel: 'Actualizar',
                  onAction: _refresh,
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _refresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      120,
                    ),
                    itemCount:
                        ventas.length +
                        (state.totalPaginas > state.pagina ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == ventas.length) {
                        return _LoadMoreButton(
                          onTap: () => ref
                              .read(ventasListProvider(_useMis).notifier)
                              .load(pagina: state.pagina + 1),
                        );
                      }
                      return _VentaCard(
                        venta: ventas[i],
                        canConciliar: canConciliarV,
                        canAnular: canAnularV,
                        onTap: () => _openDetail(ventas[i]),
                        onConciliar: canConciliarV && ventas[i].isPendiente
                            ? () => _openConciliar(ventas[i])
                            : null,
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

// ─── Filters bar ─────────────────────────────────────────────────────────────

class _FiltersBar extends StatelessWidget {
  final TextEditingController ctrl;
  final String? currentFilter;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onFilter;
  final int total;

  const _FiltersBar({
    required this.ctrl,
    required this.currentFilter,
    required this.onSearch,
    required this.onFilter,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DSSearchField(
            controller: ctrl,
            placeholder: 'Buscar por código o vendedora...',
            onChanged: onSearch,
          ),
          const SizedBox(height: AppSpacing.xs),
          DSFilterBar(
            children: [
              DSFilterChip(
                label: 'Todas',
                count: total,
                selected: currentFilter == null,
                onTap: () => onFilter(null),
              ),
              DSFilterChip(
                label: 'ACTIVA',
                selected: currentFilter == 'ACTIVA',
                onTap: () =>
                    onFilter(currentFilter == 'ACTIVA' ? null : 'ACTIVA'),
                selectedColor: AppColors.success,
              ),
              DSFilterChip(
                label: 'PENDIENTE',
                selected: currentFilter == 'PENDIENTE',
                onTap: () =>
                    onFilter(currentFilter == 'PENDIENTE' ? null : 'PENDIENTE'),
                selectedColor: AppColors.warning,
              ),
              DSFilterChip(
                label: 'ANULADA',
                selected: currentFilter == 'ANULADA',
                onTap: () =>
                    onFilter(currentFilter == 'ANULADA' ? null : 'ANULADA'),
                selectedColor: AppColors.error,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── KPI row ─────────────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  final List<Venta> ventas;
  const _KpiRow({required this.ventas});

  @override
  Widget build(BuildContext context) {
    final total = ventas.fold(0.0, (s, v) => s + v.total);
    final activas = ventas.where((v) => !v.isAnulada).length;
    final pendientes = ventas.where((v) => v.isPendiente).length;

    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          _Kpi('Total', FormatUtils.currency(total), AppColors.primary),
          _KpiDiv(),
          _Kpi('Activas', '$activas', AppColors.success),
          _KpiDiv(),
          _Kpi('Pendientes', '$pendientes', AppColors.warning),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Kpi(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Expanded(
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
          style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
        ),
      ],
    ),
  );
}

class _KpiDiv extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 28, color: AppColors.border);
}

// ─── Venta card ───────────────────────────────────────────────────────────────

class _VentaCard extends StatelessWidget {
  final Venta venta;
  final bool canConciliar, canAnular;
  final VoidCallback onTap;
  final VoidCallback? onConciliar;

  const _VentaCard({
    required this.venta,
    required this.canConciliar,
    required this.canAnular,
    required this.onTap,
    this.onConciliar,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = venta.isAnulada
        ? AppColors.error
        : venta.isPendiente
        ? AppColors.warning
        : AppColors.success;
    final statusLabel = venta.isAnulada
        ? 'ANULADA'
        : venta.isPendiente
        ? 'PENDIENTE'
        : 'ACTIVA';

    DateTime? dt;
    try {
      dt = DateTime.parse(venta.createdAt);
    } catch (_) {}

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: DSCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Miniaturas de productos
                if (venta.items.isNotEmpty)
                  SizedBox(
                    height: 36,
                    child: Stack(
                      children: venta.items
                          .take(3)
                          .toList()
                          .asMap()
                          .entries
                          .map((e) {
                            return Positioned(
                              left: e.key * 24.0,
                              child: DSProductImageSquare(
                                imageUrl: null,
                                productName: e.value.productoNombre,
                                size: 36,
                                radius: 8,
                              ),
                            );
                          })
                          .toList(),
                    ),
                  ),
                SizedBox(
                  width: venta.items.isNotEmpty
                      ? AppSpacing.sm + venta.items.take(3).length * 24.0 - 24
                      : 0,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        venta.codigo,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (venta.vendedoraUsername != null)
                        Text(
                          venta.vendedoraUsername!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      FormatUtils.currency(venta.total),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    DSStatusBadge(label: statusLabel, color: statusColor),
                  ],
                ),
              ],
            ),
            if (dt != null || onConciliar != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  if (dt != null)
                    Text(
                      FormatUtils.dateTime(dt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  const Spacer(),
                  if (onConciliar != null)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onConciliar!();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Clasificar',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
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

class _LoadMoreButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LoadMoreButton({required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
    child: Center(
      child: TextButton(
        onPressed: onTap,
        child: const Text(
          'Cargar más',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ),
    ),
  );
}
