import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/sede_scope_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/caja_repository.dart';
import 'caja_provider.dart';

class MovimientosState {
  final bool isLoading;
  final String? error;
  final List<CajaMovimiento> movimientos;
  final String? sedeId;
  final String? tipo;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final int pagina;
  final int totalPaginas;
  final int total;

  MovimientosState({
    this.isLoading = false,
    this.error,
    this.movimientos = const [],
    this.sedeId,
    this.tipo,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    this.pagina = 1,
    this.totalPaginas = 1,
    this.total = 0,
  }) : fechaInicio = fechaInicio ?? DateTime.now(),
       fechaFin = fechaFin ?? DateTime.now();

  MovimientosState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
    List<CajaMovimiento>? movimientos,
    String? sedeId,
    String? tipo,
    bool clearTipo = false,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    int? pagina,
    int? totalPaginas,
    int? total,
  }) => MovimientosState(
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : error ?? this.error,
    movimientos: movimientos ?? this.movimientos,
    sedeId: sedeId ?? this.sedeId,
    tipo: clearTipo ? null : tipo ?? this.tipo,
    fechaInicio: fechaInicio ?? this.fechaInicio,
    fechaFin: fechaFin ?? this.fechaFin,
    pagina: pagina ?? this.pagina,
    totalPaginas: totalPaginas ?? this.totalPaginas,
    total: total ?? this.total,
  );
}

class MovimientosNotifier extends StateNotifier<MovimientosState> {
  final CajaRepository _repository;
  int _requestId = 0;

  MovimientosNotifier(this._repository, String? sedeId)
    : super(MovimientosState(sedeId: sedeId)) {
    load();
  }

  Future<void> load() async {
    final requestId = ++_requestId;
    final sedeId = state.sedeId;
    if (sedeId == null || sedeId.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        clearError: true,
        movimientos: const [],
        pagina: 1,
        totalPaginas: 1,
        total: 0,
      );
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final format = DateFormat('yyyy-MM-dd');
      final page = await _repository.movimientosGenerales(
        pagina: state.pagina,
        sedeId: sedeId,
        tipo: state.tipo,
        fechaInicio: format.format(state.fechaInicio),
        fechaFin: format.format(state.fechaFin),
      );
      if (!mounted || requestId != _requestId) return;
      state = state.copyWith(
        isLoading: false,
        movimientos: page.data,
        pagina: page.pagina,
        totalPaginas: page.totalPaginas,
        total: page.total,
      );
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      state = state.copyWith(
        isLoading: false,
        error: error.toString(),
        movimientos: const [],
        pagina: 1,
        totalPaginas: 1,
        total: 0,
      );
    }
  }

  Future<void> filtrarTipo(String? tipo) async {
    state = state.copyWith(tipo: tipo, clearTipo: tipo == null, pagina: 1);
    await load();
  }

  Future<void> filtrarFechas(DateTime inicio, DateTime fin) async {
    state = state.copyWith(fechaInicio: inicio, fechaFin: fin, pagina: 1);
    await load();
  }

  Future<void> cambiarPagina(int pagina) async {
    if (pagina < 1 || pagina > state.totalPaginas || state.isLoading) return;
    state = state.copyWith(pagina: pagina);
    await load();
  }
}

final movimientosProvider =
    StateNotifierProvider<MovimientosNotifier, MovimientosState>((ref) {
      final user = ref.watch(authProvider.select((auth) => auth.user));
      final globalSedeId = ref.watch(globalSedeIdProvider);
      final sedeId = user?.isSuperAdmin == true ? globalSedeId : user?.sedeId;
      return MovimientosNotifier(ref.watch(cajaRepositoryProvider), sedeId);
    });
