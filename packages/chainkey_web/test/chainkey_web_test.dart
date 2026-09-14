import 'package:flutter_test/flutter_test.dart';
import 'package:chainkey_platform_interface/chainkey_platform_interface.dart';
import 'package:chainkey_web/chainkey_web.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('isHardwareIsolationSupported returns true only for software tier',
      () async {
    final webPlugin = ChainkeyWeb();
    expect(
      await webPlugin
          .isHardwareIsolationSupported(HardwareIsolationLevel.software),
      isTrue,
    );
    expect(
      await webPlugin
          .isHardwareIsolationSupported(HardwareIsolationLevel.secureEnclave),
      isFalse,
    );
    expect(
      await webPlugin
          .isHardwareIsolationSupported(HardwareIsolationLevel.strongBox),
      isFalse,
    );
  });
}
