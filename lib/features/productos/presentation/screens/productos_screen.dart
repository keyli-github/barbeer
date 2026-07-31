import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_ui_components.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class Producto {
  final String id, name, category;
  final String? description, emoji;
  final double salePrice, costPrice;
  final bool availableInPOS, activo;

  const Producto({required this.id, required this.name, required this.category,
      this.description, this.emoji, required this.salePrice, required this.costPrice,
      this.availableInPOS = true, this.activo = true});

  double get margin => salePrice > 0 ? ((salePrice - costPrice) / salePrice * 100) : 0;

  Producto copyWith({String? name, String? category, String? description, String? emoji,
      double? salePrice, double? costPrice, bool? availableInPOS, bool? activo}) => Producto(
    id: id, name: name ?? this.name, category: category ?? this.category,
    description: description ?? this.description, emoji: emoji ?? this.emoji,
    salePrice: salePrice ?? this.salePrice, costPrice: costPrice ?? this.costPrice,
    availableInPOS: availableInPOS ?? this.availableInPOS, activo: activo ?? this.activo);
}

// ─── State ────────────────────────────────────────────────────────────────────

class ProductosState {
  final List<Producto> products;
  final String searchQuery, categoryFilter;
  const ProductosState({this.products = const [], this.searchQuery = '', this.categoryFilter = 'Todos'});
  ProductosState copyWith({List<Producto>? products, String? searchQuery, String? categoryFilter}) =>
      ProductosState(products: products ?? this.products, searchQuery: searchQuery ?? this.searchQuery,
          categoryFilter: categoryFilter ?? this.categoryFilter);

  List<Producto> get filtered => products.where((p) {
    final matchSearch = searchQuery.isEmpty ||
        p.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
        (p.description ?? '').toLowerCase().contains(searchQuery.toLowerCase());
    final matchCat = categoryFilter == 'Todos' || p.category == categoryFilter;
    return matchSearch && matchCat;
  }).toList();
}

class ProductosNotifier extends StateNotifier<ProductosState> {
  ProductosNotifier() : super(ProductosState(products: _mockProducts));

  static final _mockProducts = [
    const Producto(id: '1', name: 'Pisco Sour', category: 'Cocteles', emoji: '🍹', salePrice: 25, costPrice: 8, description: 'Clasico peruano'),
    const Producto(id: '2', name: 'Cusquena Rubia', category: 'Cervezas', emoji: '🍺', salePrice: 12, costPrice: 5),
    const Producto(id: '3', name: 'Johnnie Walker Red', category: 'Destilados', emoji: '🥃', salePrice: 35, costPrice: 18),
    const Producto(id: '4', name: 'Malbec Trivento', category: 'Vinos', emoji: '🍷', salePrice: 45, costPrice: 25),
    const Producto(id: '5', name: 'Papas Fritas', category: 'Snacks', emoji: '🍟', salePrice: 15, costPrice: 4),
    const Producto(id: '6', name: 'Mojito', category: 'Cocteles', emoji: '🍹', salePrice: 22, costPrice: 7),
    const Producto(id: '7', name: 'Heineken', category: 'Cervezas', emoji: '🍺', salePrice: 14, costPrice: 6),
    const Producto(id: '8', name: 'Agua Mineral', category: 'Otro', emoji: '💧', salePrice: 5, costPrice: 1.5),
  ];

  void addProduct(Producto p) => state = state.copyWith(products: [...state.products, p]);

  void updateProduct(Producto p) {
    final idx = state.products.indexWhere((x) => x.id == p.id);
    if (idx >= 0) {
      final list = [...state.products];
      list[idx] = p;
      state = state.copyWith(products: list);
    }
  }

  void deleteProduct(String id) =>
      state = state.copyWith(products: state.products.where((p) => p.id != id).toList());

  void toggleStatus(String id) {
    final idx = state.products.indexWhere((p) => p.id == id);
    if (idx >= 0) {
      final list = [...state.products];
      list[idx] = list[idx].copyWith(activo: !list[idx].activo);
      state = state.copyWith(products: list);
    }
  }

