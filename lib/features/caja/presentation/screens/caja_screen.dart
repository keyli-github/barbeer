import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/app_nav.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_text_field.dart';
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
      backgroundColor: context.colors.background,
      body: Column(
        children: [
          // Tabs: Turno actual / Historial
          _CajaTabs(
            historial: _historial,
            state: state,
            onTab: (v) => setState(() => _historial = v),
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
                      canOpen:
                          auth.hasPermission('caja:aperturar') &&
                          state.sedeId != null,
                      canPrecuadre: auth.hasPermission('caja:precuadre'),
                      canClose: auth.hasPermission('caja:cerrar'),
                      canMove: auth.hasPermission('caja:movimientos'),
                      hasSedeScope: state.sedeId != null,
                      userId: auth.user?.id ?? '',
                      username: auth.user?.username ?? '',
                      isSuperAdmin: auth.user?.isSuperAdmin ?? false,
                      onOpen: () => _showOpening(context),
                      onPrecuadre: () => _showPrecuadre(context),
                      onClose: () => _showCierre(
                        context,
                        canForzar: auth.hasPermission('caja:forzar-cierre'),
                      ),
                      onMove: (tipo) => _showMovement(context, tipo),
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
                      onRefresh: ref.read(cajaProvider.notifier).load,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDetail(BuildContext context, String id) async {
    final auth = ref.read(authProvider);
    final canReopen =
        auth.hasPermission('caja:cerrar') &&
        (auth.user?.isSuperAdmin == true || auth.user?.rol == 'CAJERO');
    AppNav.push(
      context,
      _DetailSheet(
        future: ref.read(cajaProvider.notifier).detalle(id),
        canReopen: canReopen,
        onReopen: () => ref.read(cajaProvider.notifier).reaperturar(id),
      ),
    );
  }

  Future<void> _showOpening(BuildContext context) async {
    final saved = await AppNav.push<bool>(
      context,
      _OpeningSheet(initialCounts: ref.read(cajaProvider).aperturaSugerida),
    );
    if (saved == true && mounted) _success('Caja abierta correctamente');
  }

  Future<void> _showPrecuadre(BuildContext context) async {
    final state = ref.read(cajaProvider);
    final precuadre = cajaCantidadesFromResponse(
      state.actual?.denominacionesPrecuadre,
    );
    showPrecuadreSheet(
      context,
      initialCounts: precuadre.isEmpty ? state.aperturaSugerida : precuadre,
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
      initialCounts: cajaCantidadesFromResponse(
        ref.read(cajaProvider).actual?.denominacionesPrecuadre,
      ),
      onSuccess: () => _success('Caja cerrada correctamente'),
    );
  }

  Future<void> _showMovement(BuildContext context, String tipo) async {
    final saved = await AppNav.push<bool>(context, _MovementSheet(tipo: tipo));
    if (saved == true && mounted) {
      _success(tipo == 'ENTRADA' ? 'Entrada registrada' : 'Salida registrada');
    }
  }

  void _success(String message) {
    AppFeedback.success(context, message);
  }
}

class _CajaTabs extends StatelessWidget {
  final bool historial;
  final CajaState state;
  final ValueChanged<bool> onTab;

  const _CajaTabs({
    required this.historial,
    required this.state,
    required this.onTab,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
    child: Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.colors.backgroundAlt,
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
            color: selected ? Colors.white : context.colors.textSecondary,
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
  final bool canMove;
  final bool hasSedeScope;
  final String userId;
  final String username;
  final bool isSuperAdmin;
  final VoidCallback onOpen;
  final VoidCallback onPrecuadre;
  final VoidCallback onClose;
  final ValueChanged<String> onMove;
  final ValueChanged<String?> onMovementFilter;
  final ValueChanged<int> onMovementPage;
  final Future<void> Function() onRefresh;

  const _Actual({
    super.key,
    required this.state,
    required this.canOpen,
    required this.canPrecuadre,
    required this.canClose,
    this.canMove = false,
    required this.hasSedeScope,
    required this.userId,
    required this.username,
    required this.isSuperAdmin,
    required this.onOpen,
    required this.onPrecuadre,
    required this.onClose,
    required this.onMove,
    required this.onMovementFilter,
    required this.onMovementPage,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final session = state.actual;
    if (session == null) {
      return AppEmptyState(
        icon: Icons.lock_clock_outlined,
        title: 'No hay una caja abierta',
        description: !hasSedeScope
            ? 'Selecciona una sede en el encabezado para consultar o abrir su caja.'
            : canOpen
            ? 'Registra el conteo de efectivo para iniciar el turno.'
            : 'Un usuario autorizado debe abrir la caja de esta sede.',
        actionLabel: canOpen ? 'Abrir caja' : null,
        onAction: canOpen ? onOpen : null,
      );
    }
    final canInteract =
        isSuperAdmin || session.isOwnedBy(userId: userId, username: username);
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
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
        children: [
          Row(
            children: [
              _StatusPill(label: session.estado, color: AppColors.success),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${session.sede} · ${_dateTime(session.abiertaAt)} · ${session.usuarioAperturaLabel}',
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
                      color: context.colors.textSecondary,
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
          if (!canInteract) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.warningLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                session.usuarioApertura.isEmpty
                    ? 'No se pudo verificar quién abrió esta caja. Solo SUPERADMIN puede intervenir.'
                    : 'Caja abierta por ${session.usuarioAperturaLabel}. Solo ese usuario o SUPERADMIN puede operar el turno.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.warning,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (canMove && canInteract)
                OutlinedButton.icon(
                  onPressed: state.isActing ? null : () => onMove('ENTRADA'),
                  icon: const Icon(Icons.south_west_rounded, size: 18),
                  label: const Text('Entrada'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    minimumSize: const Size(0, 44),
                  ),
                ),
              if (canMove && canInteract)
                OutlinedButton.icon(
                  onPressed: state.isActing ? null : () => onMove('SALIDA'),
                  icon: const Icon(Icons.north_east_rounded, size: 18),
                  label: const Text('Salida'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    minimumSize: const Size(0, 44),
                  ),
                ),
              if (canPrecuadre && canInteract)
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
              if (canClose && canInteract)
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
                          ? context.colors.successLight
                          : context.colors.backgroundAlt,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      session.estado == 'ABIERTA'
                          ? Icons.lock_open_rounded
                          : Icons.lock_rounded,
                      color: session.estado == 'ABIERTA'
                          ? AppColors.success
                          : context.colors.textSecondary,
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
                          '${_dateTime(session.abiertaAt)} · ${session.usuarioAperturaLabel}',
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
                            : context.colors.textSecondary,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _money(
                          session.saldoActual ??
                              session.resumen?.efectivoEsperado ??
                              session.montoApertura,
                        ),
                        style: AppTextStyles.labelLarge.copyWith(
                          color: context.colors.textPrimary,
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
  final Map<double, int> initialCounts;

  const _OpeningSheet({required this.initialCounts});

  @override
  ConsumerState<_OpeningSheet> createState() => _OpeningSheetState();
}

class _OpeningSheetState extends ConsumerState<_OpeningSheet> {
  late final Map<double, TextEditingController> _controllers;
  bool _loading = false;

  double get _total => _controllers.entries.fold(
    0,
    (sum, entry) => sum + entry.key * (int.tryParse(entry.value.text) ?? 0),
  );

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final value in cajaDenominaciones)
        value: TextEditingController(
          text: widget.initialCounts.containsKey(value)
              ? widget.initialCounts[value].toString()
              : '',
        ),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.colors.surface,
    appBar: SubPageAppBar(
      title: 'Apertura de caja',
      subtitle: widget.initialCounts.isEmpty
          ? 'Conteo obligatorio de las 11 denominaciones PEN'
          : 'Prefill del último cierre; verifica el efectivo físico',
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          GridView.count(
            crossAxisCount: MediaQuery.sizeOf(context).width > 520 ? 3 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio:
                MediaQuery.sizeOf(context).width < 380 ? 1.9 : 2.5,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              for (final value in cajaDenominaciones)
                TextFormField(
                  key: ValueKey('apertura-denominacion-$value'),
                  controller: _controllers[value],
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 6,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'S/ ${_denomination(value)}',
                    hintText: '0',
                    counterText: '',
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

class _MovementSheet extends ConsumerStatefulWidget {
  final String tipo;

  const _MovementSheet({required this.tipo});

  @override
  ConsumerState<_MovementSheet> createState() => _MovementSheetState();
}

class _MovementSheetState extends ConsumerState<_MovementSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _conceptController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _conceptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entrada = widget.tipo == 'ENTRADA';
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: SubPageAppBar(
        title: entrada ? 'Nueva entrada' : 'Nueva salida',
        subtitle: 'Movimiento manual de efectivo',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              AppTextField(
                label: 'Monto (S/)',
                hint: '0.00',
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (text) {
                  final value = double.tryParse(text ?? '');
                  if (value == null || value <= 0 || value > 999999999.99) {
                    return 'Ingresa un monto válido mayor a 0';
                  }
                  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text!)) {
                    return 'Usa como máximo 2 decimales';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Concepto / motivo',
                hint: entrada
                    ? 'Ej. Cambio para vuelto'
                    : 'Ej. Pago a proveedor',
                controller: _conceptController,
                maxLength: 160,
                textCapitalization: TextCapitalization.sentences,
                validator: (text) => (text?.trim().isEmpty ?? true)
                    ? 'Ingresa un concepto'
                    : null,
              ),
              const SizedBox(height: 20),
              AppButton(
                label: entrada ? 'Registrar entrada' : 'Registrar salida',
                icon: entrada
                    ? Icons.south_west_rounded
                    : Icons.north_east_rounded,
                isFullWidth: true,
                isLoading: _loading,
                variant: entrada
                    ? AppButtonVariant.primary
                    : AppButtonVariant.danger,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(cajaProvider.notifier)
          .registrarMovimiento(
            tipo: widget.tipo,
            monto: double.parse(_amountController.text),
            concepto: _conceptController.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) _sheetError(context, error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _DetailSheet extends ConsumerStatefulWidget {
  final Future<CajaSesion> future;
  final bool canReopen;
  final Future<void> Function() onReopen;

  const _DetailSheet({
    required this.future,
    required this.canReopen,
    required this.onReopen,
  });

  @override
  ConsumerState<_DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends ConsumerState<_DetailSheet> {
  bool _reopening = false;
  // Movimientos de la sesión
  List<CajaMovimiento> _movimientos = [];
  bool _movLoading = false;
  int _movPage = 1;
  int _movPages = 1;
  int _movTotal = 0;
  String? _movTipo;
  String? _loadedId;

  Future<void> _loadMovimientos(
    String id, {
    int? pagina,
    String? tipo,
  }) async {
    setState(() => _movLoading = true);
    try {
      final repo = ref.read(cajaRepositoryProvider);
      final page = await repo.movimientos(
        id,
        pagina: pagina ?? _movPage,
        tipo: tipo,
      );
      if (!mounted) return;
      setState(() {
        _movimientos = page.data;
        _movPages = page.totalPaginas;
        _movTotal = page.total;
        _movPage = page.pagina;
        _movLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _movLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.colors.surface,
    appBar: SubPageAppBar(
      title: 'Detalle de sesión de caja',
      subtitle: 'Resumen y arqueos del turno',
    ),
    body: FutureBuilder<CajaSesion>(
      future: widget.future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _InlineSkeleton();
        }
        if (snapshot.hasError) {
          return AppErrorState(message: snapshot.error.toString());
        }
        final session = snapshot.data!;

        if (_loadedId == null) {
          _loadedId = session.id;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _loadMovimientos(session.id);
          });
        }

        final resumen = session.resumen;
        final v2 = resumen?.v2;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            // ── Cabecera ──────────────────────────────────────────────────
            Row(
              children: [
                _StatusPill(
                  label: session.estado,
                  color: session.isAbierta
                      ? AppColors.success
                      : context.colors.textSecondary,
                ),
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
            const SizedBox(height: 14),

            // ── Tarjetas de métricas ───────────────────────────────────────
            if (resumen != null)
              LayoutBuilder(
                builder: (context, constraints) {
                  final w = (constraints.maxWidth - 10) / 2;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _Metric(
                        width: w,
                        label: 'Apertura',
                        value: session.montoApertura,
                        icon: Icons.play_circle_outline_rounded,
                        color: context.colors.textSecondary,
                      ),
                      if (resumen.isV2 && v2 != null) ...[
                        _Metric(
                          width: w,
                          label: 'Ventas neto',
                          value: v2.totalVentasNeto,
                          icon: Icons.trending_up_rounded,
                          color: AppColors.success,
                        ),
                        _Metric(
                          width: w,
                          label: 'Digital neto',
                          value: v2.totalDigitalNeto,
                          icon: Icons.trending_down_rounded,
                          color: AppColors.primary,
                        ),
                        _Metric(
                          width: w,
                          label: 'Efectivo esperado',
                          value: v2.efectivoEsperado,
                          icon: Icons.account_balance_rounded,
                          color: AppColors.warning,
                        ),
                      ] else ...[
                        _Metric(
                          width: w,
                          label: 'Entradas',
                          value: resumen.v1?.totalEntradas ?? 0,
                          icon: Icons.south_west_rounded,
                          color: AppColors.success,
                        ),
                        _Metric(
                          width: w,
                          label: 'Salidas',
                          value: resumen.v1?.totalSalidas ?? 0,
                          icon: Icons.north_east_rounded,
                          color: AppColors.error,
                        ),
                        _Metric(
                          width: w,
                          label: 'Efectivo esperado',
                          value: resumen.efectivoEsperado,
                          icon: Icons.account_balance_rounded,
                          color: AppColors.warning,
                        ),
                      ],
                    ],
                  );
                },
              ),
            const SizedBox(height: 14),

            // ── Sección Apertura ───────────────────────────────────────────
            _SectionCard(title: 'Apertura', rows: [
              _DetailRow(label: 'Sede', value: session.sede),
              _DetailRow(label: 'Estado', value: session.estado),
              _DetailRow(label: 'Fecha', value: _dateTime(session.abiertaAt)),
              _DetailRow(label: 'Usuario', value: session.usuarioAperturaLabel),
              _DetailRow(label: 'Monto', value: _money(session.montoApertura)),
              if (session.createdAt != null)
                _DetailRow(label: 'Creada', value: _dateTime(session.createdAt!)),
              if (session.updatedAt != null)
                _DetailRow(label: 'Actualizada', value: _dateTime(session.updatedAt!)),
            ]),
            const SizedBox(height: 10),

            // ── Sección Precuadre ──────────────────────────────────────────
            _SectionCard(title: 'Precuadre', rows: [
              _DetailRow(
                label: 'Fecha',
                value: session.precuadreAt != null
                    ? _dateTime(session.precuadreAt!)
                    : 'No realizado',
              ),
              _DetailRow(
                label: 'Usuario',
                value: session.usuarioPrecuadre ?? 'No registrado',
              ),
              _DetailRow(
                label: 'Declarado',
                value: session.montoDeclaradoPrecuadre != null
                    ? _money(session.montoDeclaradoPrecuadre!)
                    : 'No registrado',
              ),
              _DetailRow(
                label: 'Esperado',
                value: session.saldoEsperadoPrecuadre != null
                    ? _money(session.saldoEsperadoPrecuadre!)
                    : 'No registrado',
              ),
              _DetailRow(
                label: 'Diferencia',
                value: session.diferenciaPrecuadre != null
                    ? _money(session.diferenciaPrecuadre!)
                    : 'No registrado',
              ),
            ]),
            const SizedBox(height: 10),

            // ── Sección Cierre ─────────────────────────────────────────────
            _SectionCard(title: 'Cierre', rows: [
              _DetailRow(
                label: 'Fecha',
                value: session.cerradaAt != null
                    ? _dateTime(session.cerradaAt!)
                    : 'Caja aún abierta',
              ),
              _DetailRow(
                label: 'Usuario',
                value: session.usuarioCierre ?? 'No registrado',
              ),
              _DetailRow(
                label: 'Declarado',
                value: session.montoDeclaradoCierre != null
                    ? _money(session.montoDeclaradoCierre!)
                    : 'No registrado',
              ),
              _DetailRow(
                label: 'Esperado',
                value: session.saldoEsperadoCierre != null
                    ? _money(session.saldoEsperadoCierre!)
                    : 'No registrado',
              ),
              _DetailRow(
                label: 'Diferencia',
                value: session.diferenciaCierre != null
                    ? _money(session.diferenciaCierre!)
                    : 'No registrado',
              ),
              _DetailRow(
                label: 'Observaciones',
                value: session.observacionesCierre?.isNotEmpty == true
                    ? session.observacionesCierre!
                    : 'Sin observaciones',
              ),
            ]),
            const SizedBox(height: 14),

            // ── Denominaciones de apertura (tabla) ─────────────────────────
            if (session.denominaciones.isNotEmpty) ...[
              _DenominacionesTable(
                title: 'Denominaciones de apertura',
                items: session.denominaciones,
              ),
              const SizedBox(height: 14),
            ],

            // ── Denominaciones de precuadre (tabla) ────────────────────────
            if (session.denominacionesPrecuadre.isNotEmpty) ...[
              _DenominacionesTable(
                title: 'Denominaciones de precuadre',
                items: session.denominacionesPrecuadre,
              ),
              const SizedBox(height: 14),
            ],

            // ── Vendedoras ─────────────────────────────────────────────────
            if (v2?.porVendedora.isNotEmpty ?? false) ...[
              CajaVendedoraTable(porVendedora: v2!.porVendedora),
              const SizedBox(height: 14),
            ],

            // ── Productos ──────────────────────────────────────────────────
            if (v2?.resumenProductos.isNotEmpty ?? false) ...[
              CajaProductosTable(resumenProductos: v2!.resumenProductos),
              const SizedBox(height: 14),
            ],

            // ── Movimientos ────────────────────────────────────────────────
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Movimientos',
                            style: AppTextStyles.titleMedium,
                          ),
                        ),
                        Text(
                          '$_movTotal registros',
                          style: AppTextStyles.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    child: _FilterRow(
                      selected: _movTipo,
                      values: const [null, 'ENTRADA', 'SALIDA'],
                      labels: const ['Todos', 'Entradas', 'Salidas'],
                      onChanged: (tipo) {
                        setState(() {
                          _movTipo = tipo;
                          _movPage = 1;
                        });
                        _loadMovimientos(
                          _loadedId!,
                          tipo: tipo,
                          pagina: 1,
                        );
                      },
                    ),
                  ),
                  if (_movLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  else if (_movimientos.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: AppEmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'Sin movimientos',
                        description:
                            'No hay movimientos para este filtro.',
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
                      child: Column(
                        children: [
                          for (final m in _movimientos)
                            _MovementTile(movement: m),
                        ],
                      ),
                    ),
                  if (_movPages > 1)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                      child: _Pager(
                        page: _movPage,
                        pages: _movPages,
                        total: _movTotal,
                        onPage: (page) {
                          setState(() => _movPage = page);
                          _loadMovimientos(
                            _loadedId!,
                            pagina: page,
                            tipo: _movTipo,
                          );
                        },
                      ),
                    )
                  else
                    const SizedBox(height: 10),
                ],
              ),
            ),

            // ── Reaperturar ────────────────────────────────────────────────
            if (widget.canReopen && session.isCerrada && session.isV2) ...[
              const SizedBox(height: 14),
              PrimaryButton(
                label: 'Reaperturar caja',
                icon: Icons.lock_open_rounded,
                isLoading: _reopening,
                onPressed: _reopen,
              ),
            ],
          ],
        );
      },
    ),
  );

  Future<void> _reopen() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reaperturar caja'),
        content: const Text(
          'La sesión volverá a estado abierta y se limpiará su cierre. ¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reaperturar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _reopening = true);
    try {
      await widget.onReopen();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) _sheetError(context, error);
    } finally {
      if (mounted) setState(() => _reopening = false);
    }
  }
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    incoming
                        ? Icons.south_west_rounded
                        : Icons.north_east_rounded,
                    color: color,
                    size: 17,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        movement.concepto,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        [
                          if (movement.medioPago?.isNotEmpty ?? false)
                            movement.medioPago!,
                          if (movement.etiqueta?.isNotEmpty ?? false)
                            movement.etiqueta!,
                          if (movement.origen.isNotEmpty) movement.origen,
                        ].join(' · '),
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
            // Fila secundaria: fecha, referencia y comprobante
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 46),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      [
                        _dateTime(movement.createdAt),
                        if (movement.referencia?.isNotEmpty ?? false)
                          movement.referencia!,
                      ].join(' · '),
                      style: AppTextStyles.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (movement.comprobante?.isNotEmpty ?? false)
                    _ComprobanteBtn(url: movement.comprobante),
                ],
              ),
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
            selectedColor: context.colors.primarySurface,
            side: BorderSide(
              color: active
                  ? context.colors.primaryBorder
                  : context.colors.border,
            ),
            labelStyle: AppTextStyles.labelSmall.copyWith(
              color: active ? AppColors.primary : context.colors.textSecondary,
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
      color: context.colors.warningLight,
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
              color: context.colors.textPrimary,
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
      color: context.colors.primarySurface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: context.colors.primaryBorder),
    ),
    child: Row(
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMedium,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            _money(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: AppTextStyles.titleLarge.copyWith(color: AppColors.primary),
          ),
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
      color: context.colors.backgroundAlt,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: context.colors.border),
    ),
    child: Text(
      label.replaceAll('_', ' '),
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.labelSmall.copyWith(
        color: context.colors.textSecondary,
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
            color: context.colors.textPrimary,
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
        color: context.colors.border.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),
  );
}

void _sheetError(BuildContext context, Object error) {
  AppFeedback.error(context, error.toString());
}

String _money(double value) => 'S/ ${value.toStringAsFixed(2)}';

String _denomination(double value) =>
    value >= 1 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);

String _dateTime(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

// ── Tarjeta de sección (Apertura / Precuadre / Cierre) ───────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final List<_DetailRow> rows;

  const _SectionCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) => AppCard(
    padding: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: context.colors.border),
            ),
          ),
          child: Text(
            title.toUpperCase(),
            style: AppTextStyles.labelSmall.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            children: [
              for (int i = 0; i < rows.length; i++) ...[
                rows[i],
                if (i < rows.length - 1)
                  Divider(height: 16, color: context.colors.border),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

// ── Tabla de denominaciones (apertura / precuadre) ───────────────────────────

class _DenominacionesTable extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items;

  const _DenominacionesTable({required this.title, required this.items});

  @override
  Widget build(BuildContext context) => AppCard(
    padding: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: context.colors.border),
            ),
          ),
          child: Text(
            title,
            style: AppTextStyles.titleMedium,
          ),
        ),
        // Cabecera de tabla
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'DENOMINACIÓN',
                  style: AppTextStyles.labelSmall.copyWith(fontSize: 9, letterSpacing: 0.6),
                ),
              ),
              Expanded(
                child: Text(
                  'CANT.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.labelSmall.copyWith(fontSize: 9, letterSpacing: 0.6),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'SUBTOTAL',
                  textAlign: TextAlign.right,
                  style: AppTextStyles.labelSmall.copyWith(fontSize: 9, letterSpacing: 0.6),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: context.colors.border),
        // Filas
        for (final item in items)
          _buildRow(context, item),
        const SizedBox(height: 4),
      ],
    ),
  );

  Widget _buildRow(BuildContext context, Map<String, dynamic> item) {
    final denom = (item['denominacion'] as num).toDouble();
    final qty = (item['cantidad'] as num).toInt();
    final subtotal = denom * qty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              'S/ ${_denomination(denom)}',
              style: AppTextStyles.bodySmall.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _money(subtotal),
              textAlign: TextAlign.right,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Botón visor de comprobante ────────────────────────────────────────────────

class _ComprobanteBtn extends StatelessWidget {
  final String? url;
  const _ComprobanteBtn({this.url});

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) return const SizedBox.shrink();
    return TextButton.icon(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: AppColors.primary,
      ),
      icon: const Icon(Icons.visibility_outlined, size: 13),
      label: const Text(
        'Ver comprobante',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
      ),
      onPressed: () => _show(context),
    );
  }

  void _show(BuildContext context) {
    final normalised =
        (url!.startsWith('http') || url!.startsWith('/')) ? url! : 'https://$url';
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Comprobante',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.55,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    normalised,
                    fit: BoxFit.contain,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          ),
                    errorBuilder: (_, __, ___) => const Center(
                      child: Text('No se pudo cargar el comprobante'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
