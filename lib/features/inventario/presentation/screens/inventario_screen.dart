import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_ui_components.dart';

class InventarioItem {
  final String id, code, name, category, location;
  final int stock, minStock, maxStock;
  final double costPrice;
  String get status => stock <= minStock ? 'CRITICO' : stock <= minStock * 1.5 ? 'ALERTA' : 'OK';
  const InventarioItem({required this.id, required this.code, required this.name, required this.category,
      required this.location, required this.stock, required this.minStock, required this.maxStock, required this.costPrice});
  InventarioItem copyWith({int? stock}) => InventarioItem(id:id,code:code,name:name,category:category,location:location,
      stock:stock??this.stock,minStock:minStock,maxStock:maxStock,costPrice:costPrice);
}

class InventarioState {
  final List<InventarioItem> items; final String search, category;
  const InventarioState({this.items = const [], this.search = '', this.category = 'Todos'});
  InventarioState copyWith({List<InventarioItem>? items, String? search, String? category}) =>
      InventarioState(items: items ?? this.items, search: search ?? this.search, category: category ?? this.category);
  List<InventarioItem> get filtered => items.where((i) {
    final ms = search.isEmpty || i.name.toLowerCase().contains(search.toLowerCase()) || i.code.toLowerCase().contains(search.toLowerCase());
    final mc = category == 'Todos' || i.category == category;
    return ms && mc;
  }).toList();
}

class InventarioNotifier extends StateNotifier<InventarioState> {
  InventarioNotifier() : super(InventarioState(items: _mock));
  static final _mock = [
    const InventarioItem(id:'1',code:'CKT001',name:'Pisco',category:'Destilados',location:'Bar A',stock:5,minStock:10,maxStock:50,costPrice:45),
    const InventarioItem(id:'2',code:'CRV001',name:'Cerveza Cusquena 12und',category:'Cervezas',location:'Refrigerador',stock:24,minStock:12,maxStock:72,costPrice:60),
    const InventarioItem(id:'3',code:'DST001',name:'Johnnie Walker Red 750ml',category:'Destilados',location:'Bar B',stock:3,minStock:5,maxStock:20,costPrice:18),
    const InventarioItem(id:'4',code:'VNO001',name:'Malbec Trivento 750ml',category:'Vinos',location:'Cava',stock:8,minStock:6,maxStock:24,costPrice:25),
    const InventarioItem(id:'5',code:'SNK001',name:'Papas Fritas Kg',category:'Snacks',location:'Cocina',stock:4,minStock:3,maxStock:15,costPrice:8),
    const InventarioItem(id:'6',code:'BCK001',name:'Hielo Bolsa 5kg',category:'Insumos',location:'Freezer',stock:12,minStock:8,maxStock:30,costPrice:5),
    const InventarioItem(id:'7',code:'BCK002',name:'Limon Kg',category:'Insumos',location:'Cocina',stock:2,minStock:4,maxStock:15,costPrice:4),
    const InventarioItem(id:'8',code:'CKT002',name:'Ron Havana Club 750ml',category:'Destilados',location:'Bar A',stock:7,minStock:5,maxStock:20,costPrice:35),
  ];

  void adjustStock(String id, String tipo, int qty) {
    final idx = state.items.indexWhere((i) => i.id == id);
    if (idx >= 0) {
      final list = [...state.items];
      final current = list[idx].stock;
      final newStock = tipo == 'ENTRADA' ? current + qty : (current - qty).clamp(0, 999);
      list[idx] = list[idx].copyWith(stock: newStock);
      state = state.copyWith(items: list);
    }
  }

  void setSearch(String s) => state = state.copyWith(search: s);
  void setCategory(String c) => state = state.copyWith(category: c);
}

final inventarioProvider = StateNotifierProvider<InventarioNotifier, InventarioState>((ref) => InventarioNotifier());

class InventarioScreen extends ConsumerWidget {
  const InventarioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(inventarioProvider);
    final filtered = state.filtered;
    final critical = state.items.where((i) => i.status == 'CRITICO').length;
    final alert = state.items.where((i) => i.status == 'ALERTA').length;
    final totalValue = state.items.fold(0.0, (s, i) => s + i.stock * i.costPrice);

    final categories = ['Todos', ...state.items.map((i) => i.category).toSet().toList()..sort()];