  void togglePOS(String id) {
    final idx = state.products.indexWhere((p) => p.id == id);
    if (idx >= 0) {
      final list = [...state.products];
      list[idx] = list[idx].copyWith(availableInPOS: !list[idx].availableInPOS);
      state = state.copyWith(products: list);
    }
  }

  void setSearch(String q) => state = state.copyWith(searchQuery: q);
  void setCategory(String c) => state = state.copyWith(categoryFilter: c);
}

final productosProvider = StateNotifierProvider<ProductosNotifier, ProductosState>(
    (ref) => ProductosNotifier());

const _categories = ['Todos', 'Cocteles', 'Cervezas', 'Destilados', 'Vinos', 'Snacks', 'Otro'];

// ─── Screen ───────────────────────────────────────────────────────────────────

class ProductosScreen extends ConsumerStatefulWidget {
  const ProductosScreen({super.key});
  @override ConsumerState<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends ConsumerState<ProductosScreen> {
  bool _gridView = true;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productosProvider);
    final filtered = state.filtered;
    final total = state.products.length;
    final active = state.products.where((p) => p.activo).length;
    final posCount = state.products.where((p) => p.availableInPOS).length;

    return Scaffold(backgroundColor: AppColors.backgroundAlt,
      body: SafeArea(bottom: false, child: Column(children: [
        Container(color: AppColors.background, child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: Row(children: [
            const Icon(Icons.local_bar_rounded, color: AppColors.primary, size: 24),
            const SizedBox(width: 10),
            const Expanded(child: Text('Productos', style: AppTextStyles.headlineLarge)),
            IconButton(icon: Icon(_gridView ? Icons.list_rounded : Icons.grid_view_rounded, color: AppColors.textSecondary),
                onPressed: () => setState(() => _gridView = !_gridView)),
            FilledButton.icon(onPressed: () => _showForm(context, null),
              icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Nuevo'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10))),
          ])),
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: AppSearchBar(hint: 'Buscar productos...', onChanged: (q) => ref.read(productosProvider.notifier).setSearch(q))),
          SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(children: _categories.map((c) => _CatTab(label: c, selected: state.categoryFilter == c,
                onTap: () => ref.read(productosProvider.notifier).setCategory(c))).toList())),
        ])),

        // Stats
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: Row(children: [
          _StatChip(label: 'Total', value: '$total', color: AppColors.primary),
          const SizedBox(width: 8),
          _StatChip(label: 'Activos', value: '$active', color: AppColors.success),
          const SizedBox(width: 8),
          _StatChip(label: 'En POS', value: '$posCount', color: AppColors.accent),
        ])),
        const SizedBox(height: 8),

        Expanded(child: filtered.isEmpty
          ? const AppEmptyState(icon: Icons.local_bar_outlined, title: 'Sin productos encontrados')
          : _gridView
            ? GridView.builder(padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.85, crossAxisSpacing: 10, mainAxisSpacing: 10),
                itemCount: filtered.length,
                itemBuilder: (_, i) => _ProductCard(product: filtered[i],
                    onEdit: () => _showForm(context, filtered[i]),
                    onDelete: () => ref.read(productosProvider.notifier).deleteProduct(filtered[i].id),
                    onToggleStatus: () => ref.read(productosProvider.notifier).toggleStatus(filtered[i].id),
                    onTogglePOS: () => ref.read(productosProvider.notifier).togglePOS(filtered[i].id)))
            : ListView.builder(padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                itemCount: filtered.length,
                itemBuilder: (_, i) => _ProductListTile(product: filtered[i],
                    onEdit: () => _showForm(context, filtered[i]),
                    onDelete: () => ref.read(productosProvider.notifier).deleteProduct(filtered[i].id),
                    onToggleStatus: () => ref.read(productosProvider.notifier).toggleStatus(filtered[i].id),
                    onTogglePOS: () => ref.read(productosProvider.notifier).togglePOS(filtered[i].id)))),
      ])));
  }

  void _showForm(BuildContext context, Producto? product) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => _ProductForm(product: product,
        onSave: (p) { if (product == null) ref.read(productosProvider.notifier).addProduct(p);
          else ref.read(productosProvider.notifier).updateProduct(p); }));
  }
}

