import 'package:flutter/material.dart';
import '../../../../core/utils/business_time.dart';
import '../../../../core/widgets/operation_form.dart';
import '../../data/models/venta_models.dart';
import '../../data/ventas_repository.dart';

Future<ComprobanteAnalisis?> completeManualReceipt(
  BuildContext context, {
  required ComprobanteAnalisis analysis,
  required List<Etiqueta> wallets,
  required VentasRepository repository,
  String? selectedWallet,
}) async {
  final amount = TextEditingController(
    text: analysis.monto?.toStringAsFixed(2),
  );
  final operation = TextEditingController(text: analysis.codigoOperacion);
  final security = TextEditingController(text: analysis.codigoSeguridad);
  final date = TextEditingController(
    text: analysis.fechaOperacion ?? businessDate(),
  );
  final time = TextEditingController(text: analysis.horaOperacion ?? '');
  var wallet = selectedWallet ?? analysis.etiquetaSugerida?.id;
  if (!wallets.any((item) => item.id == wallet)) wallet = null;
  ComprobanteAnalisis? result;
  await OperationForm.show(
    context,
    OperationForm(
      title: 'Completar comprobante',
      fields: (refresh) => [
        const Text(
          'El análisis automático no pudo completar los datos. Revisa la imagen e ingresa los datos originales del comprobante.',
        ),
        if (analysis.imagenUrl.isNotEmpty)
          Image.network(
            analysis.imagenUrl,
            height: 180,
            errorBuilder: (_, _, _) =>
                const Text('No se pudo cargar la imagen.'),
          ),
        DropdownButtonFormField<String>(
          initialValue: wallet,
          isExpanded: true,
          validator: requiredText,
          decoration: const InputDecoration(labelText: 'Billetera'),
          items: wallets
              .map(
                (item) =>
                    DropdownMenuItem(value: item.id, child: Text(item.nombre)),
              )
              .toList(),
          onChanged: (value) {
            wallet = value;
            refresh();
          },
        ),
        operationText(amount, 'Monto (S/)', money: true),
        operationText(
          operation,
          'Código de operación',
          maxLength: 100,
          required: false,
        ),
        operationText(
          security,
          'Código de seguridad',
          maxLength: 100,
          required: false,
        ),
        TextFormField(
          controller: date,
          decoration: const InputDecoration(labelText: 'Fecha (AAAA-MM-DD)'),
          validator: (value) =>
              RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value ?? '') &&
                  DateTime.tryParse(value!) != null
              ? null
              : 'Ingresa una fecha válida',
        ),
        TextFormField(
          controller: time,
          decoration: const InputDecoration(labelText: 'Hora de Perú (HH:MM)'),
          validator: (value) =>
              RegExp(
                r'^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$',
              ).hasMatch(value ?? '')
              ? null
              : 'Ingresa una hora válida',
        ),
      ],
      onSave: () async {
        result = await repository.completarComprobanteManual(analysis.id, {
          'etiquetaId': wallet,
          'monto': moneyValue(amount.text),
          'fechaOperacion': date.text,
          'horaOperacion': time.text,
          if (operation.text.trim().isNotEmpty)
            'codigoOperacion': operation.text.trim(),
          if (security.text.trim().isNotEmpty)
            'codigoSeguridad': security.text.trim(),
        });
      },
    ),
  );
  for (final controller in [amount, operation, security, date, time]) {
    controller.dispose();
  }
  return result;
}
