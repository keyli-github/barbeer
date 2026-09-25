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
  String? deletedId;
  String? updatedId;
  bool? updatedActivo;

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

  @override
  Future<void> delete(String id) async {
    deletedId = id;
  }

  @override
  Future<Categoria> update(
    String id, {
    required String nombre,
    required String descripcion,
    required bool activo,
  }) async {
    updatedId = id;
    updatedActivo = activo;
    return Categoria(
      id: id,
      nombre: nombre,
      descripcion: descripcion,
      activo: activo,
      productosCount: _category.productosCount,
    );
  }
}

class _StaticCategoriesNotifier extends CategoriasNotifier {
  _StaticCategoriesNotifier(CategoriasRepository repository)
    : super(repository) {
    state = const CategoriasState(
      categorias: [_category],
      total: 1,
      totalPaginas: 1,
    );
  }

  @override
  Future<void> load({int? pagina}) async {}
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

  testWidgets('mobile category delete action is shown only with permission', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakeCategoriesRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriasProvider.overrideWith(
            (ref) => _StaticCategoriesNotifier(repository),
          ),
          authProvider.overrideWith(
            (ref) => _TestAuthNotifier(
              ref.read(authRepositoryProvider),
              const AuthState(
                status: AuthStatus.authenticated,
                user: UserProfile(
                  id: 'user-1',
                  username: 'admin',
                  rol: 'ADMIN',
                  nivel: 80,
                  createdAt: '2026-09-01',
                  permisos: ['categorias:leer', 'categorias:eliminar'],
                ),
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: CategoriasScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Dar de baja'), findsOneWidget);
    expect(find.text('Desactivar (cambiar estado)'), findsNothing);
    await tester.tap(find.text('Dar de baja'));
    await tester.pumpAndSettle();
    expect(find.text('Dar de baja categoría'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Dar de baja'));
    await tester.pumpAndSettle();
    expect(repository.deletedId, 'category-1');
  });

  testWidgets(
    'mobile category state toggle and semantic deactivation are distinct',
    (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _FakeCategoriesRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoriasProvider.overrideWith(
              (ref) => _StaticCategoriesNotifier(repository),
            ),
            authProvider.overrideWith(
              (ref) => _TestAuthNotifier(
                ref.read(authRepositoryProvider),
                const AuthState(
                  status: AuthStatus.authenticated,
                  user: UserProfile(
                    id: 'user-1',
                    username: 'admin',
                    rol: 'ADMIN',
                    nivel: 80,
                    createdAt: '2026-09-01',
                    permisos: [
                      'categorias:leer',
                      'categorias:editar',
                      'categorias:eliminar',
                    ],
                  ),
                ),
              ),
            ),
          ],
          child: const MaterialApp(home: CategoriasScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Desactivar (cambiar estado)'), findsOneWidget);
      expect(find.text('Dar de baja'), findsOneWidget);
      expect(find.text('Desactivar'), findsNothing);

      await tester.tap(find.text('Desactivar (cambiar estado)'));
      await tester.pumpAndSettle();
      expect(repository.updatedId, 'category-1');
      expect(repository.updatedActivo, isFalse);
      expect(repository.deletedId, isNull);
    },
  );

  testWidgets('mobile category delete action is absent without permission', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriasProvider.overrideWith(
            (ref) => _StaticCategoriesNotifier(_FakeCategoriesRepository()),
          ),
          authProvider.overrideWith(
            (ref) => _TestAuthNotifier(
              ref.read(authRepositoryProvider),
              const AuthState(
                status: AuthStatus.authenticated,
                user: UserProfile(
                  id: 'user-1',
                  username: 'admin',
                  rol: 'ADMIN',
                  nivel: 80,
                  createdAt: '2026-09-01',
                  permisos: ['categorias:leer'],
                ),
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: CategoriasScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
  });
}
