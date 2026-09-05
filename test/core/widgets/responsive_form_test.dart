import 'package:barbeer/core/widgets/responsive_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpHarness(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => ResponsiveForm.show<void>(
                  context: context,
                  builder: (dialogMode) => ResponsiveFormScaffold(
                    dialogMode: dialogMode,
                    dialogKey: const ValueKey('test-form-dialog'),
                    dialogWidth: 560,
                    dialogHeight: 500,
                    title: 'Formulario',
                    body: const Center(child: Text('Contenido')),
                  ),
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> pumpPageHarness(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => ResponsiveForm.showPage<void>(
                  context: context,
                  dialogKey: const ValueKey('test-page-dialog'),
                  dialogWidth: 680,
                  dialogHeight: 600,
                  page: Scaffold(
                    appBar: AppBar(title: const Text('Formulario existente')),
                    body: const Center(child: Text('Contenido existente')),
                  ),
                ),
                child: const Text('Abrir página'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('desktop opens a centered bounded dialog', (tester) async {
    await pumpHarness(tester, const Size(1440, 900));

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    final dialog = find.byKey(const ValueKey('test-form-dialog'));
    expect(dialog, findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
    expect(tester.getSize(dialog), const Size(560, 320));
    expect(tester.getCenter(dialog), const Offset(720, 450));
    expect(find.byKey(const ValueKey('responsive-form-close')), findsOneWidget);
  });

  testWidgets('mobile preserves full-screen form navigation', (tester) async {
    await pumpHarness(tester, const Size(400, 800));

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('test-form-dialog')), findsNothing);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Formulario'), findsOneWidget);
    expect(find.text('Contenido'), findsOneWidget);
  });

  testWidgets('desktop bounds an existing full-screen form', (tester) async {
    await pumpPageHarness(tester, const Size(1440, 900));

    await tester.tap(find.text('Abrir página'));
    await tester.pumpAndSettle();

    final dialog = find.byKey(const ValueKey('test-page-dialog'));
    expect(find.byType(Dialog), findsOneWidget);
    expect(tester.getSize(dialog), const Size(680, 320));
    expect(tester.getCenter(dialog), const Offset(720, 450));
    expect(find.text('Formulario existente'), findsOneWidget);
  });

  testWidgets('mobile keeps an existing form as a page', (tester) async {
    await pumpPageHarness(tester, const Size(400, 800));

    await tester.tap(find.text('Abrir página'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('test-page-dialog')), findsNothing);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Formulario existente'), findsOneWidget);
    expect(find.text('Contenido existente'), findsOneWidget);
  });

  testWidgets('desktop dialog grows only when scrollable content needs it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => ResponsiveForm.showPage<void>(
                context: context,
                dialogKey: const ValueKey('tall-page-dialog'),
                dialogWidth: 600,
                dialogHeight: 700,
                page: Scaffold(
                  appBar: AppBar(title: const Text('Contenido largo')),
                  body: const SingleChildScrollView(
                    child: SizedBox(height: 460),
                  ),
                ),
              ),
              child: const Text('Abrir contenido largo'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir contenido largo'));
    await tester.pumpAndSettle();

    final dialog = find.byKey(const ValueKey('tall-page-dialog'));
    expect(tester.getSize(dialog).height, greaterThan(320));
    expect(tester.getSize(dialog).height, lessThanOrEqualTo(700));
  });
}
