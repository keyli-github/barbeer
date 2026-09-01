import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/async/operation_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../data/models/cuenta_models.dart';
import '../../../ventas/data/models/venta_models.dart';
import '../../../ventas/presentation/providers/ventas_provider.dart';
import '../../../ventas/presentation/widgets/comprobante_analysis_panel.dart';
import '../providers/cuentas_provider.dart';

class CuentasScreen extends ConsumerStatefulWidget {
  const CuentasScreen({super.key});
  @override
  ConsumerState<CuentasScreen> createState() => _CuentasScreenState();
}

class _CuentasScreenState extends ConsumerState<CuentasScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      ref.read(cuentasProvider.notifier).load(search: value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cuentasProvider);
    final notifier = ref.read(cuentasProvider.notifier);
    final allItems = state.items;
    final deudores = allItems.where((c) => (c.saldo) > 0).length;
    final totalDeuda = allItems.fold<double>(
      0,
      (sum, c) => sum + (c.saldo as double? ?? 0.0),
    );

    return Scaffold(
      backgroundColor: context.colors.background,
      body: MediaQuery.sizeOf(context).width >= 1024
          ? _buildDesktop(context, state, notifier, deudores, totalDeuda)
          : _buildMobile(context, state, notifier, deudores, totalDeuda),
    );
  }

  Widget _buildMobile(
    BuildContext context,
    CuentasState state,
    CuentasNotifier notifier,
    int deudores,
    double totalDeuda,
  ) {
    final list = state.listState;

    return RefreshIndicator(
      onRefresh: notifier.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          // ── Summary cards ─────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: 'Clientes con deuda',
                  value: '$deudores',
                  icon: Icons.people_outline,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryCard(
                  label: 'Total por cobrar',
                  value: FormatUtils.currency(totalDeuda),
                  icon: Icons.account_balance_wallet_outlined,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ── Search ────────────────────────────────────────────────────
          TextField(
            key: const Key('cuentas-search'),
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            onSubmitted: (v) {
              _debounce?.cancel();
              notifier.load(search: v.trim());
            },
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Buscar por nombre o documento...',
            ),
          ),
          const SizedBox(height: 12),
          // ── List ──────────────────────────────────────────────────────
          if (list is OperationLoading<List<Cuenta>>)
            const SizedBox(
              height: 280,
              child: AppLoading(message: 'Cargando cuentas...'),
            )
          else if (list is OperationRecoverableError<List<Cuenta>>)
            AppErrorState(message: list.error.message, onRetry: notifier.load)
          else if (list is OperationEmpty<List<Cuenta>>)
            const AppEmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Sin cuentas',
              description: 'No se encontraron cuentas con deuda.',
            )
          else ...[
            for (final account in state.items)
              Card(
                child: ListTile(
                  key: Key('cuenta-${account.id}'),
                  onTap: () => notifier.select(account.id),
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_outline_rounded),
                  ),
                  title: Text(account.nombre),
                  subtitle: Text(
                    '${account.cantidadPendientes ?? 0} venta(s) pendiente(s)',
                  ),
                  trailing: Text(
                    FormatUtils.currency(account.saldo),
                    style: TextStyle(
                      color: account.saldo > 0 ? AppColors.error : Colors.green,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            if (state.detailState case final detail?)
              _detailState(context, detail, notifier, state.selectedId),
          ],
        ],
      ),
    );
  }

  Widget _buildDesktop(
    BuildContext context,
    CuentasState state,
    CuentasNotifier notifier,
    int deudores,
    double totalDeuda,
  ) =>
      LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth = constraints.maxWidth - 48;
          final masterWidth = (contentWidth * .28).clamp(280.0, 380.0);
          final availableHeight = constraints.maxHeight - 198;
          final workspaceHeight =
              availableHeight < 520.0 ? 520.0 : availableHeight;

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: notifier.load,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _CobrosMark(),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cobros',
                              style: TextStyle(
                                color: context.colors.textPrimary,
                                fontSize: 28,
                                height: 1.08,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Clientes con saldo pendiente y detalle de las ventas cargadas a su cuenta.',
                              style: TextStyle(
                                color: context.colors.textTertiary,
                                fontSize: 14,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: 568,
                    child: Row(
                      children: [
                        Expanded(
                          child: _DesktopSummaryCard(
                            label: 'Clientes con deuda',
                            value: '$deudores',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DesktopSummaryCard(
                            label: 'Total por cobrar',
                            value: FormatUtils.currency(totalDeuda),
                            accent: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: workspaceHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: masterWidth,
                          child: _desktopMaster(context, state, notifier),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                            child: _desktopDetail(context, state, notifier)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

  Widget _desktopMaster(
    BuildContext context,
    CuentasState state,
    CuentasNotifier notifier,
  ) =>
      Container(
        key: const Key('cuentas-desktop-master'),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border:
                    Border(bottom: BorderSide(color: context.colors.border)),
              ),
              child: TextField(
                key: const Key('cuentas-search'),
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: (value) {
                  _debounce?.cancel();
                  notifier.load(search: value.trim());
                },
                style:
                    TextStyle(color: context.colors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: context.colors.background,
                  hintText: 'Buscar cliente…',
                  hintStyle: TextStyle(color: context.colors.textTertiary),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: context.colors.textTertiary,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: context.colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ),
            Expanded(child: _desktopList(context, state, notifier)),
          ],
        ),
      );

  Widget _desktopList(
    BuildContext context,
    CuentasState state,
    CuentasNotifier notifier,
  ) {
    final list = state.listState;
    if (list is OperationLoading<List<Cuenta>>) {
      return const AppLoading(message: 'Cargando cuentas...');
    }
    if (list is OperationRecoverableError<List<Cuenta>>) {
      return AppErrorState(message: list.error.message, onRetry: notifier.load);
    }
    if (list is OperationEmpty<List<Cuenta>>) {
      return Center(
        child: Text(
          'No se encontraron cuentas.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: context.colors.textTertiary),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: state.items.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, thickness: 1, color: context.colors.divider),
      itemBuilder: (context, index) {
        final account = state.items[index];
        final selected = state.selectedId == account.id;
        return Material(
          color: selected
              ? AppColors.primary.withValues(alpha: .09)
              : Colors.transparent,
          child: InkWell(
            key: Key('cuenta-${account.id}'),
            onTap: () => notifier.select(account.id),
            hoverColor: context.colors.surfaceAlt,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: .10),
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.colors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${account.cantidadPendientes ?? 0} venta(s) pendiente(s)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.colors.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        FormatUtils.currency(account.saldo),
                        style: TextStyle(
                          color: account.saldo > 0
                              ? context.colors.error
                              : context.colors.success,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 17,
                        color: context.colors.textTertiary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _desktopDetail(
    BuildContext context,
    CuentasState state,
    CuentasNotifier notifier,
  ) =>
      Container(
        key: const Key('cuentas-desktop-detail'),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: switch (state.detailState) {
          null => const _DesktopNoSelection(),
          OperationLoading<CuentaDetalle>() => const AppLoading(
              message: 'Cargando detalle...',
            ),
          OperationRecoverableError<CuentaDetalle>(:final error) =>
            AppErrorState(
              message: error.message,
              onRetry: () => notifier.select(state.selectedId!),
            ),
          OperationContent<CuentaDetalle>(:final data) => _AccountDetail(
              data,
              notifier,
              desktop: true,
            ),
          _ => const _DesktopNoSelection(),
        },
      );

  Widget _detailState(
    BuildContext context,
    OperationState<CuentaDetalle> state,
    CuentasNotifier notifier,
    String? selectedId,
  ) {
    if (state is OperationLoading<CuentaDetalle>) {
      return const SizedBox(
        height: 180,
        child: AppLoading(message: 'Cargando detalle...'),
      );
    }
    if (state is OperationRecoverableError<CuentaDetalle>) {
      return AppErrorState(
        message: state.error.message,
        onRetry: selectedId == null ? null : () => notifier.select(selectedId),
      );
    }
    return _AccountDetail(
      (state as OperationContent<CuentaDetalle>).data,
      notifier,
    );
  }
}

// ── Summary card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: color,
                      ),
                    ),
                    Text(
                      label,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _CobrosMark extends StatelessWidget {
  const _CobrosMark();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(top: 1),
        child: Icon(
          Icons.volunteer_activism_outlined,
          size: 25,
          color: AppColors.primary,
        ),
      );
}

class _DesktopSummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final bool accent;

  const _DesktopSummaryCard({
    required this.label,
    required this.value,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) => Container(
        height: 82,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: accent
                    ? const Color(0xFFFF126B)
                    : context.colors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
}

class _DesktopNoSelection extends StatelessWidget {
  const _DesktopNoSelection();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_outline_rounded,
              size: 38,
              color: context.colors.textDisabled,
            ),
            const SizedBox(height: 14),
            Text(
              'Selecciona un cliente',
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Aquí aparecerán todas sus ventas pendientes.',
              style:
                  TextStyle(color: context.colors.textTertiary, fontSize: 13),
            ),
          ],
        ),
      );
}

// ── Account detail ────────────────────────────────────────────────────────────

class _AccountDetail extends StatelessWidget {
  final CuentaDetalle detail;
  final CuentasNotifier notifier;
  final bool desktop;
  const _AccountDetail(this.detail, this.notifier, {this.desktop = false});

  @override
  Widget build(BuildContext context) => Card(
        margin: desktop ? EdgeInsets.zero : const EdgeInsets.only(top: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CUENTA DE CLIENTE',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: context.colors.textTertiary)),
                        const SizedBox(height: 4),
                        Text(detail.nombre,
                            style: Theme.of(context).textTheme.titleLarge),
                      ],
                    ),
                  ),
                  if (notifier.canCollect && detail.saldo > 0) ...[
                    FilledButton.icon(
                      key: const Key('collection-open'),
                      icon: const Icon(Icons.volunteer_activism_outlined,
                          size: 17),
                      label: const Text('Pagar'),
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.orange),
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => _CollectionDialog(detail),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Saldo total pendiente',
                          style: TextStyle(
                              fontSize: 11,
                              color: context.colors.textTertiary)),
                      Text(FormatUtils.currency(detail.saldo),
                          style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 22,
                              fontWeight: FontWeight.w900)),
                    ],
                  ),
                ],
              ),
              const Divider(height: 28),
              if (detail.pendientes.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: context.colors.successLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.colors.successBorder),
                  ),
                  child: Text('Esta cuenta no tiene ventas pendientes de pago.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.colors.success)),
                )
              else
                for (final pending in detail.pendientes) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: context.colors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              const Icon(Icons.receipt_long_outlined,
                                  size: 18, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(pending.codigo,
                                        style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.w700)),
                                    Text(
                                        '${FormatUtils.dateTime(DateTime.parse(pending.fecha).toLocal())} · ${pending.sede.nombre}',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color:
                                                context.colors.textTertiary)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('PENDIENTE',
                                      style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: context.colors.textTertiary)),
                                  Text(
                                      FormatUtils.currency(
                                          pending.montoPendiente),
                                      style: const TextStyle(
                                          color: AppColors.error,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w900)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 1, color: context.colors.border),
                        for (final item in pending.items)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(item.producto.nombre,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600)),
                                      Text(
                                          '${item.producto.codigo} · ${item.cantidad} × ${FormatUtils.currency(item.precioUnitario)}',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color:
                                                  context.colors.textTertiary)),
                                    ],
                                  ),
                                ),
                                Text(FormatUtils.currency(item.subtotal),
                                    style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
            ],
          ),
        ),
      );
}

