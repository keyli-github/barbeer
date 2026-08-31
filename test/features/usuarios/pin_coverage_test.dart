// Focused tests for Scenarios 35 and 36 (Remediation #7 Sub-Blocker B)
//
// Scenario 36: PIN denial must not expose the secret value in the error state.
// Scenario 35: pin_management_sheet.dart — happy path + search/filter state.

import 'package:barbeer/core/constants/api_constants.dart';
import 'package:barbeer/core/network/api_client.dart';
import 'package:barbeer/features/usuarios/data/usuario_admin_repository.dart';
import 'package:barbeer/features/usuarios/presentation/widgets/pin_management_sheet.dart';
import 'package:barbeer/features/usuarios/presentation/widgets/pin_stock_adjust_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _pinStockApp(UsuarioAdminRepository repo) => MaterialApp(
      home: Scaffold(
        body: PinStockAdjustSheet(
          productId: 'prod-x',
          productName: 'Crema',
          currentStock: 5,
          sedeId: 's-1',
          isSuperAdmin: false,
          repo: repo,
          onSaved: () {},
        ),
      ),
    );

final _twoUsers = [
  {'id': 'u-1', 'username': 'alice', 'rol': 'CAJERO', 'nivelAcceso': 10},
  {'id': 'u-2', 'username': 'bob', 'rol': 'ADMIN', 'nivelAcceso': 50},
];

Future<void> _openPinSheet(WidgetTester tester) async {
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: ElevatedButton(
            key: const Key('open-pin'),
            onPressed: () => showPinManagementSheet(ctx, users: _twoUsers),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.byKey(const Key('open-pin')));
  await tester.pumpAndSettle();
}

void main() {
  // ── Scenario 36: PIN denial must not expose the secret ────────────────────

  group('Scenario 36 — PIN denial does not expose the secret', () {
    testWidgets(
        'wrong PIN error message does not contain the entered PIN digits',
        (tester) async {
      const enteredPin = '9876';
      final repo = UsuarioAdminRepository(ApiClient.instance,
          postRequest: (path, body) async {
        if (path == ApiConstants.validatePin) return {'success': false};
        throw StateError('should not reach stock endpoint');
      });
      await tester.pumpWidget(_pinStockApp(repo));
      await tester.enterText(find.byKey(const Key('stock-cantidad')), '3');
      await tester.enterText(find.byKey(const Key('stock-referencia')), 'Ref');
      await tester.enterText(find.byKey(const Key('stock-pin')), enteredPin);
      await tester.tap(find.text('Confirmar ajuste'));
      await tester.pumpAndSettle();

      // Generic "PIN incorrecto" message is shown
      expect(find.textContaining('PIN incorrecto'), findsOneWidget);
      // The actual PIN digits must NOT appear in any non-obscured Text widget
      // (the obscured PIN field may still hold the value internally, but it is
      //  never visually exposed — we verify no plain Text node leaks the digits)
      final pinInPlainText = find.byWidgetPredicate((w) =>
          w is Text && (w.data?.contains(enteredPin) ?? false));
      expect(
        pinInPlainText,
        findsNothing,
        reason: 'Error state must not leak the actual PIN value',
      );
    });
  });

  // ── Scenario 35: pin_management_sheet has 0% coverage ────────────────────

  group('Scenario 35 — PinManagementSheet coverage', () {
    testWidgets('happy path: sheet renders title and user list with roles',
        (tester) async {
      await _openPinSheet(tester);
      expect(find.text('Gestionar claves PIN'), findsOneWidget,
          reason: 'Sheet title must be visible');
      expect(find.text('alice'), findsOneWidget);
      expect(find.text('bob'), findsOneWidget);
      expect(find.text('CAJERO'), findsOneWidget);
      expect(find.text('ADMIN'), findsOneWidget);
    });

    testWidgets('search input filters the user list by username',
        (tester) async {
      await _openPinSheet(tester);
      // Both visible before search
      expect(find.text('alice'), findsOneWidget);
      expect(find.text('bob'), findsOneWidget);

      // Enter search text in the field decorated with the search icon
      final searchField = find.ancestor(
        of: find.byIcon(Icons.search),
        matching: find.byType(TextField),
      );
      await tester.enterText(searchField, 'alice');
      await tester.pump();

      // After filtering: alice appears in at least one plain Text widget
      // and bob does NOT appear in any plain Text widget.
      final aliceInList = find.byWidgetPredicate(
          (w) => w is Text && (w.data?.contains('alice') ?? false));
      final bobInList = find.byWidgetPredicate(
          (w) => w is Text && (w.data?.contains('bob') ?? false));
      expect(aliceInList, findsWidgets);
      expect(bobInList, findsNothing,
          reason: 'bob filtered out after searching for alice');
    });
  });
}
