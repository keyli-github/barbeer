import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/navigation/app_nav.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../ventas/data/models/venta_models.dart';
import '../../../ventas/presentation/providers/ventas_provider.dart';

/// Formulario para crear o editar una billetera digital.
class EtiquetaFormSheet extends ConsumerStatefulWidget {
  final Etiqueta? etiqueta;
  final VoidCallback onDone;

  const EtiquetaFormSheet({super.key, this.etiqueta, required this.onDone});

  @override
  ConsumerState<EtiquetaFormSheet> createState() => _EtiquetaFormSheetState();
}

class _EtiquetaFormSheetState extends ConsumerState<EtiquetaFormSheet> {
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _ordenCtrl;
  late bool _requiereComprobante;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.etiqueta != null;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.etiqueta?.nombre ?? '');
    _ordenCtrl = TextEditingController(
      text: (widget.etiqueta?.orden ?? 0).toString(),
    );
    _requiereComprobante = widget.etiqueta?.requiereComprobante ?? true;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _ordenCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final nombre = _nombreCtrl.text.trim();
    if (nombre.isEmpty) {
      setState(() => _error = 'El nombre es obligatorio');
      return;
    }
    final orden = int.tryParse(_ordenCtrl.text.trim());
    if (orden == null || orden < 0) {
      setState(() => _error = 'El orden debe ser un número ≥ 0');
      return;
    }
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final repo = ref.read(ventasRepositoryProvider);
      if (_isEdit) {
        await repo.updateEtiqueta(
          widget.etiqueta!.id,
          nombre: nombre,
          requiereComprobante: _requiereComprobante,
          orden: orden,
        );
      } else {
        await repo.createEtiqueta(
          nombre: nombre,
          requiereComprobante: _requiereComprobante,
          orden: orden,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEdit ? 'Billetera actualizada' : 'Billetera creada'),
          backgroundColor: AppColors.success,
        ),
      );
      widget.onDone();
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _friendlyError(e);
      });
    }
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('403')) return 'No tienes permiso para esta acción';
    if (s.contains('409') ||
        s.contains('duplicate') ||
        s.contains('ya existe')) {
      return 'Ya existe una billetera con ese nombre';
    }
    if (s.contains('SocketException') || s.contains('connection')) {
      return 'Sin conexión al servidor';
    }
    return 'No se pudo guardar la billetera';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: SubPageAppBar(
        title: _isEdit ? 'Editar billetera' : 'Nueva billetera',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nombre
            TextField(
              controller: _nombreCtrl,
              decoration: InputDecoration(
                labelText: 'Nombre *',
                hintText: 'Ej: Yape, Plin, Agora',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            // Orden
            TextField(
              controller: _ordenCtrl,
              decoration: InputDecoration(
                labelText: 'Orden de visualización',
                hintText: '0',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            // RequiereComprobante
            SwitchListTile(
              value: _requiereComprobante,
              onChanged: (v) => setState(() => _requiereComprobante = v),
              title: const Text(
                'Requiere comprobante',
                style: TextStyle(fontSize: 14),
              ),
              subtitle: const Text(
                'El cajero deberá adjuntar voucher al clasificar',
                style: TextStyle(fontSize: 11),
              ),
              dense: true,
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.primary,
            ),
            const SizedBox(height: 16),
            // Error
            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(fontSize: 12, color: AppColors.error),
                ),
              ),
            // Submit
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isEdit ? 'Guardar cambios' : 'Crear billetera',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
