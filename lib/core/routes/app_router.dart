import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/change_password_screen.dart';
import '../../features/shell/presentation/screens/shell_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/usuarios/presentation/screens/usuarios_screen.dart';
import '../../features/roles/presentation/screens/roles_screen.dart';
import '../../features/permisos/presentation/screens/permisos_screen.dart';
import '../../features/sucursales/presentation/screens/sucursales_screen.dart';
import '../../features/auditoria/presentation/screens/auditoria_screen.dart';
import '../../features/perfil/presentation/screens/perfil_screen.dart';
import '../../features/productos/presentation/screens/productos_screen.dart';
import '../../features/ventas/presentation/screens/ventas_screen.dart';
import '../../features/caja/presentation/screens/caja_screen.dart';
import '../../features/inventario/presentation/screens/inventario_screen.dart';
import '../../features/kardex/presentation/screens/kardex_screen.dart';
import '../../features/compras/presentation/screens/compras_screen.dart';
import '../../features/asistencia/presentation/screens/asistencia_screen.dart';
import '../../features/etiquetas/presentation/screens/etiquetas_screen.dart';
import 'route_paths.dart';

final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  // El GoRouter se crea UNA SOLA VEZ. El estado de auth se lee en el
  // callback de redirect (no al crear el provider) para evitar que el
  // router se reconstruya con cada cambio de estado, lo que provocaba
  // que la app volviera a /splash y llamara bootstrap() de nuevo.
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: RoutePaths.splash,
    redirect: (ctx, state) {
      final auth = ref.read(authProvider); // lee el estado ACTUAL
      final path = state.matchedLocation;
      final status = auth.status;

      // Durante la carga inicial y mientras se procesa el login,
      // no forzar ninguna redirección para evitar parpadeos.
      if (status == AuthStatus.initial || status == AuthStatus.loading) {
        return null;
      }
      if (status == AuthStatus.mustChangePassword) {
        return path == RoutePaths.changePassword
            ? null
            : RoutePaths.changePassword;
      }
      if (status == AuthStatus.unauthenticated) {
        return path == RoutePaths.login ? null : RoutePaths.login;
      }
      if (status == AuthStatus.authenticated) {
        if (path == RoutePaths.login || path == RoutePaths.splash) {
          return RoutePaths.dashboard;
        }
        if (!auth.canAccess(path)) return RoutePaths.noAutorizado;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: RoutePaths.splash,
        builder: (_, __) => const _SplashScreen(),
      ),
      GoRoute(path: RoutePaths.login, builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: RoutePaths.changePassword,
        builder: (_, state) {
          final forced = state.uri.queryParameters['forced'] != 'false';
          return ChangePasswordScreen(isForced: forced);
        },
      ),
      GoRoute(
        path: RoutePaths.noAutorizado,
        builder: (_, __) => const _UnauthorizedScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellKey,
        builder: (_, state, child) =>
            ShellScreen(currentPath: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: RoutePaths.dashboard,
            builder: (_, __) => const DashboardScreen(),
          ),
          GoRoute(
            path: RoutePaths.usuarios,
            builder: (_, __) => const UsuariosScreen(),
          ),
          GoRoute(
            path: RoutePaths.roles,
            builder: (_, __) => const RolesScreen(),
          ),
          GoRoute(
            path: RoutePaths.permisos,
            builder: (_, __) => const PermisosScreen(),
          ),
          GoRoute(
            path: RoutePaths.sucursales,
            builder: (_, __) => const SucursalesScreen(),
          ),
          GoRoute(
            path: RoutePaths.auditoria,
            builder: (_, __) => const AuditoriaScreen(),
          ),
          GoRoute(
            path: RoutePaths.perfil,
            builder: (_, __) => const PerfilScreen(),
          ),
          GoRoute(
            path: RoutePaths.productos,
            builder: (_, __) => const ProductosScreen(),
          ),
          GoRoute(
            path: RoutePaths.ventas,
            builder: (_, __) => const VentasScreen(),
          ),
          GoRoute(
            path: RoutePaths.caja,
            builder: (_, __) => const CajaScreen(),
          ),
          GoRoute(
            path: RoutePaths.inventario,
            builder: (_, __) => const InventarioScreen(),
          ),
          GoRoute(
            path: RoutePaths.kardex,
            builder: (_, __) => const KardexScreen(),
          ),
          GoRoute(
            path: RoutePaths.compras,
            builder: (_, __) => const ComprasScreen(),
          ),
          GoRoute(
            path: RoutePaths.asistencia,
            builder: (_, __) => const AsistenciaScreen(),
          ),
          GoRoute(
            path: RoutePaths.etiquetas,
            builder: (_, __) => const EtiquetasScreen(),
          ),
        ],
      ),
    ],
  );
});

class _SplashScreen extends ConsumerStatefulWidget {
  const _SplashScreen();
  @override
  ConsumerState<_SplashScreen> createState() => _SplashState();
}

class _SplashState extends ConsumerState<_SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(authProvider.notifier).bootstrap(),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF2F5FA),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_bar_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Bar Beer',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 32),
          const CircularProgressIndicator(
            color: Color(0xFF2563EB),
            strokeWidth: 2.5,
          ),
        ],
      ),
    ),
  );
}

class _UnauthorizedScreen extends StatelessWidget {
  const _UnauthorizedScreen();
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outlined,
                color: Color(0xFFEF4444),
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sin acceso',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'No tienes permisos para acceder a esta seccion.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF475569)),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Volver al inicio'),
            ),
          ],
        ),
      ),
    ),
  );
}
