import 'package:flutter_test/flutter_test.dart';
import 'package:chainkey_ios/chainkey_ios.dart';
import 'package:chainkey_platform_interface/chainkey_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('can be registered as default platform instance', () {
    ChainkeyIos.registerWith();
    expect(ChainkeyPlatform.instance, isA<ChainkeyIos>());
  });
}
