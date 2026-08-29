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

    expect(find.text('Yacare'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Usuario'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Contraseña'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Ingresar'), findsOneWidget);
    expect(find.textContaining('¿Olvidaste tu contraseña?'), findsOneWidget);
    expect(find.text('SOLO PERSONAL AUTORIZADO'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the two-column composition on a wide screen', (
    tester,
  ) async {
    await pumpLogin(tester, const Size(1280, 800));

    expect(find.text('Yacare'), findsOneWidget);
    expect(find.text('SISTEMA INTERNO'), findsOneWidget);
    expect(find.text('SOLO PERSONAL AUTORIZADO'), findsOneWidget);
    expect(find.text('Caja y reportes'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Ingresar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the complete login action accessible on a tall phone', (
    tester,
  ) async {
    await pumpLogin(tester, const Size(390, 844));

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Ingresar'), findsOneWidget);
    expect(find.text('SOLO PERSONAL AUTORIZADO'), findsOneWidget);
    await tester.ensureVisible(find.text('SOLO PERSONAL AUTORIZADO'));
    await tester.pump();
    expect(
      tester.getBottomRight(find.text('SOLO PERSONAL AUTORIZADO')).dy,
      lessThanOrEqualTo(844),
    );
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
