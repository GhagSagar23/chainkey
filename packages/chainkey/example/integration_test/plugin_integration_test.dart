import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:chainkey/chainkey.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('isHardwareIsolationSupported check', (WidgetTester tester) async {
    const plugin = Chainkey();
    final isSupported = await plugin.isHardwareIsolationSupported(
      HardwareIsolationLevel.software,
    );
    expect(isSupported, isNotNull);
  });
}
