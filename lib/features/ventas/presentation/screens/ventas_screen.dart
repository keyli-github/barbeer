import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/ventas_provider.dart';
import 'nueva_venta_view.dart';
import 'historial_ventas_view.dart';

class VentasScreen extends ConsumerWidget {
  const VentasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final canCreate = canCreateVenta(auth);
    final canReadAll = canReadAllVentas(auth);
    final canReadOwn = canReadOwnVentas(auth);

    if (!canCreate && !canReadAll && !canReadOwn) {
      return const Scaffold(
        body: Center(child: Text('Sin acceso al módulo de ventas')),
      );
    }
    if (canCreate && !canReadAll) return const _VendedoraView();
    if (!canCreate && canReadAll) return const _HistorialView();
    return const _AdminView();
  }
}

// ─── Solo historial ───────────────────────────────────────────────────────────

class _HistorialView extends StatelessWidget {
  const _HistorialView();
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.colors.surface,
    body: HistorialVentasView(),
  );
}

// ─── Vendedora ────────────────────────────────────────────────────────────────

class _VendedoraView extends StatefulWidget {
  const _VendedoraView();
  @override
  State<_VendedoraView> createState() => _VendedoraViewState();
}

class _VendedoraViewState extends State<_VendedoraView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.colors.surface,
    body: Column(
      children: [
        _TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Nueva venta'),
            Tab(text: 'Mis ventas'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: const [NuevaVentaView(), HistorialVentasView()],
          ),
        ),
      ],
    ),
  );
}

// ─── Admin ────────────────────────────────────────────────────────────────────

class _AdminView extends StatefulWidget {
  const _AdminView();
  @override
  State<_AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends State<_AdminView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.colors.surface,
    body: Column(
      children: [
        _TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Nueva venta'),
            Tab(text: 'Historial'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: const [NuevaVentaView(), HistorialVentasView()],
          ),
        ),
      ],
    ),
  );
}

class _TabBar extends StatelessWidget {
  final TabController controller;
  final List<Widget> tabs;
  const _TabBar({required this.controller, required this.tabs});
  @override
  Widget build(BuildContext context) => Container(
    color: context.colors.surface,
    child: TabBar(
      controller: controller,
      labelColor: AppColors.primary,
      unselectedLabelColor: context.colors.textTertiary,
      indicatorColor: AppColors.primary,
      indicatorSize: TabBarIndicatorSize.label,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      tabs: tabs,
    ),
  );
}
