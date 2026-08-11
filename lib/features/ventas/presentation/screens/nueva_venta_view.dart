import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/widgets/ds_inputs.dart';
import '../../../../core/widgets/ds_product_image.dart';
import '../../../../core/widgets/ds_states.dart';
import '../../../productos/data/productos_repository.dart';
import '../providers/ventas_provider.dart';
import '../widgets/carrito_venta_sheet.dart';

String _fmt(double v) => FormatUtils.currency(v);

/// Vista de creación de una nueva venta (catálogo + carrito).
class NuevaVentaView extends ConsumerStatefulWidget {
  final Future<List<Producto>> Function()? productsLoader;

  const NuevaVentaView({super.key, this.productsLoader});
  @override
  ConsumerState<NuevaVentaView> createState() => _NuevaVentaViewState();
}

class _NuevaVentaViewState extends ConsumerState<NuevaVentaView> {
  final _searchCtrl = TextEditingController();
  List<Producto> _productos = [];
  bool _loadingProducts = true;
  String? _errorProducts;
  final List<CarritoItem> _carrito = [];
  bool _submitting = false;
  String? _submitError;
  late String _idempotencyKey;

  /// true después de un intento fallido ambiguo (timeout, error de red).
  /// Mientras está congelado, no se puede modificar el carrito.
  /// El usuario debe Reintentar (mismo key) o Descartar (nuevo key).
  bool _frozen = false;