    return Scaffold(backgroundColor: AppColors.backgroundAlt,
      body: SafeArea(bottom: false, child: Column(children: [
        Container(color: AppColors.background, child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: Row(children: [
            const Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 24),
            const SizedBox(width: 10),
            const Expanded(child: Text('Inventario', style: AppTextStyles.headlineLarge)),
          ])),
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: AppSearchBar(hint: 'Buscar por nombre o codigo...', onChanged: (q) => ref.read(inventarioProvider.notifier).setSearch(q))),
          SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(children: categories.map((c) => _CatTab(label: c, selected: state.category == c,
                onTap: () => ref.read(inventarioProvider.notifier).setCategory(c))).toList())),
        ])),

        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: Row(children: [
          Expanded(child: _StatChip(label: 'Total', value: '${state.items.length}', color: AppColors.primary)),
          const SizedBox(width: 8),
          Expanded(child: _StatChip(label: 'Critico', value: '$critical', color: AppColors.error)),
          const SizedBox(width: 8),
          Expanded(child: _StatChip(label: 'Alerta', value: '$alert', color: AppColors.warning)),
          const SizedBox(width: 8),
          Expanded(child: _StatChip(label: 'Valor', value: 'S/${totalValue.toStringAsFixed(0)}', color: AppColors.success)),
        ])),
        const SizedBox(height: 8),

        Expanded(child: filtered.isEmpty
          ? const AppEmptyState(icon: Icons.inventory_2_outlined, title: 'Sin productos en inventario')
          : ListView(children: [
              for (final item in filtered)
                Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item.name, style: AppTextStyles.titleMedium),
                        Text('${item.code} · ${item.category} · ${item.location}', style: AppTextStyles.labelSmall),
                      ])),
                      _StatusBadge(status: item.status),
                      const SizedBox(width: 8),
                      IconButton(icon: const Icon(Icons.tune_rounded, size: 18, color: AppColors.primary),
                          onPressed: () => _showAdjust(context, ref, item)),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Text('Stock: ', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary)),
                      Text('${item.stock}', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700, color: _statusColor(item.status))),
                      Text(' / Min: ${item.minStock} / Max: ${item.maxStock}', style: AppTextStyles.bodySmall),
                      const Spacer(),
                      Text('S/ ${item.costPrice.toStringAsFixed(2)}/u', style: AppTextStyles.bodySmall),
                    ]),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: item.maxStock > 0 ? item.stock / item.maxStock : 0,
                        color: _statusColor(item.status), backgroundColor: AppColors.backgroundAlt,
                        minHeight: 6, borderRadius: BorderRadius.circular(3)),
                  ]))),
              const SizedBox(height: 80),
            ])),
      ])));
  }

  Color _statusColor(String s) => s == 'CRITICO' ? AppColors.error : s == 'ALERTA' ? AppColors.warning : AppColors.success;

  void _showAdjust(BuildContext context, WidgetRef ref, InventarioItem item) {
    String tipo = 'ENTRADA';
    final qtyCtrl = TextEditingController(text: '1');
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => StatefulBuilder(builder: (ctx, setS) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
        child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Text('Ajuste: ${item.name}', style: AppTextStyles.headlineMedium), const Spacer(),
            IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(ctx).pop())]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: GestureDetector(onTap: () => setS(() => tipo = 'ENTRADA'),
              child: _TipoBtn(label: 'Entrada', icon: Icons.add_rounded, selected: tipo == 'ENTRADA', color: AppColors.success))),
            const SizedBox(width: 12),
            Expanded(child: GestureDetector(onTap: () => setS(() => tipo = 'SALIDA'),
              child: _TipoBtn(label: 'Salida', icon: Icons.remove_rounded, selected: tipo == 'SALIDA', color: AppColors.error))),
          ]),
          const SizedBox(height: 16),
          TextField(controller: qtyCtrl, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Cantidad', prefixIcon: Icon(Icons.numbers_rounded))),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
            onPressed: () { final q = int.tryParse(qtyCtrl.text) ?? 0;
              if (q > 0) { ref.read(inventarioProvider.notifier).adjustStock(item.id, tipo, q); Navigator.of(ctx).pop(); } },
            child: const Text('Aplicar ajuste'))),
        ])))));
  }
}

class _TipoBtn extends StatelessWidget {
  final String label; final IconData icon; final bool selected; final Color color;
  const _TipoBtn({required this.label, required this.icon, required this.selected, required this.color});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(color: selected ? color.withOpacity(0.12) : AppColors.backgroundAlt,
        borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: selected ? color : AppColors.border)),
    child: Column(children: [Icon(icon, color: selected ? color : AppColors.textSecondary, size: 22),
      const SizedBox(height: 4), Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: selected ? color : AppColors.textSecondary))]));
}

class _StatusBadge extends StatelessWidget {
  final String status; const _StatusBadge({required this.status});
  @override Widget build(BuildContext context) {
    Color c = status == 'CRITICO' ? AppColors.error : status == 'ALERTA' ? AppColors.warning : AppColors.success;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(100)),
      child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c)));
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
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? AppColors.primary : AppColors.textSecondary))));
}

class _StatChip extends StatelessWidget {
  final String label, value; final Color color;
  const _StatChip({required this.label, required this.value, required this.color});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(AppRadius.sm)),
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      Text(label, style: AppTextStyles.labelSmall),
    ]));
}
