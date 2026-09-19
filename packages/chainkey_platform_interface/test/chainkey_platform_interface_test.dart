import 'package:flutter/services.dart';
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

  group('MethodChannelChainkey exception handling', () {
    late MethodChannelChainkey channel;

    setUp(() {
      channel = MethodChannelChainkey();
    });

    test(
        'rethrows PlatformException as typed ChainkeyException on generateHardwareKey',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel.methodChannel, (call) async {
        if (call.method == 'generateHardwareKey') {
          throw PlatformException(
            code: 'KEY_PERMANENTLY_INVALIDATED',
            message: 'Biometric enrollment invalidated key',
          );
        }
        return null;
      });

      expect(
        () => channel.generateHardwareKey(keyAlias: 'test'),
        throwsA(isA<KeyPermanentlyInvalidatedException>()),
      );
    });

    test(
        'rethrows PlatformException as typed ChainkeyException on signWithHardwareKey',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel.methodChannel, (call) async {
        if (call.method == 'signWithHardwareKey') {
          throw PlatformException(
            code: 'LAErrorUserCancel',
            message: 'User cancelled biometric prompt',
          );
        }
        return null;
      });

      expect(
        () => channel.signWithHardwareKey(
          keyAlias: 'test',
          hash32: Uint8List(32),
        ),
        throwsA(isA<UserCancelledException>()),
      );
    });

    test(
        'rethrows PlatformException as typed ChainkeyException on deleteHardwareKey',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel.methodChannel, (call) async {
        if (call.method == 'deleteHardwareKey') {
          throw PlatformException(
            code: 'KEY_NOT_FOUND',
            message: 'Key does not exist in enclave',
          );
        }
        return null;
      });

      expect(
        () => channel.deleteHardwareKey(keyAlias: 'test'),
        throwsA(isA<HardwareEnclaveException>()),
      );
    });

    test(
        'rethrows PlatformException as typed ChainkeyException on isHardwareIsolationSupported',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel.methodChannel, (call) async {
        if (call.method == 'isHardwareIsolationSupported') {
          throw PlatformException(
            code: 'BIOMETRICS_UNAVAILABLE',
            message: 'Sensor not present',
          );
        }
        return null;
      });

      expect(
        () => channel
            .isHardwareIsolationSupported(HardwareIsolationLevel.strongBox),
        throwsA(isA<BiometricsUnavailableException>()),
      );
    });
  });
}
