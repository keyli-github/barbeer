import 'dart:async';
import 'package:flutter/material.dart';
import '../errors/app_exception.dart';
import 'responsive_form.dart';

/// A scrollable, keyboard-safe editor that stays open when a request fails.
class OperationForm extends StatefulWidget {
  final String title;
  final List<Widget> Function(VoidCallback refresh) fields;
  final Future<void> Function() onSave;
  final String submitLabel;
  final VoidCallback? _onDisposed;
  const OperationForm({
    super.key,
    required this.title,
    required this.fields,
    required this.onSave,
    this.submitLabel = 'Guardar',
  }) : _onDisposed = null;

  OperationForm._tracked(OperationForm form, this._onDisposed)
    : title = form.title,
      fields = form.fields,
      onSave = form.onSave,
      submitLabel = form.submitLabel;

  static Future<bool?> show(BuildContext context, OperationForm form) async {
    final disposed = Completer<void>();
    final result = await ResponsiveForm.showPage<bool>(
      context: context,
      page: OperationForm._tracked(form, disposed.complete),
    );
    // Navigator.pop resolves before the reverse transition removes the form.
    // Keep caller-owned controllers alive until the fields are unmounted.
    await disposed.future;
    return result;
  }

  @override
  State<OperationForm> createState() => _OperationFormState();
}

class _OperationFormState extends State<OperationForm> {
  final _key = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    widget._onDisposed?.call();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_key.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSave();
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted)
        setState(
          () => _error = error is AppException
              ? error.message
              : 'No se pudo guardar. Intenta nuevamente.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: _key,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  ...widget
                      .fields(() => setState(() {}))
                      .expand((field) => [field, const SizedBox(height: 16)]),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: _busy ? null : _save,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(_busy ? 'Guardando…' : widget.submitLabel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

String? requiredText(String? value) =>
    value == null || value.trim().isEmpty ? 'Este campo es obligatorio' : null;

String? moneyValidator(String? value, {bool allowZero = false}) {
  final text = value?.trim().replaceAll(',', '.') ?? '';
  final number = double.tryParse(text);
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text) ||
      number == null ||
      !number.isFinite ||
      number > 9999999999.99 ||
      (allowZero ? number < 0 : number <= 0)) {
    return allowZero
        ? 'Ingresa un monto válido (0 o mayor)'
        : 'Ingresa un monto mayor a 0';
  }
  return null;
}

double moneyValue(String value) =>
    double.parse(value.trim().replaceAll(',', '.'));

Widget operationText(
  TextEditingController controller,
  String label, {
  int maxLength = 240,
  bool required = true,
  bool money = false,
  bool allowZero = false,
}) => TextFormField(
  controller: controller,
  maxLength: maxLength,
  keyboardType: money
      ? const TextInputType.numberWithOptions(decimal: true)
      : TextInputType.text,
  decoration: InputDecoration(labelText: label, counterText: ''),
  validator: money
      ? (value) => moneyValidator(value, allowZero: allowZero)
      : required
      ? requiredText
      : null,
);

Future<bool> confirmOperation(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    ) ??
    false;
