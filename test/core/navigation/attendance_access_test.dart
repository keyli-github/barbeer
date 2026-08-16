import 'package:barbeer/core/navigation/app_destinations.dart';
import 'package:barbeer/features/auth/data/models/auth_models.dart';
import 'package:barbeer/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empleado autenticado conserva acceso al escáner de asistencia', () {
    const user = UserProfile(
      id: 'employee-id',
      username: 'vendedora',
      rol: 'VENDEDORA',
      nivel: 10,
      sedeId: 'sede-id',
      createdAt: '2026-01-01',
      permisos: ['ventas:crear', 'ventas:leer-propias'],
    );
    const auth = AuthState(status: AuthStatus.authenticated, user: user);
    final attendance = appDestinations.singleWhere(
      (destination) => destination.path == '/asistencia',
    );

    expect(attendance.canAccess(auth.hasPermission), isTrue);
    expect(auth.canAccess('/asistencia'), isTrue);
  });
}
