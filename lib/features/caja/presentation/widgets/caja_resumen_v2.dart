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
                  color: AppColors.textSecondary,
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
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Detalle del turno',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              _InfoRow('Ventas activas', '${resumen.cantidadVentas}'),
              _InfoRow('Ventas anuladas', '${resumen.cantidadAnuladas}'),
              _InfoRow('Total ventas bruto', _money(resumen.totalVentasBruto)),
              _InfoRow('Anulaciones', _money(resumen.totalAnulaciones)),
              _InfoRow(
                'Total digital bruto',
                _money(resumen.totalDigitalBruto),
              ),
              if (resumen.ventasPendientes > 0)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(8),
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
          ),
        ),
      ],
    );
  }
}

// ── CajaBilleteraCard ────────────────────────────────────────────────────────

/// Desglose de ventas clasificadas por billetera (porBilletera).
/// Solo se muestra cuando la lista no está vacía.
class CajaBilleteraCard extends StatelessWidget {
  final List<Map<String, dynamic>> porBilletera;

  const CajaBilleteraCard({super.key, required this.porBilletera});

  @override
  Widget build(BuildContext context) {
    if (porBilletera.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Text(
              'Desglose por billetera',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const Divider(height: 1),
          ...porBilletera.map((b) {
            final nombre =
                (b['conciliacion'] as Map?)?['etiqueta']?['nombre']
                    as String? ??
                b['conciliacionId'] as String? ??
                'Sin etiqueta';
            final total = (b['total'] as num?)?.toDouble() ?? 0;
            final cantidad = (b['cantidad'] as num?)?.toInt() ?? 0;
            return ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              title: Text(nombre, style: const TextStyle(fontSize: 12)),
              trailing: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _money(total),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    '$cantidad venta(s)',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
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
              v['username'] as String? ?? '',
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const Divider(height: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 32,
              dataRowMinHeight: 36,
              dataRowMaxHeight: 36,
              horizontalMargin: 12,
              columnSpacing: 16,
              headingTextStyle: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textTertiary,
              ),
              dataTextStyle: const TextStyle(fontSize: 11),
              columns: headers
                  .map((h) => DataColumn(label: Text(h.toUpperCase())))
                  .toList(),
              rows: rows
                  .map(
                    (row) => DataRow(
                      cells: row.map((c) => DataCell(Text(c))).toList(),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderLight),
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
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
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

// ── _InfoRow (privado) ───────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    ),
  );
}
