import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class DashboardData {
  final List roles, sedes, audit, sessions, users;
  // Datos para vendedora/cajero
  final int misVentasHoy;
  final double misTotalesHoy;
  final int misVentasMes;
  final double misTotalesMes;
  // Ventas últimos 7 días para gráfica (index 0 = hace 6 días, 6 = hoy)
  final List<double> ventasUltimos7Dias;
  const DashboardData({
    this.roles = const [],
    this.sedes = const [],
    this.audit = const [],
    this.sessions = const [],
    this.users = const [],
    this.misVentasHoy = 0,
    this.misTotalesHoy = 0,
    this.misVentasMes = 0,
    this.misTotalesMes = 0,
    this.ventasUltimos7Dias = const [0, 0, 0, 0, 0, 0, 0],
  });
}

class DashboardState {
  final bool isLoading;
  final String? error;
  final DashboardData? data;
  const DashboardState({this.isLoading = false, this.error, this.data});
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  final ApiClient _api;
  final Set<String> _permissions;
  DashboardNotifier(this._api, Iterable<String> permissions)
    : _permissions = Set.of(permissions),
      super(const DashboardState()) {
    load();
  }

  Future<void> load() async {
    state = const DashboardState(isLoading: true);

    Future<_SectionResult> get(
      String path, [
      Map<String, dynamic>? query,
      String? permission,
    ]) async {
      if (permission != null && !_permissions.contains(permission)) {
        return const _SectionResult.skipped();
      }
      try {
        final response = await _api.get(path, queryParameters: query);
        final body = response.data;
        if (body is Map) {
          return _SectionResult.success(List.from(body['data'] ?? const []));
        }
        if (body is List) return _SectionResult.success(List.from(body));
        return const _SectionResult.success([]);
      } catch (error) {
        return _SectionResult.failure(error);
      }
    }

    // Ventas propias para vendedora/cajero
    int misVentasHoy = 0;
    double misTotalesHoy = 0;
    int misVentasMes = 0;
    double misTotalesMes = 0;
    List<double> ventasUltimos7Dias = List<double>.filled(7, 0);

    final canLeerPropias = _permissions.contains('ventas:leer-propias');
    final canLeerTodas = _permissions.contains('ventas:leer');

    if (canLeerPropias || canLeerTodas) {
      try {
        final endpoint = canLeerPropias
            ? ApiConstants.misVentas
            : ApiConstants.ventas;
        final resp = await _api.get(
          endpoint,
          queryParameters: {'limite': 200, 'pagina': 1},
        );
        final body = resp.data;
        if (body is Map) {
          final ventas = List.from(body['data'] ?? []);
          final now = DateTime.now();
          final hoy = DateTime(now.year, now.month, now.day);
          final mes = DateTime(now.year, now.month, 1);
          for (final v in ventas) {
            if (v is! Map) continue;
            final total = (v['total'] as num?)?.toDouble() ?? 0;
            final estado = v['estado'] as String? ?? '';
            if (estado == 'ANULADA') continue;
            DateTime? dt;
            try {
              dt = DateTime.parse(v['createdAt'] as String? ?? '');
            } catch (_) {}
            if (dt == null) continue;
            final diaNorm = DateTime(dt.year, dt.month, dt.day);
            final diff = hoy.difference(diaNorm).inDays;
            // Gráfica últimos 7 días
            if (diff >= 0 && diff < 7) ventasUltimos7Dias[6 - diff] += total;
            if (!diaNorm.isBefore(hoy)) {
              misVentasHoy++;
              misTotalesHoy += total;
            }
            if (!diaNorm.isBefore(mes)) {
              misVentasMes++;
              misTotalesMes += total;
            }
          }
        }
      } catch (_) {}
    }

    final results = await Future.wait([
      get(ApiConstants.roles, {'pagina': 1, 'limite': 50}, 'roles:leer'),
      get(ApiConstants.establishments, {
        'pagina': 1,
        'limite': 50,
      }, 'establecimientos:leer'),
      get(ApiConstants.audit, {'pagina': 1, 'limite': 8}, 'audit:leer'),
      get(ApiConstants.sessions),
      get(ApiConstants.users, {'pagina': 1, 'limite': 100}, 'usuarios:leer'),
    ]);

    final attempted = results.where((result) => !result.skipped).toList();
    if (attempted.isNotEmpty &&
        attempted.every((result) => result.error != null)) {
      state = DashboardState(error: attempted.first.error.toString());
      return;
    }

    state = DashboardState(
      data: DashboardData(
        roles: results[0].data,
        sedes: results[1].data,
        audit: results[2].data,
        sessions: results[3].data,
        users: results[4].data,
        misVentasHoy: misVentasHoy,
        misTotalesHoy: misTotalesHoy,
        misVentasMes: misVentasMes,
        misTotalesMes: misTotalesMes,
        ventasUltimos7Dias: ventasUltimos7Dias,
      ),
    );
  }
}

class _SectionResult {
  final List data;
  final Object? error;
  final bool skipped;

  const _SectionResult.success(this.data) : error = null, skipped = false;
  const _SectionResult.failure(this.error) : data = const [], skipped = false;
  const _SectionResult.skipped()
    : data = const [],
      error = null,
      skipped = true;
}

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
      final permissions = ref.watch(
        authProvider.select((state) => state.permisos),
      );
      return DashboardNotifier(ApiClient.instance, permissions);
    });
