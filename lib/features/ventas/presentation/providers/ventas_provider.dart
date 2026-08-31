import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/upload_client.dart';
import '../../../../core/providers/sede_scope_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../caja/presentation/providers/caja_provider.dart';
import '../../../caja/presentation/providers/movimientos_provider.dart';
import '../../../cuentas/presentation/providers/cuentas_provider.dart';
import '../../../kardex/presentation/providers/kardex_provider.dart';
import '../../../productos/presentation/providers/productos_provider.dart';
import '../../../../core/errors/app_exception.dart';
import '../../data/models/venta_models.dart';
import '../../data/ventas_repository.dart';

// ── Repository provider ──────────────────────────────────────────────────────

final ventasRepositoryProvider = Provider<VentasRepository>((ref) {
  return VentasRepository(ApiClient.instance);
});

final uploadClientProvider = Provider<UploadClient>((ref) {
  return UploadClient(ApiClient.instance);
});

final voucherImagePickerProvider =
    Provider<Future<PickedUploadImage?> Function()>((ref) {
      return () async {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
          withData: true,
        );
        final file = result?.files.single;
        if (file == null || file.bytes == null) return null;
        final bytes = file.bytes!;
        if (bytes.lengthInBytes > 5 * 1024 * 1024) {
          throw const FormatException('La imagen no debe superar 5 MB');
        }
        return PickedUploadImage(bytes: bytes, filename: file.name);
      };
    });

String saleMutationError(Object error) {
  if (error is! AppException) return error.toString();
  return [
    error.message,
    if (error.code?.isNotEmpty == true) error.code!,
    ...error.details,
  ].where((value) => value.isNotEmpty).join(' · ');
}

void invalidateSaleSideEffects(WidgetRef ref) {
  ref.invalidate(cuentasProvider);
  ref.invalidate(cajaProvider);
  ref.invalidate(movimientosProvider);
  ref.invalidate(kardexProvider);
  ref.invalidate(productosProvider);
}

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
}

class VentasListNotifier extends StateNotifier<VentasListState> {
  final VentasRepository _repo;
  final bool useMisVentas;
  final String? sedeId;
  int _requestVersion = 0;

  VentasListNotifier(this._repo, {required this.useMisVentas, this.sedeId})
    : super(const VentasListState()) {
    load();
  }

  Future<void> load({String? estado}) async {
    final version = ++_requestVersion;
    state = VentasListState(loading: true, filterEstado: estado);

    if (estado == 'PENDIENTE') {
      await _loadPendientes(version);
      return;
    }

    await _loadPage(pagina: 1, estado: estado, append: false, version: version);
  }

  Future<void> loadMore() async {
    if (state.loading || state.pagina >= state.totalPaginas) return;

    final version = _requestVersion;
    final previous = state;
    state = VentasListState(
      ventas: previous.ventas,
      total: previous.total,
      totalPaginas: previous.totalPaginas,
      pagina: previous.pagina,
      loading: true,
      filterEstado: previous.filterEstado,
    );
    await _loadPage(
      pagina: previous.pagina + 1,
      estado: previous.filterEstado,
      append: true,
      version: version,
    );
  }

  Future<void> _loadPage({
    required int pagina,
    required String? estado,
    required bool append,
    required int version,
  }) async {
    try {
      final result = await _list(pagina: pagina, estado: estado);
      if (version != _requestVersion) return;

      final ventas = _uniqueVentas([
        if (append) ...state.ventas,
        ...result.data,
      ]);
      state = VentasListState(
        ventas: ventas,
        total: result.total,
        totalPaginas: result.totalPaginas,
        pagina: pagina,
        loading: false,
        filterEstado: estado,
      );
    } catch (e) {
      if (version != _requestVersion) return;
      state = VentasListState(
        ventas: state.ventas,
        total: state.total,
        totalPaginas: state.totalPaginas,
        pagina: state.pagina,
        loading: false,
        error: _friendlyError(e),
        filterEstado: estado,
      );
    }
  }

  Future<void> _loadPendientes(int version) async {
    try {
      final first = await _list(pagina: 1, estado: null);
      final ventas = <Venta>[...first.data];
      for (var pagina = 2; pagina <= first.totalPaginas; pagina++) {
        final next = await _list(pagina: pagina, estado: null);
        if (version != _requestVersion) return;
        ventas.addAll(next.data);
      }
      if (version != _requestVersion) return;

      final pendientes = _uniqueVentas(
        ventas.where((venta) => venta.isPendiente),
      );
      state = VentasListState(
        ventas: pendientes,
        total: pendientes.length,
        totalPaginas: first.totalPaginas,
        pagina: first.totalPaginas,
        loading: false,
        filterEstado: 'PENDIENTE',
      );
    } catch (e) {
      if (version != _requestVersion) return;
      state = VentasListState(
        loading: false,
        error: _friendlyError(e),
        filterEstado: 'PENDIENTE',
      );
    }
  }

  Future<({List<Venta> data, int total, int totalPaginas})> _list({
    required int pagina,
    required String? estado,
  }) => useMisVentas
      ? _repo.listMisVentas(pagina: pagina, estado: estado)
      : _repo.listVentas(pagina: pagina, estado: estado, sedeId: sedeId);

  List<Venta> _uniqueVentas(Iterable<Venta> ventas) => <String, Venta>{
    for (final venta in ventas) venta.id: venta,
  }.values.toList();

  Future<void> refresh() => load(estado: state.filterEstado);

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
/// La sede activa (`globalSedeIdProvider`) alimenta el filtro: un SUPERADMIN
/// ve la sede elegida en el selector (null = todas); los demás roles siempre
/// ven su propia sede. Al cambiar de sede el notifier se recrea y recarga.
final ventasListProvider =
    StateNotifierProvider.family<VentasListNotifier, VentasListState, bool>((
      ref,
      useMisVentas,
    ) {
      final repo = ref.watch(ventasRepositoryProvider);
      final sedeId = ref.watch(globalSedeIdProvider);
      return VentasListNotifier(
        repo,
        useMisVentas: useMisVentas,
        sedeId: sedeId,
      );
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