class _ProductCard extends StatelessWidget {
  final Producto product;
  final VoidCallback onEdit, onDelete, onToggleStatus, onTogglePOS;
  const _ProductCard({required this.product, required this.onEdit, required this.onDelete,
      required this.onToggleStatus, required this.onTogglePOS});

  @override
  Widget build(BuildContext context) {
    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(product.emoji ?? '🍹', style: const TextStyle(fontSize: 28)),
        const Spacer(),
        PopupMenuButton<String>(icon: const Icon(Icons.more_vert_rounded, size: 16, color: AppColors.textTertiary),
          onSelected: (v) { if (v == 'edit') onEdit(); else if (v == 'delete') onDelete();
            else if (v == 'status') onToggleStatus(); else if (v == 'pos') onTogglePOS(); },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Editar')),
            const PopupMenuItem(value: 'status', child: Text('Cambiar estado')),
            const PopupMenuItem(value: 'pos', child: Text('Toggle POS')),
            const PopupMenuItem(value: 'delete', child: Text('Eliminar', style: TextStyle(color: AppColors.error))),
          ]),
      ]),
      const SizedBox(height: 6),
      Text(product.name, style: AppTextStyles.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
      Text(product.category, style: AppTextStyles.labelSmall),
      const Spacer(),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('S/ ${product.salePrice.toStringAsFixed(2)}',
            style: AppTextStyles.titleMedium.copyWith(color: AppColors.primary)),
        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: _marginColor(product.margin).withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
          child: Text('${product.margin.toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _marginColor(product.margin)))),
      ]),
    ]));
  }

  Color _marginColor(double m) => m >= 40 ? AppColors.success : m >= 20 ? AppColors.warning : AppColors.error;
}

class _ProductListTile extends StatelessWidget {
  final Producto product;
  final VoidCallback onEdit, onDelete, onToggleStatus, onTogglePOS;
  const _ProductListTile({required this.product, required this.onEdit, required this.onDelete,
      required this.onToggleStatus, required this.onTogglePOS});

  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8),
    child: AppCard(child: Row(children: [
      Text(product.emoji ?? '🍹', style: const TextStyle(fontSize: 28)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(product.name, style: AppTextStyles.titleMedium),
        Row(children: [Text(product.category, style: AppTextStyles.labelSmall),
          const SizedBox(width: 8), Text('S/ ${product.salePrice.toStringAsFixed(2)}',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600))]),
      ])),
      PopupMenuButton<String>(icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppColors.textTertiary),
        onSelected: (v) { if (v == 'edit') onEdit(); else if (v == 'delete') onDelete();
          else if (v == 'status') onToggleStatus(); else if (v == 'pos') onTogglePOS(); },
        itemBuilder: (_) => [const PopupMenuItem(value: 'edit', child: Text('Editar')),
          const PopupMenuItem(value: 'status', child: Text('Estado')),
          const PopupMenuItem(value: 'pos', child: Text('Toggle POS')),
          const PopupMenuItem(value: 'delete', child: Text('Eliminar', style: TextStyle(color: AppColors.error)))]),
    ])));
}

