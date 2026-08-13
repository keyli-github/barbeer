import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/navigation/app_nav.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/widgets/ds_states.dart';
import '../../data/models/venta_models.dart';
import '../providers/ventas_provider.dart';

/// Subpantalla completa para clasificar el pago de una venta.
/// Uso: AppNav.push(context, ConciliarVentaScreen(venta: v, onDone: ...))
class ConciliarVentaScreen extends ConsumerStatefulWidget {
  final Venta venta;
  final VoidCallback onDone;

  const ConciliarVentaScreen({
    super.key,
    required this.venta,
    required this.onDone,
  });

  @override
  ConsumerState<ConciliarVentaScreen> createState() =>
      _ConciliarVentaScreenState();
}

class _ConciliarVentaScreenState extends ConsumerState<ConciliarVentaScreen> {
  String _estado = 'EFECTIVO';
  String? _etiquetaId;
  final _codOpCtrl = TextEditingController();
  bool _saving = false;
  String? _error;
  List<Etiqueta> _etiquetas = [];
  bool _loadingEtiquetas = false;
  Uint8List? _voucherBytes;
  String? _voucherFilename;

  @override
  void initState() {
    super.initState();
    _loadEtiquetas();
  }

  @override
  void dispose() {
    _codOpCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEtiquetas() async {
    setState(() => _loadingEtiquetas = true);
    try {
      _etiquetas = await ref
          .read(ventasRepositoryProvider)
          .listEtiquetasActivas();
      if (_etiquetas.isNotEmpty) _etiquetaId = _etiquetas.first.id;
    } catch (_) {}
    if (mounted) setState(() => _loadingEtiquetas = false);
  }

  Etiqueta? get _selectedEtiqueta =>
      _etiquetas.where((e) => e.id == _etiquetaId).firstOrNull;

  bool get _requiereComprobante =>
      _selectedEtiqueta?.requiereComprobante ?? false;

  Future<void> _pickVoucher() async {
    final file = await ref.read(voucherImagePickerProvider)();
    if (file == null || !mounted) return;
    setState(() {
      _voucherBytes = file.bytes;
      _voucherFilename = file.filename;
    });
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (_estado == 'BILLETERA' && _etiquetaId == null) {
      setState(() => _error = 'Selecciona una billetera');
      return;
    }
    if (_estado == 'BILLETERA' &&
        _requiereComprobante &&
        _voucherBytes == null) {
      setState(
        () => _error = 'Ingresa el comprobante requerido por esta billetera',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      String? comprobante;
      if (_estado == 'BILLETERA' && _voucherBytes != null) {
        final upload = await ref
            .read(uploadClientProvider)
            .uploadImage(
              bytes: _voucherBytes!,
              filename: _voucherFilename ?? 'comprobante.jpg',
            );
        comprobante = upload.url;
      }
      await ref
          .read(ventasRepositoryProvider)
          .conciliarVenta(
            widget.venta.id,
            estado: _estado,
            etiquetaId: _estado == 'BILLETERA' ? _etiquetaId : null,
            comprobante: comprobante,
            codigoOperacion: _codOpCtrl.text.trim().isNotEmpty
                ? _codOpCtrl.text.trim()
                : null,
          );
      if (!mounted) return;
      widget.onDone();
      DSSuccessOverlay.show(
        context,
        title: _estado == 'EFECTIVO'
            ? 'Marcada como efectivo'
            : 'Pago digital registrado',
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = _friendlyError(e);
      });
    }
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('CONCILIACION_CONGELADA')) {
      return 'La caja fue cerrada. No se puede modificar.';
    }
    if (s.contains('CONCILIACION_YA_CLASIFICADA')) {
      return 'La venta ya fue clasificada.';
    }
    if (s.contains('CODIGO_OPERACION_DUPLICADO')) {
      return 'Código de operación duplicado.';
    }
    if (s.contains('VENTA_ANULADA')) {
      return 'No se puede conciliar una venta anulada.';
    }
    if (s.contains('403')) return 'Sin permiso para esta acción.';
    return 'No se pudo clasificar el pago.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: SubPageAppBar(
        title: 'Clasificar pago',
        subtitle:
            '${widget.venta.codigo} · ${FormatUtils.currency(widget.venta.total)}',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Método selector
            const Text(
              'Método de pago',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MethodChip(
                    label: 'Efectivo',
                    icon: Icons.payments_rounded,
                    selected: _estado == 'EFECTIVO',
                    onTap: () => setState(() => _estado = 'EFECTIVO'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MethodChip(
                    label: 'Billetera',
                    icon: Icons.account_balance_wallet_rounded,
                    selected: _estado == 'BILLETERA',
                    onTap: () => setState(() => _estado = 'BILLETERA'),
                  ),
                ),
              ],
            ),

            // Campos de billetera
            if (_estado == 'BILLETERA') ...[
              const SizedBox(height: 20),
              const Text(
                'Billetera',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              if (_loadingEtiquetas)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  key: ValueKey(_etiquetaId),
                  initialValue: _etiquetaId,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  items: _etiquetas
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.id,
                          child: Text(e.nombre),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _etiquetaId = v),
                ),

              if (_requiereComprobante || _estado == 'BILLETERA') ...[
                const SizedBox(height: 16),
                const Text(
                  'Comprobante / voucher *',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const ValueKey('comprobanteField'),
                  onPressed: _saving ? null : _pickVoucher,
                  icon: Icon(
                    _voucherBytes == null
                        ? Icons.upload_file_rounded
                        : Icons.check_circle_rounded,
                  ),
                  label: Text(_voucherFilename ?? 'Seleccionar imagen'),
                ),
              ],

              const SizedBox(height: 16),
              const Text(
                'Código de operación (opcional)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('codigoOperacionField'),
                controller: _codOpCtrl,
                maxLength: 100,
                decoration: const InputDecoration(
                  hintText: 'Ej. 1234567890',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 16,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
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
                    : const Text(
                        'Confirmar clasificación',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _MethodChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppColors.backgroundAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.borderLight,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 18,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}
