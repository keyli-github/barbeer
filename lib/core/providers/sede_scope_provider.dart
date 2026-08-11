import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/models/auth_models.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../constants/api_constants.dart';
import '../network/api_client.dart';

class SedeScopeOption {
  final String id;
  final String nombre;
  final String codigoSede;
  final bool activo;

  const SedeScopeOption({
    required this.id,
    required this.nombre,
    required this.codigoSede,
    required this.activo,
  });

  factory SedeScopeOption.fromJson(Map<String, dynamic> json) =>
      SedeScopeOption(
        id: json['id'] as String? ?? '',
        nombre: json['nombre'] as String? ?? '',
        codigoSede:
            json['codigoSede'] as String? ?? json['codigo'] as String? ?? '',
        activo: json['activo'] as bool? ?? true,
      );
}

class SedeScopeNotifier extends StateNotifier<String?> {
  final UserProfile? user;

  SedeScopeNotifier(this.user)
    : super(user?.isSuperAdmin == true ? null : user?.sedeId);

  void select(String? sedeId) {
    state = user?.isSuperAdmin == true ? sedeId : user?.sedeId;
  }
}

/// Sede used by all sede-aware screens. For SUPERADMIN, null means all sedes.
final globalSedeIdProvider = StateNotifierProvider<SedeScopeNotifier, String?>((
  ref,
) {
  final user = ref.watch(authProvider.select((auth) => auth.user));
  return SedeScopeNotifier(user);
});

final sedeScopeOptionsProvider = FutureProvider<List<SedeScopeOption>>((
  ref,
) async {
  final auth = ref.watch(authProvider);
  if (auth.user?.isSuperAdmin != true ||
      !auth.hasPermission('establecimientos:leer')) {
    return const [];
  }

  final response = await ApiClient.instance.get(
    ApiConstants.establishments,
    queryParameters: const {'pagina': 1, 'limite': 100},
  );
  final payload = Map<String, dynamic>.from(response.data as Map);
  return (payload['data'] as List? ?? const [])
      .whereType<Map>()
      .map((item) => SedeScopeOption.fromJson(Map<String, dynamic>.from(item)))
      .where((sede) => sede.id.isNotEmpty && sede.activo)
      .toList();
});
