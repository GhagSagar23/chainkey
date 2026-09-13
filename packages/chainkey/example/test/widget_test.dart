import 'package:flutter_test/flutter_test.dart';
import 'package:chainkey_example/main.dart';

void main() {
  testWidgets('Renders Chainkey HomeScreen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ChainkeyExampleApp());

    // Verify that the title and key buttons are rendered.
    expect(find.text('chainkey Web3 Hardware Signer'), findsOneWidget);
    expect(find.text('Generate Enclave Key'), findsOneWidget);
    expect(find.text('Sign 32B Hash'), findsOneWidget);
  });
}
