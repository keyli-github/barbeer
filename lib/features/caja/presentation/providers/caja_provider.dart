import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../auth/data/models/auth_models.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/caja_repository.dart';

class CajaState {
  final bool isLoading;
  final bool isActing;
  final String? error;
  final CajaSesion? actual;
  final List<CajaSesion> historial;
  final List<CajaMovimiento> movimientos;
  final List<Map<String, dynamic>> sedes;
  final Map<double, int> aperturaSugerida;
  final String? sedeId;
  final String? estadoFiltro;
  final String? tipoFiltro;
  final int historialPagina;
  final int historialPaginas;
  final int historialTotal;
  final int movimientosPagina;
  final int movimientosPaginas;
  final int movimientosTotal;

  const CajaState({
    this.isLoading = false,
    this.isActing = false,
    this.error,
    this.actual,
    this.historial = const [],
    this.movimientos = const [],
    this.sedes = const [],
    this.aperturaSugerida = const {},
    this.sedeId,
    this.estadoFiltro,
    this.tipoFiltro,
    this.historialPagina = 1,
    this.historialPaginas = 1,
    this.historialTotal = 0,
    this.movimientosPagina = 1,
    this.movimientosPaginas = 1,
    this.movimientosTotal = 0,
  });

  CajaState copyWith({
    bool? isLoading,
    bool? isActing,
    String? error,
    bool clearError = false,
    CajaSesion? actual,
    bool clearActual = false,
    List<CajaSesion>? historial,
    List<CajaMovimiento>? movimientos,
    List<Map<String, dynamic>>? sedes,
    Map<double, int>? aperturaSugerida,
    String? sedeId,
    String? estadoFiltro,
    bool clearEstadoFiltro = false,
    String? tipoFiltro,
    bool clearTipoFiltro = false,
    int? historialPagina,
    int? historialPaginas,
    int? historialTotal,
    int? movimientosPagina,
    int? movimientosPaginas,
    int? movimientosTotal,
  }) => CajaState(
    isLoading: isLoading ?? this.isLoading,
    isActing: isActing ?? this.isActing,
    error: clearError ? null : (error ?? this.error),
    actual: clearActual ? null : (actual ?? this.actual),
    historial: historial ?? this.historial,
    movimientos: movimientos ?? this.movimientos,
    sedes: sedes ?? this.sedes,
    aperturaSugerida: aperturaSugerida ?? this.aperturaSugerida,
    sedeId: sedeId ?? this.sedeId,
    estadoFiltro: clearEstadoFiltro
        ? null
        : (estadoFiltro ?? this.estadoFiltro),
    tipoFiltro: clearTipoFiltro ? null : (tipoFiltro ?? this.tipoFiltro),
    historialPagina: historialPagina ?? this.historialPagina,
    historialPaginas: historialPaginas ?? this.historialPaginas,
    historialTotal: historialTotal ?? this.historialTotal,
    movimientosPagina: movimientosPagina ?? this.movimientosPagina,
    movimientosPaginas: movimientosPaginas ?? this.movimientosPaginas,
    movimientosTotal: movimientosTotal ?? this.movimientosTotal,
  );
}

class CajaNotifier extends StateNotifier<CajaState> {
  final CajaRepository _repository;
  final UserProfile? _user;

