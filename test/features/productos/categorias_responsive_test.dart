import 'package:barbeer/features/auth/data/models/auth_models.dart';
import 'package:barbeer/features/auth/presentation/providers/auth_provider.dart';
import 'package:barbeer/features/categorias/data/models/categoria.dart';
import 'package:barbeer/features/categorias/data/repositories/categorias_repository.dart';
import 'package:barbeer/features/categorias/presentation/providers/categorias_provider.dart';
import 'package:barbeer/features/categorias/presentation/screens/categorias_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _category = Categoria(
  id: 'category-1',
  nombre: 'Agua',
  descripcion: 'Bebidas sin alcohol',
  activo: true,
  productosCount: 1,
);

class _FakeCategoriesRepository extends CategoriasRepository {
  @override
  Future<CategoriasPage> list({
    int pagina = 1,
    int limite = 25,
    String? q,
    bool? activo,
  }) async => const CategoriasPage(
    data: [_category],
    total: 1,
    pagina: 1,
    limite: 25,
    totalPaginas: 1,
  );
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(super.repository, AuthState value) {
    state = value;
  }
}

void main() {
  testWidgets('desktop category create and edit use centered dialogs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const user = UserProfile(
      id: 'user-1',
      username: 'admin',
      rol: 'ADMIN',
      nivel: 80,
      createdAt: '2026-09-01',
      permisos: ['categorias:leer', 'categorias:crear', 'categorias:editar'],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriasRepositoryProvider.overrideWithValue(
            _FakeCategoriesRepository(),
          ),
          authProvider.overrideWith(
            (ref) => _TestAuthNotifier(
              ref.read(authRepositoryProvider),
              const AuthState(status: AuthStatus.authenticated, user: user),
            ),
          ),
        ],
        child: const MaterialApp(home: CategoriasScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('NUEVA CATEGORÍA'));
    await tester.pumpAndSettle();
    final createDialog = find.byKey(const Key('category-form-dialog'));
    expect(createDialog, findsOneWidget);
    expect(tester.getSize(createDialog).width, 540);
    expect(tester.getSize(createDialog).height, lessThan(520));
    expect(tester.getCenter(createDialog), const Offset(720, 450));
    expect(find.text('Nueva categoria'), findsOneWidget);
    await tester.tap(find.byKey(const Key('responsive-form-close')));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('category-form-dialog')), findsOneWidget);
    expect(find.text('Editar categoria'), findsOneWidget);
    expect(find.text('Agua'), findsWidgets);
  });
}