// ── Collection dialog ─────────────────────────────────────────────────────────

class _CollectionDialog extends ConsumerStatefulWidget {
  final CuentaDetalle detail;
  const _CollectionDialog(this.detail);
  @override
  ConsumerState<_CollectionDialog> createState() => _CollectionDialogState();
}

class _CollectionDialogState extends ConsumerState<_CollectionDialog> {
  late final TextEditingController amount = TextEditingController(
    text: widget.detail.saldo.toStringAsFixed(2),
  );
  String method = 'EFECTIVO';
  String? localError;
  bool submitting = false;
  bool analyzing = false;
  bool analysisLinked = false;
  int analysisToken = 0;
  Uint8List? voucherBytes;
  ComprobanteAnalisis? analysis;

  @override
  void dispose() {
    amount.dispose();
    if (!analysisLinked) _cancelAnalysis(analysis);
    super.dispose();
  }

  double get _parsedAmount =>
      double.tryParse(amount.text.replaceAll(',', '.')) ?? 0;
  double get _effectiveAmount =>
      method == 'TRANSFERENCIA' ? analysis?.monto ?? 0 : _parsedAmount;
  double get _remaining =>
      (widget.detail.saldo - _effectiveAmount).clamp(0.0, double.infinity);

  Future<void> _pickVoucher() async {
    final token = ++analysisToken;
    try {
      final file = await ref.read(voucherImagePickerProvider)();
      if (file == null || !mounted || token != analysisToken) return;
      await _cancelAnalysis(analysis);
      if (!mounted || token != analysisToken) return;
      setState(() {
        voucherBytes = file.bytes;
        analysis = null;
        localError = null;
        analyzing = true;
      });
      final result =
          await ref.read(ventasRepositoryProvider).analizarComprobante(
                bytes: file.bytes,
                filename: file.filename,
                sedeId: ref.read(cuentasProvider.notifier).sedeId,
              );
      if (!mounted || token != analysisToken) {
        await _cancelAnalysis(result);
        return;
      }
      setState(() {
        analysis = result;
        analyzing = false;
        localError = comprobanteAnalysisError(
          analysis: result,
          total: result.monto ?? 0,
          required: true,
        );
      });
    } catch (error) {
      if (!mounted || token != analysisToken) return;
      setState(() {
        analyzing = false;
        analysis = null;
        localError = error is FormatException
            ? error.message
            : error.toString().replaceFirst('AppException: ', '');
      });
    }
  }

