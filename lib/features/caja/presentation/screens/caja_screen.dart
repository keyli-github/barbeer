import 'package:flutter/material.dart';
import '../../../../core/widgets/app_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/app_nav.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/caja_repository.dart';
import '../providers/caja_provider.dart';
import '../widgets/caja_arqueo_sheets.dart';
import '../widgets/caja_resumen_v2.dart';

class CajaScreen extends ConsumerStatefulWidget {
  const CajaScreen({super.key});

  @override
  ConsumerState<CajaScreen> createState() => _CajaScreenState();
}

class _CajaScreenState extends ConsumerState<CajaScreen> {
  bool _historial = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cajaProvider);
    final auth = ref.watch(authProvider);

    // Selector de tabs en una barra debajo del header global
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Tabs: Turno actual / Historial
          _CajaTabs(
            historial: _historial,
            state: state,
            isSuperAdmin: auth.user?.isSuperAdmin ?? false,
            onTab: (v) => setState(() => _historial = v),
            onSede: (v) {
              if (v != null) ref.read(cajaProvider.notifier).seleccionarSede(v);
            },
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: state.isLoading
                  ? const _CajaSkeleton(key: ValueKey('loading'))
                  : state.error != null &&
                        state.actual == null &&
                        state.historial.isEmpty
                  ? AppErrorState(
                      key: const ValueKey('error'),
                      message: state.error!,
                      onRetry: ref.read(cajaProvider.notifier).load,
                    )
                  : _historial
                  ? _Historial(
                      key: const ValueKey('history'),
                      state: state,
                      onFilter: ref
                          .read(cajaProvider.notifier)
                          .filtrarHistorial,
                      onPage: ref
                          .read(cajaProvider.notifier)
                          .cambiarPaginaHistorial,
                      onDetail: (id) => _showDetail(context, id),
                    )
                  : _Actual(
                      key: const ValueKey('current'),
                      state: state,
                      canOpen: auth.hasPermission('caja:aperturar'),
                      canPrecuadre: auth.hasPermission('caja:precuadre'),
                      canClose: auth.hasPermission('caja:cerrar'),
                      canForzar: auth.hasPermission('caja:forzar-cierre'),
                      onOpen: () => _showOpening(context),
                      onPrecuadre: () => _showPrecuadre(context),
                      onClose: () => _showCierre(
                        context,
                        canForzar: auth.hasPermission('caja:forzar-cierre'),
                      ),
                      onMovementFilter: (tipo) {
                        if (state.actual != null) {
                          ref
                              .read(cajaProvider.notifier)
                              .filtrarMovimientos(state.actual!.id, tipo);
                        }
                      },
                      onMovementPage: (page) {
                        if (state.actual != null) {
                          ref
                              .read(cajaProvider.notifier)
                              .loadMovimientos(state.actual!.id, pagina: page);
                        }
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDetail(BuildContext context, String id) async {
    AppNav.push(
      context,
      _DetailSheet(future: ref.read(cajaProvider.notifier).detalle(id)),
    );
  }

  Future<void> _showOpening(BuildContext context) async {
    final saved = await AppNav.push<bool>(context, const _OpeningSheet());
    if (saved == true && mounted) _success('Caja abierta correctamente');
  }

  Future<void> _showPrecuadre(BuildContext context) async {
    showPrecuadreSheet(
      context,
      onSuccess: () => _success('Precuadre registrado'),
    );
  }

  Future<void> _showCierre(
    BuildContext context, {
    required bool canForzar,
  }) async {
    showCierreSheet(
      context,
      canForzar: canForzar,
      onSuccess: () => _success('Caja cerrada correctamente'),
    );
  }

  /// @deprecated Movimientos manuales prohibidos en V2.
  // Future<void> _showMovement(BuildContext context) async { ... }

  void _success(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

class _CajaTabs extends StatelessWidget {
  final bool historial;
  final CajaState state;
  final bool isSuperAdmin;
  final ValueChanged<bool> onTab;
  final ValueChanged<String?> onSede;

  const _CajaTabs({
    required this.historial,
    required this.state,
    required this.isSuperAdmin,
    required this.onTab,
    required this.onSede,
  });

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
    child: Column(
      children: [
        // Selector de sede solo para SuperAdmin
        if (isSuperAdmin && state.sedes.isNotEmpty) ...[
          DropdownButtonFormField<String>(
            value: state.sedeId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Sede',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: state.sedes
                .map(
                  (s) => DropdownMenuItem(
                    value: s['id'] as String,
                    child: Text(
                      s['nombre'] as String? ?? '',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: onSede,
          ),
          const SizedBox(height: 8),
        ],
        // Tabs: Turno actual / Historial
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.backgroundAlt,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              _Tab(
                label: 'Turno actual',
                selected: !historial,
                onTap: () => onTab(false),
              ),
              _Tab(
                label: 'Historial',
                selected: historial,
                onTap: () => onTab(true),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Tab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.labelLarge.copyWith(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    ),
  );
}

class _Actual extends StatelessWidget {
  final CajaState state;
  final bool canOpen;
  final bool canPrecuadre;
  final bool canClose;
  final bool canForzar;
  final VoidCallback onOpen;
  final VoidCallback onPrecuadre;
  final VoidCallback onClose;
  final ValueChanged<String?> onMovementFilter;
  final ValueChanged<int> onMovementPage;

  const _Actual({
    super.key,
    required this.state,
    required this.canOpen,
    required this.canPrecuadre,
    required this.canClose,
    this.canForzar = false,
    required this.onOpen,
    required this.onPrecuadre,
    required this.onClose,
    required this.onMovementFilter,
    required this.onMovementPage,
  });

  @override
  Widget build(BuildContext context) {
    final session = state.actual;
    if (session == null) {
      return AppEmptyState(
        icon: Icons.lock_clock_outlined,
        title: 'No hay una caja abierta',
        description: canOpen
            ? 'Registra el conteo de efectivo para iniciar el turno.'
            : 'Un usuario autorizado debe abrir la caja de esta sede.',
        actionLabel: canOpen ? 'Abrir caja' : null,
        onAction: canOpen ? onOpen : null,
      );
    }
    final summary =
        session.resumen ??
        CajaResumen(
          version: 'V2',
          v2: CajaResumenV2(
            totalVentasBruto: 0,
            totalAnulaciones: 0,
            totalVentasNeto: 0,
            totalDigitalBruto: 0,
            totalReversDigital: 0,
            totalDigitalNeto: 0,
            efectivoEsperado: session.montoApertura,
            ventasPendientes: 0,
            cantidadVentas: 0,
            cantidadAnuladas: 0,
          ),
        );
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
        children: [
          Row(
            children: [
              _StatusPill(label: session.estado, color: AppColors.success),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${session.sede} · ${_dateTime(session.abiertaAt)}',
                  style: AppTextStyles.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ── Resumen principal V2 ────────────────────────────────────
          if (summary.isV2 && summary.v2 != null) ...[
            CajaResumenPrincipalV2(
              resumen: summary.v2!,
              montoApertura: session.montoApertura,
            ),
            const SizedBox(height: 12),
            CajaBilleteraCard(porBilletera: summary.v2!.porBilletera),
            if (summary.v2!.porBilletera.isNotEmpty) const SizedBox(height: 12),
            CajaVendedoraTable(porVendedora: summary.v2!.porVendedora),
            if (summary.v2!.porVendedora.isNotEmpty) const SizedBox(height: 12),
            CajaProductosTable(resumenProductos: summary.v2!.resumenProductos),
          ] else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth - 10) / 2;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _Metric(
                      width: width,
                      label: 'Apertura',
                      value: session.montoApertura,
                      icon: Icons.play_circle_outline_rounded,
                      color: AppColors.textSecondary,
                    ),
                    _Metric(
                      width: width,
                      label: 'Ventas neto',
                      value: summary.v1?.totalEntradas ?? 0,
                      icon: Icons.south_west_rounded,
                      color: AppColors.success,
                    ),
                    _Metric(
                      width: width,
                      label: 'Salidas',
                      value: summary.v1?.totalSalidas ?? 0,
                      icon: Icons.north_east_rounded,
                      color: AppColors.primary,
                    ),
                    _Metric(
                      width: width,
                      label: 'Efectivo esperado',
                      value: summary.efectivoEsperado,
                      icon: Icons.account_balance_rounded,
                      color: AppColors.warning,
                    ),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              // Movimientos manuales eliminados por regla de negocio V2.
              // Las entradas se generan automáticamente desde ventas.
              // Las salidas digitales se generan desde conciliación.
              if (canPrecuadre)
                OutlinedButton.icon(
                  onPressed: state.isActing ? null : onPrecuadre,
                  icon: const Icon(Icons.fact_check_outlined, size: 18),
                  label: const Text('Precuadre'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    minimumSize: const Size(0, 44),
                  ),
                ),
              if (canClose)
                OutlinedButton.icon(
                  onPressed: state.isActing ? null : onClose,
                  icon: const Icon(Icons.lock_outline_rounded, size: 18),
                  label: const Text('Cerrar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    minimumSize: const Size(0, 44),
                  ),
                ),
            ],
          ),
          if (session.precuadreAt != null) ...[
            const SizedBox(height: 12),
            _PrecuadreBanner(session: session),
          ],
          const SizedBox(height: 22),
          Row(
            children: [
              const Expanded(
                child: Text('Movimientos', style: AppTextStyles.titleLarge),
              ),
              Text(
                '${state.movimientosTotal} registros',
                style: AppTextStyles.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _FilterRow(
            selected: state.tipoFiltro,
            values: const [null, 'ENTRADA', 'SALIDA'],
            labels: const ['Todos', 'Entradas', 'Salidas'],
            onChanged: onMovementFilter,
          ),
          const SizedBox(height: 10),
          if (state.movimientos.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: AppEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Sin movimientos',
                description: 'El turno aun no registra entradas ni salidas.',
              ),
            )
          else
            for (final movement in state.movimientos)
              _MovementTile(movement: movement),
          _Pager(
            page: state.movimientosPagina,
            pages: state.movimientosPaginas,
            total: state.movimientosTotal,
            onPage: onMovementPage,
          ),
        ],
      ),
    );
  }
}

class _Historial extends StatelessWidget {
  final CajaState state;
  final ValueChanged<String?> onFilter;
  final ValueChanged<int> onPage;
  final ValueChanged<String> onDetail;

  const _Historial({
    super.key,
    required this.state,
    required this.onFilter,
    required this.onPage,
    required this.onDetail,
  });

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
    children: [
      _FilterRow(
        selected: state.estadoFiltro,
        values: const [null, 'ABIERTA', 'CERRADA'],
        labels: const ['Todas', 'Abiertas', 'Cerradas'],
        onChanged: onFilter,
      ),
      const SizedBox(height: 12),
      if (state.historial.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 80),
          child: AppEmptyState(
            icon: Icons.history_rounded,
            title: 'Sin sesiones de caja',
            description: 'No hay resultados para el filtro seleccionado.',
          ),
        )
      else
        for (final session in state.historial)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              onTap: () => onDetail(session.id),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: session.estado == 'ABIERTA'
                          ? AppColors.successLight
                          : AppColors.backgroundAlt,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      session.estado == 'ABIERTA'
                          ? Icons.lock_open_rounded
                          : Icons.lock_rounded,
                      color: session.estado == 'ABIERTA'
                          ? AppColors.success
                          : AppColors.textSecondary,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(session.sede, style: AppTextStyles.titleMedium),
                        Text(
                          '${_dateTime(session.abiertaAt)} · ${session.usuarioApertura}',
                          style: AppTextStyles.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _StatusPill(
                        label: session.estado,
                        color: session.estado == 'ABIERTA'
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _money(
                          session.resumen?.efectivoEsperado ??
                              session.montoApertura,
                        ),
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      _Pager(
        page: state.historialPagina,
        pages: state.historialPaginas,
        total: state.historialTotal,
        onPage: onPage,
      ),
    ],
  );
}

class _OpeningSheet extends ConsumerStatefulWidget {
  const _OpeningSheet();

  @override
  ConsumerState<_OpeningSheet> createState() => _OpeningSheetState();
}

class _OpeningSheetState extends ConsumerState<_OpeningSheet> {
  late final Map<double, TextEditingController> _controllers = {
    for (final value in cajaDenominaciones) value: TextEditingController(),
  };
  bool _loading = false;

  double get _total => _controllers.entries.fold(
    0,
    (sum, entry) => sum + entry.key * (int.tryParse(entry.value.text) ?? 0),
  );

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: SubPageAppBar(
      title: 'Apertura de caja',
      subtitle: 'Conteo obligatorio de las 10 denominaciones PEN',
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          GridView.count(
            crossAxisCount: MediaQuery.sizeOf(context).width > 520 ? 3 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.5,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              for (final value in cajaDenominaciones)
                TextFormField(
                  controller: _controllers[value],
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'S/ ${_denomination(value)}',
                    hintText: '0',
                    prefixIcon: const Icon(Icons.payments_outlined, size: 18),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _TotalBand(label: 'Total de apertura', value: _total),
          const SizedBox(height: 18),
          PrimaryButton(
            label: 'Abrir caja',
            icon: Icons.lock_open_rounded,
            isLoading: _loading,
            onPressed: _submit,
          ),
        ],
      ),
    ),
  );

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await ref.read(cajaProvider.notifier).abrir({
        for (final entry in _controllers.entries)
          entry.key: int.tryParse(entry.value.text) ?? 0,
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) _sheetError(context, error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// === MOVIMIENTOS MANUALES ELIMINADOS ===
// Las entradas y salidas se generan automaticamente desde ventas y conciliacion.
// _MovementOption, _MovementSheet y _ArqueoSheet removidos por regla de negocio V2.
// Los sheets de arqueo están en widgets/caja_arqueo_sheets.dart.

class _DetailSheet extends StatelessWidget {
  final Future<CajaSesion> future;

  const _DetailSheet({required this.future});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: SubPageAppBar(
      title: 'Detalle de caja',
      subtitle: 'Resumen y arqueos registrados por el servidor',
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: FutureBuilder<CajaSesion>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _InlineSkeleton();
          }
          if (snapshot.hasError) {
            return AppErrorState(message: snapshot.error.toString());
          }
          final session = snapshot.data!;
          final values = <String, String>{
            'Sede': session.sede,
            'Estado': session.estado,
            'Apertura': _money(session.montoApertura),
            'Abierta por': session.usuarioApertura,
            'Fecha de apertura': _dateTime(session.abiertaAt),
            if (session.resumen != null)
              'Saldo esperado': _money(session.resumen!.efectivoEsperado),
            if (session.montoDeclaradoPrecuadre != null)
              'Precuadre declarado': _money(session.montoDeclaradoPrecuadre!),
            if (session.diferenciaPrecuadre != null)
              'Diferencia precuadre': _money(session.diferenciaPrecuadre!),
            if (session.montoDeclaradoCierre != null)
              'Cierre declarado': _money(session.montoDeclaradoCierre!),
            if (session.diferenciaCierre != null)
              'Diferencia cierre': _money(session.diferenciaCierre!),
            if (session.cerradaAt != null)
              'Fecha de cierre': _dateTime(session.cerradaAt!),
            if (session.observacionesCierre?.isNotEmpty ?? false)
              'Observaciones': session.observacionesCierre!,
          };
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final entry in values.entries) ...[
                _DetailRow(label: entry.key, value: entry.value),
                const Divider(height: 18),
              ],
              const SizedBox(height: 8),
              const Text(
                'Conteo de apertura',
                style: AppTextStyles.titleMedium,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: session.denominaciones
                    .map(
                      (item) => _ReadOnlyChip(
                        label:
                            'S/ ${_denomination((item['denominacion'] as num).toDouble())} × ${item['cantidad']}',
                      ),
                    )
                    .toList(),
              ),
              if (session.resumen?.v2?.porBilletera.isNotEmpty ?? false) ...[
                const SizedBox(height: 16),
                CajaBilleteraCard(
                  porBilletera: session.resumen!.v2!.porBilletera,
                ),
              ],
              if (session.resumen?.v2?.porVendedora.isNotEmpty ?? false) ...[
                const SizedBox(height: 16),
                CajaVendedoraTable(
                  porVendedora: session.resumen!.v2!.porVendedora,
                ),
              ],
              if (session.resumen?.v2?.resumenProductos.isNotEmpty ??
                  false) ...[
                const SizedBox(height: 16),
                CajaProductosTable(
                  resumenProductos: session.resumen!.v2!.resumenProductos,
                ),
              ],
            ],
          );
        },
      ),
    ),
  );
}

class _SheetFrame extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SheetFrame({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.9,
    ),
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    decoration: const BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 4,
          margin: const EdgeInsets.only(top: 10),
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 10, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.headlineMedium),
                    const SizedBox(height: 3),
                    Text(subtitle, style: AppTextStyles.labelSmall),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  final double width;
  final String label;
  final double value;
  final IconData icon;
  final Color color;

  const _Metric({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 7),
              Expanded(child: Text(label, style: AppTextStyles.labelSmall)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _money(value),
            style: AppTextStyles.titleLarge.copyWith(color: color),
          ),
        ],
      ),
    ),
  );
}

