import 'dart:async';

import 'package:barbeer/core/network/api_client.dart';
import 'package:barbeer/features/seguridad/presentation/screens/seguridad_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSecurityRepository extends SecuritySessionsRepository {
  _FakeSecurityRepository() : super(ApiClient.instance);

  final revokeCompleter = Completer<void>();
  var revokeCalls = 0;

  @override
  Future<List<Map<String, dynamic>>> list() async => [
    {
      'id': 'current',
      'actual': true,
      'deviceName': 'Este equipo',
      'deviceType': 'windows',
    },
    {
      'id': 'other',
      'actual': false,
      'deviceName': 'Otro equipo',
      'deviceType': 'android',
    },
  ];

  @override
  Future<void> revoke(String id) {
    revokeCalls++;
    return revokeCompleter.future;
  }
}

void main() {
  testWidgets(
    'revocar sesión muestra carga, evita doble envío y reporta error',
    (tester) async {
      final repository = _FakeSecurityRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            securitySessionsRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(home: SeguridadScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Cerrar sesión'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerrar sesión').last);
      await tester.pump();

      expect(repository.revokeCalls, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byTooltip('Cerrar sesión'), findsNothing);

      repository.revokeCompleter.completeError(Exception('fallo controlado'));
      await tester.pumpAndSettle();

      expect(repository.revokeCalls, 1);
      expect(
        find.textContaining('No se pudo cerrar la sesión'),
        findsOneWidget,
      );
      expect(find.byTooltip('Cerrar sesión'), findsOneWidget);
    },
  );
}
