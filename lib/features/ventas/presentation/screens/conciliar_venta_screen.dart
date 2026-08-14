import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/navigation/app_nav.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/widgets/ds_states.dart';
import '../../data/models/venta_models.dart';
import '../../data/ventas_repository.dart';
import '../providers/ventas_provider.dart';
import '../widgets/comprobante_analysis_panel.dart';

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
      _etiquetas = await ref
          .read(ventasRepositoryProvider)
          .listEtiquetasActivas(sedeId: widget.venta.sedeId);
      if (_etiquetas.isNotEmpty) _etiquetaId = _etiquetas.first.id;
    } catch (_) {}
    if (mounted) setState(() => _loadingEtiquetas = false);
  }

  Etiqueta? get _selectedEtiqueta =>
      _etiquetas.where((e) => e.id == _etiquetaId).firstOrNull;

  bool get _requiereComprobante =>
      _selectedEtiqueta?.requiereComprobante ?? false;

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
          required: _requiereComprobante,
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
        required: _requiereComprobante,
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
      await ref
          .read(ventasRepositoryProvider)
          .conciliarVenta(
            widget.venta.id,
            estado: _estado,
            etiquetaId: _estado == 'BILLETERA' ? _etiquetaId : null,
            comprobanteAnalisisId: _estado == 'BILLETERA'
                ? _comprobanteAnalisis?.id
                : null,
            codigoOperacion:
                _comprobanteAnalisis == null &&
                    _codOpCtrl.text.trim().isNotEmpty
                ? _codOpCtrl.text.trim()
                : null,
          );
      if (!mounted) return;
      _comprobanteAnalisis = null;
      widget.onDone();
      DSSuccessOverlay.show(
        context,
        title: _estado == 'EFECTIVO'
            ? 'Marcada como efectivo'
            : 'Pago digital registrado',
      );
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
      backgroundColor: context.colors.surface,
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
            Text(
              'Método de pago',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: context.colors.textSecondary,
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
                    onTap: () => setState(() {
                      _estado = 'EFECTIVO';
                      _clearVoucherAnalysis();
                    }),
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
              Text(
                'Billetera',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: context.colors.textSecondary,
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
                  onChanged: (v) => setState(() {
                    if (_etiquetaId != v) _clearVoucherAnalysis();
                    _etiquetaId = v;
                    _error = null;
                  }),
                ),

              if (_estado == 'BILLETERA') ...[
                const SizedBox(height: 16),
                Text(
                  _requiereComprobante
                      ? 'Comprobante / voucher *'
                      : 'Comprobante / voucher (opcional)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: context.colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
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
                        : _voucherFilename ?? 'Seleccionar imagen',
                  ),
                ),
                if (_voucherBytes != null || _comprobanteAnalisis != null) ...[
                  const SizedBox(height: 8),
                  ComprobanteAnalysisPanel(
                    analysis: _comprobanteAnalisis,
                    bytes: _voucherBytes,
                    analyzing: _analizandoComprobante,
                  ),
                ],
              ],

              const SizedBox(height: 16),
              Text(
                'Código de operación (opcional)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: context.colors.textSecondary,
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
                  color: context.colors.errorLight,
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
            color: selected ? AppColors.primary : context.colors.textSecondary,
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
  );
}
