import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/navigation/app_nav.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/widgets/app_feedback.dart';
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
  late String _estado;
  String? _etiquetaId;
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
  // Comprobantes adicionales ya confirmados (APTO).
  final List<ComprobanteAnalisis> _comprobantesAdicionales = [];
  // Diferencia cubierta en efectivo.
  bool _pagoRestoEfectivo = false;

  /// true cuando la venta YA está clasificada como BILLETERA.
  /// En ese caso no se puede volver a clasificar como billetera (solo → efectivo).
  bool get _esBilleteraActual =>
      widget.venta.conciliacion?.estado == EstadoConciliacion.billetera;

  @override
  void initState() {
    super.initState();
    _repository = ref.read(ventasRepositoryProvider);
    // Pre-seleccionar el método actual si ya fue clasificado (caso Corregir)
    final conc = widget.venta.conciliacion;
    if (conc?.estado == EstadoConciliacion.billetera) {
      _estado = 'BILLETERA';
      _etiquetaId = conc?.etiquetaId;
    } else if (conc?.estado == EstadoConciliacion.efectivo) {
      _estado = 'EFECTIVO';
    } else {
      _estado = 'EFECTIVO'; // PENDIENTE: default efectivo
    }
    _loadEtiquetas();
  }

  @override
  void dispose() {
    _voucherRequestToken++;
    _cancelAnalysis(_comprobanteAnalisis);
    for (final a in _comprobantesAdicionales) {
      _cancelAnalysis(a);
    }
    super.dispose();
  }

  Future<void> _loadEtiquetas() async {
    setState(() => _loadingEtiquetas = true);
    try {
      _etiquetas = await ref
          .read(ventasRepositoryProvider)
          .listEtiquetasActivas(sedeId: widget.venta.sedeId);
      // No auto-seleccionar: el usuario elige la billetera explícitamente.
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
        final suggested = analysis.etiquetaSugerida;
        if (suggested != null) {
          _etiquetaId = suggested.id;
          // Asegura que la billetera detectada por Gemini aparezca en el
          // selector aunque la carga de etiquetas haya fallado en remoto
          if (!_etiquetas.any((item) => item.id == suggested.id)) {
            _etiquetas = [
              ..._etiquetas,
              Etiqueta(
                id: suggested.id,
                nombre: suggested.nombre,
                activo: true,
                requiereComprobante: true,
                esSistema: false,
                tipo: 'ENTRADA',
                orden: 999,
              ),
            ];
          }
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
      // Collect all comprobante IDs (primary + additional confirmed ones).
      final allAnalysisIds = [
        if (_estado == 'BILLETERA' && _comprobanteAnalisis?.id != null)
          _comprobanteAnalisis!.id,
        ..._comprobantesAdicionales.map((a) => a.id),
      ];
      await ref
          .read(ventasRepositoryProvider)
          .conciliarVenta(
            widget.venta.id,
            estado: _estado,
            etiquetaId: _estado == 'BILLETERA' ? _etiquetaId : null,
            comprobanteAnalisisIds: _estado == 'BILLETERA' &&
                    allAnalysisIds.isNotEmpty
                ? allAnalysisIds
                : null,
            pagoRestoEfectivo: _estado == 'BILLETERA' && _pagoRestoEfectivo
                ? true
                : null,
          );
      if (!mounted) return;
      _comprobanteAnalisis = null;
      _comprobantesAdicionales.clear();
      widget.onDone();
      AppFeedback.success(
        context,
        _estado == 'EFECTIVO' ? 'Marcada como efectivo' : 'Pago digital registrado',
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
                    // Si ya está clasificada como billetera no se puede
                    // volver a seleccionar: solo se puede cambiar a efectivo
                    enabled: !_esBilleteraActual,
                    onTap: _esBilleteraActual
                        ? null
                        : () => setState(() => _estado = 'BILLETERA'),
                  ),
                ),
              ],
            ),

            // Campos de billetera
            if (_estado == 'BILLETERA') ...[
              const SizedBox(height: 20),
              _SectionLabel(
                '1 · Billetera / banco',
                subtitle: 'Selecciona la billetera donde se recibió el pago.',
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
                // Dropdown estable (sin ValueKey cambiante): siempre abre y
                // refleja el valor auto-sugerido por el análisis de Gemini.
                InputDecorator(
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      key: const ValueKey('billeteraField'),
                      value: _etiquetas.any((e) => e.id == _etiquetaId)
                          ? _etiquetaId
                          : null,
                      isExpanded: true,
                      isDense: true,
                      hint: const Text('Selecciona una billetera…'),
                      items: _etiquetas
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.id,
                              child: Text(e.nombre),
                            ),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (v) => setState(() {
                                if (_etiquetaId != v) _clearVoucherAnalysis();
                                _etiquetaId = v;
                                _error = null;
                              }),
                    ),
                  ),
                ),

              if (_estado == 'BILLETERA') ...[
                const SizedBox(height: 16),
                _SectionLabel(
                  '2 · Comprobante (Gemini)',
                  subtitle: _requiereComprobante
                      ? 'Sube la captura del pago para validar el monto antes de confirmar.'
                      : 'Opcional: sube la captura del pago para validar el monto.',
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const ValueKey('comprobanteField'),
                  onPressed: _saving ? null : _pickVoucher,
                  icon: _analizandoComprobante
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _comprobanteAnalisis?.esApto == true
                              ? Icons.verified_rounded
                              : Icons.add_photo_alternate_outlined,
                          size: 17,
                        ),
                  label: Text(
                    _analizandoComprobante
                        ? 'Analizando comprobante...'
                        : _voucherFilename ??
                              (_requiereComprobante
                                  ? 'Seleccionar comprobante *'
                                  : 'Seleccionar comprobante (opcional)'),
                    overflow: TextOverflow.ellipsis,
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
                // Comprobantes adicionales confirmados
                if (_comprobantesAdicionales.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Column(
                    children: _comprobantesAdicionales
                        .asMap()
                        .entries
                        .map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Container(
                              decoration: BoxDecoration(
                                color: context.colors.successLight,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: context.colors.successBorder,
                                ),
                              ),
                              child: ListTile(
                                dense: true,
                                leading: const Icon(
                                  Icons.verified_rounded,
                                  size: 18,
                                  color: AppColors.success,
                                ),
                                title: Text(
                                  entry.value.entidad ??
                                      'Comprobante ${entry.key + 1}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  entry.value.monto != null
                                      ? FormatUtils.currency(entry.value.monto!)
                                      : 'Monto no identificado',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                  ),
                                  onPressed: _saving
                                      ? null
                                      : () {
                                          _cancelAnalysis(entry.value);
                                          setState(
                                            () => _comprobantesAdicionales
                                                .removeAt(entry.key),
                                          );
                                        },
                                  tooltip: 'Quitar comprobante',
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                // Botón para agregar otro comprobante
                if (_comprobanteAnalisis?.esApto == true && !_saving) ...[
                  const SizedBox(height: 4),
                  TextButton.icon(
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                    label: const Text('Agregar otro comprobante'),
                    onPressed: () {
                      setState(() {
                        _comprobantesAdicionales.add(_comprobanteAnalisis!);
                        _comprobanteAnalisis = null;
                        _voucherBytes = null;
                        _voucherFilename = null;
                      });
                    },
                  ),
                ],
                // Toggle pagoRestoEfectivo (vuelto)
                if (_comprobantesAdicionales.isNotEmpty ||
                    _comprobanteAnalisis?.monto != null) ...[
                  const SizedBox(height: 8),
                  CheckboxListTile.adaptive(
                    key: const Key('pago-resto-efectivo-conciliar'),
                    value: _pagoRestoEfectivo,
                    onChanged: _saving
                        ? null
                        : (v) =>
                              setState(() => _pagoRestoEfectivo = v ?? false),
                    title: const Text(
                      'La diferencia se cobra en efectivo',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'El resto no cubierto por comprobantes se registra como efectivo.',
                      style: TextStyle(fontSize: 11),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ],
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
  final bool enabled;
  final VoidCallback? onTap;
  const _MethodChip({
    required this.label,
    required this.icon,
    required this.selected,
    this.enabled = true,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: !enabled
            ? context.colors.backgroundAlt.withValues(alpha: 0.4)
            : selected
                ? AppColors.primary.withValues(alpha: 0.08)
                : context.colors.backgroundAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: !enabled
              ? context.colors.borderLight.withValues(alpha: 0.4)
              : selected
                  ? AppColors.primary
                  : context.colors.borderLight,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 18,
            color: !enabled
                ? context.colors.textSecondary.withValues(alpha: 0.4)
                : selected
                    ? AppColors.primary
                    : context.colors.textSecondary,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: !enabled
                    ? context.colors.textSecondary.withValues(alpha: 0.4)
                    : selected
                        ? AppColors.primary
                        : context.colors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _SectionLabel(this.title, {this.subtitle});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: context.colors.textPrimary,
        ),
      ),
      if (subtitle != null) ...[
        const SizedBox(height: 2),
        Text(
          subtitle!,
          style: TextStyle(
            fontSize: 11.5,
            height: 1.35,
            color: context.colors.textTertiary,
          ),
        ),
      ],
    ],
  );
}
