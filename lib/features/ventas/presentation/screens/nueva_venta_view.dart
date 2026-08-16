import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/providers/sede_scope_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/ds_inputs.dart';
import '../../../../core/widgets/ds_product_image.dart';
import '../../../../core/widgets/ds_states.dart';
import '../../../productos/data/productos_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/venta_models.dart';
import '../../data/ventas_repository.dart';
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
  CreateVentaPayload? _retryPayload;
  EstadoConciliacion _payment = EstadoConciliacion.efectivo;
  List<Etiqueta> _etiquetas = [];
  String? _etiquetaId;
  List<VendedorVenta> _vendedores = [];
  String? _vendedoraId;
  double? _recargoMonto;
  String? _recargoMotivo;
  Uint8List? _voucherBytes;
  String? _voucherFilename;
  ComprobanteAnalisis? _comprobanteAnalisis;
  bool _analizandoComprobante = false;
  bool _analisisInvalidado = false;
  String? _comprobanteError;
  int _voucherRequestToken = 0;
  String? _loadedSedeId;
  late final VentasRepository _repository;

  /// true después de un intento fallido ambiguo (timeout, error de red).
  /// Mientras está congelado, no se puede modificar el carrito.
  /// El usuario debe Reintentar (mismo key) o Descartar (nuevo key).
  bool _frozen = false;

  @override
  void initState() {
    super.initState();
    _repository = ref.read(ventasRepositoryProvider);
    _idempotencyKey = ref
        .read(ventasRepositoryProvider)
        .generateIdempotencyKey();
    _loadProducts();
  }

  @override
  void dispose() {
    _voucherRequestToken++;
    _cancelAnalysis(_comprobanteAnalisis);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loadingProducts = true;
      _errorProducts = null;
    });
    try {
      final auth = ref.read(authProvider);
      final selectedSedeId = ref.read(globalSedeIdProvider);
      final effectiveSedeId = auth.user?.isSuperAdmin == true
          ? selectedSedeId
          : auth.user?.sedeId;
      if (widget.productsLoader == null && effectiveSedeId == null) {
        throw StateError(
          auth.user?.isSuperAdmin == true
              ? 'Selecciona una sede para vender'
              : 'Tu usuario no tiene una sede asignada',
        );
      }
      final products = widget.productsLoader != null
          ? await widget.productsLoader!()
          : (await ProductosRepository(ApiClient.instance).list(
              pagina: 1,
              limite: 100,
              activo: 'true',
              sedeId: effectiveSedeId,
            )).data;
      if (!mounted) return;
      setState(() {
        _productos = products
            .where((p) => p.disponiblePos && p.activo)
            .toList();
        _loadingProducts = false;
        _loadedSedeId = effectiveSedeId;
      });
      if (effectiveSedeId != null) {
        await _loadSaleOptions(effectiveSedeId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingProducts = false;
        _errorProducts = e is StateError
            ? e.message.toString()
            : 'No se pudieron cargar los productos';
      });
    }
  }

  Future<void> _loadSaleOptions(String sedeId) async {
    final repo = ref.read(ventasRepositoryProvider);
    final auth = ref.read(authProvider);
    final results = await Future.wait<Object>([
      repo.listEtiquetasActivas(sedeId: sedeId).catchError((_) => <Etiqueta>[]),
      if (canReadAllVentas(auth))
        repo.listVendedores(sedeId: sedeId).catchError((_) => <VendedorVenta>[])
      else
        Future.value(<VendedorVenta>[]),
    ]);
    if (!mounted || _loadedSedeId != sedeId) return;
    setState(() {
      _etiquetas = results[0] as List<Etiqueta>;
      _vendedores = results[1] as List<VendedorVenta>;
      // No auto-seleccionar: el usuario elige la billetera explícitamente.
      if (!_etiquetas.any((e) => e.id == _etiquetaId)) {
        _etiquetaId = null;
      }
      final user = auth.user;
      _vendedoraId = _vendedores.any((v) => v.id == _vendedoraId)
          ? _vendedoraId
          : user?.id;
    });
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

  void _addToCart(Producto product, {double? precioVenta}) {
    if (_frozen) return; // Carrito congelado tras error ambiguo
    final existing = _carrito
        .where((i) => i.productoId == product.id)
        .firstOrNull;
    final stock = product.stockDisponible;
    if (stock != null && (existing?.cantidad ?? 0) >= stock) {
      AppFeedback.error(context, 'No puedes superar el stock disponible.');
      return;
    }
    setState(() {
      if (existing != null) {
        existing.cantidad++;
        if (precioVenta != null) existing.precio = precioVenta;
      } else {
        _carrito.add(
          CarritoItem(
            productoId: product.id,
            nombre: product.nombre,
            codigo: product.codigo,
            precio: precioVenta ?? product.precioVenta,
          ),
        );
      }
    });
    _invalidateAnalysisIfAmountChanged();
  }

  Future<void> _selectProduct(Producto product) async {
    if (_frozen) return;
    final price = await _showProductModal(
      nombre: product.nombre,
      imageUrl: product.imageUrl,
      basePrice: product.precioVenta,
    );
    if (price != null && mounted) _addToCart(product, precioVenta: price);
  }

  /// Modal "Añadir a la Venta" equivalente al de la web:
  /// imagen, nombre, precio base, precio a cobrar y confirmación.
  Future<double?> _showProductModal({
    required String nombre,
    required String? imageUrl,
    required double basePrice,
  }) async {
    var text = basePrice.toStringAsFixed(2);
    String? error;
    final result = await showDialog<double>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          key: const Key('add-to-sale-modal'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header ───────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Añadir a la Venta',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.of(context).pop(),
                          color: context.colors.textTertiary,
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: context.colors.border),
                  // ── Cuerpo ───────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 64,
                                height: 64,
                                child: DSProductImage(
                                  imageUrl: imageUrl,
                                  productName: nombre,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  radius: 0,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nombre,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      height: 1.25,
                                      color: context.colors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Precio base: ${_fmt(basePrice)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Precio a cobrar (S/)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          key: const Key('custom-price-field'),
                          initialValue: text,
                          autofocus: true,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}'),
                            ),
                          ],
                          decoration: InputDecoration(
                            hintText: '0.00',
                            errorText: error,
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onChanged: (value) => text = value,
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          alignment: WrapAlignment.end,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancelar'),
                            ),
                            FilledButton(
                              onPressed: () {
                                final value = double.tryParse(text.trim());
                                if (value == null || value <= 0) {
                                  setDialogState(
                                    () => error = 'Ingresa un precio mayor a 0',
                                  );
                                  return;
                                }
                                Navigator.of(context).pop(value);
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.brand,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Confirmar'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return result;
  }

  Future<void> _editPrice(CarritoItem item) async {
    if (_frozen) return;
    final product = _productos
        .where((p) => p.id == item.productoId)
        .firstOrNull;
    final price = await _showProductModal(
      nombre: item.nombre,
      imageUrl: product?.imageUrl,
      basePrice: item.precio,
    );
    if (price != null && mounted) {
      setState(() => item.precio = price);
      _invalidateAnalysisIfAmountChanged();
    }
  }

  void _changeQuantity(String productoId, int delta) {
    if (_frozen) return; // Carrito congelado tras error ambiguo
    if (delta > 0) {
      final stock = _stockDisponible(productoId);
      if (stock != null && _cartQty(productoId) >= stock) {
        AppFeedback.error(context, 'No puedes superar el stock disponible.');
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
    _invalidateAnalysisIfAmountChanged();
  }

  void _removeFromCart(String productoId) {
    if (_frozen) return; // Carrito congelado tras error ambiguo
    setState(() {
      _carrito.removeWhere((i) => i.productoId == productoId);
    });
    _invalidateAnalysisIfAmountChanged();
  }

  /// Descarta el intento fallido y permite modificar el carrito.
  /// Genera un nuevo idempotencyKey — la operación anterior se considera abandonada.
  void _discardFrozen() {
    setState(() {
      _frozen = false;
      _submitError = null;
      _retryPayload = null;
      _idempotencyKey = ref
          .read(ventasRepositoryProvider)
          .generateIdempotencyKey();
    });
  }

  void _clearCart() {
    _cancelAnalysis(_comprobanteAnalisis);
    _voucherRequestToken++;
    setState(() {
      _carrito.clear();
      _frozen = false;
      _submitError = null;
      _retryPayload = null;
      _recargoMonto = null;
      _recargoMotivo = null;
      _payment = EstadoConciliacion.efectivo;
      _voucherBytes = null;
      _voucherFilename = null;
      _comprobanteAnalisis = null;
      _comprobanteError = null;
      _analisisInvalidado = false;
      _analizandoComprobante = false;
      _idempotencyKey = ref
          .read(ventasRepositoryProvider)
          .generateIdempotencyKey();
    });
  }

  double get _subtotal => _carrito.fold(0.0, (sum, i) => sum + i.subtotal);
  double get _total => _subtotal + (_recargoMonto ?? 0);

  Future<void> _pickVoucher(VoidCallback refresh) async {
    final token = ++_voucherRequestToken;
    try {
      final file = await ref.read(voucherImagePickerProvider)();
      if (file == null || !mounted || token != _voucherRequestToken) return;
      final auth = ref.read(authProvider);
      final sedeId = auth.user?.isSuperAdmin == true
          ? ref.read(globalSedeIdProvider)
          : auth.user?.sedeId;
      await _cancelAnalysis(_comprobanteAnalisis);
      if (!mounted || token != _voucherRequestToken) return;
      setState(() {
        _voucherBytes = file.bytes;
        _voucherFilename = file.filename;
        _comprobanteAnalisis = null;
        _comprobanteError = null;
        _analisisInvalidado = false;
        _analizandoComprobante = true;
      });
      refresh();
      final analysis = await _repository.analizarComprobante(
        bytes: file.bytes,
        filename: file.filename,
        sedeId: auth.user?.isSuperAdmin == true ? sedeId : null,
      );
      if (!mounted || token != _voucherRequestToken) {
        await _repository
            .cancelarComprobanteAnalisis(analysis.id)
            .catchError((_) {});
        return;
      }
      setState(() {
        _comprobanteAnalisis = analysis;
        _analizandoComprobante = false;
        final suggested = analysis.etiquetaSugerida;
        if (suggested != null) {
          _etiquetaId = suggested.id;
          // Asegura que la billetera detectada por Gemini aparezca en el
          // selector aunque la carga de etiquetas haya fallado en remoto
          if (!_etiquetas.any((e) => e.id == suggested.id)) {
            _etiquetas = [
              ..._etiquetas,
              Etiqueta(
                id: suggested.id,
                nombre: suggested.nombre,
                activo: true,
                requiereComprobante: true,
                esSistema: false,
                tipo: 'ENTRADA',
                orden: 999,
              ),
            ];
          }
        }
        _comprobanteError = comprobanteAnalysisError(
          analysis: analysis,
          total: _total,
          required: true,
          selectedEtiquetaId: _etiquetaId,
        );
        _analisisInvalidado = false;
      });
      refresh();
    } catch (e) {
      if (!mounted || token != _voucherRequestToken) return;
      setState(() {
        _analizandoComprobante = false;
        _comprobanteAnalisis = null;
        _comprobanteError = e is FormatException
            ? e.message
            : e.toString().replaceFirst('AppException: ', '');
      });
      refresh();
    }
  }

  void _invalidateAnalysisIfAmountChanged() {
    final analysis = _comprobanteAnalisis;
    if (analysis == null || !analysis.montoExcede(_total)) return;
    setState(() {
      _analisisInvalidado = true;
      _comprobanteError =
          'El monto cambió. Selecciona y analiza un nuevo comprobante.';
    });
  }

  void _clearVoucherAnalysis() {
    _voucherRequestToken++;
    _cancelAnalysis(_comprobanteAnalisis);
    _voucherBytes = null;
    _voucherFilename = null;
    _comprobanteAnalisis = null;
    _comprobanteError = null;
    _analisisInvalidado = false;
    _analizandoComprobante = false;
  }

  Future<void> _cancelAnalysis(ComprobanteAnalisis? analysis) async {
    if (analysis == null || analysis.id.isEmpty) return;
    await _repository
        .cancelarComprobanteAnalisis(analysis.id)
        .catchError((_) {});
  }

  Future<void> _editRecargo(VoidCallback refresh) async {
    var amountText = _recargoMonto?.toStringAsFixed(2) ?? '';
    var reasonText = _recargoMotivo ?? '';
    String? error;
    final result = await showDialog<(double, String)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          title: const Text('Recargo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const Key('recargo-amount-field'),
                initialValue: amountText,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: InputDecoration(
                  labelText: 'Monto',
                  errorText: error,
                ),
                onChanged: (value) => amountText = value,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('recargo-reason-field'),
                initialValue: reasonText,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Motivo'),
                onChanged: (value) => reasonText = value,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(amountText.trim());
                final reason = reasonText.trim();
                if (amount == null || amount <= 0 || reason.isEmpty) {
                  setDialogState(
                    () => error = 'Monto y motivo son obligatorios',
                  );
                  return;
                }
                Navigator.pop(context, (amount, reason));
              },
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _recargoMonto = result.$1;
      _recargoMotivo = result.$2;
    });
    _invalidateAnalysisIfAmountChanged();
    refresh();
  }

  Widget _buildSaleDetails({required VoidCallback refresh}) {
    final auth = ref.read(authProvider);
    final selectedEtiqueta = _etiquetas
        .where((item) => item.id == _etiquetaId)
        .firstOrNull;
    void update(VoidCallback change) {
      setState(change);
      refresh();
    }

    return Container(
      key: const Key('sale-details'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canReadAllVentas(auth) && _vendedores.isNotEmpty) ...[
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Asignar venta a',
                isDense: true,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  key: const ValueKey('seller-field'),
                  value: _vendedores.any((v) => v.id == _vendedoraId)
                      ? _vendedoraId
                      : null,
                  isExpanded: true,
                  isDense: true,
                  hint: const Text('Selecciona...'),
                  items: _vendedores
                      .map(
                        (seller) => DropdownMenuItem(
                          value: seller.id,
                          child: Text('${seller.username} (${seller.rol})'),
                        ),
                      )
                      .toList(),
                  onChanged: _frozen
                      ? null
                      : (value) => update(() => _vendedoraId = value),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Wrap(
            spacing: 6,
            children: EstadoConciliacion.values
                .map(
                  (payment) => ChoiceChip(
                    key: ValueKey('payment-${payment.name}'),
                    label: Text(estadoConciliacionLabel(payment)),
                    selected: _payment == payment,
                    onSelected: _frozen
                        ? null
                        : (_) => update(() {
                            if (_payment != payment) {
                              _payment = payment;
                              _clearVoucherAnalysis();
                            }
                          }),
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(),
          ),
          if (_payment == EstadoConciliacion.billetera) ...[
            const SizedBox(height: AppSpacing.xs),
            // Dropdown estable (sin ValueKey cambiante): siempre abre y
            // refleja el valor auto-sugerido por el análisis de Gemini.
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Billetera / banco',
                isDense: true,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  key: const ValueKey('wallet-field'),
                  value: _etiquetas.any((e) => e.id == _etiquetaId)
                      ? _etiquetaId
                      : null,
                  isExpanded: true,
                  isDense: true,
                  hint: const Text('Selecciona una billetera…'),
                  items: _etiquetas
                      .map(
                        (e) =>
                            DropdownMenuItem(value: e.id, child: Text(e.nombre)),
                      )
                      .toList(),
                  onChanged: _frozen
                      ? null
                      : (value) => update(() {
                          _etiquetaId = value;
                          if (_comprobanteAnalisis?.etiquetaSugerida?.id !=
                              value) {
                            _clearVoucherAnalysis();
                          }
                        }),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('voucher-picker'),
                onPressed: _frozen || _submitting
                    ? null
                    : () => _pickVoucher(refresh),
                icon: _analizandoComprobante
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _comprobanteAnalisis?.esApto == true &&
                                !_analisisInvalidado
                            ? Icons.verified_rounded
                            : Icons.add_photo_alternate_outlined,
                        size: 17,
                      ),
                label: Text(
                  _analizandoComprobante
                      ? 'Analizando comprobante...'
                      : _voucherFilename ??
                            (selectedEtiqueta?.requiereComprobante == true
                                ? 'Seleccionar comprobante *'
                                : 'Seleccionar comprobante (opcional)'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (_voucherBytes != null || _comprobanteAnalisis != null) ...[
              const SizedBox(height: AppSpacing.xs),
              _buildReceiptPanel(),
            ],
            if (_comprobanteError != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Container(
                key: const Key('receipt-analysis-error'),
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: _comprobanteAnalisis?.posibleDuplicado == true
                      ? context.colors.errorLight
                      : context.colors.warningLight,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                ),
                child: Text(
                  _comprobanteError!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _comprobanteAnalisis?.posibleDuplicado == true
                        ? AppColors.error
                        : AppColors.warning,
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: _recargoMonto == null
                    ? TextButton.icon(
                        key: const Key('add-surcharge'),
                        onPressed: _frozen ? null : () => _editRecargo(refresh),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Agregar recargo'),
                      )
                    : Text(
                        'Recargo: ${_fmt(_recargoMonto!)}\n${_recargoMotivo ?? ''}',
                        style: const TextStyle(fontSize: 11),
                      ),
              ),
              if (_recargoMonto != null)
                IconButton(
                  key: const Key('remove-surcharge'),
                  onPressed: _frozen
                      ? null
                      : () {
                          update(() {
                            _recargoMonto = null;
                            _recargoMotivo = null;
                          });
                          _invalidateAnalysisIfAmountChanged();
                        },
                  icon: const Icon(Icons.close_rounded, size: 17),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptPanel() {
    final analysis = _comprobanteAnalisis;
    return Container(
      key: const Key('receipt-analysis-panel'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border: Border.all(
          color: analysis?.esApto == true && !_analisisInvalidado
              ? context.colors.successBorder
              : context.colors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
            child: SizedBox(
              width: 76,
              height: 96,
              child: _voucherBytes != null
                  ? Image.memory(_voucherBytes!, fit: BoxFit.cover)
                  : Image.network(
                      analysis?.thumbnailUrl ?? analysis?.imagenUrl ?? '',
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => ColoredBox(
                        color: context.colors.surfaceAlt,
                        child: const Icon(Icons.receipt_long_outlined),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: analysis == null
                ? Text(
                    _analizandoComprobante
                        ? 'Gemini está leyendo la imagen y validando sus datos.'
                        : 'No se pudo completar el análisis.',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.textSecondary,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              analysis.entidad ?? 'Entidad no identificada',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: context.colors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            'Conf. ${(analysis.confianza.promedio * 100).round()}%',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      _receiptLine(
                        'Monto',
                        analysis.monto == null
                            ? 'No identificado'
                            : _fmt(analysis.monto!),
                      ),
                      _receiptLine(
                        'Operación',
                        analysis.codigoOperacion ?? 'No identificada',
                      ),
                      _receiptLine(
                        'Seguridad',
                        analysis.codigoSeguridad ?? 'No identificado',
                      ),
                      _receiptLine(
                        'Fecha / hora',
                        [
                          analysis.fechaOperacion,
                          analysis.horaOperacion,
                        ].whereType<String>().join(' '),
                      ),
                      _receiptLine(
                        'Etiqueta',
                        analysis.etiquetaSugerida?.nombre ?? 'Sin sugerencia',
                      ),
                      if (analysis.montoEsMenor(_total) && !_analisisInvalidado)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: context.colors.warningLight,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusSM,
                              ),
                            ),
                            child: Text(
                              'Monto menor al total: el cliente puede completar con otro pago.',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                        ),
                      if (analysis.advertencias.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            analysis.advertencias.join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.warning,
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

  Widget _receiptLine(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Text.rich(
      TextSpan(
        style: TextStyle(fontSize: 10, color: context.colors.textSecondary),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: value.isEmpty ? 'No identificada' : value),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );

  Future<void> _submit() async {
    if (_submitting || _carrito.isEmpty) return;
    if (_retryPayload != null) {
      await _executePayload(_retryPayload!);
      return;
    }
    final auth = ref.read(authProvider);
    final sedeId = auth.user?.isSuperAdmin == true
        ? ref.read(globalSedeIdProvider)
        : auth.user?.sedeId;
    if (auth.user?.isSuperAdmin == true && sedeId == null) {
      setState(
        () => _submitError = 'Selecciona una sede para registrar la venta',
      );
      return;
    }
    final etiqueta = _etiquetas.where((e) => e.id == _etiquetaId).firstOrNull;
    if (_payment == EstadoConciliacion.billetera && etiqueta == null) {
      setState(() => _submitError = 'Selecciona una billetera compatible');
      return;
    }
    final analysis = _comprobanteAnalisis;
    if (_payment == EstadoConciliacion.billetera) {
      if (_analizandoComprobante) {
        setState(() => _submitError = 'Espera a que termine el análisis');
        return;
      }
      final analysisError = comprobanteAnalysisError(
        analysis: analysis,
        total: _total,
        required: etiqueta!.requiereComprobante,
        selectedEtiquetaId: _etiquetaId,
      );
      if (analysisError != null || _analisisInvalidado) {
        setState(
          () => _submitError = _analisisInvalidado
              ? 'El monto cambió. Selecciona y analiza un nuevo comprobante.'
              : analysisError,
        );
        return;
      }
    }
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final payload = CreateVentaPayload(
        idempotencyKey: _idempotencyKey,
        items: _carrito
            .map(
              (i) => <String, dynamic>{
                'productoId': i.productoId,
                'cantidad': i.cantidad,
                'precioVenta': i.precio,
              },
            )
            .toList(),
        sedeId: auth.user?.isSuperAdmin == true ? sedeId : null,
        vendedoraId: _vendedoraId ?? auth.user?.id,
        estadoConciliacion: _payment,
        etiquetaId: _payment == EstadoConciliacion.billetera
            ? _etiquetaId
            : null,
        comprobanteAnalisisId: _payment == EstadoConciliacion.billetera
            ? analysis?.id
            : null,
        recargoMonto: _recargoMonto,
        recargoMotivo: _recargoMotivo,
      );
      await _executePayload(payload);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = _friendlySubmitError(e);
      });
    }
  }

  Future<void> _executePayload(CreateVentaPayload payload) async {
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final repo = ref.read(ventasRepositoryProvider);
      await repo.crearVenta(payload: payload);
      if (!mounted) return;
      // Feedback de éxito centrado
      AppFeedback.success(context, 'Venta registrada');
      _voucherRequestToken++;
      setState(() {
        _carrito.clear();
        _idempotencyKey = repo.generateIdempotencyKey();
        _submitting = false;
        _retryPayload = null;
        _frozen = false;
        _recargoMonto = null;
        _recargoMotivo = null;
        _payment = EstadoConciliacion.efectivo;
        _voucherBytes = null;
        _voucherFilename = null;
        _comprobanteAnalisis = null;
        _comprobanteError = null;
        _analisisInvalidado = false;
        _analizandoComprobante = false;
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
        if (isAmbiguous) {
          _retryPayload = payload;
          _frozen = true;
        } else {
          _retryPayload = null;
        }
      });
    }
  }

  void _retry() {
    final payload = _retryPayload;
    if (payload != null) _executePayload(payload);
  }

  /// Guarda la venta como PENDIENTE sin clasificar método de pago.
  Future<void> _submitPending() async {
    if (_submitting || _carrito.isEmpty) return;
    final auth = ref.read(authProvider);
    final sedeId = auth.user?.isSuperAdmin == true
        ? ref.read(globalSedeIdProvider)
        : auth.user?.sedeId;
    if (auth.user?.isSuperAdmin == true && sedeId == null) {
      setState(
        () => _submitError = 'Selecciona una sede para registrar la venta',
      );
      return;
    }
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final payload = CreateVentaPayload(
        idempotencyKey: _idempotencyKey,
        items: _carrito
            .map(
              (i) => <String, dynamic>{
                'productoId': i.productoId,
                'cantidad': i.cantidad,
                'precioVenta': i.precio,
              },
            )
            .toList(),
        sedeId: auth.user?.isSuperAdmin == true ? sedeId : null,
        vendedoraId: _vendedoraId ?? auth.user?.id,
        estadoConciliacion: EstadoConciliacion.pendiente,
        recargoMonto: _recargoMonto,
        recargoMotivo: _recargoMotivo,
      );
      await _executePayload(payload);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = _friendlySubmitError(e);
      });
    }
  }

  /// Determina si el error es ambiguo (no sabemos si el backend recibió la solicitud).
  bool _isAmbiguousError(Object e) {
    if (e is AppException) {
      return e is NetworkException ||
          e.statusCode == null ||
          e.statusCode! >= 500;
    }
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
          onSavePending: () async {
            await _submitPending();
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
          onEditPrice: _frozen
              ? null
              : (item) async {
                  await _editPrice(item);
                  setModalState(() {});
                },
          saleDetails: _buildSaleDetails(refresh: () => setModalState(() {})),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final selectedSedeId = ref.watch(globalSedeIdProvider);
    final effectiveSedeId = auth.user?.isSuperAdmin == true
        ? selectedSedeId
        : auth.user?.sedeId;
    if (widget.productsLoader == null &&
        effectiveSedeId != _loadedSedeId &&
        !_loadingProducts &&
        !_frozen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _clearCart();
        _loadProducts();
      });
    }
    final desktop = MediaQuery.sizeOf(context).width >= 1024;
    return desktop ? _buildDesktop() : _buildMobile();
  }

  Widget _buildDesktop() {
    return ColoredBox(
      key: const Key('desktop-sales-layout'),
      color: context.colors.backgroundAlt,
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
                  onSavePending: _submitPending,
                  onRetry: _retry,
                  onClear: _frozen ? _discardFrozen : _clearCart,
                  onChangeQuantity: _changeQuantity,
                  onRemove: _removeFromCart,
                  onEditPrice: _frozen ? null : _editPrice,
                  saleDetails: _buildSaleDetails(refresh: () {}),
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
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
        border: Border.all(color: context.colors.border),
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
                    Expanded(
                      child: Text(
                        'Catálogo de productos',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      status,
                      key: const Key('desktop-catalog-status'),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.textSecondary,
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
          Divider(height: 1, color: context.colors.border),
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
          color: context.colors.background,
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

    return ListView.builder(
      key: const Key('mobile-catalog-list'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        100,
      ),
      itemCount: products.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: _buildProductCard(products[i], desktop: false),
      ),
    );
  }

  Widget _buildProductCard(Producto product, {required bool desktop}) {
    return _ProductoCard(
      producto: product,
      qty: _cartQty(product.id),
      frozen: _frozen,
      desktop: desktop,
      onAdd: () => _selectProduct(product),
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
    return desktop ? _buildDesktop(context) : _buildMobile(context);
  }

  Widget _buildDesktop(BuildContext context) {
    final stock = producto.stockDisponible;
    final agotado = stock != null && stock <= 0;
    final stockBajo = stock != null && stock > 0 && stock <= 5;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: agotado || frozen ? null : onAdd,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
        child: Container(
          key: ValueKey('desktop-product-${producto.id}'),
          decoration: _decoration(context),
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
                    style: TextStyle(
                      fontSize: 10,
                      color: context.colors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    producto.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
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
                  _buildQuantityControl(
                    context,
                    agotado: agotado,
                    stock: stock,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
      ),
    );
  }

  Widget _buildMobile(BuildContext context) {
    final stock = producto.stockDisponible;
    final agotado = stock != null && stock <= 0;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: agotado ? 0.62 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: agotado || frozen ? null : onAdd,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
          child: Container(
            key: ValueKey('mobile-product-${producto.id}'),
            height: 148,
            decoration: _decoration(context),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: MediaQuery.sizeOf(context).width < 360 ? 118 : 150,
                      height: double.infinity,
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
                        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              producto.codigo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: context.colors.textTertiary,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              producto.nombre,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.25,
                                fontWeight: FontWeight.w800,
                                color: context.colors.textSecondary,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              FormatUtils.currency(producto.precioVenta),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: AppColors.brand,
                              ),
                            ),
                            if (stock != null) ...[
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: agotado
                                        ? context.colors.errorLight
                                        : context.colors.successLight,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Stock $stock',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: agotado
                                          ? AppColors.error
                                          : AppColors.success,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (qty > 0)
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.brand,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$qty',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _decoration(BuildContext context) => BoxDecoration(
    color: context.colors.surface,
    borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
    border: Border.all(
      color: qty > 0
          ? AppColors.primary.withValues(alpha: 0.3)
          : context.colors.border,
      width: qty > 0 ? 1.5 : 0.75,
    ),
    boxShadow: AppShadows.card,
  );

  Widget _buildQuantityControl(
    BuildContext context, {
    required bool agotado,
    required int? stock,
  }) {
    if (qty == 0 || agotado) {
      return SizedBox(
        width: double.infinity,
        height: desktop ? 32 : 36,
        child: TextButton(
          onPressed: (agotado || frozen) ? null : onAdd,
          style: TextButton.styleFrom(
            backgroundColor: agotado
                ? context.colors.surfaceAlt
                : context.colors.primarySurface,
            foregroundColor: agotado
                ? context.colors.textTertiary
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
        color: (color ?? context.colors.textTertiary).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        size: 18,
        color: onTap != null
            ? (color ?? context.colors.textSecondary)
            : context.colors.textDisabled,
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
  final VoidCallback? onSavePending;
  final VoidCallback onRetry;
  final VoidCallback onClear;
  final void Function(String productoId, int delta) onChangeQuantity;
  final void Function(String productoId) onRemove;
  final void Function(CarritoItem item)? onEditPrice;
  final Widget saleDetails;

  const _DesktopCartPanel({
    required this.items,
    required this.total,
    required this.submitting,
    required this.frozen,
    required this.error,
    required this.onConfirm,
    this.onSavePending,
    required this.onRetry,
    required this.onClear,
    required this.onChangeQuantity,
    required this.onRemove,
    this.onEditPrice,
    required this.saleDetails,
  });

  int get _itemCount => items.fold(0, (sum, item) => sum + item.cantidad);

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('desktop-cart-panel'),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
        border: Border.all(color: context.colors.border),
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
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
                          ? context.colors.warningLight
                          : context.colors.primarySurface,
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
                        Text(
                          'Venta actual',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        Text(
                          _itemCount == 1
                              ? '1 producto seleccionado'
                              : '$_itemCount productos seleccionados',
                          style: TextStyle(
                            fontSize: 11,
                            color: context.colors.textSecondary,
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
            Divider(height: 1, color: context.colors.border),
            Expanded(
              child: items.isEmpty
                  ? Column(
                      children: [
                        const Expanded(child: _DesktopEmptyCart()),
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          child: saleDetails,
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      itemCount: items.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: context.colors.divider),
                      itemBuilder: (_, index) {
                        final item = items[index];
                        return _DesktopCartItem(
                          key: ValueKey('desktop-cart-item-${item.productoId}'),
                          item: item,
                          frozen: frozen,
                          onDecrease: () =>
                              onChangeQuantity(item.productoId, -1),
                          onIncrease: () =>
                              onChangeQuantity(item.productoId, 1),
                          onRemove: () => onRemove(item.productoId),
                          onEditPrice: onEditPrice == null
                              ? null
                              : () => onEditPrice!(item),
                        );
                      },
                    ),
            ),
            Divider(height: 1, color: context.colors.border),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight * 0.65,
              ),
              child: SingleChildScrollView(
                child: Padding(
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
                                ? context.colors.warningLight
                                : context.colors.errorLight,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMD,
                            ),
                            border: Border.all(
                              color: frozen
                                  ? context.colors.warningBorder
                                  : context.colors.errorBorder,
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
                                  color: frozen
                                      ? AppColors.warning
                                      : AppColors.error,
                                ),
                              ),
                              if (frozen) ...[
                                const SizedBox(height: AppSpacing.xxs),
                                Text(
                                  'Reintenta sin modificar el carrito para conservar la operación.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: context.colors.textSecondary,
                                  ),
                                ),
                              ],
                              const SizedBox(height: AppSpacing.xs),
                              TextButton.icon(
                                key: const Key('desktop-cart-retry'),
                                onPressed: submitting ? null : onRetry,
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(0, 32),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  foregroundColor: frozen
                                      ? AppColors.warning
                                      : AppColors.error,
                                ),
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  size: 16,
                                ),
                                label: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      if (items.isNotEmpty) ...[
                        saleDetails,
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      if (total !=
                          items.fold(0.0, (sum, item) => sum + item.subtotal))
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.xxs,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Subtotal',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: context.colors.textSecondary,
                                ),
                              ),
                              Text(
                                _fmt(
                                  items.fold(
                                    0.0,
                                    (sum, item) => sum + item.subtotal,
                                  ),
                                ),
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: context.colors.textSecondary,
                            ),
                          ),
                          Text(
                            _fmt(total),
                            key: const Key('desktop-cart-total'),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: context.colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // DEJAR PDTE. — guarda sin clasificar
                      if (onSavePending != null) ...[
                        SizedBox(
                          width: double.infinity,
                          height: AppSpacing.buttonHeightSmall,
                          child: OutlinedButton(
                            key: const Key('desktop-cart-save-pending'),
                            onPressed: items.isEmpty || submitting
                                ? null
                                : onSavePending,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.warning,
                              side: BorderSide(
                                color: AppColors.warning.withValues(alpha: 0.6),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusLG,
                                ),
                              ),
                            ),
                            child: const Text(
                              'DEJAR PDTE.',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                      SizedBox(
                        width: double.infinity,
                        height: AppSpacing.buttonHeight,
                        child: ElevatedButton(
                          key: const Key('desktop-cart-confirm'),
                          onPressed: items.isEmpty || submitting
                              ? null
                              : onConfirm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: context.colors.border,
                            disabledForegroundColor:
                                context.colors.textTertiary,
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
              ),
            ),
          ],
        ),
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
                color: context.colors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
              ),
              child: Icon(
                Icons.add_shopping_cart_rounded,
                size: 28,
                color: context.colors.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Tu carrito está vacío',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Selecciona productos del catálogo para comenzar.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: context.colors.textSecondary,
              ),
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
  final VoidCallback? onEditPrice;

  const _DesktopCartItem({
    super.key,
    required this.item,
    required this.frozen,
    required this.onDecrease,
    required this.onIncrease,
    required this.onRemove,
    this.onEditPrice,
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
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxxs),
                    Text(
                      item.codigo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: context.colors.textTertiary,
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
                color: context.colors.textTertiary,
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
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        '${_fmt(item.precio)} × ${item.cantidad}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 10,
                          color: context.colors.textTertiary,
                        ),
                      ),
                    ),
                    if (onEditPrice != null)
                      IconButton(
                        key: ValueKey('desktop-edit-price-${item.productoId}'),
                        onPressed: frozen ? null : onEditPrice,
                        constraints: const BoxConstraints.tightFor(
                          width: 28,
                          height: 28,
                        ),
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.edit_rounded, size: 13),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                _fmt(item.subtotal),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
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
        color: context.colors.background,
        border: Border(
          top: BorderSide(color: context.colors.border, width: 0.75),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  FormatUtils.currency(total),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
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
