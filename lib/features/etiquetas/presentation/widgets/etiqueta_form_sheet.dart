import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/navigation/app_nav.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/etiqueta.dart';
import '../providers/etiquetas_provider.dart';

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
  late bool _requiereComprobante;
  late EtiquetaTipo _tipo;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.etiqueta != null;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.etiqueta?.nombre ?? '');
    _requiereComprobante = widget.etiqueta?.requiereComprobante ?? true;
    _tipo = widget.etiqueta?.tipo ?? EtiquetaTipo.entrada;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final nombre = _nombreCtrl.text.trim();
    if (nombre.isEmpty) {
      setState(() => _error = 'El nombre es obligatorio');
      return;
    }
    if (widget.etiqueta?.esSistema == true) return;
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final repo = ref.read(etiquetasRepositoryProvider);
      if (_isEdit) {
        await repo.update(
          widget.etiqueta!.id,
          nombre: nombre,
          requiereComprobante: _requiereComprobante,
          tipo: _tipo,
        );
      } else {
        await repo.create(
          nombre: nombre,
          requiereComprobante: _requiereComprobante,
          tipo: _tipo,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEdit ? 'Etiqueta actualizada' : 'Etiqueta creada'),
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
      return 'Ya existe una etiqueta con ese nombre';
    }
    if (s.contains('SocketException') || s.contains('connection')) {
      return 'Sin conexión al servidor';
    }
    return 'No se pudo guardar la etiqueta';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: SubPageAppBar(
        title: _isEdit ? 'Editar etiqueta' : 'Nueva etiqueta',
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
                hintText: 'Ej: Yape, Gastos, Caja chica',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<EtiquetaTipo>(
              initialValue: _tipo,
              decoration: InputDecoration(
                labelText: 'Tipo *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              items: EtiquetaTipo.values
                  .map(
                    (tipo) => DropdownMenuItem(
                      value: tipo,
                      child: Text('${tipo.value} - ${tipo.label}'),
                    ),
                  )
                  .toList(),
              onChanged: (tipo) => setState(() => _tipo = tipo ?? _tipo),
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
              activeThumbColor: AppColors.primary,
            ),
            const SizedBox(height: 16),
            // Error
            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: context.colors.errorLight,
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
                        _isEdit ? 'Guardar cambios' : 'Crear etiqueta',
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