  @override
  void initState() {
    super.initState();
    _idempotencyKey = ref
        .read(ventasRepositoryProvider)
        .generateIdempotencyKey();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loadingProducts = true;
      _errorProducts = null;
    });
    try {
      final products = widget.productsLoader != null
          ? await widget.productsLoader!()
          : (await ProductosRepository(
              ApiClient.instance,
            ).list(pagina: 1, limite: 100, activo: 'true')).data;
      if (!mounted) return;
      setState(() {
        _productos = products
            .where((p) => p.disponiblePos && p.activo)
            .toList();
        _loadingProducts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingProducts = false;
        _errorProducts = 'No se pudieron cargar los productos';
      });
    }
  }

  List<Producto> get _filteredProducts {
    final q = _searchCtrl.text.toLowerCase();
    if (q.isEmpty) return _productos;
    return _productos
        .where(
          (p) =>
              p.nombre.toLowerCase().contains(q) ||
              p.codigo.toLowerCase().contains(q),
        )
        .toList();
  }

  int _cartQty(String productoId) {
    final item = _carrito.where((i) => i.productoId == productoId).firstOrNull;
    return item?.cantidad ?? 0;
  }

  int? _stockDisponible(String productoId) =>
      _productos.where((p) => p.id == productoId).firstOrNull?.stockDisponible;

  void _addToCart(Producto product) {
    if (_frozen) return; // Carrito congelado tras error ambiguo
    final existing = _carrito
        .where((i) => i.productoId == product.id)
        .firstOrNull;
    final stock = product.stockDisponible;
    if (stock != null && (existing?.cantidad ?? 0) >= stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No puedes superar el stock disponible.')),
      );
      return;
    }
    setState(() {
      if (existing != null) {
        existing.cantidad++;
      } else {
        _carrito.add(
          CarritoItem(
            productoId: product.id,
            nombre: product.nombre,
            codigo: product.codigo,
            precio: product.precioVenta,
          ),
        );
      }
    });
  }

  void _changeQuantity(String productoId, int delta) {
    if (_frozen) return; // Carrito congelado tras error ambiguo
    if (delta > 0) {
      final stock = _stockDisponible(productoId);
      if (stock != null && _cartQty(productoId) >= stock) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No puedes superar el stock disponible.'),
          ),
        );
        return;
      }
    }
    setState(() {
      final item = _carrito
          .where((i) => i.productoId == productoId)
          .firstOrNull;
      if (item == null) return;
      item.cantidad += delta;
      if (item.cantidad <= 0) {
        _carrito.removeWhere((i) => i.productoId == productoId);
      }
    });
  }

  void _removeFromCart(String productoId) {
    if (_frozen) return; // Carrito congelado tras error ambiguo
    setState(() {
      _carrito.removeWhere((i) => i.productoId == productoId);
    });
  }

  /// Descarta el intento fallido y permite modificar el carrito.
  /// Genera un nuevo idempotencyKey — la operación anterior se considera abandonada.
  void _discardFrozen() {
    setState(() {
      _frozen = false;
      _submitError = null;
      _idempotencyKey = ref
          .read(ventasRepositoryProvider)
          .generateIdempotencyKey();
    });
  }

  void _clearCart() {
    setState(() {
      _carrito.clear();
      _frozen = false;
      _submitError = null;
      _idempotencyKey = ref
          .read(ventasRepositoryProvider)
          .generateIdempotencyKey();
    });
  }

  double get _total => _carrito.fold(0.0, (sum, i) => sum + i.subtotal);

  Future<void> _submit() async {
    if (_submitting || _carrito.isEmpty) return;
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final repo = ref.read(ventasRepositoryProvider);
      await repo.crearVenta(
        idempotencyKey: _idempotencyKey,
        items: _carrito
            .map(
              (i) => <String, dynamic>{
                'productoId': i.productoId,
                'cantidad': i.cantidad,
              },
            )
            .toList(),
      );
      if (!mounted) return;
      // Feedback de éxito centrado
      DSSuccessOverlay.show(
        context,
        title: 'Venta registrada',
        description: 'La venta se registró correctamente.',
      );
      setState(() {
        _carrito.clear();
        _idempotencyKey = repo.generateIdempotencyKey();
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      final error = _friendlySubmitError(e);
      final isAmbiguous = _isAmbiguousError(e);
      setState(() {
        _submitting = false;
        _submitError = error;
        // Si el error es ambiguo (timeout, red), congelar el carrito
        // para que el usuario no modifique y reintente con el mismo key.
        if (isAmbiguous) _frozen = true;
      });
    }
  }

  void _retry() => _submit(); // Mismo idempotencyKey

  /// Determina si el error es ambiguo (no sabemos si el backend recibió la solicitud).
  bool _isAmbiguousError(Object e) {
    final s = e.toString();
    // Errores claros del backend: NO son ambiguos (sabemos que no se creó)
    if (s.contains('STOCK_INSUFICIENTE')) return false;
    if (s.contains('caja') || s.contains('CAJA')) return false;
    if (s.contains('403')) return false;
    if (s.contains('400')) return false;
    // Timeout, conexión perdida, error desconocido: SÍ son ambiguos
    return true;
  }

  String _friendlySubmitError(Object e) {
    final s = e.toString();
    if (s.contains('STOCK_INSUFICIENTE')) {
      return 'Stock insuficiente para algún producto';
    }
    if (s.contains('caja') || s.contains('CAJA')) {
      return 'No hay caja abierta en esta sede';
    }
    if (s.contains('SESION_LEGACY')) {
      return 'La caja actual es legacy. Ciérrela y abra una nueva.';
    }
    if (s.contains('SocketException') || s.contains('connection')) {
      return 'Sin conexión al servidor';
    }
    if (s.contains('409')) return 'Esta venta ya fue registrada anteriormente';
    if (s.contains('403')) return 'No tienes permiso para registrar ventas';
    return 'No se pudo registrar la venta. Intenta de nuevo.';
  }

  void _showCarrito() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => CarritoVentaSheet(
          items: _carrito,
          total: _total,
          submitting: _submitting,
          error: _submitError,
          onConfirm: () async {
            await _submit();
            if (_carrito.isEmpty && ctx.mounted) Navigator.of(ctx).pop();
          },
          onRetry: _retry,
          onClear: () {
            if (_frozen) {
              _discardFrozen(); // Descartar intento fallido → nuevo key
            } else {
              _clearCart();
            }
            Navigator.of(ctx).pop();
          },
          onChangeQuantity: (id, delta) {
            if (_frozen) return; // No permitir cambios con carrito congelado
            _changeQuantity(id, delta);
            setModalState(() {});
            setState(() {});
          },
          onRemove: (id) {
            if (_frozen) return; // No permitir cambios con carrito congelado
            _removeFromCart(id);
            setModalState(() {});
            setState(() {});
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 1024;
    return desktop ? _buildDesktop() : _buildMobile();
  }

  Widget _buildDesktop() {
    return ColoredBox(
      key: const Key('desktop-sales-layout'),
      color: const Color(0xFFFAFAFA),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cartWidth = constraints.maxWidth < 900 ? 340.0 : 360.0;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildDesktopCatalogPanel()),
              const SizedBox(width: AppSpacing.md),
              SizedBox(
                width: cartWidth,
                child: _DesktopCartPanel(
                  items: _carrito,
                  total: _total,
                  submitting: _submitting,
                  frozen: _frozen,
                  error: _submitError,
                  onConfirm: _submit,
                  onRetry: _retry,
                  onClear: _frozen ? _discardFrozen : _clearCart,
                  onChangeQuantity: _changeQuantity,
                  onRemove: _removeFromCart,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDesktopCatalogPanel() {
    final status = _loadingProducts
        ? 'Cargando...'
        : _errorProducts != null
        ? 'No disponible'
        : '${_filteredProducts.length} disponibles';

    return Container(
      key: const Key('desktop-catalog-panel'),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Catálogo de productos',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      status,
                      key: const Key('desktop-catalog-status'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                DSSearchField(
                  controller: _searchCtrl,
                  placeholder: 'Buscar producto por nombre o código...',
                  onChanged: (_) => setState(() {}),
                  onClear: () {
                    _searchCtrl.clear();
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
          _buildPaymentNote(),
          const Divider(height: 1, color: AppColors.border),
          Expanded(child: _buildCatalog(desktop: true)),
        ],
      ),
    );
  }

  Widget _buildMobile() {
    return Column(
      key: const Key('mobile-sales-layout'),
      children: [
        // ── Buscador ───────────────────────────────────────────────────
        Container(
          color: AppColors.background,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: DSSearchField(
            controller: _searchCtrl,
            placeholder: 'Buscar producto por nombre o código...',
            onChanged: (_) => setState(() {}),
          ),
        ),

        // ── Nota de pago ───────────────────────────────────────────────
        _buildPaymentNote(),

        // ── Catálogo ───────────────────────────────────────────────────
        Expanded(child: _buildCatalog(desktop: false)),

        // ── Barra de carrito ───────────────────────────────────────────
        if (_carrito.isNotEmpty)
          _CartBar(
            key: const Key('mobile-cart-bar'),
            count: _carrito.fold(0, (s, i) => s + i.cantidad),
            total: _total,
            frozen: _frozen,
            onTap: _showCarrito,
          ),
      ],
    );
  }

  Widget _buildPaymentNote() {
    return Container(
      color: AppColors.brandSurface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 14, color: AppColors.brand),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'El método de pago se clasifica después en Caja / Conciliación.',
              style: TextStyle(fontSize: 11, color: AppColors.brandDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalog({required bool desktop}) {
    if (_loadingProducts) return const DSSkeletonList(count: 6);
    if (_errorProducts != null) {
      return DSErrorState(message: _errorProducts, onRetry: _loadProducts);
    }

    final products = _filteredProducts;
    if (products.isEmpty) {
      return DSEmptyState(
        icon: Icons.liquor_outlined,
        title: _searchCtrl.text.isNotEmpty ? 'Sin resultados' : 'Sin productos',
        message: _searchCtrl.text.isNotEmpty
            ? 'Sin productos para "${_searchCtrl.text}"'
            : 'No hay productos disponibles para vender.',
        actionLabel: 'Recargar',
        onAction: _loadProducts,
      );
    }

    if (desktop) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final columns = (constraints.maxWidth / 300).floor().clamp(2, 3);
          return GridView.builder(
            key: const Key('desktop-catalog-grid'),
            padding: const EdgeInsets.all(AppSpacing.md),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisExtent: 148,
              crossAxisSpacing: AppSpacing.sm,
              mainAxisSpacing: AppSpacing.sm,
            ),
            itemCount: products.length,
            itemBuilder: (_, i) =>
                _buildProductCard(products[i], desktop: true),
          );
        },
      );
    }

    return GridView.builder(
      key: const Key('mobile-catalog-grid'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        100,
      ),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        childAspectRatio: 0.78,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
      ),
      itemCount: products.length,
      itemBuilder: (_, i) => _buildProductCard(products[i], desktop: false),
    );
  }

  Widget _buildProductCard(Producto product, {required bool desktop}) {
    return _ProductoCard(
      producto: product,
      qty: _cartQty(product.id),
      frozen: _frozen,
      desktop: desktop,
      onAdd: () => _addToCart(product),
      onIncrease: () => _changeQuantity(product.id, 1),
      onDecrease: () => _changeQuantity(product.id, -1),
    );
  }
}

// --- Tarjeta de producto para nueva venta ------------------------------------

class _ProductoCard extends StatelessWidget {
  final Producto producto;
  final int qty;
  final bool frozen;
  final bool desktop;
  final VoidCallback onAdd, onIncrease, onDecrease;

  const _ProductoCard({
    required this.producto,
    required this.qty,
    required this.frozen,
    required this.desktop,
    required this.onAdd,
    required this.onIncrease,
    required this.onDecrease,
  });

  @override
  Widget build(BuildContext context) {
    return desktop ? _buildDesktop() : _buildMobile();
  }

  Widget _buildDesktop() {
    final stock = producto.stockDisponible;
    final agotado = stock != null && stock <= 0;
    final stockBajo = stock != null && stock > 0 && stock <= 5;

    return Container(
      key: ValueKey('desktop-product-${producto.id}'),
      decoration: _decoration,
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            child: DSProductImage(
              imageUrl: producto.imageUrl,
              productName: producto.nombre,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              radius: 0,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    producto.codigo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    producto.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          FormatUtils.currency(producto.precioVenta),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      if (stockBajo)
                        Text(
                          '$stock disp.',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.warning,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  _buildQuantityControl(agotado: agotado, stock: stock),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobile() {
    final stock = producto.stockDisponible;
    final agotado = stock != null && stock <= 0;
    final stockBajo = stock != null && stock > 0 && stock <= 5;

    return Container(
      decoration: _decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagen (los productos no tienen imageUrl aún — placeholder con inicial)
          Expanded(
            flex: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppSpacing.radiusLG),
              ),
              child: DSProductImage(
                imageUrl: producto.imageUrl,
                productName: producto.nombre,
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
          ),
          // Info
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    producto.nombre,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Text(
                        FormatUtils.currency(producto.precioVenta),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      const Spacer(),
                      if (stock != null && stockBajo)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warningLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$stock',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  _buildQuantityControl(agotado: agotado, stock: stock),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration get _decoration => BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
    border: Border.all(
      color: qty > 0
          ? AppColors.primary.withValues(alpha: 0.3)
          : AppColors.border,
      width: qty > 0 ? 1.5 : 0.75,
    ),
    boxShadow: AppShadows.card,
  );

  Widget _buildQuantityControl({required bool agotado, required int? stock}) {
    if (qty == 0 || agotado) {
      return SizedBox(
        width: double.infinity,
        height: desktop ? 32 : 36,
        child: TextButton(
          onPressed: (agotado || frozen) ? null : onAdd,
          style: TextButton.styleFrom(
            backgroundColor: agotado
                ? AppColors.surfaceAlt
                : AppColors.primarySurface,
            foregroundColor: agotado
                ? AppColors.textTertiary
                : AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            agotado ? 'Sin stock' : '+ Agregar',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _QtyBtn(
          icon: Icons.remove_rounded,
          onTap: frozen ? null : onDecrease,
          size: desktop ? 28 : 34,
        ),
        Text(
          '$qty',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
        _QtyBtn(
          icon: Icons.add_rounded,
          onTap: (frozen || (stock != null && qty >= stock))
              ? null
              : onIncrease,
          color: AppColors.primary,
          size: desktop ? 28 : 34,
        ),
      ],
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  final double size;
  const _QtyBtn({required this.icon, this.onTap, this.color, this.size = 34});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      if (onTap != null) {
        HapticFeedback.selectionClick();
        onTap!();
      }
    },
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: (color ?? AppColors.textTertiary).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        size: 18,
        color: onTap != null
            ? (color ?? AppColors.textSecondary)
            : AppColors.textDisabled,
      ),
    ),
  );
}

class _DesktopCartPanel extends StatelessWidget {
  final List<CarritoItem> items;
  final double total;
  final bool submitting;
  final bool frozen;
  final String? error;
  final VoidCallback onConfirm;
  final VoidCallback onRetry;
  final VoidCallback onClear;
  final void Function(String productoId, int delta) onChangeQuantity;
  final void Function(String productoId) onRemove;

  const _DesktopCartPanel({
    required this.items,
    required this.total,
    required this.submitting,
    required this.frozen,
    required this.error,
    required this.onConfirm,
    required this.onRetry,
    required this.onClear,
    required this.onChangeQuantity,
    required this.onRemove,
  });

  int get _itemCount => items.fold(0, (sum, item) => sum + item.cantidad);

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('desktop-cart-panel'),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.xs,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: frozen
                        ? AppColors.warningLight
                        : AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                  ),
                  child: Icon(
                    frozen
                        ? Icons.sync_problem_rounded
                        : Icons.shopping_cart_rounded,
                    size: 19,
                    color: frozen ? AppColors.warning : AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Venta actual',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        _itemCount == 1
                            ? '1 producto seleccionado'
                            : '$_itemCount productos seleccionados',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (items.isNotEmpty)
                  TextButton(
                    key: const Key('desktop-cart-clear'),
                    onPressed: submitting ? null : onClear,
                    child: Text(
                      frozen ? 'Descartar intento' : 'Limpiar',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: items.isEmpty
                ? const _DesktopEmptyCart()
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.divider),
                    itemBuilder: (_, index) {
                      final item = items[index];
                      return _DesktopCartItem(
                        key: ValueKey('desktop-cart-item-${item.productoId}'),
                        item: item,
                        frozen: frozen,
                        onDecrease: () => onChangeQuantity(item.productoId, -1),
                        onIncrease: () => onChangeQuantity(item.productoId, 1),
                        onRemove: () => onRemove(item.productoId),
                      );
                    },
                  ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                if (error != null) ...[
                  Container(
                    key: const Key('desktop-cart-error'),
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: frozen
                          ? AppColors.warningLight
                          : AppColors.errorLight,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                      border: Border.all(
                        color: frozen
                            ? AppColors.warningBorder
                            : AppColors.errorBorder,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          error!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: frozen ? AppColors.warning : AppColors.error,
                          ),
                        ),
                        if (frozen) ...[
                          const SizedBox(height: AppSpacing.xxs),
                          const Text(
                            'Reintenta sin modificar el carrito para conservar la operación.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xs),
                        TextButton.icon(
                          key: const Key('desktop-cart-retry'),
                          onPressed: submitting ? null : onRetry,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 32),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            foregroundColor: frozen
                                ? AppColors.warning
                                : AppColors.error,
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      _fmt(total),
                      key: const Key('desktop-cart-total'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'El método de pago se registra después en caja.',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  height: AppSpacing.buttonHeight,
                  child: ElevatedButton(
                    key: const Key('desktop-cart-confirm'),
                    onPressed: items.isEmpty || submitting ? null : onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.border,
                      disabledForegroundColor: AppColors.textTertiary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusLG,
                        ),
                      ),
                    ),
                    child: submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'CONFIRMAR VENTA',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopEmptyCart extends StatelessWidget {
  const _DesktopEmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
              ),
              child: const Icon(
                Icons.add_shopping_cart_rounded,
                size: 28,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Tu carrito está vacío',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            const Text(
              'Selecciona productos del catálogo para comenzar.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopCartItem extends StatelessWidget {
  final CarritoItem item;
  final bool frozen;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onRemove;

  const _DesktopCartItem({
    super.key,
    required this.item,
    required this.frozen,
    required this.onDecrease,
    required this.onIncrease,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxxs),
                    Text(
                      item.codigo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: ValueKey('desktop-cart-remove-${item.productoId}'),
                tooltip: 'Quitar producto',
                onPressed: frozen ? null : onRemove,
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.close_rounded, size: 17),
                color: AppColors.textTertiary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              _QtyBtn(
                icon: Icons.remove_rounded,
                onTap: frozen ? null : onDecrease,
                size: 28,
              ),
              SizedBox(
                width: 34,
                child: Text(
                  '${item.cantidad}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _QtyBtn(
                icon: Icons.add_rounded,
                onTap: frozen ? null : onIncrease,
                color: AppColors.primary,
                size: 28,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  '${_fmt(item.precio)} × ${item.cantidad}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                _fmt(item.subtotal),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- Barra del carrito --------------------------------------------------------

class _CartBar extends StatelessWidget {
  final int count;
  final double total;
  final bool frozen;
  final VoidCallback onTap;

  const _CartBar({
    super.key,
    required this.count,
    required this.total,
    required this.frozen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: const Border(
          top: BorderSide(color: AppColors.border, width: 0.75),
        ),
      ),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: frozen ? AppColors.warning : AppColors.primary,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: (frozen ? AppColors.warning : AppColors.primary)
                    .withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: AppSpacing.md),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  frozen ? 'Revisar carrito (error)' : 'Ver carrito',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                FormatUtils.currency(total),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
            ],
          ),
        ),
      ),
    ),
  );
}
