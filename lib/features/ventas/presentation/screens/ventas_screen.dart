import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/app_nav.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/ventas_provider.dart';
import 'historial_ventas_view.dart';
import 'nueva_venta_view.dart';

class VentasScreen extends ConsumerWidget {
  const VentasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final canCreate = canCreateVenta(auth);
    final canRead = canReadAllVentas(auth) || canReadOwnVentas(auth);

    if (!canCreate && !canRead) {
      return const Scaffold(
        body: Center(child: Text('Sin acceso al módulo de ventas')),
      );
    }

    // Igual que el responsive web: el módulo abre en el historial y Nueva
    // venta es un flujo independiente accesible desde su CTA.
    return Scaffold(
      backgroundColor: context.colors.background,
      body: canRead
          ? HistorialVentasView(
              onCreate: canCreate ? () => _openNewSale(context) : null,
            )
          : _CreateOnly(onCreate: () => _openNewSale(context)),
    );
  }

  void _openNewSale(BuildContext context) {
    AppNav.push(context, const _NuevaVentaPage());
  }
}

class _CreateOnly extends StatelessWidget {
  final VoidCallback onCreate;

  const _CreateOnly({required this.onCreate});

  @override
  Widget build(BuildContext context) => Center(
    child: ElevatedButton.icon(
      onPressed: onCreate,
      icon: const Icon(Icons.shopping_cart_outlined),
      label: const Text('NUEVA VENTA'),
    ),
  );
}

class _NuevaVentaPage extends StatelessWidget {
  const _NuevaVentaPage();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.colors.background,
    appBar: AppBar(
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back_rounded, size: 20),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          Text(
            'Ventas',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: context.colors.textTertiary,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9),
            child: Text(
              '/',
              style: TextStyle(color: context.colors.textTertiary),
            ),
          ),
          Text(
            'Nueva Venta',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: context.colors.border),
      ),
    ),
    body: const NuevaVentaView(),
  );
}
