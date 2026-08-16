import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/navigation/app_nav.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/ds_product_image.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/venta_models.dart';
import '../providers/ventas_provider.dart';
import '../widgets/anular_venta_dialog.dart';
import 'conciliar_venta_screen.dart';

/// Subpantalla completa de detalle de venta.
/// Navegación: AppNav.push(context, VentaDetailScreen(venta: v))
class VentaDetailScreen extends ConsumerStatefulWidget {
  final Venta venta;
  final VoidCallback? onChanged;

  const VentaDetailScreen({super.key, required this.venta, this.onChanged});

  @override
  ConsumerState<VentaDetailScreen> createState() => _VentaDetailScreenState();
}

class _VentaDetailScreenState extends ConsumerState<VentaDetailScreen> {
  bool _anulando = false;
  String? _errorAnular;
  late Venta _venta;

  @override
  void initState() {
    super.initState();
    _venta = widget.venta;
  }

  Future<void> _anular() async {
    if (_anulando) return;
    final motivo = await showAnularVentaDialog(context, codigo: _venta.codigo);
    if (motivo == null || !mounted) return;

    setState(() {
      _anulando = true;
      _errorAnular = null;
    });
    try {
      await ref
          .read(ventasRepositoryProvider)
          .anularVenta(_venta.id, motivo: motivo);
      if (mounted) {
        widget.onChanged?.call();
        AppFeedback.success(context, 'Venta anulada');
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _anulando = false;
        _errorAnular = e.toString();
      });
    }
  }

  void _openConciliar() {
    AppNav.push(
      context,
      ConciliarVentaScreen(
        venta: _venta,
        onDone: () {
          widget.onChanged?.call();
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final canAnular = canAnularVenta(auth) && !_venta.isAnulada;
    final puedeClasificar = canConciliar(auth) && _venta.isPendiente;
    final puedeCorregir =
        canConciliarCorregir(auth) && !_venta.isAnulada && !_venta.isPendiente;

    final isAnulada = _venta.isAnulada;
    final isPendiente = _venta.isPendiente;
    final statusLabel = isAnulada
        ? 'ANULADA'
        : isPendiente
        ? 'PENDIENTE'
        : 'ACTIVA';

    DateTime? dt;
    try {
      dt = DateTime.parse(_venta.createdAt);
    } catch (_) {}

    return Scaffold(
      backgroundColor: context.colors.backgroundAlt,
      appBar: SubPageAppBar(
        title: 'Detalle de venta',
        subtitle: 'Información completa',
        actions: [
          if (puedeClasificar)
            TextButton(
              onPressed: _openConciliar,
              child: const Text(
                'Clasificar',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          if (puedeCorregir)
            TextButton(
              onPressed: _openConciliar,
              child: const Text(
                'Corregir',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          if (canAnular)
            IconButton(
              icon: Icon(
                Icons.more_vert_rounded,
                color: context.colors.textSecondary,
              ),
              onPressed: _anular,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // ── Total + estado
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, const Color(0xFF1D4ED8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _venta.codigo,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          FormatUtils.currency(_venta.total),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        if (dt != null)
                          Text(
                            FormatUtils.dateTime(dt),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Info de la venta
            _Section('Información general', [
              _InfoRow('Sede', _venta.sedeId),
              if (_venta.vendedoraUsername != null)
                _InfoRow('Vendedora', _venta.vendedoraUsername!),
              _InfoRow(
                'Sesión de caja',
                _venta.cajaSesionId.length > 8
                    ? '...${_venta.cajaSesionId.substring(_venta.cajaSesionId.length - 8)}'
                    : _venta.cajaSesionId,
                mono: true,
              ),
            ]),

            const SizedBox(height: 12),

            if (_venta.recargoMonto != null) ...[
              _Section('Recargo', [
                _InfoRow('Monto', FormatUtils.currency(_venta.recargoMonto!)),
                if (_venta.recargoMotivo != null)
                  _InfoRow('Motivo', _venta.recargoMotivo!),
              ]),
              const SizedBox(height: 12),
            ],

            // ── Conciliación / método de pago
            if (_venta.conciliacion != null) ...[
              _Section('Método de pago', [
                _InfoRow(
                  'Estado',
                  estadoConciliacionLabel(_venta.conciliacion!.estado),
                ),
                if (_venta.conciliacion!.etiquetaNombre != null)
                  _InfoRow('Billetera', _venta.conciliacion!.etiquetaNombre!),
                if (_venta.conciliacion!.codigoOperacion != null)
                  _InfoRow('Código op.', _venta.conciliacion!.codigoOperacion!),
                if (_venta.conciliacion!.comprobante != null)
                  _InfoRow('Comprobante', _venta.conciliacion!.comprobante!),
              ]),
              const SizedBox(height: 12),
            ],

            // ── Productos
            _SectionLabel('Productos (${_venta.items.length})'),
            Container(
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.colors.borderLight),
              ),
              child: Column(
                children: _venta.items.asMap().entries.map((e) {
                  final idx = e.key;
                  final item = e.value;
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            DSProductImageSquare(
                              imageUrl: null,
                              productName: item.productoNombre,
                              size: 44,
                              radius: 10,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.productoNombre ??
                                        item.productoCodigo ??
                                        '—',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${item.cantidad} × ${FormatUtils.currency(item.precioUnitario)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              FormatUtils.currency(item.subtotal),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: context.colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (idx < _venta.items.length - 1)
                        Divider(
                          height: 1,
                          indent: 72,
                          color: context.colors.surfaceAlt,
                        ),
                    ],
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 8),

            // ── Total
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: context.colors.primarySurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colors.primaryBorder),
              ),
              child: Column(
                children: [
                  if (_venta.recargoMonto != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal'),
                          Text(FormatUtils.currency(_venta.subtotalSinRecargo)),
                        ],
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        FormatUtils.currency(_venta.total),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Error anular
            if (_errorAnular != null) ...[
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
                        _errorAnular!,
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

            // ── Botones de acción
            if (puedeClasificar || puedeCorregir || canAnular) ...[
              const SizedBox(height: 20),
              if (puedeClasificar)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _openConciliar,
                    icon: const Icon(Icons.payment_rounded, size: 18),
                    label: const Text('Clasificar pago'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              if (puedeCorregir) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _openConciliar,
                    icon: const Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 18,
                    ),
                    label: const Text('Corregir pago'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
              if (canAnular) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _anulando ? null : _anular,
                    icon: _anulando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.error,
                            ),
                          )
                        : const Icon(Icons.block_rounded, size: 18),
                    label: Text(_anulando ? 'Anulando...' : 'Anular venta'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Widgets auxiliares ───────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.colors.textSecondary,
        letterSpacing: 0.2,
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section(this.title, this.children);
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SectionLabel(title),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.borderLight),
        ),
        child: Column(
          children: children
              .asMap()
              .entries
              .expand(
                (e) => [
                  e.value,
                  if (e.key < children.length - 1)
                    Divider(height: 1, color: context.colors.surfaceAlt),
                ],
              )
              .toList(),
        ),
      ),
    ],
  );
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  final bool mono;
  const _InfoRow(this.label, this.value, {this.mono = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, color: context.colors.textSecondary),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
              fontFamily: mono ? 'monospace' : null,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}
