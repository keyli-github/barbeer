import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/venta_models.dart';

class ComprobanteAnalysisPanel extends StatelessWidget {
  final ComprobanteAnalisis? analysis;
  final Uint8List? bytes;
  final bool analyzing;

  const ComprobanteAnalysisPanel({
    super.key,
    required this.analysis,
    this.bytes,
    this.analyzing = false,
  });

  @override
  Widget build(BuildContext context) {
    final item = analysis;
    return Container(
      key: const Key('receipt-analysis-panel'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border: Border.all(
          color: item?.esApto == true
              ? context.colors.successBorder
              : context.colors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
            child: SizedBox(
              width: 72,
              height: 92,
              child: bytes != null
                  ? Image.memory(bytes!, fit: BoxFit.cover)
                  : item != null
                  ? Image.network(
                      item.thumbnailUrl.isNotEmpty
                          ? item.thumbnailUrl
                          : item.imagenUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _fallback(context),
                    )
                  : _fallback(context),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: item == null
                ? Text(
                    analyzing
                        ? 'Gemini está validando el comprobante.'
                        : 'No se pudo completar el análisis.',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textSecondary,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.entidad ?? 'Entidad no identificada',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      _line(context, 'Monto', item.monto?.toStringAsFixed(2)),
                      _line(context, 'Operación', item.codigoOperacion),
                      _line(
                        context,
                        'Fecha',
                        [
                          item.fechaOperacion,
                          item.horaOperacion,
                        ].whereType<String>().join(' '),
                      ),
                      _line(
                        context,
                        'Billetera',
                        item.etiquetaSugerida?.nombre,
                      ),
                      Text(
                        item.posibleDuplicado
                            ? 'Posible duplicado'
                            : item.esApto
                            ? 'Análisis apto'
                            : 'Requiere revisión',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: item.posibleDuplicado
                              ? context.colors.error
                              : item.esApto
                              ? context.colors.success
                              : context.colors.warning,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _fallback(BuildContext context) => ColoredBox(
    color: context.colors.surfaceAlt,
    child: Icon(
      Icons.receipt_long_outlined,
      color: context.colors.textTertiary,
    ),
  );

  Widget _line(BuildContext context, String label, String? value) => Text(
    '$label: ${value == null || value.isEmpty ? 'No identificado' : value}',
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(fontSize: 11, color: context.colors.textSecondary),
  );
}
