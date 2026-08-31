import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/errors/app_exception.dart';
import '../../data/cuentas_repository.dart';
import '../../data/models/cuenta_models.dart';

typedef CreateCuenta =
    Future<Cuenta> Function({
      required String nombre,
      String? documento,
      String? telefono,
    });

Future<Cuenta?> showCreateCuentaDialog(
  BuildContext context,
  CreateCuenta create,
) => showDialog<Cuenta>(
  context: context,
  builder: (_) => _CreateCuentaDialog(create),
);

class _CreateCuentaDialog extends StatefulWidget {
  final CreateCuenta create;
  const _CreateCuentaDialog(this.create);
  @override
  State<_CreateCuentaDialog> createState() => _CreateCuentaDialogState();
}

class _CreateCuentaDialogState extends State<_CreateCuentaDialog> {
  final name = TextEditingController(),
      document = TextEditingController(),
      phone = TextEditingController();
  String? error;
  bool busy = false;
  @override
  void dispose() {
    name.dispose();
    document.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (name.text.trim().isEmpty || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final account = await widget.create(
        nombre: name.text,
        documento: document.text,
        telefono: phone.text,
      );
      if (mounted) Navigator.pop(context, account);
    } catch (value) {
      if (mounted)
        setState(() {
          busy = false;
          error = value is AppException
              ? value.message
              : 'No se pudo crear la cuenta';
        });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Crear Nueva Cuenta'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('account-name'),
            controller: name,
            autofocus: true,
            inputFormatters: [LengthLimitingTextInputFormatter(100)],
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Nombre de Usuario *',
              hintText: 'Ej. Juan Pérez',
            ),
          ),
          TextField(
            key: const Key('account-document'),
            controller: document,
            inputFormatters: [LengthLimitingTextInputFormatter(20)],
            decoration: const InputDecoration(
              labelText: 'Documento (opcional)',
            ),
          ),
          TextField(
            key: const Key('account-phone'),
            controller: phone,
            keyboardType: TextInputType.phone,
            inputFormatters: [LengthLimitingTextInputFormatter(20)],
            decoration: const InputDecoration(labelText: 'Teléfono (opcional)'),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const Key('account-create-submit'),
        onPressed: busy || name.text.trim().isEmpty ? null : submit,
        child: Text(busy ? 'Creando...' : 'CREAR Y SELECCIONAR'),
      ),
    ],
  );
}

class CuentaChargeSelection {
  final Cuenta cuenta;
  final double monto;
  const CuentaChargeSelection(this.cuenta, this.monto);
}

Future<CuentaChargeSelection?> showCuentaChargeDialog(
  BuildContext context, {
  required CuentasRepository repository,
  required String sedeId,
  required double total,
  required bool canCreate,
  double? paidAmount,
  String paidLabel = 'Monto dejado en efectivo (S/)',
}) => showDialog<CuentaChargeSelection>(
  context: context,
  builder: (_) => _CuentaChargeDialog(
    repository,
    sedeId,
    total,
    canCreate,
    paidAmount,
    paidLabel,
  ),
);

class _CuentaChargeDialog extends StatefulWidget {
  final CuentasRepository repository;
  final String sedeId;
  final double total;
  final bool canCreate;
  final double? paidAmount;
  final String paidLabel;
  const _CuentaChargeDialog(
    this.repository,
    this.sedeId,
    this.total,
    this.canCreate,
    this.paidAmount,
    this.paidLabel,
  );
  @override
  State<_CuentaChargeDialog> createState() => _CuentaChargeDialogState();
}

class _CuentaChargeDialogState extends State<_CuentaChargeDialog> {
  final search = TextEditingController(), cash = TextEditingController();
  List<Cuenta> items = const [];
  Cuenta? selected;
  String? error;
  bool loading = true;
  @override
  void initState() {
    super.initState();
    cash.text = (widget.paidAmount ?? widget.total).toStringAsFixed(2);
    load();
  }

  @override
  void dispose() {
    search.dispose();
    cash.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.repository.selector(
        search: search.text,
        sedeId: widget.sedeId,
      );
      if (mounted)
        setState(() {
          items = result;
          loading = false;
        });
    } catch (value) {
      if (mounted)
        setState(() {
          loading = false;
          error = value is AppException
              ? value.message
              : 'No se pudieron buscar las cuentas.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cashValue = double.tryParse(cash.text.replaceAll(',', '.'));
    final difference = cashValue == null ? 0.0 : widget.total - cashValue;
    return AlertDialog(
      title: const Text('Cargar a Cuenta de Cliente'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('account-search'),
                controller: search,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => load(),
                decoration: const InputDecoration(
                  labelText: '1. Buscar Cuenta Existente',
                ),
              ),
              const SizedBox(height: 8),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Buscando cuentas...'),
                )
              else if (error != null)
                Column(
                  children: [
                    Text(error!),
                    TextButton(
                      onPressed: load,
                      child: const Text('Reintentar'),
                    ),
                  ],
                )
              else if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No se encontraron resultados'),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final account in items)
                        ListTile(
                          key: Key('account-option-${account.id}'),
                          selected: selected?.id == account.id,
                          title: Text(account.nombre),
                          subtitle: Text(
                            account.esPersonal == true
                                ? 'Cuenta personal'
                                : 'Deuda actual: ${account.saldo.toStringAsFixed(2)}',
                          ),
                          trailing: Text(
                            '${account.saldo.toStringAsFixed(2)}\n${account.cantidadPendientes ?? 0} pendiente(s)',
                            textAlign: TextAlign.end,
                          ),
                          onTap: () => setState(() => selected = account),
                        ),
                    ],
                  ),
                ),
              if (widget.canCreate)
                TextButton.icon(
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Crear Nueva Cuenta'),
                  onPressed: () async {
                    final created = await showCreateCuentaDialog(
                      context,
                      widget.repository.create,
                    );
                    if (created != null && mounted)
                      setState(() => selected = created);
                  },
                ),
              if (selected != null) ...[
                const Divider(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Cliente Seleccionado: ${selected!.nombre}'),
                ),
                TextField(
                  key: const Key('account-cash-amount'),
                  controller: cash,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(labelText: widget.paidLabel),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Diferencia a cargar a cuenta: ${difference.clamp(0, widget.total).toStringAsFixed(2)}',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('account-charge-apply'),
          onPressed:
              selected == null ||
                  cashValue == null ||
                  cashValue < 0 ||
                  difference <= 0
              ? null
              : () {
                  final amount = double.parse(difference.toStringAsFixed(2));
                  Navigator.pop(
                    context,
                    CuentaChargeSelection(selected!, amount),
                  );
                },
          child: const Text('CONFIRMAR Y APLICAR'),
        ),
      ],
    );
  }
}
