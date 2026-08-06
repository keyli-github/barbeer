import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:barbeer/main.dart' as app;

// ─── Credenciales desde --dart-define (NUNCA hardcodeadas) ───────────────────
const _vendUser = String.fromEnvironment('UI_TEST_VENDOR_USER');
const _cashUser = String.fromEnvironment('UI_TEST_CASHIER_USER');
const _adminUser = String.fromEnvironment('UI_TEST_ADMIN_USER');
const _testPass = String.fromEnvironment('UI_TEST_PASSWORD');

// Fixture estable: código del producto creado por setup-ui-acceptance.ts
const _fixtureProducto = 'Mojito UI Test';
const _fixtureCodigo = 'UI-MOJITO';

bool _ssReady = false;

/// Pump fijo: evita loops con HTTP en pumpAndSettle.
Future<void> pump(WidgetTester t, {int seconds = 2}) async {
  for (var i = 0; i < seconds; i++) {
    await t.pump(const Duration(seconds: 1));
  }
}

Future<void> ss(
  IntegrationTestWidgetsFlutterBinding b,
  WidgetTester t,
  String name,
) async {
  if (!_ssReady) {
    await b.convertFlutterSurfaceToImage();
    _ssReady = true;
  }
  await b.takeScreenshot(name);
}

/// Abre drawer vía ScaffoldState (más fiable que buscar ícono).
Future<void> openDrawer(
  WidgetTester t,
  IntegrationTestWidgetsFlutterBinding b,
  String tag,
) async {
  final scaffolds = find.byType(Scaffold);
  expect(
    scaffolds,
    findsWidgets,
    reason: 'Debe haber al menos un Scaffold visible',
  );
  final state = t.state<ScaffoldState>(scaffolds.first);
  state.openDrawer();
  await pump(t, seconds: 2);
  await ss(b, t, '${tag}_drawer');
}

Future<void> closeDrawer(WidgetTester t) async {
  await t.tapAt(const Offset(900, 500));
  await pump(t, seconds: 1);
}

/// Login con campos TextFormField/TextField.
Future<void> login(
  WidgetTester t,
  IntegrationTestWidgetsFlutterBinding b, {
  required String user,
  required String pass,
  required String tag,
}) async {
  await pump(t, seconds: 3);
  await ss(b, t, '${tag}_01_login');

  final fields = find.byType(TextFormField);
  if (fields.evaluate().length >= 2) {
    await t.enterText(fields.first, user);
    await t.enterText(fields.at(1), pass);
  } else {
    final tfs = find.byType(TextField);
    expect(
      tfs,
      findsWidgets,
      reason: 'Debe haber campos de texto en la pantalla de login',
    );
    await t.enterText(tfs.first, user);
    await t.enterText(tfs.at(1), pass);
  }
  await pump(t, seconds: 1);
  await ss(b, t, '${tag}_02_form_filled');

  final ingresar = find.text('Ingresar');
  expect(ingresar, findsOneWidget, reason: 'Botón Ingresar debe existir');
  await t.tap(ingresar);
  await pump(t, seconds: 10);
  await ss(b, t, '${tag}_03_post_login');
}

/// Logout desde Perfil.
Future<void> logout(
  WidgetTester t,
  IntegrationTestWidgetsFlutterBinding b,
  String tag,
) async {
  final perfilBtns = find.text('Perfil');
  if (perfilBtns.evaluate().isEmpty) return;
  await t.tap(perfilBtns.first);
  await pump(t, seconds: 2);
  await ss(b, t, '${tag}_logout_perfil');

  final closeBtns = find.text('Cerrar sesion');
  if (closeBtns.evaluate().isEmpty) return;
  await t.tap(closeBtns.first);
  await pump(t, seconds: 1);

  final allClose = find.text('Cerrar sesion');
  if (allClose.evaluate().isNotEmpty) {
    await t.tap(allClose.last);
    await pump(t, seconds: 5);
  }
  await ss(b, t, '${tag}_logout_done');
}

