import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';
import '../errors/app_exception.dart';
import '../storage/secure_storage.dart';
import 'http_header_utils.dart';

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
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        sendTimeout: ApiConstants.sendTimeout,
        contentType: 'application/json',
        headers: _deviceHeaders,
      ),
    );
    _initialized = true;
  }

  void updateCallbacks({
    Future<String?> Function()? onRefreshToken,
    void Function()? onSessionExpired,
  }) {
    _onRefreshToken = onRefreshToken;
    _onSessionExpired = onSessionExpired;
  }

  static const _publicPaths = {
    '/auth/login',
    '/auth/refresh',
    '/auth/logout',
    '/branding',
    '/health',
  };

  static Map<String, String>? get _deviceHeaders {
    if (kIsWeb) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => const {
        'x-device-name': 'BarBeer Android',
        'x-device-type': 'android',
        'user-agent': 'BarBeer/1.0 (Android)',
      },
      TargetPlatform.windows => const {
        'x-device-name': 'BarBeer Windows',
        'x-device-type': 'windows',
        'user-agent': 'BarBeer/1.0 (Windows)',
      },
      _ => null,
    };
  }

  static bool _isPublic(String path) =>
      _publicPaths.contains(Uri.parse(path).path);

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

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final h = await _headers(path);
    return _execute(
      () => _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: _opts(h),
      ),
      path,
    );
  }

  Future<Uint8List> getBytes(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final h = await _headers(path);
    final resp = await _execute(
      () => _dio.get<Uint8List>(
        path,
        queryParameters: queryParameters,
        options: _opts(h).copyWith(responseType: ResponseType.bytes),
      ),
      path,
    );
    return resp.data ?? Uint8List(0);
  }

  /// Like [getBytes] but preserves Content-Disposition and Content-Type.
  Future<HttpBytesResponse> getBytesResponse(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final h = await _headers(path);
    final resp = await _execute(
      () => _dio.get<Uint8List>(
        path,
        queryParameters: queryParameters,
        options: _opts(h).copyWith(responseType: ResponseType.bytes),
      ),
      path,
    );
    return HttpBytesResponse(
      bytes: resp.data ?? Uint8List(0),
      contentDisposition: resp.headers.value('content-disposition'),
      contentType: resp.headers.value('content-type'),
    );
  }

  Future<Response<T>> post<T>(String path, {dynamic data}) async {
    final h = await _headers(path);
    return _execute(
      () => _dio.post<T>(path, data: data, options: _opts(h)),
      path,
    );
  }

  Future<Response<T>> postMultipart<T>(
    String path, {
    required FormData data,
    Duration? receiveTimeout,
    Duration? sendTimeout,
  }) async {
    final h = await _headers(path);
    return _execute(
      () => _dio.post<T>(
        path,
        data: data,
        options: _opts({
          ...?h,
          'Content-Type': 'multipart/form-data',
        }).copyWith(receiveTimeout: receiveTimeout, sendTimeout: sendTimeout),
      ),
      path,
    );
  }

  Future<Response<T>> patch<T>(String path, {dynamic data}) async {
    final h = await _headers(path);
    return _execute(
      () => _dio.patch<T>(path, data: data, options: _opts(h)),
      path,
    );
  }

  Future<Response<T>> put<T>(String path, {dynamic data}) async {
    final h = await _headers(path);
    return _execute(
      () => _dio.put<T>(path, data: data, options: _opts(h)),
      path,
    );
  }

  Future<Response<T>> delete<T>(String path, {dynamic data}) async {
    final h = await _headers(path);
    return _execute(
      () => _dio.delete<T>(path, data: data, options: _opts(h)),
      path,
    );
  }

  Future<Response<T>> _execute<T>(
    Future<Response<T>> Function() fn,
    String path, {
    bool isRetry = false,
  }) async {
    try {
      return await fn();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 && !_isPublic(path) && !isRetry) {
        final newToken = await _handleRefresh();
        if (newToken != null) {
          return _execute(
            () => _dio.fetch<T>(
              e.requestOptions..headers['Authorization'] = 'Bearer $newToken',
            ),
            path,
            isRetry: true,
          );
        }
      }
      throw mapDioException(e);
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
        await _expireSession();
        return null;
      }
      for (final c in _refreshQueue) {
        c.complete(newToken);
      }
      _refreshQueue.clear();
      return newToken;
    } on NetworkException {
      _failRefreshQueue();
      return null;
    } catch (_) {
      await _expireSession();
      return null;
    } finally {
      _isRefreshing = false;
    }
  }

  void _failRefreshQueue() {
    for (final c in _refreshQueue) {
      c.completeError('session_expired');
    }
    _refreshQueue.clear();
  }

  Future<void> _expireSession() async {
    _failRefreshQueue();
    await SecureStorageService.instance.clearSession();
    _onSessionExpired?.call();
  }
}

AppException mapDioException(DioException error) {
  if (error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout) {
    return const NetworkException();
  }

  final response = error.response;
  if (response == null) return const NetworkException();

  final body = response.data is Map
      ? Map<String, dynamic>.from(response.data as Map)
      : const <String, dynamic>{};
  final rawMessage = body['message'];
  final details = rawMessage is List
      ? rawMessage.whereType<String>().toList(growable: false)
      : const <String>[];
  final fallback = body['error'];
  final message = switch (rawMessage) {
    String value when value.isNotEmpty => value,
    List _ when details.isNotEmpty => details.first,
    _ when fallback is String && fallback.isNotEmpty => fallback,
    _ => 'Ocurrio un error inesperado',
  };

  return AppException(
    message: message,
    statusCode:
        (body['statusCode'] as num?)?.toInt() ?? response.statusCode ?? 0,
    path: body['path'] as String? ?? error.requestOptions.path,
    code: body['code'] as String?,
    details: details,
  );
}
