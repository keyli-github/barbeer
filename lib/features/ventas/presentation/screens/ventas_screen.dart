import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../productos/presentation/screens/productos_screen.dart';

// ─── Order Model ──────────────────────────────────────────────────────────────

class OrderItem {
  final Producto product;
  final int quantity;
  const OrderItem({required this.product, required this.quantity});
  double get subtotal => product.salePrice * quantity;
  OrderItem copyWith({int? quantity}) => OrderItem(product: product, quantity: quantity ?? this.quantity);
}

class VentasState {
  final List<OrderItem> order;
  final String searchQuery, categoryFilter;
  const VentasState({this.order = const [], this.searchQuery = '', this.categoryFilter = 'Todos'});
  VentasState copyWith({List<OrderItem>? order, String? searchQuery, String? categoryFilter}) =>
      VentasState(order: order ?? this.order, searchQuery: searchQuery ?? this.searchQuery, categoryFilter: categoryFilter ?? this.categoryFilter);
  double get subtotal => order.fold(0, (s, i) => s + i.subtotal);
  double get igv => subtotal * 0.18;
  double get total => subtotal + igv;
  int get itemCount => order.fold(0, (s, i) => s + i.quantity);
}

class VentasNotifier extends StateNotifier<VentasState> {
  VentasNotifier() : super(const VentasState());

  void addItem(Producto p) {
    final idx = state.order.indexWhere((i) => i.product.id == p.id);
    if (idx >= 0) {
      final list = [...state.order];
      list[idx] = list[idx].copyWith(quantity: list[idx].quantity + 1);
      state = state.copyWith(order: list);
    } else {
      state = state.copyWith(order: [...state.order, OrderItem(product: p, quantity: 1)]);
    }
  }

  void removeItem(String productId) {
    final idx = state.order.indexWhere((i) => i.product.id == productId);
    if (idx >= 0) {
      final list = [...state.order];
      if (list[idx].quantity > 1) list[idx] = list[idx].copyWith(quantity: list[idx].quantity - 1);
      else list.removeAt(idx);
      state = state.copyWith(order: list);
    }
  }

  void clearOrder() => state = state.copyWith(order: []);
  void setSearch(String q) => state = state.copyWith(searchQuery: q);
  void setCategory(String c) => state = state.copyWith(categoryFilter: c);
}

final ventasProvider = StateNotifierProvider<VentasNotifier, VentasState>((ref) => VentasNotifier());

const _paymentMethods = ['Efectivo', 'Tarjeta', 'Transferencia', 'Mixto'];

// ─── Screen ───────────────────────────────────────────────────────────────────

class VentasScreen extends ConsumerStatefulWidget {
  const VentasScreen({super.key});
  @override ConsumerState<VentasScreen> createState() => _VentasScreenState();
}

class _VentasScreenState extends ConsumerState<VentasScreen> {
  bool _showOrder = false;

