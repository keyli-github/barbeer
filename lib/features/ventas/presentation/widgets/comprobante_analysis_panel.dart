import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/venta_models.dart';

/// Panel con la vista previa del comprobante y los datos extraídos por Gemini.
///
/// La miniatura se puede tocar para abrir el comprobante en tamaño completo
/// (con zoom), de modo que el usuario pueda verificar la imagen antes de
/// confirmar la clasificación.
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
          _Thumbnail(
            bytes: bytes,
            analysis: item,
            onTap: () => _showFullImage(context),
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
                      InkWell(
                        onTap: () => _showFullImage(context),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Ver comprobante',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: context.colors.textTertiary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _showFullImage(BuildContext context) {
    final item = analysis;
    final hasImage = bytes != null ||
        (item != null &&
            (item.imagenUrl.isNotEmpty || item.thumbnailUrl.isNotEmpty));
    if (!hasImage) return;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                maxScale: 5,
                child: Image(
                  image: bytes != null
                      ? MemoryImage(bytes!)
                      : NetworkImage(
                          item!.imagenUrl.isNotEmpty
                              ? item.imagenUrl
                              : item.thumbnailUrl,
                        ),
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => ColoredBox(
                    color: context.colors.surfaceAlt,
                    child: Icon(
                      Icons.receipt_long_outlined,
                      color: context.colors.textTertiary,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _line(BuildContext context, String label, String? value) => Text(
    '$label: ${value == null || value.isEmpty ? 'No identificado' : value}',
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(fontSize: 11, color: context.colors.textSecondary),
  );
}

class _Thumbnail extends StatelessWidget {
  final Uint8List? bytes;
  final ComprobanteAnalisis? analysis;
  final VoidCallback onTap;

  const _Thumbnail({
    required this.bytes,
    required this.analysis,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final item = analysis;
    final Widget image = bytes != null
        ? Image.memory(bytes!, fit: BoxFit.cover)
        : item != null
        ? Image.network(
            item.thumbnailUrl.isNotEmpty ? item.thumbnailUrl : item.imagenUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fallback(context),
          )
        : _fallback(context);

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
            child: SizedBox(width: 72, height: 92, child: image),
          ),
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.zoom_in_rounded,
                size: 13,
                color: Colors.white,
              ),
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
}
