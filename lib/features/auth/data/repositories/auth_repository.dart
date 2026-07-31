import 'dart:convert';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../models/auth_models.dart';

class AuthRepository {
  final ApiClient _api;
  final SecureStorageService _storage;
  AuthRepository({required ApiClient api, required SecureStorageService storage})
      : _api = api, _storage = storage;

  Future<AuthResponse> login({required String username, required String password, bool rememberMe = false}) async {
    final r = await _api.post(ApiConstants.login, data: {'username': username, 'password': password});
    final auth = AuthResponse.fromJson(r.data);
    await _storage.saveAccessToken(auth.accessToken);
    await _storage.saveRefreshToken(auth.refreshToken);
    await _storage.saveRememberMe(rememberMe);
    return auth;
  }

  Future<UserProfile> getProfile() async {
    final r = await _api.get(ApiConstants.profile);
    return UserProfile.fromJson(r.data);
  }

  Future<AuthResponse?> refreshToken() async {
    final rt = await _storage.getRefreshToken();
    if (rt == null) return null;
    final r = await _api.post(ApiConstants.refresh, data: {'refreshToken': rt});
    final auth = AuthResponse.fromJson(r.data);
    await _storage.saveAccessToken(auth.accessToken);
    await _storage.saveRefreshToken(auth.refreshToken);
    return auth;
  }

  Future<void> logout() async {
    final rt = await _storage.getRefreshToken();
    if (rt != null) {
      try { await _api.post(ApiConstants.logout, data: {'refreshToken': rt}); } catch (_) {}
    }
    await _storage.clearSession();
  }

  Future<void> logoutAll() async {
    try { await _api.post(ApiConstants.logoutAll); } catch (_) {}
    await _storage.clearSession();
  }

  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    await _api.patch(ApiConstants.changePassword, data: {
      'passwordActual': currentPassword, 'passwordNuevo': newPassword, 'confirmacion': newPassword});
    await _storage.clearSession();
  }

  Future<List<ActiveSession>> getSessions() async {
    final r = await _api.get(ApiConstants.sessions);
    return (r.data as List).map((e) => ActiveSession.fromJson(e)).toList();
  }

  Future<void> revokeSession(String id) async =>
      await _api.delete(ApiConstants.revokeSession(id));

  Future<void> revokeAllOtherSessions() async =>
      await _api.delete(ApiConstants.sessions);

  static Map<String, dynamic>? decodeJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final decoded = utf8.decode(base64.decode(base64.normalize(parts[1])));
      return Map<String, dynamic>.from(jsonDecode(decoded));
    } catch (_) { return null; }
  }
}
