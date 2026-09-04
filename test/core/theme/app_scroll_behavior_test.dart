import 'package:barbeer/core/theme/app_scroll_behavior.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('desktop scrolling does not force visible scrollbar chrome', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const AppScrollBehavior(),
        theme: ThemeData(platform: TargetPlatform.windows),
        home: ListView.builder(
          itemCount: 40,
          itemBuilder: (_, index) =>
              SizedBox(height: 40, child: Text('Item $index')),
        ),
      ),
    );

    expect(find.byType(Scrollbar), findsNothing);
    expect(find.byType(RawScrollbar), findsNothing);
  });
}
