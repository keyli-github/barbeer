import 'package:barbeer/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpLogin(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders without overflow on a compact phone', (tester) async {
    await pumpLogin(tester, const Size(320, 568));

    expect(find.text('BarBeer', findRichText: true), findsOneWidget);
    expect(find.byKey(const Key('login-hero')), findsOneWidget);
    expect(
      find.image(const AssetImage('assets/images/bebb1.webp')),
      findsOneWidget,
    );
    expect(
      find.image(const AssetImage('assets/images/barbeer_Log.png')),
      findsOneWidget,
    );
    final panel = tester.widget<Container>(
      find.byKey(const Key('login-panel')),
    );
    final panelDecoration = panel.decoration as BoxDecoration;
    expect(panelDecoration.color, const Color(0xFF0B0A08));
    expect((panelDecoration.borderRadius! as BorderRadius).topLeft.x, 28);
    expect((panelDecoration.borderRadius! as BorderRadius).topRight.x, 28);
    final logoCircle = tester.widget<Container>(
      find.byKey(const Key('login-logo-circle')),
    );
    expect((logoCircle.decoration as BoxDecoration).color, const Color(0xFF171512));
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
    expect(find.byKey(const Key('login-scroll-view')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the two-column composition on a wide screen', (
    tester,
  ) async {
    await pumpLogin(tester, const Size(1280, 800));

    expect(find.byKey(const Key('login-desktop-composition')), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('login-hero'))).width, 640);
    expect(
      tester.getSize(find.byKey(const Key('login-desktop-panel'))).width,
      640,
    );
    expect(find.byKey(const Key('login-panel')), findsNothing);
    expect(find.text('Sistema interno\nde gestión'), findsOneWidget);
    expect(find.text('SOLO PERSONAL AUTORIZADO'), findsOneWidget);
    expect(find.text('Caja y reportes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('extends the dark panel to the bottom of the viewport', (
    tester,
  ) async {
    await pumpLogin(tester, const Size(390, 844));

    expect(tester.getBottomRight(find.byKey(const Key('login-panel'))).dy, 844);
    final panel = tester.widget<Container>(
      find.byKey(const Key('login-panel')),
    );
    expect((panel.margin as EdgeInsets).bottom, 24);
    expect(tester.takeException(), isNull);
  });

  testWidgets('toggles password visibility', (tester) async {
    await pumpLogin(tester, const Size(390, 844));
    final passwordField = find.widgetWithText(TextFormField, 'Contraseña');
    final passwordInput = find.descendant(
      of: passwordField,
      matching: find.byType(EditableText),
    );

    expect(tester.widget<EditableText>(passwordInput).obscureText, isTrue);
    await tester.tap(find.byTooltip('Mostrar contraseña'));
    await tester.pump();

    expect(tester.widget<EditableText>(passwordInput).obscureText, isFalse);
    expect(find.byTooltip('Ocultar contraseña'), findsOneWidget);
  });
}
