import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/kardex.dart';
import '../../data/repositories/kardex_repository.dart';

final kardexRepositoryProvider = Provider<KardexRepository>(
  (ref) => KardexRepository(),
);

class KardexState {
  final List<KardexMovimiento> movimientos;
  final KardexResumen resumen;
  final List<KardexOption> sedes;
  final List<KardexOption> productos;
  final bool isLoading;
  final String? error;
  final String search;
  final String? tipo;
  final String? productoId;
  final String? sedeId;
  final DateTime? desde;
  final DateTime? hasta;
  final int pagina;
  final int limite;
  final int total;
  final int totalPaginas;

  const KardexState({
    this.movimientos = const [],
    this.resumen = const KardexResumen(),
    this.sedes = const [],
    this.productos = const [],
    this.isLoading = false,
    this.error,
    this.search = '',
    this.tipo,
    this.productoId,
    this.sedeId,
    this.desde,
    this.hasta,
    this.pagina = 1,
    this.limite = 20,
    this.total = 0,
    this.totalPaginas = 0,
  });

  KardexState copyWith({
    List<KardexMovimiento>? movimientos,
    KardexResumen? resumen,
    List<KardexOption>? sedes,
    List<KardexOption>? productos,
    bool? isLoading,
    String? error,
    bool clearError = false,
    String? search,
    String? tipo,
    bool clearTipo = false,
    String? productoId,
    bool clearProducto = false,
    String? sedeId,
    bool clearSede = false,
    DateTime? desde,
    DateTime? hasta,
    bool clearDates = false,
    int? pagina,
    int? limite,
    int? total,
    int? totalPaginas,
  }) => KardexState(
    movimientos: movimientos ?? this.movimientos,
    resumen: resumen ?? this.resumen,
    sedes: sedes ?? this.sedes,
    productos: productos ?? this.productos,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : error ?? this.error,
    search: search ?? this.search,
    tipo: clearTipo ? null : tipo ?? this.tipo,
    productoId: clearProducto ? null : productoId ?? this.productoId,
    sedeId: clearSede ? null : sedeId ?? this.sedeId,
    desde: clearDates ? null : desde ?? this.desde,
    hasta: clearDates ? null : hasta ?? this.hasta,
    pagina: pagina ?? this.pagina,
    limite: limite ?? this.limite,
    total: total ?? this.total,
    totalPaginas: totalPaginas ?? this.totalPaginas,
  );
}

class KardexNotifier extends StateNotifier<KardexState> {
  final KardexRepository _repository;
  final bool _isSuperAdmin;
  final bool _canReadProducts;
  Timer? _searchTimer;
  int _request = 0;

  KardexNotifier(
    this._repository, {
    required bool isSuperAdmin,
    required bool canReadProducts,
  }) : _isSuperAdmin = isSuperAdmin,
       _canReadProducts = canReadProducts,
       super(const KardexState()) {
    load();
    loadOptions();
  }

  String? _date(DateTime? value) => value == null
      ? null
      : '${value.year.toString().padLeft(4, '0')}-'
            '${value.month.toString().padLeft(2, '0')}-'
            '${value.day.toString().padLeft(2, '0')}';

  Future<void> load({int? pagina}) async {
    final request = ++_request;
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      pagina: pagina ?? state.pagina,
    );
    try {
      final sedeId = _isSuperAdmin ? state.sedeId : null;
      final desde = _date(state.desde);
      final hasta = _date(state.hasta);
      final results = await Future.wait([
        _repository.list(
          pagina: state.pagina,
          limite: state.limite,
          q: state.search,
          tipo: state.tipo,
          productoId: state.productoId,
          desde: desde,
          hasta: hasta,
          sedeId: sedeId,
        ),
        _repository.summary(
          q: state.search,
          tipo: state.tipo,
          productoId: state.productoId,
          desde: desde,
          hasta: hasta,
          sedeId: sedeId,
        ),
      ]);
      if (request != _request) return;
      final page = results[0] as KardexPage;
      state = state.copyWith(
        movimientos: page.data,
        resumen: results[1] as KardexResumen,
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

  Future<void> loadOptions() async {
    try {
      final results = await Future.wait([
        if (_isSuperAdmin) _repository.sedes(),
        if (_canReadProducts) _repository.productos(),
      ]);
      var index = 0;
      List<KardexOption>? sedes;
      List<KardexOption>? productos;
      if (_isSuperAdmin) sedes = results[index++] as List<KardexOption>;
      if (_canReadProducts) productos = results[index] as List<KardexOption>;
      state = state.copyWith(sedes: sedes, productos: productos);
    } catch (_) {
      // The movement list remains usable when an optional lookup is denied.
    }
  }

  void search(String value) {
    _searchTimer?.cancel();
    state = state.copyWith(search: value);
    _searchTimer = Timer(
      const Duration(milliseconds: 350),
      () => load(pagina: 1),
    );
  }

  void filterTipo(String? value) {
    state = state.copyWith(tipo: value, clearTipo: value == null);
    load(pagina: 1);
  }

  void filterProducto(String? id) {
    state = state.copyWith(productoId: id, clearProducto: id == null);
    load(pagina: 1);
  }

  void selectSede(String? id) {
    if (!_isSuperAdmin) return;
    state = state.copyWith(sedeId: id, clearSede: id == null);
    load(pagina: 1);
  }

  void filterDates(DateTime? desde, DateTime? hasta) {
    state = state.copyWith(
      desde: desde,
      hasta: hasta,
      clearDates: desde == null && hasta == null,
    );
    load(pagina: 1);
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }
}

final kardexProvider = StateNotifierProvider<KardexNotifier, KardexState>((
  ref,
) {
  final auth = ref.watch(authProvider);
  return KardexNotifier(
    ref.watch(kardexRepositoryProvider),
    isSuperAdmin: auth.user?.isSuperAdmin ?? false,
    canReadProducts: auth.hasPermission('productos:leer'),
  );
});