class _ProductForm extends StatefulWidget {
  final Producto? product;
  final void Function(Producto) onSave;
  const _ProductForm({this.product, required this.onSave});
  @override State<_ProductForm> createState() => _ProductFormState();
}
class _ProductFormState extends State<_ProductForm> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _salePriceCtrl = TextEditingController();
  final _costPriceCtrl = TextEditingController();
  String _category = 'Cocteles', _emoji = '🍹';
  bool _inPOS = true, _activo = true;

  @override void initState() { super.initState();
    if (widget.product != null) {
      _nameCtrl.text = widget.product!.name;
      _descCtrl.text = widget.product!.description ?? '';
      _salePriceCtrl.text = widget.product!.salePrice.toString();
      _costPriceCtrl.text = widget.product!.costPrice.toString();
      _category = widget.product!.category;
      _emoji = widget.product!.emoji ?? '🍹';
      _inPOS = widget.product!.availableInPOS;
      _activo = widget.product!.activo;
    }
  }
  @override void dispose() { _nameCtrl.dispose(); _descCtrl.dispose(); _salePriceCtrl.dispose(); _costPriceCtrl.dispose(); super.dispose(); }

  double get margin { final s = double.tryParse(_salePriceCtrl.text) ?? 0; final c = double.tryParse(_costPriceCtrl.text) ?? 0; return s > 0 ? (s - c) / s * 100 : 0; }

  @override Widget build(BuildContext context) => Container(
    height: MediaQuery.of(context).size.height * 0.88,
    decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
    child: Column(children: [
      Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
      Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 0), child: Row(children: [
        Text(widget.product == null ? 'Nuevo producto' : 'Editar producto', style: AppTextStyles.headlineMedium),
        const Spacer(), IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop()),
      ])),
      const Divider(),
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Emoji picker
        _label('Emoji'), const SizedBox(height: 6),
        Wrap(spacing: 8, children: ['🍹','🍺','🥃','🍷','🍾','🧃','🍔','🍟','🥗','🧁','🍰','💧']
          .map((e) => GestureDetector(onTap: () => setState(() => _emoji = e),
            child: Container(width: 44, height: 44, decoration: BoxDecoration(
                color: _emoji == e ? AppColors.primarySurface : AppColors.backgroundAlt,
                borderRadius: BorderRadius.circular(8), border: Border.all(color: _emoji == e ? AppColors.primary : AppColors.border)),
                child: Center(child: Text(e, style: const TextStyle(fontSize: 22)))))).toList()),
        const SizedBox(height: 14),
        AppTextField(label: 'Nombre', hint: 'Nombre del producto', controller: _nameCtrl,
            validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null),
        const SizedBox(height: 14),
        AppTextField(label: 'Descripcion', hint: 'Descripcion (opcional)', controller: _descCtrl, maxLines: 2),
        const SizedBox(height: 14),
        _label('Categoria'), const SizedBox(height: 6),
        DropdownButtonFormField<String>(value: _category,
          items: ['Cocteles','Cervezas','Destilados','Vinos','Snacks','Otro'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => setState(() => _category = v ?? 'Cocteles')),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: AppTextField(label: 'Precio de venta (S/)', hint: '0.00', controller: _salePriceCtrl,
              keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
          const SizedBox(width: 12),
          Expanded(child: AppTextField(label: 'Costo (S/)', hint: '0.00', controller: _costPriceCtrl,
              keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
        ]),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: AppColors.backgroundAlt, borderRadius: BorderRadius.circular(8)),
          child: Row(children: [const Text('Margen: ', style: AppTextStyles.bodySmall),
            Text('${margin.toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.w700,
                color: margin >= 40 ? AppColors.success : margin >= 20 ? AppColors.warning : AppColors.error))])),
        const SizedBox(height: 14),
        Row(children: [
          const Expanded(child: Text('Disponible en POS', style: AppTextStyles.bodyMedium)),
          Switch(value: _inPOS, onChanged: (v) => setState(() => _inPOS = v)),
        ]),
        Row(children: [
          const Expanded(child: Text('Activo', style: AppTextStyles.bodyMedium)),
          Switch(value: _activo, onChanged: (v) => setState(() => _activo = v)),
        ]),
        const SizedBox(height: 24),
        PrimaryButton(label: widget.product == null ? 'Crear producto' : 'Guardar cambios', onPressed: _submit),
      ]))),
    ]));

  Widget _label(String t) => Text(t, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w500, color: AppColors.textSecondary));

  void _submit() {
    final p = Producto(
      id: widget.product?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameCtrl.text.trim(), category: _category, emoji: _emoji,
      description: _descCtrl.text, salePrice: double.tryParse(_salePriceCtrl.text) ?? 0,
      costPrice: double.tryParse(_costPriceCtrl.text) ?? 0, availableInPOS: _inPOS, activo: _activo);
    widget.onSave(p);
    Navigator.of(context).pop();
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

class _StatChip extends StatelessWidget {
  final String label, value; final Color color;
  const _StatChip({required this.label, required this.value, required this.color});
  @override Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(AppRadius.sm)),
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
      Text(label, style: AppTextStyles.labelSmall),
    ])));
}
