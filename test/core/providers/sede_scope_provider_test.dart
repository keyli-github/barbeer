import 'package:barbeer/core/providers/sede_scope_provider.dart';
import 'package:barbeer/features/auth/data/models/auth_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const scopedUser = UserProfile(
    id: 'user-1',
    username: 'admin',
    rol: 'ADMIN',
    nivel: 50,
    sedeId: 'sede-1',
    sede: 'Centro',
    createdAt: '',
    permisos: [],
  );
  const superAdmin = UserProfile(
    id: 'user-2',
    username: 'root',
    rol: 'SUPERADMIN',
    nivel: 100,
    createdAt: '',
    permisos: [],
  );

  test('scoped users always use their assigned sede', () {
    final notifier = SedeScopeNotifier(scopedUser);

    expect(notifier.state, 'sede-1');
    notifier.select(null);
    expect(notifier.state, 'sede-1');
    notifier.select('sede-2');
    expect(notifier.state, 'sede-1');
  });

  test('superadmin null scope means all sedes and can select one', () {
    final notifier = SedeScopeNotifier(superAdmin);

    expect(notifier.state, isNull);
    notifier.select('sede-2');
    expect(notifier.state, 'sede-2');
    notifier.select(null);
    expect(notifier.state, isNull);
  });

  test('sede options parse codigoSede from the current API', () {
    final sede = SedeScopeOption.fromJson({
      'id': 'sede-1',
      'nombre': 'Centro',
      'codigoSede': 'CENT',
      'activo': true,
    });

    expect(sede.codigoSede, 'CENT');
  });
}
