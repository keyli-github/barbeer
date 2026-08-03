import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class DashboardData {
  final List roles, sedes, audit, sessions, users;
  const DashboardData({
    this.roles = const [],
    this.sedes = const [],
    this.audit = const [],
    this.sessions = const [],
    this.users = const [],
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
