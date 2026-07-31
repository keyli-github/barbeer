import 'dart:async';
import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../errors/app_exception.dart';
import '../storage/secure_storage.dart';

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  late Dio _dio;
  bool _initialized = false;
  bool _isRefreshing = false;
  final List<Completer<String>> _refreshQueue = [];

  Future<String?> Function()? _onRefreshToken;
  void Function()? _onSessionExpired;

  void initialize({
    Future<String?> Function()? onRefreshToken,
    void Function()? onSessionExpired,
  }) {
    _onRefreshToken = onRefreshToken;
    _onSessionExpired = onSessionExpired;
    if (_initialized) return;
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: ApiConstants.connectTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      sendTimeout: ApiConstants.sendTimeout,
      contentType: 'application/json',
    ));
    _initialized = true;
  }

  void updateCallbacks({
    Future<String?> Function()? onRefreshToken,
    void Function()? onSessionExpired,
  }) {
    _onRefreshToken = onRefreshToken;
    _onSessionExpired = onSessionExpired;
  }

  static const _publicPaths = ['/auth/login', '/auth/refresh', '/auth/logout', '/health'];
  static bool _isPublic(String path) => _publicPaths.any((p) => path.contains(p));

  Future<Map<String, dynamic>?> _headers(String path) async {
    if (_isPublic(path)) return null;
    final token = await SecureStorageService.instance.getAccessToken();
    if (token == null) return null;
    return {'Authorization': 'Bearer $token'};
  }

  Options _opts(Map<String, dynamic>? extra) {
    if (extra == null) return Options();
    return Options(headers: extra);
  }

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? queryParameters}) async {
    final h = await _headers(path);
    return _execute(() => _dio.get<T>(path, queryParameters: queryParameters, options: _opts(h)), path);
  }

  Future<Response<T>> post<T>(String path, {dynamic data}) async {
    final h = await _headers(path);
    return _execute(() => _dio.post<T>(path, data: data, options: _opts(h)), path);
  }

  Future<Response<T>> patch<T>(String path, {dynamic data}) async {
    final h = await _headers(path);
    return _execute(() => _dio.patch<T>(path, data: data, options: _opts(h)), path);
  }

  Future<Response<T>> put<T>(String path, {dynamic data}) async {
    final h = await _headers(path);
    return _execute(() => _dio.put<T>(path, data: data, options: _opts(h)), path);
  }

  Future<Response<T>> delete<T>(String path, {dynamic data}) async {
    final h = await _headers(path);
    return _execute(() => _dio.delete<T>(path, data: data, options: _opts(h)), path);
  }

  Future<Response<T>> _execute<T>(Future<Response<T>> Function() fn, String path, {bool isRetry = false}) async {
    try {
      return await fn();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 && !_isPublic(path) && !isRetry) {
        final newToken = await _handleRefresh();
        if (newToken != null) {
          final h = {'Authorization': 'Bearer $newToken'};
          return _execute(() => _dio.fetch<T>(e.requestOptions..headers['Authorization'] = 'Bearer $newToken'), path, isRetry: true);
        }
      }
      throw _mapError(e);
    }
  }

  Future<String?> _handleRefresh() async {
    if (_isRefreshing) {
      final completer = Completer<String>();
      _refreshQueue.add(completer);
      try {
        return await completer.future;
      } catch (_) {
        return null;
      }
    }
    _isRefreshing = true;
    try {
      final newToken = await _onRefreshToken?.call();
      if (newToken == null) {
        for (final c in _refreshQueue) c.completeError('session_expired');
        _refreshQueue.clear();
        _onSessionExpired?.call();
        return null;
      }
      for (final c in _refreshQueue) c.complete(newToken);
      _refreshQueue.clear();
      return newToken;
    } catch (_) {
      for (final c in _refreshQueue) c.completeError('session_expired');
      _refreshQueue.clear();
      _onSessionExpired?.call();
      return null;
    } finally {
      _isRefreshing = false;
    }
  }

  AppException _mapError(DioException e) {
    // Sin red o timeout de conexión
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return const NetworkException();
    }
    // Sin respuesta del servidor
    final resp = e.response;
    if (resp == null) return const NetworkException();

    final msg = _extractMessage(resp.data);
    final code = resp.statusCode ?? 0;

    switch (code) {
      case 400:
        return ValidationException(message: msg);
      case 401:
        // Para el endpoint de login, el 401 trae "Credenciales incorrectas"
        // Para otros endpoints, es sesión expirada
        if (msg.isNotEmpty &&
            msg != 'Ocurrio un error inesperado' &&
            !msg.toLowerCase().contains('sesion') &&
            !msg.toLowerCase().contains('session')) {
          return AppException(message: msg, statusCode: 401);
        }
        return const SessionExpiredException();
      case 403:
        return UnauthorizedException(message: msg);
      case 404:
        return NotFoundException(message: msg);
      case 409:
        return ConflictException(message: msg);
      case 422:
        return ValidationException(message: msg);
      case 429:
        return const AppException(
            message: 'Demasiados intentos. Espera un momento.', statusCode: 429);
      case 423:
        return AppException(message: msg, statusCode: 423); // cuenta bloqueada
      default:
        return AppException(message: msg, statusCode: code);
    }
  }

  String _extractMessage(dynamic d) {
    if (d is Map) {
      final m = d['message'];
      if (m is String) return m;
      if (m is List) return m.join(', ');
    }
    return 'Ocurrio un error inesperado';
  }
}
