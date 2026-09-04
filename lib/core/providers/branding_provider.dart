import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';

enum BrandingMutation { logo, cover }

class BrandingState {
  final String? logoUrl;
  final String? coverUrl;
  final bool loading;
  final BrandingMutation? mutation;
  final String? error;

  const BrandingState({
    this.logoUrl,
    this.coverUrl,
    this.loading = true,
    this.mutation,
    this.error,
  });

  BrandingState copyWith({
    String? logoUrl,
    String? coverUrl,
    bool clearLogo = false,
    bool clearCover = false,
    bool? loading,
    BrandingMutation? mutation,
    bool clearMutation = false,
    String? error,
    bool clearError = false,
  }) => BrandingState(
    logoUrl: clearLogo ? null : (logoUrl ?? this.logoUrl),
    coverUrl: clearCover ? null : (coverUrl ?? this.coverUrl),
    loading: loading ?? this.loading,
    mutation: clearMutation ? null : (mutation ?? this.mutation),
    error: clearError ? null : (error ?? this.error),
  );
}

class BrandingNotifier extends StateNotifier<BrandingState> {
  BrandingNotifier(this._api) : super(const BrandingState()) {
    load();
  }

  BrandingNotifier.noop()
    : _api = null,
      super(const BrandingState(loading: false));

  final ApiClient? _api;

  Future<void> load() async {
    if (_api == null) return;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final response = await _api.get('/branding');
      _apply(Map<String, dynamic>.from(response.data as Map));
    } catch (error) {
      state = BrandingState(loading: false, error: error.toString());
    }
  }

  Future<void> setLogo(Uint8List bytes, String filename) =>
      _upload('/branding/logo', bytes, filename, BrandingMutation.logo);

  Future<void> removeLogo() async {
    await _remove('/branding/logo', BrandingMutation.logo);
  }

  Future<void> setCover(Uint8List bytes, String filename) =>
      _upload('/branding/login-cover', bytes, filename, BrandingMutation.cover);

  Future<void> removeCover() async {
    await _remove('/branding/login-cover', BrandingMutation.cover);
  }

  Future<void> _upload(
    String path,
    Uint8List bytes,
    String filename,
    BrandingMutation mutation,
  ) async {
    state = state.copyWith(mutation: mutation, clearError: true);
    try {
      final response = await _api!.postMultipart(
        path,
        data: FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes, filename: filename),
        }),
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
      );
      _apply(Map<String, dynamic>.from(response.data as Map));
    } catch (error) {
      state = state.copyWith(clearMutation: true, error: error.toString());
      rethrow;
    }
  }

  Future<void> _remove(String path, BrandingMutation mutation) async {
    state = state.copyWith(mutation: mutation, clearError: true);
    try {
      final response = await _api!.delete(path);
      _apply(Map<String, dynamic>.from(response.data as Map));
    } catch (error) {
      state = state.copyWith(clearMutation: true, error: error.toString());
      rethrow;
    }
  }

  void _apply(Map<String, dynamic> json) {
    state = BrandingState(
      logoUrl: json['logoUrl'] as String?,
      coverUrl: json['coverUrl'] as String?,
      loading: false,
    );
  }
}

final brandingProvider = StateNotifierProvider<BrandingNotifier, BrandingState>(
  (_) => BrandingNotifier(ApiClient.instance),
);
