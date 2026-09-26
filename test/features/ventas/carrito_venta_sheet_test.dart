import 'package:barbeer/features/ventas/presentation/widgets/carrito_venta_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

CarritoVentaSheet _sheet({
  required CarritoItem item,
  required void Function(String, int) onChangeQuantity,
  required void Function(String) onRemove,
}) => CarritoVentaSheet(
  items: [item],
  total: item.subtotal,
  submitting: false,
  onConfirm: () {},
  onRetry: () {},
  onClear: () {},
  onChangeQuantity: onChangeQuantity,
  onRemove: onRemove,
);

Future<void> _pumpSheet(WidgetTester tester, Size size, Widget child) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pump();
}

Future<void> _activateByKeyboard(
  WidgetTester tester, {
  required Key key,
  required IconData icon,
}) async {
  final iconFinder = find.descendant(
    of: find.byKey(key),
    matching: find.byIcon(icon),
  );
  Focus.of(tester.element(iconFinder)).requestFocus();
  await tester.pump();
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pump();
}

void main() {
  testWidgets('mobile cart actions have named 44-pixel targets and fit', (
    tester,
  ) async {
    final item = CarritoItem(
      productoId: 'p1',
      nombre: 'Long beverage name that must remain readable on mobile',
      codigo: 'SKU-1',
      precio: 12,
      cantidad: 2,
    );
    final changes = <int>[];
    final removed = <String>[];
    await _pumpSheet(
      tester,
      const Size(390, 844),
      _sheet(
        item: item,
        onChangeQuantity: (_, delta) => changes.add(delta),
        onRemove: removed.add,
      ),
    );

    final semantics = tester.ensureSemantics();
    for (final entry in {
      'cart-decrease-p1': 'Disminuir cantidad de ${item.nombre}',
      'cart-increase-p1': 'Aumentar cantidad de ${item.nombre}',
      'cart-remove-p1': 'Eliminar ${item.nombre} del carrito',
    }.entries) {
      final keyedControl = find.byKey(ValueKey(entry.key));
      final control = entry.key.startsWith('cart-remove-')
          ? keyedControl
          : find.descendant(
              of: keyedControl,
              matching: find.byType(IconButton),
            );
      final target = tester.getSize(control);
      expect(target.width, greaterThanOrEqualTo(44));
      expect(target.height, greaterThanOrEqualTo(44));
      expect(find.byTooltip(entry.value), findsOneWidget);
      expect(tester.widget<IconButton>(control).tooltip, entry.value);
      expect(
        tester.getSemantics(control).getSemanticsData().label,
        entry.value,
      );
    }

    await tester.tap(find.byKey(const ValueKey('cart-increase-p1')));
    await tester.tap(find.byKey(const ValueKey('cart-decrease-p1')));
    await tester.tap(find.byKey(const ValueKey('cart-remove-p1')));

    expect(changes, [1, -1]);
    expect(removed, ['p1']);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets(
    'cart quantity actions can be activated from a desktop keyboard',
    (tester) async {
      final item = CarritoItem(
        productoId: 'p2',
        nombre: 'Keyboard beverage',
        codigo: 'SKU-2',
        precio: 10,
        cantidad: 2,
      );
      final changes = <int>[];
      await _pumpSheet(
        tester,
        const Size(1280, 900),
        _sheet(
          item: item,
          onChangeQuantity: (_, delta) => changes.add(delta),
          onRemove: (_) {},
        ),
      );

      await _activateByKeyboard(
        tester,
        key: const ValueKey('cart-increase-p2'),
        icon: Icons.add,
      );
      await _activateByKeyboard(
        tester,
        key: const ValueKey('cart-decrease-p2'),
        icon: Icons.remove,
      );

      expect(changes, [1, -1]);
      expect(tester.takeException(), isNull);
    },
  );
}
