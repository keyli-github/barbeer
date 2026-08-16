import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barbeer/core/providers/branding_provider.dart';
import 'package:barbeer/main.dart';
import 'package:barbeer/core/providers/theme_mode_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          brandingProvider.overrideWith((_) => BrandingNotifier.noop()),
        ],
        child: const BarBeerApp(),
      ),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
