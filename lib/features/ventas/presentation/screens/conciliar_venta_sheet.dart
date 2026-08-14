import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../data/models/venta_models.dart';
import '../../data/ventas_repository.dart';
import '../providers/ventas_provider.dart';
import '../widgets/comprobante_analysis_panel.dart';

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
  final _codOpCtrl = TextEditingController();
  bool _saving = false;
  String? _error;
  List<Etiqueta> _etiquetas = [];
  bool _loadingEtiquetas = false;
  Uint8List? _voucherBytes;
  String? _voucherFilename;
  ComprobanteAnalisis? _comprobanteAnalisis;
  bool _analizandoComprobante = false;
  int _voucherRequestToken = 0;
  late final VentasRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = ref.read(ventasRepositoryProvider);
    _loadEtiquetas();
  }

  @override
  void dispose() {
    _voucherRequestToken++;
    _cancelAnalysis(_comprobanteAnalisis);
    _codOpCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEtiquetas() async {
    setState(() => _loadingEtiquetas = true);
    try {
      final repo = ref.read(ventasRepositoryProvider);
      _etiquetas = await repo.listEtiquetasActivas(sedeId: widget.venta.sedeId);
      if (_etiquetas.isNotEmpty) _etiquetaId = _etiquetas.first.id;
    } catch (_) {}
    if (mounted) setState(() => _loadingEtiquetas = false);
  }

  Etiqueta? get _selectedEtiqueta =>
      _etiquetas.where((e) => e.id == _etiquetaId).firstOrNull;

  Future<void> _pickVoucher() async {
    final token = ++_voucherRequestToken;
    try {
      final file = await ref.read(voucherImagePickerProvider)();
      if (file == null || !mounted || token != _voucherRequestToken) return;
      await _cancelAnalysis(_comprobanteAnalisis);
      if (!mounted || token != _voucherRequestToken) return;
      setState(() {
        _voucherBytes = file.bytes;
        _voucherFilename = file.filename;
        _comprobanteAnalisis = null;
        _analizandoComprobante = true;
        _error = null;
      });
      final analysis = await _repository.analizarComprobante(
        bytes: file.bytes,
        filename: file.filename,
        sedeId: widget.venta.sedeId,
      );
      if (!mounted || token != _voucherRequestToken) {
        await _repository
            .cancelarComprobanteAnalisis(analysis.id)
            .catchError((_) {});
        return;
      }
      setState(() {
        _comprobanteAnalisis = analysis;
        _analizandoComprobante = false;
        final suggestedId = analysis.etiquetaSugerida?.id;
        if (_etiquetas.any((item) => item.id == suggestedId)) {
          _etiquetaId = suggestedId;
        }
        _error = comprobanteAnalysisError(
          analysis: analysis,
          total: widget.venta.total,
          required: _selectedEtiqueta?.requiereComprobante ?? false,
          selectedEtiquetaId: _etiquetaId,
        );
      });
    } catch (e) {
      if (!mounted || token != _voucherRequestToken) return;
      setState(() {
        _analizandoComprobante = false;
        _comprobanteAnalisis = null;
        _error = e is FormatException
            ? e.message
            : 'No se pudo analizar el comprobante';
      });
    }
  }

  void _clearVoucherAnalysis() {
    _voucherRequestToken++;
    _cancelAnalysis(_comprobanteAnalisis);
    _voucherBytes = null;
    _voucherFilename = null;
    _comprobanteAnalisis = null;
    _analizandoComprobante = false;
  }

  Future<void> _cancelAnalysis(ComprobanteAnalisis? analysis) async {
    if (analysis == null || analysis.id.isEmpty) return;
    await _repository
        .cancelarComprobanteAnalisis(analysis.id)
        .catchError((_) {});
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (_estado == 'BILLETERA' && _etiquetaId == null) {
      setState(() => _error = 'Selecciona una billetera');
      return;
    }
    if (_estado == 'BILLETERA') {
      if (_analizandoComprobante) {
        setState(() => _error = 'Espera a que termine el análisis');
        return;
      }
      final analysisError = comprobanteAnalysisError(
        analysis: _comprobanteAnalisis,
        total: widget.venta.total,
        required: _selectedEtiqueta?.requiereComprobante ?? false,
        selectedEtiquetaId: _etiquetaId,
      );
      if (analysisError != null) {
        setState(() => _error = analysisError);
        return;
      }
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
        comprobanteAnalisisId: _estado == 'BILLETERA'
            ? _comprobanteAnalisis?.id
            : null,
        codigoOperacion:
            _comprobanteAnalisis == null && _codOpCtrl.text.trim().isNotEmpty
            ? _codOpCtrl.text.trim()
            : null,
      );
      if (!mounted) return;
      _comprobanteAnalisis = null;
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
      decoration: BoxDecoration(
        color: context.colors.backgroundAlt,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle + header
          Container(
            color: context.colors.background,
            child: Column(
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.colors.border,
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
                            Text(
                              'Clasificar pago',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: context.colors.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              '${widget.venta.codigo} · ${FormatUtils.currency(widget.venta.total)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(context),
                        color: context.colors.textTertiary,
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: context.colors.border),
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
                        onTap: () => setState(() {
                          _estado = 'EFECTIVO';
                          _clearVoucherAnalysis();
                        }),
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
                        onChanged: (v) => setState(() {
                          if (_etiquetaId != v) _clearVoucherAnalysis();
                          _etiquetaId = v;
                          _error = null;
                        }),
                      ),
                      const SizedBox(height: 12),
                      if (_estado == 'BILLETERA') ...[
                        OutlinedButton.icon(
                          key: const ValueKey('comprobanteField'),
                          onPressed: _saving ? null : _pickVoucher,
                          icon: Icon(
                            _analizandoComprobante
                                ? Icons.hourglass_top_rounded
                                : _comprobanteAnalisis == null
                                ? Icons.upload_file_rounded
                                : Icons.check_circle_rounded,
                          ),
                          label: Text(
                            _analizandoComprobante
                                ? 'Analizando comprobante...'
                                : _voucherFilename ??
                                      (_selectedEtiqueta?.requiereComprobante ==
                                              true
                                          ? 'Seleccionar comprobante *'
                                          : 'Seleccionar comprobante (opcional)'),
                          ),
                        ),
                        if (_voucherBytes != null ||
                            _comprobanteAnalisis != null) ...[
                          const SizedBox(height: 8),
                          ComprobanteAnalysisPanel(
                            analysis: _comprobanteAnalisis,
                            bytes: _voucherBytes,
                            analyzing: _analizandoComprobante,
                          ),
                        ],
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
                : context.colors.backgroundAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : context.colors.borderLight,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? AppColors.primary
                    : context.colors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? AppColors.primary
                      : context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
