import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/producto.dart';
import '../../data/repositories/productos_repository.dart';

final productosRepositoryProvider = Provider<ProductosRepository>(
  (ref) => ProductosRepository(),
);

class ProductosState {
  final List<Producto> productos;
  final ProductosResumen resumen;
  final bool isLoading;
  final String? error;
  final String search;
  final String? categoriaId;
  final bool? activo;
  final int pagina;
  final int limite;
  final int total;
  final int totalPaginas;

  const ProductosState({
    this.productos = const [],
    this.resumen = const ProductosResumen(),
    this.isLoading = false,
    this.error,
    this.search = '',
    this.categoriaId,
    this.activo,
    this.pagina = 1,
    this.limite = 20,
    this.total = 0,
    this.totalPaginas = 0,
  });

  ProductosState copyWith({
    List<Producto>? productos,
    ProductosResumen? resumen,
    bool? isLoading,
    String? error,
    bool clearError = false,
    String? search,
    String? categoriaId,
    bool clearCategoria = false,
    bool? activo,
    bool clearActivo = false,
    int? pagina,
    int? limite,
    int? total,
    int? totalPaginas,
  }) =>
      ProductosState(
        productos: productos ?? this.productos,
        resumen: resumen ?? this.resumen,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error ?? this.error,
        search: search ?? this.search,
        categoriaId: clearCategoria ? null : categoriaId ?? this.categoriaId,
        activo: clearActivo ? null : activo ?? this.activo,
        pagina: pagina ?? this.pagina,
        limite: limite ?? this.limite,
        total: total ?? this.total,
        totalPaginas: totalPaginas ?? this.totalPaginas,
      );
}

class ProductosNotifier extends StateNotifier<ProductosState> {
  final ProductosRepository _repository;
  Timer? _searchTimer;
  int _request = 0;

  ProductosNotifier(this._repository) : super(const ProductosState()) {
    load();
  }

  Future<void> load({int? pagina}) async {
    final request = ++_request;
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      pagina: pagina ?? state.pagina,
    );
    try {
      final results = await Future.wait([
        _repository.list(
          pagina: state.pagina,
          limite: state.limite,
          q: state.search,
          categoriaId: state.categoriaId,
          activo: state.activo,
        ),
        _repository.summary(),
      ]);
      if (request != _request) return;
      final page = results[0] as ProductosPage;
      state = state.copyWith(
        productos: page.data,
        resumen: results[1] as ProductosResumen,
        isLoading: false,
        pagina: page.pagina,
        limite: page.limite,
        total: page.total,
        totalPaginas: page.totalPaginas,
      );
    } catch (error) {
      if (request != _request) return;
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  void search(String value) {
    _searchTimer?.cancel();
    state = state.copyWith(search: value);
    _searchTimer = Timer(const Duration(milliseconds: 350), () => load(pagina: 1));
  }

  void filterCategory(String? id) {
    state = state.copyWith(categoriaId: id, clearCategoria: id == null);
    load(pagina: 1);
  }

  void filterActivo(bool? value) {
    state = state.copyWith(activo: value, clearActivo: value == null);
    load(pagina: 1);
  }

  Future<Producto> detail(String id) => _repository.detail(id);

  Future<void> save(ProductoPayload payload, {Producto? producto}) async {
    if (producto == null) {
      await _repository.create(payload);
    } else {
      await _repository.update(producto.id, payload);
    }
    await load(pagina: state.pagina);
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    final targetPage = state.productos.length == 1 && state.pagina > 1
        ? state.pagina - 1
        : state.pagina;
    await load(pagina: targetPage);
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }
}

final productosProvider = StateNotifierProvider<ProductosNotifier, ProductosState>(
  (ref) => ProductosNotifier(ref.watch(productosRepositoryProvider)),
);
