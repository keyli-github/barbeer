import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../data/models/venta_models.dart';
import '../providers/ventas_provider.dart';

/// Bottom sheet para clasificar el pago de una venta.
class ConciliarVentaSheet extends ConsumerStatefulWidget {
  final Venta venta;
  final VoidCallback onDone;

  const ConciliarVentaSheet({
    super.key,
    required this.venta,
    required this.onDone,
  });

  @override
  ConsumerState<ConciliarVentaSheet> createState() =>
      _ConciliarVentaSheetState();
}

class _ConciliarVentaSheetState extends ConsumerState<ConciliarVentaSheet> {
  String _estado = 'EFECTIVO';
  String? _etiquetaId;
  final _compCtrl = TextEditingController();
  final _codOpCtrl = TextEditingController();
  bool _saving = false;
  String? _error;
  List<Etiqueta> _etiquetas = [];
  bool _loadingEtiquetas = false;

  @override
  void initState() {
    super.initState();
    _loadEtiquetas();
  }

  @override
  void dispose() {
    _compCtrl.dispose();
    _codOpCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEtiquetas() async {
    setState(() => _loadingEtiquetas = true);
    try {
      final repo = ref.read(ventasRepositoryProvider);
      _etiquetas = await repo.listEtiquetasActivas();
      if (_etiquetas.isNotEmpty) _etiquetaId = _etiquetas.first.id;
    } catch (_) {}
    if (mounted) setState(() => _loadingEtiquetas = false);
  }

  Etiqueta? get _selectedEtiqueta =>
      _etiquetas.where((e) => e.id == _etiquetaId).firstOrNull;

  Future<void> _submit() async {
    if (_saving) return;
    if (_estado == 'BILLETERA' && _etiquetaId == null) {
      setState(() => _error = 'Selecciona una billetera');
      return;
    }
    if (_estado == 'BILLETERA' &&
        _selectedEtiqueta?.requiereComprobante == true &&
        _compCtrl.text.trim().isEmpty) {
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
      final repo = ref.read(ventasRepositoryProvider);
      await repo.conciliarVenta(
        widget.venta.id,
        estado: _estado,
        etiquetaId: _estado == 'BILLETERA' ? _etiquetaId : null,
        comprobante: _compCtrl.text.trim().isNotEmpty
            ? _compCtrl.text.trim()
            : null,
        codigoOperacion: _codOpCtrl.text.trim().isNotEmpty
            ? _codOpCtrl.text.trim()
            : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _estado == 'EFECTIVO'
                ? 'Marcada como efectivo'
                : 'Pago digital registrado',
          ),
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
    if (s.contains('CONCILIACION_CONGELADA')) {
      return 'La caja fue cerrada. No se puede modificar.';
    }
    if (s.contains('CONCILIACION_YA_CLASIFICADA')) {
      return 'La venta ya fue clasificada por otro usuario.';
    }
    if (s.contains('CODIGO_OPERACION_DUPLICADO')) {
      return 'Este código de operación ya fue registrado.';
    }
    if (s.contains('PERMISO_INSUFICIENTE')) {
      return 'No tienes permiso para corregir esta clasificación.';
    }
    if (s.contains('VENTA_ANULADA')) {
      return 'No se puede conciliar una venta anulada.';
    }
    if (s.contains('403')) return 'No tienes permiso para esta acción.';
    if (s.contains('SocketException') || s.contains('connection')) {
      return 'Sin conexión al servidor.';
    }
    return 'No se pudo clasificar el pago.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: const BoxDecoration(
        color: AppColors.backgroundAlt,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle + header
          Container(
            color: AppColors.background,
            child: Column(
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Clasificar pago',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              '${widget.venta.codigo} · ${FormatUtils.currency(widget.venta.total)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(context),
                        color: AppColors.textTertiary,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Estado selector
                  Row(
                    children: [
                      _MethodChip(
                        label: 'Efectivo',
                        icon: Icons.payments_rounded,
                        selected: _estado == 'EFECTIVO',
                        onTap: () => setState(() => _estado = 'EFECTIVO'),
                      ),
                      const SizedBox(width: 10),
                      _MethodChip(
                        label: 'Billetera',
                        icon: Icons.account_balance_wallet_rounded,
                        selected: _estado == 'BILLETERA',
                        onTap: () => setState(() => _estado = 'BILLETERA'),
                      ),
                    ],
                  ), // Row
                  const SizedBox(height: 16),
                  // Billetera fields
                  if (_estado == 'BILLETERA') ...[
                    if (_loadingEtiquetas)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else ...[
                      const Text(
                        'Billetera *',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        key: ValueKey(_etiquetaId),
                        initialValue: _etiquetaId,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
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
                      const SizedBox(height: 12),
                      if (_selectedEtiqueta?.requiereComprobante == true) ...[
                        TextField(
                          key: const ValueKey('comprobanteField'),
                          controller: _compCtrl,
                          maxLength: 500,
                          decoration: InputDecoration(
                            labelText: 'Comprobante / voucher',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        key: const ValueKey('codigoOperacionField'),
                        controller: _codOpCtrl,
                        maxLength: 100,
                        decoration: InputDecoration(
                          labelText: 'Código de operación (opcional)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
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
                          : const Text(
                              'Confirmar',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
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
      ),
    );
  }
}
