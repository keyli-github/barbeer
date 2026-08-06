import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../data/models/auth_models.dart';
import '../../data/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    api: ApiClient.instance,
    storage: SecureStorageService.instance,
  ),
);

enum AuthStatus {
  initial,
  authenticated,
  unauthenticated,
  mustChangePassword,
  loading,
}

class AuthState {
  final AuthStatus status;
  final UserProfile? user;
  final String? error;
  final bool isBootstrapping;
  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
    this.isBootstrapping = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserProfile? user,
    String? error,
    bool? isBootstrapping,
    bool clearErr = false,
  }) => AuthState(
    status: status ?? this.status,
    user: user ?? this.user,
    error: clearErr ? null : (error ?? this.error),
    isBootstrapping: isBootstrapping ?? this.isBootstrapping,
  );

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isMustChangePassword => status == AuthStatus.mustChangePassword;
  List<String> get permisos => user?.permisos ?? [];
  bool hasPermission(String p) => user?.hasPermission(p) ?? false;
  bool canAccess(String path) {
    const m = {
      '/productos': 'productos:crear',
      '/inventario': 'inventario:leer',
      '/kardex': 'kardex:leer',
      '/compras': 'compras:leer',
      '/asistencia': 'asistencia:leer',
      '/usuarios': 'usuarios:leer',
      '/roles': 'roles:leer',
      '/permisos': 'permisos:leer',
      '/sucursales': 'establecimientos:leer',
      '/auditoria': 'audit:leer',
      '/etiquetas': 'etiquetas:crear',
      '/caja': 'caja:leer',
    };
    final req = m[path];
    return req == null || hasPermission(req);
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;
  AuthNotifier(this._repo) : super(const AuthState()) {
    ApiClient.instance.initialize(
      onRefreshToken: _doRefresh,
      onSessionExpired: _sessionExpired,
    );
  }

  Future<String?> _doRefresh() async {
    try {
      final auth = await _repo.refreshToken();
      return auth?.accessToken;
    } on NetworkException {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  void _sessionExpired() =>
      state = const AuthState(status: AuthStatus.unauthenticated);

  Future<void> bootstrap() async {
    // Evita re-ejecutar si ya hay sesión activa o si ya hay un bootstrap
    // en curso (puede ocurrir si el widget que llama a bootstrap se reconstruye).
    if (state.isBootstrapping ||
        state.status == AuthStatus.authenticated ||
        state.status == AuthStatus.mustChangePassword) {
      return;
    }
    state = state.copyWith(isBootstrapping: true);
    try {
      final rt = await SecureStorageService.instance.getRefreshToken();
      if (rt == null) {
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }
      final auth = await _repo.refreshToken();
      if (auth == null) {
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }
      final payload = AuthRepository.decodeJwt(auth.accessToken);
      final permisos = (payload?['permisos'] as List?)?.cast<String>() ?? [];
      final mustChange = payload?['mustChangePassword'] as bool? ?? false;
      if (mustChange) {
        state = AuthState(
          status: AuthStatus.mustChangePassword,
          user: _fromPayload(payload, permisos),
        );
        return;
      }
      final profile = await _repo.getProfile();
      state = AuthState(
        status: AuthStatus.authenticated,
        user: _merge(profile, permisos),
      );
    } on NetworkException {
      // Sin red: dejar unauthenticated para que el usuario haga login manual
      state = const AuthState(status: AuthStatus.unauthenticated);
    } catch (_) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login({
    required String username,
    required String password,
    bool rememberMe = false,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, clearErr: true);
    try {
      final auth = await _repo.login(
        username: username,
        password: password,
        rememberMe: rememberMe,
      );
      final payload = AuthRepository.decodeJwt(auth.accessToken);
      final permisos = (payload?['permisos'] as List?)?.cast<String>() ?? [];
      if (auth.mustChangePassword) {
        state = AuthState(
          status: AuthStatus.mustChangePassword,
          user:
              _fromPayload(payload, permisos) ??
              UserProfile(
                id: '',
                username: username,
                rol: '',
                nivel: 0,
                createdAt: '',
                permisos: permisos,
              ),
        );
        return;
      }
      final profile = await _repo.getProfile();
      state = AuthState(
        status: AuthStatus.authenticated,
        user: _merge(profile, permisos),
      );
    } on AppException catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: e.message,
      );
      rethrow; // permite que login_screen muestre el error
    } catch (e) {
      const msg = 'Error inesperado. Verifica tu conexión.';
      state = state.copyWith(status: AuthStatus.unauthenticated, error: msg);
      throw AppException(message: msg);
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> logoutAll() async {
    await _repo.logoutAll();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> changePassword({
    required String current,
    required String newPwd,
  }) async {
    await _repo.changePassword(currentPassword: current, newPassword: newPwd);
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  UserProfile? _fromPayload(Map<String, dynamic>? p, List<String> permisos) {
    if (p == null) return null;
    return UserProfile(
      id: p['sub'] as String? ?? '',
      username: p['username'] as String? ?? '',
      rol: p['rol'] as String? ?? '',
      nivel: (p['nivel'] as num?)?.toInt() ?? 0,
      sedeId: p['sedeId'] as String?,
      createdAt: '',
      permisos: permisos,
    );
  }

  UserProfile _merge(UserProfile profile, List<String> permisos) => UserProfile(
    id: profile.id,
    username: profile.username,
    rol: profile.rol,
    nivel: profile.nivel,
    sedeId: profile.sedeId,
    sede: profile.sede,
    createdAt: profile.createdAt,
    permisos: permisos.isNotEmpty ? permisos : profile.permisos,
  );
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.watch(authRepositoryProvider)),
);
