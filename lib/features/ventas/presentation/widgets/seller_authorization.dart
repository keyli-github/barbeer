import 'package:flutter/material.dart';
import '../../../../core/widgets/operation_form.dart';

Future<String?> requestSellerAuthorization(BuildContext context) async {
  final controller = TextEditingController();
  String? pin;
  final accepted = await OperationForm.show(
    context,
    OperationForm(
      title: 'Autorizar venta',
      submitLabel: 'Continuar',
      fields: (_) => [
        const Text(
          'Solicita la clave del superadministrador para registrar esta venta.',
        ),
        TextFormField(
          controller: controller,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          validator: requiredText,
          decoration: const InputDecoration(labelText: 'Clave de autorización'),
        ),
      ],
      onSave: () async {
        pin = controller.text.trim();
      },
    ),
  );
  controller.clear();
  controller.dispose();
  return accepted == true ? pin : null;
}
