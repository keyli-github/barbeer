import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/venta_models.dart';
import '../../data/ventas_repository.dart';

// ── Repository provider ──────────────────────────────────────────────────────

final ventasRepositoryProvider = Provider<VentasRepository>((ref) {
  return VentasRepository(ApiClient.instance);
});

// ── Ventas list state ────────────────────────────────────────────────────────

class VentasListState {
  final List<Venta> ventas;
  final int total;
  final int totalPaginas;
  final int pagina;
  final bool loading;
  final String? error;
  final String? filterEstado;

  const VentasListState({
    this.ventas = const [],
    this.total = 0,
    this.totalPaginas = 1,
    this.pagina = 1,
    this.loading = true,
    this.error,
    this.filterEstado,
  });

  VentasListState copyWith({
    List<Venta>? ventas,
    int? total,
    int? totalPaginas,
    int? pagina,
    bool? loading,
    String? error,
    String? filterEstado,
  }) => VentasListState(
    ventas: ventas ?? this.ventas,
    total: total ?? this.total,
    totalPaginas: totalPaginas ?? this.totalPaginas,
    pagina: pagina ?? this.pagina,
    loading: loading ?? this.loading,
    error: error,
    filterEstado: filterEstado ?? this.filterEstado,
  );
}

class VentasListNotifier extends StateNotifier<VentasListState> {
  final VentasRepository _repo;
  final bool _useMisVentas;

  VentasListNotifier(this._repo, {required bool useMisVentas})
    : _useMisVentas = useMisVentas,
      super(const VentasListState());

  Future<void> load({int pagina = 1, String? estado}) async {
    state = state.copyWith(loading: true, error: null, filterEstado: estado);
    try {
      final result = _useMisVentas
          ? await _repo.listMisVentas(pagina: pagina, estado: estado)
          : await _repo.listVentas(pagina: pagina, estado: estado);
      state = state.copyWith(
        ventas: result.data,
        total: result.total,
        totalPaginas: result.totalPaginas,
        pagina: pagina,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: _friendlyError(e));
    }
  }

  Future<void> refresh() =>
      load(pagina: state.pagina, estado: state.filterEstado);

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('SocketException') || msg.contains('connection')) {
      return 'Sin conexión al servidor';
    }
    if (msg.contains('403')) return 'No tienes permiso para ver ventas';
    if (msg.contains('401')) return 'Sesión expirada';
    return 'No se pudieron cargar las ventas';
  }
}

/// Provider para la lista de ventas.
/// Usa `misVentas` si la vendedora solo puede ver las propias.
final ventasListProvider =
    StateNotifierProvider.family<VentasListNotifier, VentasListState, bool>((
      ref,
      useMisVentas,
    ) {
      final repo = ref.watch(ventasRepositoryProvider);
      return VentasListNotifier(repo, useMisVentas: useMisVentas);
    });

// ── Etiquetas activas ────────────────────────────────────────────────────────

final etiquetasActivasProvider = FutureProvider<List<Etiqueta>>((ref) async {
  final repo = ref.watch(ventasRepositoryProvider);
  return repo.listEtiquetasActivas();
});

// ── Helpers de permisos ──────────────────────────────────────────────────────

/// true si el usuario puede CREAR ventas (VENDEDORA, ADMIN, SUPERADMIN).
bool canCreateVenta(AuthState auth) =>
    auth.user?.hasPermission('ventas:crear') ?? false;

/// true si el usuario puede ver TODAS las ventas de la sede.
bool canReadAllVentas(AuthState auth) =>
    auth.user?.hasPermission('ventas:leer') ?? false;

/// true si el usuario puede ver solo sus propias ventas.
bool canReadOwnVentas(AuthState auth) =>
    auth.user?.hasPermission('ventas:leer-propias') ?? false;

/// true si puede clasificar pagos (CAJERO+).
bool canConciliar(AuthState auth) =>
    auth.user?.hasPermission('ventas:conciliar') ?? false;

/// true si puede corregir clasificaciones (ADMIN+).
bool canConciliarCorregir(AuthState auth) =>
    auth.user?.hasPermission('ventas:conciliar-corregir') ?? false;

/// true si puede anular ventas (ADMIN+).
bool canAnularVenta(AuthState auth) =>
    auth.user?.hasPermission('ventas:anular') ?? false;