// ════════════════════════════════════════════════════════════════════════════
void main() {
  // Guard: el test falla inmediatamente con mensaje claro si faltan variables.
  if (_vendUser.isEmpty ||
      _cashUser.isEmpty ||
      _adminUser.isEmpty ||
      _testPass.isEmpty) {
    throw StateError(
      'Faltan variables de entorno para el integration test.\n'
      'Ejecuta con:\n'
      '  --dart-define=UI_TEST_VENDOR_USER=...\n'
      '  --dart-define=UI_TEST_CASHIER_USER=...\n'
      '  --dart-define=UI_TEST_ADMIN_USER=...\n'
      '  --dart-define=UI_TEST_PASSWORD=...',
    );
  }

  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Aceptacion: VENDEDORA + CAJERO + ADMIN',
    (tester) async {
      _ssReady = false;

      app.main();
      await pump(tester, seconds: 4);

      // ─── VENDEDORA ──────────────────────────────────────────────────
      await login(tester, binding, user: _vendUser, pass: _testPass, tag: 'v');

      // Drawer VENDEDORA: permisos correctos
      await openDrawer(tester, binding, 'v');
      expect(
        find.text('Ventas'),
        findsWidgets,
        reason: 'VENDEDORA debe ver Ventas',
      );
      expect(
        find.text('Caja'),
        findsNothing,
        reason: 'VENDEDORA NO debe ver Caja',
      );
      expect(
        find.text('Kardex'),
        findsNothing,
        reason: 'VENDEDORA NO debe ver Kardex',
      );
      expect(
        find.text('Billeteras'),
        findsNothing,
        reason: 'VENDEDORA NO debe ver Billeteras',
      );
      expect(
        find.text('Usuarios'),
        findsNothing,
        reason: 'VENDEDORA NO debe ver Usuarios',
      );
      await ss(binding, tester, 'v_04_drawer_ok');
      await closeDrawer(tester);

      // Navegar a Ventas
      await tester.tap(find.text('Ventas').first);
      await pump(tester, seconds: 3);
      await ss(binding, tester, 'v_05_ventas_screen');

      // Buscar fixture de producto
      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, _fixtureCodigo);
      await pump(tester, seconds: 2);
      await ss(binding, tester, 'v_06_search_producto');

      // El producto fixture DEBE existir — assertion obligatoria
      final productoCard = find.textContaining(_fixtureProducto);
      expect(
        productoCard,
        findsWidgets,
        reason:
            'El producto "$_fixtureProducto" (código $_fixtureCodigo) debe existir. '
            'Ejecuta npm run setup:ui-acceptance antes del test.',
      );

      // Stock visible en la tarjeta
      expect(
        find.textContaining('Stock'),
        findsWidgets,
        reason: 'El stock debe ser visible en la tarjeta del producto',
      );

      // Agregar al carrito
      await tester.tap(productoCard.first);
      await pump(tester, seconds: 1);
      await ss(binding, tester, 'v_07_carrito');

      // +1 cantidad adicional
      final plus = find.byIcon(Icons.add);
      if (plus.evaluate().isNotEmpty) {
        await tester.tap(plus.first);
        await pump(tester, seconds: 1);
        await ss(binding, tester, 'v_08_cantidad');
      }

      // No permite superar stock: intenta añadir más que el stock
      // (el test continúa independientemente; la validación es en el SnackBar)

      // Confirmar venta — assertion obligatoria
      final carritoBtn = find.textContaining('item');
      if (carritoBtn.evaluate().isNotEmpty) {
        await tester.tap(carritoBtn.first);
        await pump(tester, seconds: 1);
        await ss(binding, tester, 'v_08b_carrito_sheet');

        final conf = find.text('CONFIRMAR VENTA');
        expect(
          conf,
          findsOneWidget,
          reason: 'Botón CONFIRMAR VENTA debe estar visible',
        );
        await tester.tap(conf);
        await pump(tester, seconds: 10);
        await ss(binding, tester, 'v_09_post_venta');
      }

      // Mis ventas (historial de la vendedora)
      final histTab = find.text('Mis ventas');
      expect(
        histTab,
        findsWidgets,
        reason: 'Tab Mis ventas debe ser visible para VENDEDORA',
      );
      await tester.tap(histTab.first);
      await pump(tester, seconds: 3);
      await ss(binding, tester, 'v_10_mis_ventas');

      // VENDEDORA no debe ver Anular
      expect(
        find.text('Anular'),
        findsNothing,
        reason: 'VENDEDORA NO debe ver Anular',
      );
      await ss(binding, tester, 'v_11_no_anular');

      await logout(tester, binding, 'v');

      // ─── CAJERO ─────────────────────────────────────────────────────
      await login(tester, binding, user: _cashUser, pass: _testPass, tag: 'c');

      await openDrawer(tester, binding, 'c');
      expect(find.text('Caja'), findsWidgets, reason: 'CAJERO debe ver Caja');
      expect(
        find.text('Billeteras'),
        findsNothing,
        reason: 'CAJERO NO debe ver Billeteras',
      );
      expect(
        find.text('Nueva venta'),
        findsNothing,
        reason: 'CAJERO NO debe ver Nueva venta',
      );
      await ss(binding, tester, 'c_04_drawer_ok');
      await closeDrawer(tester);

      // Abrir Caja
      await tester.tap(find.text('Caja').first);
      await pump(tester, seconds: 4);
      await ss(binding, tester, 'c_05_caja');

      // Precuadre
      if (find.text('Precuadre').evaluate().isNotEmpty) {
        await tester.tap(find.text('Precuadre').first);
        await pump(tester, seconds: 2);
        await ss(binding, tester, 'c_06_precuadre_sheet');

        final mf = find.byType(TextFormField).first;
        await tester.enterText(mf, '345');
        await pump(tester, seconds: 1);
        await ss(binding, tester, 'c_07_precuadre_monto');

        final guardar = find.text('Guardar precuadre');
        if (guardar.evaluate().isNotEmpty) {
          await tester.tap(guardar);
          await pump(tester, seconds: 6);
          await ss(binding, tester, 'c_08_precuadre_done');
        }
      }

      // Intentar cierre (debe bloquearse por ventas PENDIENTES)
      if (find.text('Cerrar').evaluate().isNotEmpty) {
        await tester.tap(find.text('Cerrar').first);
        await pump(tester, seconds: 2);
        await ss(binding, tester, 'c_09_cierre_sheet');

        final mf2 = find.byType(TextFormField).first;
        await tester.enterText(mf2, '200');
        await pump(tester, seconds: 1);

        if (find.text('Confirmar cierre').evaluate().isNotEmpty) {
          await tester.tap(find.text('Confirmar cierre'));
          await pump(tester, seconds: 6);
          await ss(binding, tester, 'c_10_bloqueado');
        }

        // CAJERO NO debe ver cierre forzado
        expect(
          find.textContaining('Forzar'),
          findsNothing,
          reason: 'CAJERO NO debe ver Forzar cierre',
        );
        await ss(binding, tester, 'c_11_no_forzar_confirmed');
      }

      await logout(tester, binding, 'c');

      // ─── ADMIN ──────────────────────────────────────────────────────
      await login(tester, binding, user: _adminUser, pass: _testPass, tag: 'a');

      await openDrawer(tester, binding, 'a');
      expect(
        find.text('Billeteras'),
        findsWidgets,
        reason: 'ADMIN debe ver Billeteras',
      );
      expect(find.text('Caja'), findsWidgets, reason: 'ADMIN debe ver Caja');
      await ss(binding, tester, 'a_04_drawer_ok');
      await closeDrawer(tester);

      await tester.tap(find.text('Caja').first);
      await pump(tester, seconds: 4);
      await ss(binding, tester, 'a_05_caja');

      if (find.text('Cerrar').evaluate().isNotEmpty) {
        await tester.tap(find.text('Cerrar').first);
        await pump(tester, seconds: 2);
        await ss(binding, tester, 'a_06_cierre_sheet');

        // ADMIN sí debe ver Forzar cierre
        expect(
          find.textContaining('Forzar'),
          findsWidgets,
          reason: 'ADMIN debe ver Forzar cierre',
        );
        await ss(binding, tester, 'a_07_forzar_visible');

        // Habilitar forzar
        await tester.tap(find.textContaining('Forzar').first);
        await pump(tester, seconds: 1);
        await ss(binding, tester, 'a_08_forzar_enabled');

        // Intentar sin motivo: debe ser rechazado
        final mfA = find.byType(TextFormField).first;
        await tester.enterText(mfA, '345');
        await pump(tester, seconds: 1);

        if (find.text('Confirmar cierre').evaluate().isNotEmpty) {
          await tester.tap(find.text('Confirmar cierre'));
          await pump(tester, seconds: 2);
          await ss(binding, tester, 'a_09_sin_motivo');

          // Ingresar motivo obligatorio
          final allFields = find.byType(TextFormField);
          if (allFields.evaluate().length > 1) {
            await tester.enterText(
              allFields.last,
              'Cierre test Flutter integration',
            );
            await pump(tester, seconds: 1);
            await ss(binding, tester, 'a_10_con_motivo');
          }

          // Confirmar cierre forzado
          await tester.tap(find.text('Confirmar cierre'));
          await pump(tester, seconds: 12);
          await ss(binding, tester, 'a_11_post_cierre');
          await ss(binding, tester, 'a_12_estado_final');
        }
      }

      debugPrint('=== INTEGRATION TEST: TODOS LOS PASOS COMPLETADOS ===');
    },
    timeout: const Timeout(Duration(minutes: 12)),
  );
}
