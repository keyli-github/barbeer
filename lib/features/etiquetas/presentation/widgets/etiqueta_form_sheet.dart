import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/navigation/app_nav.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_feedback.dart';
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
      AppFeedback.success(
        context,
        _isEdit ? 'Etiqueta actualizada' : 'Etiqueta creada',
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
            // Indicador de estado activo/inactivo (solo en modo edición)
            if (_isEdit) ...[
              _EstadoIndicator(activo: widget.etiqueta!.activo),
              const SizedBox(height: 16),
            ],
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
            // RequiereComprobante — switch con diseño consistente con la app
            GestureDetector(
              onTap: () =>
                  setState(() => _requiereComprobante = !_requiereComprobante),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _requiereComprobante
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : context.colors.backgroundAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _requiereComprobante
                        ? AppColors.primary.withValues(alpha: 0.35)
                        : context.colors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Requiere comprobante',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _requiereComprobante
                                  ? AppColors.primary
                                  : context.colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _requiereComprobante
                                ? 'El cajero debe adjuntar voucher al clasificar'
                                : 'Sin voucher obligatorio',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.colors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _requiereComprobante,
                      onChanged: (v) =>
                          setState(() => _requiereComprobante = v),
                      activeColor: AppColors.primary,
                      activeTrackColor: AppColors.primary.withValues(
                        alpha: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
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

/// Indicador de estado activo/inactivo para el encabezado del form de edición.
/// Solo lectura — para cambiar el estado se usa el botón de toggle en la lista.
class _EstadoIndicator extends StatelessWidget {
  final bool activo;
  const _EstadoIndicator({required this.activo});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: activo ? AppColors.success : context.colors.textTertiary,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 8),
      Text(
        activo ? 'Etiqueta activa' : 'Etiqueta inactiva',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: activo ? AppColors.success : context.colors.textTertiary,
        ),
      ),
      const Spacer(),
      if (!activo)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: context.colors.backgroundAlt,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(color: context.colors.border),
          ),
          child: Text(
            'INACTIVA',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: context.colors.textTertiary,
            ),
          ),
        ),
    ],
  );
}
