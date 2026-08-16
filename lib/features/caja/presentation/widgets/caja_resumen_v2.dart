// Widgets extraídos del resumen Caja V2 para mantener caja_screen.dart manejable.

import 'package:flutter/material.dart';

import 'package:barbeer/core/theme/app_colors.dart';
import 'package:barbeer/core/theme/app_dimensions.dart';
import '../../data/caja_repository.dart';

// ── Helpers locales ──────────────────────────────────────────────────────────

String _money(double value) => 'S/ ${value.toStringAsFixed(2)}';

// ── CajaResumenPrincipalV2 ───────────────────────────────────────────────────

/// Métricas de 4 tarjetas + card "Detalle del turno" + alerta de ventas pendientes.
class CajaResumenPrincipalV2 extends StatelessWidget {
  final CajaResumenV2 resumen;
  final double montoApertura;

  const CajaResumenPrincipalV2({
    super.key,
    required this.resumen,
    required this.montoApertura,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MetricCard(
                  width: width,
                  label: 'Apertura',
                  value: montoApertura,
                  icon: Icons.play_circle_outline_rounded,
                  color: context.colors.textSecondary,
                ),
                _MetricCard(
                  width: width,
                  label: 'Ventas neto',
                  value: resumen.totalVentasNeto,
                  icon: Icons.south_west_rounded,
                  color: AppColors.success,
                ),
                _MetricCard(
                  width: width,
                  label: 'Digital neto',
                  value: resumen.totalDigitalNeto,
                  icon: Icons.north_east_rounded,
                  color: AppColors.primary,
                ),
                _MetricCard(
                  width: width,
                  label: 'Efectivo esperado',
                  value: resumen.efectivoEsperado,
                  icon: Icons.account_balance_rounded,
                  color: AppColors.warning,
                ),
              ],
            );
          },
        ),
        if (resumen.ventasPendientes > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.warningLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.hourglass_top_rounded,
                  size: 16,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${resumen.ventasPendientes} venta(s) sin clasificar '
                    'como efectivo o billetera.',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── CajaVendedoraTable ───────────────────────────────────────────────────────

/// Tabla de ventas agrupadas por vendedora.
class CajaVendedoraTable extends StatelessWidget {
  final List<Map<String, dynamic>> porVendedora;

  const CajaVendedoraTable({super.key, required this.porVendedora});

  @override
  Widget build(BuildContext context) {
    if (porVendedora.isEmpty) return const SizedBox.shrink();
    return _CajaDataTable(
      title: 'Ventas por vendedora',
      headers: const ['Vendedora', 'Ventas', 'Total'],
      rows: porVendedora
          .map(
            (v) => [
              v['username'] as String? ??
                  (v['vendedora'] is Map
                      ? (v['vendedora'] as Map)['username'] as String? ?? ''
                      : ''),
              '${v['cantidadVentas'] ?? 0}',
              _money((v['totalVentas'] as num?)?.toDouble() ?? 0),
            ],
          )
          .toList(),
    );
  }
}

// ── CajaProductosTable ───────────────────────────────────────────────────────

/// Tabla de unidades y montos por producto.
class CajaProductosTable extends StatelessWidget {
  final List<Map<String, dynamic>> resumenProductos;

  const CajaProductosTable({super.key, required this.resumenProductos});

  @override
  Widget build(BuildContext context) {
    if (resumenProductos.isEmpty) return const SizedBox.shrink();
    return _CajaDataTable(
      title: 'Resumen de productos',
      headers: const ['Código', 'Producto', 'Cant.', 'Total'],
      rows: resumenProductos
          .map(
            (p) => [
              p['codigo'] as String? ?? '',
              p['nombre'] as String? ?? '',
              '${p['cantidadTotal'] ?? 0}',
              _money((p['montoTotal'] as num?)?.toDouble() ?? 0),
            ],
          )
          .toList(),
    );
  }
}

// ── _CajaDataTable (privado) ─────────────────────────────────────────────────

/// Tabla responsiva: distribuye el ancho disponible entre las columnas
/// usando pesos, en lugar de un DataTable con scroll horizontal que se ve
/// pequeño y desalineado en pantallas móviles.
class _CajaDataTable extends StatelessWidget {
  final String title;
  final List<String> headers;
  final List<List<String>> rows;

  const _CajaDataTable({
    required this.title,
    required this.headers,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: context.colors.textSecondary,
              ),
            ),
          ),
          const Divider(height: 1),
          // Cabecera
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: Row(
              children: List.generate(headers.length, (index) {
                return Expanded(
                  flex: _flexFor(index),
                  child: Text(
                    headers[index].toUpperCase(),
                    textAlign: _alignFor(index, isHeader: true),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: context.colors.textTertiary,
                    ),
                  ),
                );
              }),
            ),
          ),
          const Divider(height: 1),
          // Filas
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                children: List.generate(row.length, (index) {
                  return Expanded(
                    flex: _flexFor(index),
                    child: Text(
                      row[index],
                      textAlign: _alignFor(index),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.textPrimary,
                      ),
                    ),
                  );
                }),
              ),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // Pesos por posición para que cada tabla ocupe el ancho completo.
  int _flexFor(int index) {
    // 4 columnas: Código / Producto / Cant. / Total
    if (headers.length == 4) {
      return switch (index) {
        0 => 1,
        1 => 2,
        2 => 1,
        _ => 1,
      };
    }
    // 3 columnas: Vendedora / Ventas / Total
    return switch (index) {
      0 => 2,
      1 => 1,
      _ => 1,
    };
  }

  TextAlign _alignFor(int index, {bool isHeader = false}) {
    // Columna numérica (última) alineada a la derecha
    if (index == headers.length - 1) return TextAlign.right;
    if (headers.length == 4 && index == 2) return TextAlign.center;
    return TextAlign.left;
  }
}

// ── _MetricCard (privado) ────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  final double width;
  final String label;
  final double value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.colors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _money(value),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );
}
