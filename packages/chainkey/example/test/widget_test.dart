import 'package:chainkey_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Renders app shell with loading indicator',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ChainkeyExampleApp());

    // Initial state shows loading while checking for existing key
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
