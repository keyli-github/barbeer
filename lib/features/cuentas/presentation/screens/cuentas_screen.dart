import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/async/operation_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_ui_components.dart';
import '../../data/models/cuenta_models.dart';
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
    final list = state.listState;

    // Summary stats from loaded items
    final allItems = state.items;
    final deudores = allItems.where((c) => (c.saldo) > 0).length;
    final totalDeuda =
        allItems.fold<double>(0, (sum, c) => sum + (c.saldo as double? ?? 0.0));

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: notifier.load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            // ── Summary cards ─────────────────────────────────────────────
            if (allItems.isNotEmpty) ...[
              Row(children: [
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
              ]),
              const SizedBox(height: 12),
            ],
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
                  child: AppLoading(message: 'Cargando cuentas...'))
            else if (list is OperationRecoverableError<List<Cuenta>>)
              AppErrorState(
                  message: list.error.message, onRetry: notifier.load)
            else if (list is OperationEmpty<List<Cuenta>>)
              const AppEmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Sin cuentas',
                description: 'No se encontraron cuentas con deuda.',
              )
            else ...[
              for (final account in state.pageItems)
                Card(
                  child: ListTile(
                    key: Key('cuenta-${account.id}'),
                    onTap: () => notifier.select(account.id),
                    leading:
                        const CircleAvatar(child: Icon(Icons.person_outline_rounded)),
                    title: Text(account.nombre),
                    subtitle: Text(
                        '${account.cantidadPendientes ?? 0} venta(s) pendiente(s)'),
                    trailing: Text(
                      FormatUtils.currency(account.saldo),
                      style: TextStyle(
                        color: (account.saldo as double? ?? 0.0) > 0
                            ? AppColors.error
                            : Colors.green,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              AppPagination(
                page: state.page,
                totalPages: state.totalPages,
                total: state.items.length,
                onPageChange: notifier.setPage,
              ),
              if (state.detailState case final detail?)
                _detailState(context, detail, notifier),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailState(BuildContext context,
      OperationState<CuentaDetalle> state, CuentasNotifier notifier) {
    if (state is OperationLoading<CuentaDetalle>) {
      return const SizedBox(
          height: 180, child: AppLoading(message: 'Cargando detalle...'));
    }
    if (state is OperationRecoverableError<CuentaDetalle>) {
      return AppErrorState(
          message: state.error.message,
          onRetry: () => notifier.select(notifier.state.selectedId!));
    }
    return _AccountDetail(
        (state as OperationContent<CuentaDetalle>).data, notifier);
  }
}

// ── Summary card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _SummaryCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) => Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: color)),
                    Text(label,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey)),
                  ]),
            ),
          ]),
        ),
      );
}

// ── Account detail ────────────────────────────────────────────────────────────

class _AccountDetail extends StatelessWidget {
  final CuentaDetalle detail;
  final CuentasNotifier notifier;
  const _AccountDetail(this.detail, this.notifier);

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(top: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(detail.nombre,
                  style: Theme.of(context).textTheme.titleLarge),
              Text(
                'Saldo ${FormatUtils.currency(detail.saldo)}',
                style: const TextStyle(
                    color: AppColors.error, fontWeight: FontWeight.w800),
              ),
              if (notifier.canCollect && detail.saldo > 0)
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    key: const Key('collection-open'),
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Registrar pago'),
                    style:
                        FilledButton.styleFrom(backgroundColor: Colors.orange),
                    onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => _CollectionDialog(detail)),
                  ),
                ),
              const Divider(),
              const Text('Ventas pendientes',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              if (detail.pendientes.isEmpty)
                const Text('Sin ventas pendientes.')
              else
                for (final pending in detail.pendientes) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(pending.codigo,
                              style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Text(pending.sede.nombre,
                              style: const TextStyle(color: Colors.grey)),
                          const Spacer(),
                          Text(
                            FormatUtils.currency(pending.montoPendiente),
                            style: const TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.bold),
                          ),
                        ]),
                        for (final item in pending.items)
                          Text(
                              '${item.producto.nombre} · ${item.cantidad} × ${FormatUtils.currency(item.precioUnitario)}',
                              style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              const SizedBox(height: 8),
              if (detail.movimientos.isNotEmpty) ...[
                const Divider(),
                const Text('Movimientos',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                for (final m in detail.movimientos)
                  Text(
                      '${m.tipo} · ${FormatUtils.currency(m.monto)} · ${m.referencia ?? '-'}',
                      style: const TextStyle(fontSize: 12)),
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
    text: (widget.detail.saldo as double).toStringAsFixed(2),
  );
  final receipt = TextEditingController();
  String method = 'EFECTIVO';
  String? localError;
  bool submitting = false;

  @override
  void dispose() {
    amount.dispose();
    receipt.dispose();
    super.dispose();
  }

  double get _parsedAmount =>
      double.tryParse(amount.text.replaceAll(',', '.')) ?? 0;
  double get _remaining =>
      ((widget.detail.saldo as double) - _parsedAmount).clamp(0.0, double.infinity);

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
                  const Text('Saldo pendiente',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(
                    FormatUtils.currency(widget.detail.saldo),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppColors.error),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('collection-amount'),
              controller: amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
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
            if (_parsedAmount > 0 && _parsedAmount <= (widget.detail.saldo as double)) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(children: [
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Pago aplicado',
                              style:
                                  TextStyle(fontSize: 11, color: Colors.grey)),
                          Text(FormatUtils.currency(_parsedAmount),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green)),
                        ]),
                  ),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Saldo restante',
                              style:
                                  TextStyle(fontSize: 11, color: Colors.grey)),
                          Text(
                            FormatUtils.currency(_remaining),
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _remaining > 0
                                    ? Colors.orange
                                    : Colors.green),
                          ),
                        ]),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: method,
              decoration: const InputDecoration(
                  labelText: 'Medio de pago',
                  border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(
                    value: 'EFECTIVO', child: Text('Efectivo')),
                DropdownMenuItem(
                    value: 'TRANSFERENCIA', child: Text('Transferencia')),
              ],
              onChanged: busy ? null : (v) => setState(() => method = v!),
            ),
            if (method == 'TRANSFERENCIA') ...[
              const SizedBox(height: 8),
              TextField(
                controller: receipt,
                decoration: const InputDecoration(
                    labelText: 'ID análisis del comprobante',
                    border: OutlineInputBorder()),
              ),
            ],
            if (localError ?? state.collectionError?.message
                case final message?) ...[
              const SizedBox(height: 8),
              Text(message,
                  style: const TextStyle(color: AppColors.error)),
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
                  final value =
                      double.tryParse(amount.text.replaceAll(',', '.'));
                  if (value == null ||
                      value <= 0 ||
                      value > (widget.detail.saldo as double)) {
                    setState(() => localError =
                        'Ingrese un monto válido hasta ${FormatUtils.currency(widget.detail.saldo)}.');
                    return;
                  }
                  setState(() {
                    localError = null;
                    submitting = true;
                  });
                  await notifier.collect(
                    monto: value,
                    medioPago: method,
                    comprobanteAnalisisId: receipt.text.trim().isEmpty
                        ? null
                        : receipt.text.trim(),
                  );
                  if (mounted) setState(() => submitting = false);
                  if (mounted && notifier.state.collectionSucceeded) {
                    Navigator.pop(context);
                  }
                },
          child: Text(busy ? 'Registrando...' : 'Registrar pago'),
        ),
      ],
    );
  }
}