  @override
  Widget build(BuildContext context) {
    final ventas = ref.watch(ventasProvider);
    final productos = ref.watch(productosProvider);
    final posProducts = productos.products.where((p) => p.availableInPOS && p.activo).toList();
    final filtered = posProducts.where((p) {
      final matchSearch = ventas.searchQuery.isEmpty ||
          p.name.toLowerCase().contains(ventas.searchQuery.toLowerCase());
      final matchCat = ventas.categoryFilter == 'Todos' || p.category == ventas.categoryFilter;
      return matchSearch && matchCat;
    }).toList();

    final categories = ['Todos', ...posProducts.map((p) => p.category).toSet().toList()..sort()];

    return Scaffold(backgroundColor: AppColors.backgroundAlt,
      body: SafeArea(bottom: false, child: Column(children: [
        // Header
        Container(color: AppColors.background, child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: Row(children: [
            const Icon(Icons.point_of_sale_rounded, color: AppColors.primary, size: 24),
            const SizedBox(width: 10),
            const Expanded(child: Text('Punto de Venta', style: AppTextStyles.headlineLarge)),
          ])),
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(onChanged: ref.read(ventasProvider.notifier).setSearch,
              decoration: const InputDecoration(hintText: 'Buscar productos...',
                  prefixIcon: Icon(Icons.search_rounded, color: AppColors.textTertiary, size: 20),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12)))),
          SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(children: categories.map((c) => _CatTab(label: c, selected: ventas.categoryFilter == c,
                onTap: () => ref.read(ventasProvider.notifier).setCategory(c))).toList())),
        ])),

        // Product grid
        Expanded(child: filtered.isEmpty
          ? const AppEmptyState(icon: Icons.local_bar_outlined, title: 'Sin productos disponibles en POS')
          : GridView.builder(padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, childAspectRatio: 0.8, crossAxisSpacing: 8, mainAxisSpacing: 8),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final p = filtered[i];
                final qty = ventas.order.where((o) => o.product.id == p.id).fold(0, (s, o) => s + o.quantity);
                return GestureDetector(onTap: () => ref.read(ventasProvider.notifier).addItem(p),
                  child: Container(
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: qty > 0 ? AppColors.primary : AppColors.borderLight, width: qty > 0 ? 1.5 : 0.5)),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(p.emoji ?? '🍹', style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 4),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(p.name, style: AppTextStyles.labelLarge.copyWith(color: AppColors.textPrimary), maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis)),
                      const SizedBox(height: 2),
                      Text('S/ ${p.salePrice.toStringAsFixed(2)}', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary)),
                      if (qty > 0) Container(margin: const EdgeInsets.only(top: 4), width: 24, height: 24,
                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        child: Center(child: Text('$qty', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)))),
                    ])));
              })),
      ])),

      // Floating cart button
      floatingActionButton: ventas.itemCount > 0 ? FloatingActionButton.extended(
        onPressed: () => _showOrderPanel(context, ventas),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.shopping_cart_rounded, color: Colors.white),
        label: Text('${ventas.itemCount} items · S/ ${ventas.total.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))) : null,
    );
  }

  void _showOrderPanel(BuildContext context, VentasState ventas) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => Container(height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
        child: Column(children: [
          Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
          Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(children: [const Text('Orden actual', style: AppTextStyles.headlineMedium), const Spacer(),
                TextButton(onPressed: ref.read(ventasProvider.notifier).clearOrder, child: const Text('Limpiar'))])),
          const Divider(),
          Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
            for (final item in ventas.order)
              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [
                Text(item.product.emoji ?? '🍹', style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.product.name, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w500)),
                  Text('S/ ${item.product.salePrice.toStringAsFixed(2)} c/u', style: AppTextStyles.labelSmall)])),
                Row(children: [
                  IconButton(icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.error, size: 20),
                      onPressed: () => ref.read(ventasProvider.notifier).removeItem(item.product.id)),
                  Text('${item.quantity}', style: AppTextStyles.titleMedium),
                  IconButton(icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 20),
                      onPressed: () => ref.read(ventasProvider.notifier).addItem(item.product)),
                ]),
                SizedBox(width: 70, child: Text('S/ ${item.subtotal.toStringAsFixed(2)}',
                    textAlign: TextAlign.end, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700))),
              ])),
          ])),
          Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            Row(children: [const Text('Subtotal', style: AppTextStyles.bodyMedium), const Spacer(),
                Text('S/ ${ventas.subtotal.toStringAsFixed(2)}', style: AppTextStyles.bodyMedium)]),
            const SizedBox(height: 4),
            Row(children: [const Text('IGV (18%)', style: AppTextStyles.bodyMedium), const Spacer(),
                Text('S/ ${ventas.igv.toStringAsFixed(2)}', style: AppTextStyles.bodyMedium)]),
            const SizedBox(height: 8),
            Row(children: [const Text('TOTAL', style: AppTextStyles.titleLarge), const Spacer(),
                Text('S/ ${ventas.total.toStringAsFixed(2)}', style: AppTextStyles.titleLarge.copyWith(color: AppColors.primary))]),
            const SizedBox(height: 16),
            PrimaryButton(label: 'Procesar pago', onPressed: () {
              Navigator.of(context).pop();
              _showPaymentDialog(context, ventas);
            }, icon: Icons.payment_rounded),
          ])),
        ])));
  }

  void _showPaymentDialog(BuildContext context, VentasState ventas) {
    String selected = 'Efectivo';
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      title: const Text('Seleccionar metodo de pago'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final m in _paymentMethods) RadioListTile<String>(value: m, groupValue: selected, title: Text(m),
            onChanged: (v) => setS(() => selected = v ?? 'Efectivo')),
        const Divider(),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Total:', style: AppTextStyles.titleMedium),
          Text('S/ ${ventas.total.toStringAsFixed(2)}', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primary)),
        ]),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () { Navigator.of(ctx).pop(); ref.read(ventasProvider.notifier).clearOrder();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pago procesado exitosamente'))); },
          child: const Text('Confirmar pago')),
      ])));
  }
}

class _CatTab extends StatelessWidget {
  final String label; final bool selected; final VoidCallback onTap;
  const _CatTab({required this.label, required this.selected, required this.onTap});
  @override Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(color: selected ? AppColors.primarySurface : AppColors.backgroundAlt,
          borderRadius: BorderRadius.circular(AppRadius.full), border: Border.all(color: selected ? AppColors.primaryBorder : AppColors.border)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? AppColors.primary : AppColors.textSecondary))));
}