class _MovementTile extends StatelessWidget {
  final CajaMovimiento movement;

  const _MovementTile({required this.movement});

  @override
  Widget build(BuildContext context) {
    final incoming = movement.tipo == 'ENTRADA';
    final color = incoming ? AppColors.success : AppColors.error;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: AppCard(
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                incoming ? Icons.south_west_rounded : Icons.north_east_rounded,
                color: color,
                size: 18,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movement.concepto,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${movement.medioPago} · ${movement.origen} · ${_dateTime(movement.createdAt)}',
                    style: AppTextStyles.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${incoming ? '+' : '-'} ${_money(movement.monto)}',
              style: AppTextStyles.labelLarge.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final String? selected;
  final List<String?> values;
  final List<String> labels;
  final ValueChanged<String?> onChanged;

  const _FilterRow({
    required this.selected,
    required this.values,
    required this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: List.generate(values.length, (index) {
        final active = selected == values[index];
        return Padding(
          padding: const EdgeInsets.only(right: 7),
          child: ChoiceChip(
            selected: active,
            label: Text(labels[index]),
            onSelected: (_) => onChanged(values[index]),
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            selectedColor: AppColors.primarySurface,
            side: BorderSide(
              color: active ? AppColors.primaryBorder : AppColors.border,
            ),
            labelStyle: AppTextStyles.labelSmall.copyWith(
              color: active ? AppColors.primary : AppColors.textSecondary,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        );
      }),
    ),
  );
}

class _Pager extends StatelessWidget {
  final int page;
  final int pages;
  final int total;
  final ValueChanged<int> onPage;

  const _Pager({
    required this.page,
    required this.pages,
    required this.total,
    required this.onPage,
  });

  @override
  Widget build(BuildContext context) {
    if (pages <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Text('$total registros', style: AppTextStyles.labelSmall),
          const Spacer(),
          IconButton.outlined(
            visualDensity: VisualDensity.compact,
            onPressed: page > 1 ? () => onPage(page - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('$page / $pages', style: AppTextStyles.labelLarge),
          ),
          IconButton.outlined(
            visualDensity: VisualDensity.compact,
            onPressed: page < pages ? () => onPage(page + 1) : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _PrecuadreBanner extends StatelessWidget {
  final CajaSesion session;

  const _PrecuadreBanner({required this.session});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.warningLight,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.warning.withValues(alpha: 0.28)),
    ),
    child: Row(
      children: [
        const Icon(Icons.fact_check_outlined, color: AppColors.warning),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Precuadre ${_money(session.montoDeclaradoPrecuadre ?? 0)} · diferencia ${_money(session.diferenciaPrecuadre ?? 0)}',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    ),
  );
}

class _TotalBand extends StatelessWidget {
  final String label;
  final double value;

  const _TotalBand({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.primarySurface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.primaryBorder),
    ),
    child: Row(
      children: [
        Text(label, style: AppTextStyles.bodyMedium),
        const Spacer(),
        Text(
          _money(value),
          style: AppTextStyles.titleLarge.copyWith(color: AppColors.primary),
        ),
      ],
    ),
  );
}

class _ReadOnlyChip extends StatelessWidget {
  final String label;

  const _ReadOnlyChip({required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
    decoration: BoxDecoration(
      color: AppColors.backgroundAlt,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.border),
    ),
    child: Text(
      label.replaceAll('_', ' '),
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.labelSmall.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(100),
    ),
    child: Text(
      label,
      style: AppTextStyles.labelSmall.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: Text(label, style: AppTextStyles.labelSmall)),
      Expanded(
        flex: 2,
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

class _CajaSkeleton extends StatelessWidget {
  const _CajaSkeleton({super.key});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: const [
      Row(
        children: [
          Expanded(child: _SkeletonBox(height: 96)),
          SizedBox(width: 10),
          Expanded(child: _SkeletonBox(height: 96)),
        ],
      ),
      SizedBox(height: 10),
      Row(
        children: [
          Expanded(child: _SkeletonBox(height: 96)),
          SizedBox(width: 10),
          Expanded(child: _SkeletonBox(height: 96)),
        ],
      ),
      SizedBox(height: 24),
      _SkeletonBox(height: 64),
      SizedBox(height: 8),
      _SkeletonBox(height: 64),
      SizedBox(height: 8),
      _SkeletonBox(height: 64),
    ],
  );
}

class _InlineSkeleton extends StatelessWidget {
  const _InlineSkeleton();

  @override
  Widget build(BuildContext context) => const Column(
    children: [
      _SkeletonBox(height: 48),
      SizedBox(height: 10),
      _SkeletonBox(height: 48),
      SizedBox(height: 10),
      _SkeletonBox(height: 48),
    ],
  );
}

class _SkeletonBox extends StatelessWidget {
  final double height;

  const _SkeletonBox({required this.height});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0.35, end: 0.8),
    duration: const Duration(milliseconds: 800),
    builder: (_, opacity, _) => Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.border.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),
  );
}

void _sheetError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(error.toString()),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

String _money(double value) => 'S/ ${value.toStringAsFixed(2)}';

String _denomination(double value) =>
    value >= 1 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);

String _dateTime(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
