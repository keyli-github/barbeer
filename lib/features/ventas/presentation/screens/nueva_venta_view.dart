import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../productos/data/productos_repository.dart';
import '../providers/ventas_provider.dart';
import '../widgets/producto_venta_card.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Venta registrada correctamente'),
          backgroundColor: AppColors.success,
        ),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Buscar producto...',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.borderLight),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            style: const TextStyle(fontSize: 14),
          ),
        ),
        Expanded(
          child: _loadingProducts
              ? const Center(child: CircularProgressIndicator())
              : _errorProducts != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _errorProducts!,
                        style: TextStyle(color: AppColors.error),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _loadProducts,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : _filteredProducts.isEmpty
              ? Center(
                  child: Text(
                    _searchCtrl.text.isNotEmpty
                        ? 'Sin resultados para "${_searchCtrl.text}"'
                        : 'No hay productos disponibles',
                    style: TextStyle(color: AppColors.textTertiary),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _filteredProducts.length,
                  itemBuilder: (_, i) {
                    final p = _filteredProducts[i];
                    return ProductoVentaCard(
                      codigo: p.codigo,
                      nombre: p.nombre,
                      precio: p.precioVenta,
                      cantidadEnCarrito: _cartQty(p.id),
                      stockDisponible: p.stockDisponible,
                      onTap: () => _addToCart(p),
                    );
                  },
                ),
        ),
        if (_carrito.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.borderLight)),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _showCarrito,
                  icon: const Icon(Icons.shopping_cart_rounded, size: 18),
                  label: Text(
                    '${_carrito.length} item${_carrito.length == 1 ? '' : 's'} · ${_fmt(_total)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
