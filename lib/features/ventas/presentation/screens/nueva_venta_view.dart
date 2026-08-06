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
  const NuevaVentaView({super.key});
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
      final repo = ProductosRepository(ApiClient.instance);
      final result = await repo.list(pagina: 1, limite: 100, activo: 'true');
      setState(() {
        _productos = result.data
            .where((p) => p.disponiblePos && p.activo)
            .toList();
        _loadingProducts = false;
      });
    } catch (e) {
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
      DSSuccessOverlay.show(context,
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
    if (s.contains('STOCK_INSUFICIENTE'))
      return 'Stock insuficiente para algún producto';
    if (s.contains('caja') || s.contains('CAJA'))
      return 'No hay caja abierta en esta sede';
    if (s.contains('SESION_LEGACY'))
      return 'La caja actual es legacy. Ciérrela y abra una nueva.';
    if (s.contains('SocketException') || s.contains('connection'))
      return 'Sin conexión al servidor';
    if (s.contains('409')) return 'Esta venta ya fue registrada anteriormente';
    if (s.contains('403')) return 'No tienes permiso para registrar ventas';
    return 'No se pudo registrar la venta. Intenta de nuevo.';
  }

  void _showCarrito() {
    showModalBottomSheet(
      context: context,
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
            if (_carrito.isEmpty && mounted) Navigator.of(ctx).pop();
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
    return Column(
      children: [
        // ── Buscador ───────────────────────────────────────────────────
        Container(
          color: AppColors.background,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
          child: DSSearchField(
            controller: _searchCtrl,
            placeholder: 'Buscar producto por nombre o código...',
            onChanged: (_) => setState(() {}),
          ),
        ),

        // ── Nota de pago ───────────────────────────────────────────────
        Container(
          color: AppColors.brandSurface,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          child: Row(children: [
            Icon(Icons.info_outline_rounded,
              size: 14, color: AppColors.brand),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'El método de pago se clasifica después en Caja / Conciliación.',
                style: TextStyle(fontSize: 11, color: AppColors.brandDark)),
            ),
          ]),
        ),

        // ── Catálogo ───────────────────────────────────────────────────
        Expanded(
          child: _loadingProducts
              ? const DSSkeletonList(count: 6)
              : _errorProducts != null
                  ? DSErrorState(message: _errorProducts, onRetry: _loadProducts)
                  : _filteredProducts.isEmpty
                      ? DSEmptyState(
                          icon: Icons.liquor_outlined,
                          title: _searchCtrl.text.isNotEmpty
                              ? 'Sin resultados' : 'Sin productos',
                          message: _searchCtrl.text.isNotEmpty
                              ? 'Sin productos para "${_searchCtrl.text}"'
                              : 'No hay productos disponibles para vender.',
                          actionLabel: 'Recargar',
                          onAction: _loadProducts,
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md, AppSpacing.sm,
                            AppSpacing.md, 100),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.78,
                            crossAxisSpacing: AppSpacing.sm,
                            mainAxisSpacing: AppSpacing.sm,
                          ),
                          itemCount: _filteredProducts.length,
                          itemBuilder: (_, i) {
                            final p = _filteredProducts[i];
                            final qty = _cartQty(p.id);
                            return _ProductoCard(
                              producto: p,
                              qty: qty,
                              frozen: _frozen,
                              onAdd: () => _addToCart(p),
                              onIncrease: () => _changeQuantity(p.id, 1),
                              onDecrease: () => _changeQuantity(p.id, -1),
                            );
                          },
                        ),
        ),

        // ── Barra de carrito ───────────────────────────────────────────
        if (_carrito.isNotEmpty)
          _CartBar(
            count: _carrito.fold(0, (s, i) => s + i.cantidad),
            total: _total,
            frozen: _frozen,
            onTap: _showCarrito,
          ),
      ],
    );
  }
}

// --- Tarjeta de producto para nueva venta ------------------------------------

class _ProductoCard extends StatelessWidget {
  final dynamic producto;
  final int qty;
  final bool frozen;
  final VoidCallback onAdd, onIncrease, onDecrease;

  const _ProductoCard({
    required this.producto,
    required this.qty,
    required this.frozen,
    required this.onAdd,
    required this.onIncrease,
    required this.onDecrease,
  });

  @override
  Widget build(BuildContext context) {
    final stock = producto.stockDisponible as int?;
    final agotado = stock != null && stock <= 0;
    final stockBajo = stock != null && stock > 0 && stock <= 5;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
        border: Border.all(
          color: qty > 0 ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border,
          width: qty > 0 ? 1.5 : 0.75),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagen
          Expanded(
            flex: 5,
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppSpacing.radiusLG)),
              child: DSProductImage(
                imageUrl: producto.imageUrl as String?,
                productName: producto.nombre as String,
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
          ),
          // Info
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(producto.nombre as String,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                  const Spacer(),
                  Row(children: [
                    Text(FormatUtils.currency(producto.precioVenta as double),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                        color: AppColors.primary)),
                    const Spacer(),
                    if (stock != null && stockBajo)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.warningLight,
                          borderRadius: BorderRadius.circular(4)),
                        child: Text('$stock', style: const TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w700,
                          color: AppColors.warning))),
                  ]),
                  const SizedBox(height: AppSpacing.xxs),
                  // Controles de cantidad
                  if (qty == 0 || agotado)
                    SizedBox(
                      width: double.infinity,
                      height: 32,
                      child: TextButton(
                        onPressed: (agotado || frozen) ? null : onAdd,
                        style: TextButton.styleFrom(
                          backgroundColor: agotado
                              ? AppColors.surfaceAlt
                              : AppColors.primarySurface,
                          foregroundColor: agotado
                              ? AppColors.textTertiary : AppColors.primary,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(agotado ? 'Sin stock' : '+ Agregar',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _QtyBtn(icon: Icons.remove_rounded,
                          onTap: frozen ? null : onDecrease),
                        Text('$qty', style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800,
                          color: AppColors.primary)),
                        _QtyBtn(icon: Icons.add_rounded,
                          onTap: (frozen || (stock != null && qty >= stock))
                              ? null : onIncrease,
                          color: AppColors.primary),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  const _QtyBtn({required this.icon, this.onTap, this.color});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () { if (onTap != null) { HapticFeedback.selectionClick(); onTap!(); } },
    child: Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: (color ?? AppColors.textTertiary).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 16,
        color: onTap != null
            ? (color ?? AppColors.textSecondary)
            : AppColors.textDisabled),
    ),
  );
}

// --- Barra del carrito --------------------------------------------------------

class _CartBar extends StatelessWidget {
  final int count;
  final double total;
  final bool frozen;
  final VoidCallback onTap;

  const _CartBar({
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
        AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: const Border(top: BorderSide(color: AppColors.border, width: 0.75)),
      ),
      child: GestureDetector(
        onTap: () { HapticFeedback.mediumImpact(); onTap(); },
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: frozen ? AppColors.warning : AppColors.primary,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: (frozen ? AppColors.warning : AppColors.primary)
                    .withValues(alpha: 0.3),
                blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(children: [
            const SizedBox(width: AppSpacing.md),
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8)),
              child: Center(
                child: Text('$count',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                    color: Colors.white)),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(
              frozen ? 'Revisar carrito (error)' : 'Ver carrito',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                color: Colors.white))),
            Text(FormatUtils.currency(total),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                color: Colors.white)),
            const SizedBox(width: AppSpacing.md),
          ]),
        ),
      ),
    ),
  );
}
