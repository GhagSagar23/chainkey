import 'package:flutter_test/flutter_test.dart';
import 'package:chainkey_android/chainkey_android.dart';
import 'package:chainkey_platform_interface/chainkey_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('can be registered as default platform instance', () {
    ChainkeyAndroid.registerWith();
    expect(ChainkeyPlatform.instance, isA<ChainkeyAndroid>());
  });
}
