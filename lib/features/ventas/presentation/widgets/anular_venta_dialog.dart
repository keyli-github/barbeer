import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

Future<String?> showAnularVentaDialog(
  BuildContext context, {
  required String codigo,
}) => showDialog<String>(
  context: context,
  useRootNavigator: true,
  builder: (_) => _AnularVentaDialog(codigo: codigo),
);

class _AnularVentaDialog extends StatefulWidget {
  final String codigo;

  const _AnularVentaDialog({required this.codigo});

  @override
  State<_AnularVentaDialog> createState() => _AnularVentaDialogState();
}

class _AnularVentaDialogState extends State<_AnularVentaDialog> {
  final _motivoCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _motivoCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final motivo = _motivoCtrl.text.trim();
    if (motivo.isEmpty) {
      setState(() => _error = 'El motivo de anulación es obligatorio');
      return;
    }
    Navigator.pop(context, motivo);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    title: const Text(
      'Anular venta',
      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Esta acción anulará ${widget.codigo} y no se puede deshacer.'),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('motivoAnulacionField'),
          controller: _motivoCtrl,
          autofocus: true,
          maxLines: 3,
          maxLength: 500,
          decoration: InputDecoration(
            labelText: 'Motivo de anulación *',
            hintText: 'Describe el motivo de la anulación',
            errorText: _error,
          ),
          onSubmitted: (_) => _submit(),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      TextButton(
        onPressed: _submit,
        style: TextButton.styleFrom(foregroundColor: AppColors.error),
        child: const Text(
          'Anular',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );
}