  Future<void> _cancelAnalysis(ComprobanteAnalisis? value) async {
    if (value == null || value.id.isEmpty) return;
    await ref
        .read(ventasRepositoryProvider)
        .cancelarComprobanteAnalisis(value.id)
        .catchError((_) {});
  }

  void _selectMethod(String value) {
    if (value == method) return;
    if (value == 'EFECTIVO') {
      analysisToken++;
      _cancelAnalysis(analysis);
      analysis = null;
      voucherBytes = null;
      analyzing = false;
    }
    setState(() {
      method = value;
      localError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cuentasProvider);
    final notifier = ref.read(cuentasProvider.notifier);
    final busy = submitting || state.collectionBusy;

    return AlertDialog(
      title: Text('Pago · ${widget.detail.nombre}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Saldo actual
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Saldo pendiente',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    FormatUtils.currency(widget.detail.saldo),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('collection-amount'),
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Monto a pagar (S/)',
                prefixText: 'S/ ',
                border: const OutlineInputBorder(),
                helperText:
                    'Máximo: ${FormatUtils.currency(widget.detail.saldo)}',
              ),
            ),
            // Balance preview
            if (_effectiveAmount > 0 &&
                _effectiveAmount <= widget.detail.saldo) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pago aplicado',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          Text(
                            FormatUtils.currency(_effectiveAmount),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Saldo restante',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          Text(
                            FormatUtils.currency(_remaining),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color:
                                  _remaining > 0 ? Colors.orange : Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: method,
              decoration: const InputDecoration(
                labelText: 'Medio de pago',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'EFECTIVO', child: Text('Efectivo')),
                DropdownMenuItem(
                  value: 'TRANSFERENCIA',
                  child: Text('Transferencia'),
                ),
              ],
              onChanged: busy ? null : (v) => _selectMethod(v!),
            ),
            if (method == 'TRANSFERENCIA') ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('collection-voucher-pick'),
                onPressed: busy || analyzing ? null : _pickVoucher,
                icon: analyzing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.add_photo_alternate_outlined),
                label: Text(analyzing
                    ? 'Analizando comprobante...'
                    : analysis == null
                        ? 'Seleccionar comprobante'
                        : 'Cambiar comprobante'),
              ),
              if (voucherBytes != null || analysis != null) ...[
                const SizedBox(height: 8),
                ComprobanteAnalysisPanel(
                  analysis: analysis,
                  bytes: voucherBytes,
                  analyzing: analyzing,
                ),
              ],
            ],
            if (localError ?? state.collectionError?.message
                case final message?) ...[
              const SizedBox(height: 8),
              Text(message, style: const TextStyle(color: AppColors.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('collection-submit'),
          style: FilledButton.styleFrom(backgroundColor: Colors.orange),
          onPressed: busy
              ? null
              : () async {
                  if (submitting) return;
                  final value = _effectiveAmount;
                  final analysisError = method == 'TRANSFERENCIA'
                      ? comprobanteAnalysisError(
                          analysis: analysis,
                          total: analysis?.monto ?? 0,
                          required: true,
                        )
                      : null;
                  if (analysisError != null) {
                    setState(() => localError = analysisError);
                    return;
                  }
                  if (value <= 0 || value > widget.detail.saldo) {
                    setState(
                      () => localError =
                          'Ingrese un monto válido hasta ${FormatUtils.currency(widget.detail.saldo)}.',
                    );
                    return;
                  }
                  setState(() {
                    localError = null;
                    submitting = true;
                  });
                  await notifier.collect(
                    monto: value,
                    medioPago: method,
                    comprobanteAnalisisId:
                        method == 'TRANSFERENCIA' ? analysis?.id : null,
                  );
                  if (!mounted) return;
                  setState(() => submitting = false);
                  if (ref.read(cuentasProvider).collectionSucceeded) {
                    analysisLinked = true;
                    final remaining = _remaining;
                    final messenger = ScaffoldMessenger.of(this.context);
                    Navigator.pop(this.context);
                    messenger.showSnackBar(SnackBar(
                      content: Text(remaining > .009
                          ? 'Pago registrado. Saldo: ${FormatUtils.currency(remaining)}.'
                          : 'Pago registrado.'),
                    ));
                  }
                },
          child: Text(busy ? 'Registrando...' : 'Registrar pago'),
        ),
      ],
    );
  }
}
