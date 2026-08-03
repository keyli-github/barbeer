import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/categoria.dart';
import '../../data/repositories/categorias_repository.dart';

final categoriasRepositoryProvider = Provider<CategoriasRepository>(
  (ref) => CategoriasRepository(),
);

class CategoriasState {
  final List<Categoria> categorias;
  final bool isLoading;
  final String? error;
  final String search;
  final bool? activo;
  final int pagina;
  final int limite;
  final int total;
  final int totalPaginas;

  const CategoriasState({
    this.categorias = const [],
    this.isLoading = false,
    this.error,
    this.search = '',
    this.activo,
    this.pagina = 1,
    this.limite = 25,
    this.total = 0,
    this.totalPaginas = 0,
  });

  CategoriasState copyWith({
    List<Categoria>? categorias,
    bool? isLoading,
    String? error,
    bool clearError = false,
    String? search,
    bool? activo,
    bool clearActivo = false,
    int? pagina,
    int? limite,
    int? total,
    int? totalPaginas,
  }) =>
      CategoriasState(
        categorias: categorias ?? this.categorias,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error ?? this.error,
        search: search ?? this.search,
        activo: clearActivo ? null : activo ?? this.activo,
        pagina: pagina ?? this.pagina,
        limite: limite ?? this.limite,
        total: total ?? this.total,
        totalPaginas: totalPaginas ?? this.totalPaginas,
      );
}

class CategoriasNotifier extends StateNotifier<CategoriasState> {
  final CategoriasRepository _repository;
  Timer? _searchTimer;
  int _request = 0;

  CategoriasNotifier(this._repository) : super(const CategoriasState()) {
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
      final page = await _repository.list(
        pagina: state.pagina,
        limite: state.limite,
        q: state.search,
        activo: state.activo,
      );
      if (request != _request) return;
      state = state.copyWith(
        categorias: page.data,
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

  void filterActivo(bool? value) {
    state = state.copyWith(activo: value, clearActivo: value == null);
    load(pagina: 1);
  }

  Future<Categoria> detail(String id) => _repository.detail(id);

  Future<void> save({
    Categoria? categoria,
    required String nombre,
    required String descripcion,
    required bool activo,
  }) async {
    if (categoria == null) {
      await _repository.create(
        nombre: nombre,
        descripcion: descripcion,
        activo: activo,
      );
    } else {
      await _repository.update(
        categoria.id,
        nombre: nombre,
        descripcion: descripcion,
        activo: activo,
      );
    }
    await load(pagina: state.pagina);
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    final targetPage = state.categorias.length == 1 && state.pagina > 1
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

final categoriasProvider =
    StateNotifierProvider<CategoriasNotifier, CategoriasState>(
  (ref) => CategoriasNotifier(ref.watch(categoriasRepositoryProvider)),
);
