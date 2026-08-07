import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
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

// ─── Historial solo ───────────────────────────────────────────────────────────

class _HistorialView extends StatelessWidget {
  const _HistorialView();
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: const AppHeader(subtitle: 'Ventas'),
    body: const HistorialVentasView(),
  );
}

// ─── Vendedora: Nueva venta + Mis ventas ─────────────────────────────────────

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
    backgroundColor: Colors.white,
    appBar: AppHeader(
      subtitle: 'Ventas',
      actions: [
        PreferredSize(
          preferredSize: const Size.fromHeight(0),
          child: TabBar(
            controller: _tabs,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textTertiary,
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            tabs: const [
              Tab(text: 'Nueva venta'),
              Tab(text: 'Mis ventas'),
            ],
          ),
        ),
      ],
    ),
    body: Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabs,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textTertiary,
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            tabs: const [
              Tab(text: 'Nueva venta'),
              Tab(text: 'Mis ventas'),
            ],
          ),
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

// ─── Admin: Nueva venta + Historial ─────────────────────────────────────────

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
    backgroundColor: Colors.white,
    appBar: const AppHeader(subtitle: 'Ventas'),
    body: Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabs,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textTertiary,
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            tabs: const [
              Tab(text: 'Nueva venta'),
              Tab(text: 'Historial'),
            ],
          ),
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
