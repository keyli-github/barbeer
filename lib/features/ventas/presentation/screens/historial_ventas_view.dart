import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/navigation/app_nav.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/widgets/ds_inputs.dart';
import '../../../../core/widgets/ds_product_image.dart';
import '../../../../core/widgets/ds_states.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/venta_models.dart';
import '../providers/ventas_provider.dart';
import 'conciliar_venta_screen.dart';
import 'venta_detail_screen.dart';

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

  // Subpantalla completa de detalle — usa rootNavigator para ocultar Shell
  void _openDetail(Venta v) =>
      AppNav.push(context, VentaDetailScreen(venta: v, onChanged: _refresh));

  // Conciliar también como subpantalla
  void _openConciliar(Venta v) =>
      AppNav.push(context, ConciliarVentaScreen(venta: v, onDone: _refresh));

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
                  child: Container(
                    color: AppColors.background,
                    child: ListView.separated(
                      padding: const EdgeInsets.only(bottom: 120),
                      itemCount:
                          ventas.length +
                          (state.totalPaginas > state.pagina ? 1 : 0),
                      separatorBuilder: (_, _) => const Divider(
                        height: 1,
                        indent: 71,
                        color: AppColors.borderLight,
                      ),
                      itemBuilder: (_, i) {
                        if (i == ventas.length) {
                          return _LoadMoreButton(
                            loading: state.loading,
                            onTap: state.loading
                                ? null
                                : () => ref
                                      .read(
                                        ventasListProvider(_useMis).notifier,
                                      )
                                      .loadMore(),
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

// ─── Venta card — compacta estilo iOS ────────────────────────────────────────

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
    final isAnulada = venta.isAnulada;
    final isPendiente = venta.isPendiente;
    final statusColor = isAnulada
        ? AppColors.error
        : isPendiente
        ? AppColors.warning
        : AppColors.success;

    DateTime? dt;
    try {
      dt = DateTime.parse(venta.createdAt);
    } catch (_) {}

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 10,
        ),
        child: Row(
          children: [
            // Barra de color
            Container(
              width: 3,
              height: 40,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Imagen miniatura
            DSProductImageSquare(
              imageUrl: null,
              productName: venta.items.isNotEmpty
                  ? venta.items.first.productoNombre
                  : null,
              size: 40,
              radius: 8,
            ),
            const SizedBox(width: AppSpacing.sm),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    venta.codigo,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (venta.vendedoraUsername != null)
                        venta.vendedoraUsername!,
                      if (dt != null) FormatUtils.timeAgo(dt),
                    ].join(' · '),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Precio + badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  FormatUtils.currency(venta.total),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isAnulada
                        ? 'ANULADA'
                        : isPendiente
                        ? 'PENDIENTE'
                        : 'ACTIVA',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
            // Clasificar o chevron
            if (onConciliar != null)
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onConciliar!();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Clasificar',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              )
            else
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textTertiary,
              ),
          ],
        ),
      ),
    );
  }
}

class _LoadMoreButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool loading;
  const _LoadMoreButton({required this.onTap, required this.loading});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: TextButton(
        onPressed: onTap,
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text(
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
