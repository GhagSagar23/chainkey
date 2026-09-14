import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:chainkey_platform_interface/chainkey_platform_interface.dart';

class ImplementsChainkeyPlatform implements ChainkeyPlatform {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ExtendsChainkeyPlatform extends ChainkeyPlatform {
  @override
  Future<bool> deleteHardwareKey({required String keyAlias}) async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChainkeyPlatform', () {
    test('default instance is MethodChannelChainkey', () {
      expect(ChainkeyPlatform.instance, isA<MethodChannelChainkey>());
    });

    test('cannot be implemented directly without extending PlatformInterface',
        () {
      expect(
        () {
          ChainkeyPlatform.instance = ImplementsChainkeyPlatform();
        },
        throwsA(isA<AssertionError>()),
      );
    });

    test('can be extended with custom subclass', () {
      final mock = ExtendsChainkeyPlatform();
      ChainkeyPlatform.instance = mock;
      expect(ChainkeyPlatform.instance, equals(mock));
    });

    test('default methods throw UnimplementedError when not overridden', () {
      final mock = ExtendsChainkeyPlatform();
      expect(
        () => mock.generateHardwareKey(keyAlias: 'test'),
        throwsUnimplementedError,
      );
      expect(
        () => mock.signWithHardwareKey(
          keyAlias: 'test',
          hash32: Uint8List(32),
        ),
        throwsUnimplementedError,
      );
      expect(
        () => mock
            .isHardwareIsolationSupported(HardwareIsolationLevel.secureEnclave),
        throwsUnimplementedError,
      );
    });
  });
}
