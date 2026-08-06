import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/ventas_provider.dart';
import 'nueva_venta_view.dart';
import 'historial_ventas_view.dart';

/// Pantalla principal del módulo de ventas.
/// - VENDEDORA: muestra Nueva Venta + Mis Ventas.
/// - CAJERO/ADMIN/SUPERADMIN: muestra solo el Historial (todas las ventas de la sede).
class VentasScreen extends ConsumerWidget {
  const VentasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final canCreate = canCreateVenta(auth);
    final canReadAll = canReadAllVentas(auth);
    final canReadOwn = canReadOwnVentas(auth);

    // Si no tiene ningún permiso de ventas
    if (!canCreate && !canReadAll && !canReadOwn) {
      return Scaffold(
        backgroundColor: AppColors.backgroundAlt,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_rounded, size: 48, color: AppColors.textTertiary),
              const SizedBox(height: 12),
              Text(
                'No tienes acceso al módulo de ventas',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    // VENDEDORA: tabs con Nueva Venta + Mis Ventas
    if (canCreate && !canReadAll) {
      return const _VendedoraView();
    }

    // CAJERO/ADMIN/SUPERADMIN que no crean ventas: solo historial
    if (!canCreate && canReadAll) {
      return Material(
        color: AppColors.backgroundAlt,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _Header(
                title: 'Ventas',
                subtitle: 'Historial de ventas de la sede',
              ),
              const Expanded(child: HistorialVentasView()),
            ],
          ),
        ),
      );
    }

    // ADMIN/SUPERADMIN que pueden crear Y ver todas
    return const _AdminView();
  }
}

/// Vista VENDEDORA: tabs Nueva Venta / Mis Ventas.
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
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.backgroundAlt,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(title: 'Ventas', subtitle: 'Registro de ventas'),
            TabBar(
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
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: const [NuevaVentaView(), HistorialVentasView()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vista ADMIN: tabs Nueva Venta / Historial (todas).
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
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.backgroundAlt,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(title: 'Ventas', subtitle: 'Registro y clasificación'),
            TabBar(
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
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: const [NuevaVentaView(), HistorialVentasView()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  const _Header({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Builder(
            builder: (ctx) => IconButton(
              tooltip: 'Abrir menú',
              icon: const Icon(Icons.menu_rounded),
              color: AppColors.textPrimary,
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.shopping_cart_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.headlineLarge),
              Text(subtitle, style: AppTextStyles.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
