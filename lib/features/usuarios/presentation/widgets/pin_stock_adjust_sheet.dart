import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/errors/app_exception.dart';
import '../../data/models/usuario_permission_models.dart';
import '../../data/usuario_admin_repository.dart';

/// PIN-authorized stock adjustment. Validates PIN via [UsuarioAdminRepository.validatePin]
/// before [UsuarioAdminRepository.adjustStock]. Handles 429/incorrect/success.
class PinStockAdjustSheet extends StatefulWidget {
  final String productId, productName;
  final double currentStock;
  final String? sedeId;
  final bool isSuperAdmin;
  final UsuarioAdminRepository repo;
  final VoidCallback onSaved;
  const PinStockAdjustSheet({required this.productId, required this.productName,
    required this.currentStock, required this.sedeId, required this.isSuperAdmin,
    required this.repo, required this.onSaved, super.key});
  @override
  State<PinStockAdjustSheet> createState() => _PinStockState();
}

class _PinStockState extends State<PinStockAdjustSheet> {
  String _tipo = 'ENTRADA';
  final _cantCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() { _cantCtrl.dispose(); _refCtrl.dispose(); _pinCtrl.dispose(); super.dispose(); }

  Future<void> _confirm() async {
    final cant = double.tryParse(_cantCtrl.text);
    if (cant == null || cant <= 0) { setState(() => _error = 'Cantidad debe ser positiva.'); return; }
    final ref = _refCtrl.text.trim();
    if (!widget.isSuperAdmin && ref.isEmpty) { setState(() => _error = 'La referencia es obligatoria.'); return; }
    final pin = _pinCtrl.text.trim();
    if (pin.length != 4) { setState(() => _error = 'Ingresa un PIN de 4 dígitos.'); return; }
    setState(() { _saving = true; _error = null; });
    try {
      final pinResult = await widget.repo.validatePin(pin);
      if (!pinResult.success) {
        if (mounted) setState(() { _saving = false; _error = 'PIN incorrecto. Intenta de nuevo.'; });
        return;
      }
      await widget.repo.adjustStock(widget.productId, StockAdjustPayload(
        sedeId: widget.sedeId, tipo: _tipo, cantidad: cant,
        referencia: ref.isEmpty ? null : ref, superadminPin: pin));
      if (!mounted) return;
      widget.onSaved();
      Navigator.of(context).pop();
    } on AppException catch (e) {
      if (mounted) setState(() { _saving = false; _error = e.message; });
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Ajustar stock: ${widget.productName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      Text('Stock actual: ${widget.currentStock}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
      const SizedBox(height: 12),
      Row(children: [
        for (final t in [('ENTRADA', 'Entrada'), ('SALIDA', 'Salida')])
          Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: GestureDetector(
            onTap: () => setState(() { _tipo = t.$1; _error = null; }),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: _tipo == t.$1 ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _tipo == t.$1 ? Colors.blue : Colors.grey.shade300)),
              child: Text(t.$2, textAlign: TextAlign.center,
                style: TextStyle(fontWeight: _tipo == t.$1 ? FontWeight.bold : FontWeight.normal,
                  color: _tipo == t.$1 ? Colors.blue : Colors.grey)))))),
      ]),
      const SizedBox(height: 12),
      TextField(key: const Key('stock-cantidad'), controller: _cantCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Cantidad')),
      const SizedBox(height: 10),
      TextField(key: const Key('stock-referencia'), controller: _refCtrl,
        decoration: InputDecoration(labelText: widget.isSuperAdmin ? 'Referencia (opcional)' : 'Referencia (obligatoria)')),
      const SizedBox(height: 10),
      TextField(key: const Key('stock-pin'), controller: _pinCtrl, obscureText: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
        decoration: const InputDecoration(labelText: 'PIN de autorización', hintText: '• • • •')),
      if (_error != null) ...[const SizedBox(height: 8),
        Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))],
      const SizedBox(height: 16),
      SizedBox(height: 48, child: ElevatedButton(
        onPressed: _saving ? null : _confirm,
        child: _saving ? const SizedBox(width: 22, height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
        : const Text('Confirmar ajuste'))),
    ]));
}
