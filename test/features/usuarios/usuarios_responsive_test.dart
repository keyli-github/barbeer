import 'package:barbeer/core/network/api_client.dart';
import 'package:barbeer/features/auth/data/models/auth_models.dart';
import 'package:barbeer/features/auth/presentation/providers/auth_provider.dart';
import 'package:barbeer/features/usuarios/presentation/screens/usuarios_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _admin = UserProfile(
  id: 'admin-1',
  username: 'admin',
  rol: 'SUPERADMIN',
  nivel: 100,
  createdAt: '2026-09-01',
  permisos: [
    'usuarios:leer',
    'usuarios:editar',
    'usuarios:eliminar',
    'usuarios:resetear-password',
  ],
);

final _frank = <String, dynamic>{
  'id': 'user-1',
  'username': 'frank',
  'activo': true,
  'createdAt': '2026-09-01',
  'rol': <String, dynamic>{'id': 'role-1', 'nombre': 'CAJERO', 'nivel': 10},
  'sede': <String, dynamic>{'id': 'branch-1', 'nombre': 'YACARE'},
};

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(super.repository) {
    state = const AuthState(status: AuthStatus.authenticated, user: _admin);
  }
}

class _FakeUsuariosNotifier extends UsuariosNotifier {
  _FakeUsuariosNotifier() : super(ApiClient.instance, false, false, null) {
    state = UsuariosState(
      users: [_frank],
      total: 1,
      roles: const [
        {'id': 'role-1', 'nombre': 'CAJERO', 'nivel': 10, 'activo': true},
      ],
      sedes: const [
        {'id': 'branch-1', 'nombre': 'YACARE', 'activo': true},
      ],
    );
  }

  @override
  Future<void> load({int page = 1}) async {}
}

void main() {
  testWidgets('desktop user detail opens as a centered dialog', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(
            (ref) => _TestAuthNotifier(ref.read(authRepositoryProvider)),
          ),
          usuariosProvider.overrideWith((ref) => _FakeUsuariosNotifier()),
        ],
        child: const MaterialApp(home: UsuariosScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('@frank'));
    await tester.pumpAndSettle();

    final dialog = find.byKey(const ValueKey('user-detail-dialog'));
    expect(find.byType(Dialog), findsOneWidget);
    expect(dialog, findsOneWidget);
    expect(tester.getCenter(dialog), const Offset(720, 450));
    expect(tester.getSize(dialog).height, lessThan(680));
    expect(find.text('Detalle de usuario'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