  CajaNotifier(this._repository, this._user) : super(const CajaState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      var sedes = state.sedes;
      var sedeId = state.sedeId ?? _user?.sedeId;
      if (_user?.isSuperAdmin ?? false) {
        sedes = await _repository.sedes();
        sedeId ??= sedes.isNotEmpty ? sedes.first['id'] as String? : null;
      }
      final results = await Future.wait<Object?>([
        if (sedeId != null) _repository.actual(sedeId: sedeId),
        _repository.historial(
          pagina: state.historialPagina,
          estado: state.estadoFiltro,
          sedeId: (_user?.isSuperAdmin ?? false) ? sedeId : null,
        ),
        _loadUltimoCierre(sedeId),
      ]);
      final actual = sedeId == null ? null : results.first as CajaSesion?;
      final page = results[results.length - 2] as CajaPage<CajaSesion>;
      final aperturaSugerida = results.last as Map<double, int>;
      state = state.copyWith(
        isLoading: false,
        actual: actual,
        clearActual: actual == null,
        sedes: sedes,
        aperturaSugerida: aperturaSugerida,
        sedeId: sedeId,
        historial: page.data,
        historialPagina: page.pagina,
        historialPaginas: page.totalPaginas,
        historialTotal: page.total,
      );
      if (actual != null) await loadMovimientos(actual.id);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<Map<double, int>> _loadUltimoCierre(String? sedeId) async {
    if (sedeId == null) return const {};
    try {
      return await _repository.ultimoCierre(sedeId: sedeId);
    } catch (_) {
      return const {};
    }
  }

  Future<void> seleccionarSede(String sedeId) async {
    state = state.copyWith(sedeId: sedeId, historialPagina: 1);
    await load();
  }

  Future<void> filtrarHistorial(String? estado) async {
    state = state.copyWith(
      estadoFiltro: estado,
      clearEstadoFiltro: estado == null,
      historialPagina: 1,
    );
    await load();
  }

  Future<void> cambiarPaginaHistorial(int pagina) async {
    state = state.copyWith(historialPagina: pagina);
    await load();
  }

  Future<void> loadMovimientos(String sesionId, {int pagina = 1}) async {
    try {
      final page = await _repository.movimientos(
        sesionId,
        pagina: pagina,
        tipo: state.tipoFiltro,
      );
      state = state.copyWith(
        movimientos: page.data,
        movimientosPagina: page.pagina,
        movimientosPaginas: page.totalPaginas,
        movimientosTotal: page.total,
      );
    } catch (error) {
      state = state.copyWith(error: error.toString());
    }
  }

  Future<void> filtrarMovimientos(String sesionId, String? tipo) async {
    state = state.copyWith(tipoFiltro: tipo, clearTipoFiltro: tipo == null);
    await loadMovimientos(sesionId);
  }

  Future<CajaSesion> detalle(String id) => _repository.detalle(id);

  Future<void> abrir(Map<double, int> cantidades) => _action(() async {
    await _repository.abrir(cantidades, sedeId: state.sedeId);
  });

  Future<void> registrarMovimiento({
    required String tipo,
    required double monto,
    required String concepto,
  }) async {
    final id = state.actual?.id;
    if (id == null) return;
    await _action(
      () => _repository.registrarMovimiento(
        id,
        tipo: tipo,
        monto: monto,
        concepto: concepto,
      ),
    );
  }

  Future<void> precuadre(Map<double, int> cantidades) async {
    final id = state.actual?.id;
    if (id == null) return;
    await _action(() => _repository.precuadre(id, cantidades));
  }

  Future<void> cerrar(
    Map<double, int> cantidades, {
    String? observaciones,
    bool forzarPendientes = false,
    String? motivoForzado,
  }) async {
    final id = state.actual?.id;
    if (id == null) return;
    await _action(
      () => _repository.cerrar(
        id,
        cantidades,
        observaciones: observaciones,
        forzarPendientes: forzarPendientes,
        motivoForzado: motivoForzado,
      ),
    );
  }

  Future<void> _action(Future<void> Function() operation) async {
    state = state.copyWith(isActing: true, clearError: true);
    try {
      await operation();
      state = state.copyWith(isActing: false);
      await load();
    } catch (error) {
      state = state.copyWith(isActing: false, error: error.toString());
      rethrow;
    }
  }
}

final cajaRepositoryProvider = Provider<CajaRepository>(
  (ref) => CajaRepository(ApiClient.instance),
);

final cajaProvider = StateNotifierProvider<CajaNotifier, CajaState>(
  (ref) => CajaNotifier(
    ref.watch(cajaRepositoryProvider),
    ref.watch(authProvider).user,
  ),
);
