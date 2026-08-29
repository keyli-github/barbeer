import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/ventas_provider.dart';
import 'historial_ventas_view.dart';
import 'nueva_venta_view.dart';

/// Módulo de ventas.
///
/// Usa estado local para alternar entre historial y nueva venta SIN
/// hacer push de una nueva ruta — esto conserva el shell (sidebar +
/// header) exactamente igual que en la web.
class VentasScreen extends ConsumerStatefulWidget {
  const VentasScreen({super.key});

  @override
  ConsumerState<VentasScreen> createState() => _VentasScreenState();
}

class _VentasScreenState extends ConsumerState<VentasScreen> {
  bool _showingNuevaVenta = false;

  void _openNewSale() => setState(() => _showingNuevaVenta = true);
  void _closeNewSale() => setState(() => _showingNuevaVenta = false);

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final canCreate = canCreateVenta(auth);
    final canRead = canReadAllVentas(auth) || canReadOwnVentas(auth);

    if (!canCreate && !canRead) {
      return const Center(child: Text('Sin acceso al módulo de ventas'));
    }

    if (_showingNuevaVenta) {
      return _NuevaVentaInline(onBack: _closeNewSale);
    }

    if (canRead) {
      return HistorialVentasView(
        onCreate: canCreate ? _openNewSale : null,
      );
    }

    return Center(
      child: ElevatedButton.icon(
        onPressed: _openNewSale,
        icon: const Icon(Icons.shopping_cart_outlined),
        label: const Text('NUEVA VENTA'),
      ),
    );
  }
}

/// Vista de nueva venta embebida dentro del shell — sin Scaffold propio.
/// Muestra el breadcrumb en la parte superior y la vista de catálogo+carrito.
class _NuevaVentaInline extends StatelessWidget {
  final VoidCallback onBack;

  const _NuevaVentaInline({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Breadcrumb (replica la web: "← Ventas / Nueva Venta") ──
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: context.colors.background,
            border: Border(
              bottom: BorderSide(color: context.colors.border),
            ),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_back_rounded,
                      size: 15,
                      color: context.colors.textTertiary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Ventas',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '/',
                  style: TextStyle(color: context.colors.textTertiary),
                ),
              ),
              Text(
                'Nueva Venta',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        // ── Vista de catálogo + carrito ──
        const Expanded(child: NuevaVentaView()),
      ],
    );
  }
}
