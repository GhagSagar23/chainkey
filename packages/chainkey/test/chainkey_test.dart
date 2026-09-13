import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:chainkey/chainkey.dart';
import 'package:chainkey_platform_interface/chainkey_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockChainkeyPlatform
    with MockPlatformInterfaceMixin
    implements ChainkeyPlatform {
  @override
  Future<P256PublicKey> generateHardwareKey({
    required String keyAlias,
    bool requireUserPresence = true,
  }) async {
    return P256PublicKey(
      keyAlias: keyAlias,
      x: Uint8List(32),
      y: Uint8List(32),
      uncompressedBytes: Uint8List(65),
      isolationLevel: HardwareIsolationLevel.secureEnclave,
    );
  }

  @override
  Future<P256Signature> signWithHardwareKey({
    required String keyAlias,
    required Uint8List hash32,
    BiometricPromptOptions? promptOptions,
  }) async {
    return P256Signature(
      r: Uint8List(32),
      s: Uint8List(32),
      rawDerSignature: Uint8List(70),
    );
  }

  @override
  Future<bool> deleteHardwareKey({required String keyAlias}) async => true;

  @override
  Future<bool> isHardwareIsolationSupported(
    HardwareIsolationLevel level,
  ) async =>
      level == HardwareIsolationLevel.secureEnclave;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Chainkey app-facing API', () {
    late Chainkey chainkey;
    late MockChainkeyPlatform mockPlatform;

    setUp(() {
      chainkey = const Chainkey();
      mockPlatform = MockChainkeyPlatform();
      ChainkeyPlatform.instance = mockPlatform;
    });

    test('generateHardwareKey delegates to platform interface', () async {
      final key = await chainkey.generateHardwareKey(keyAlias: 'test_key');
      expect(key.keyAlias, 'test_key');
      expect(key.isolationLevel, HardwareIsolationLevel.secureEnclave);
    });

    test('signWithHardwareKey rejects hashes not exactly 32 bytes', () async {
      expect(
        () => chainkey.signWithHardwareKey(
          keyAlias: 'test_key',
          hash32: Uint8List(31), // Invalid length
        ),
        throwsArgumentError,
      );
      expect(
        () => chainkey.signWithHardwareKey(
          keyAlias: 'test_key',
          hash32: Uint8List(33), // Invalid length
        ),
        throwsArgumentError,
      );
    });

    test('signWithHardwareKey delegates valid 32-byte hash', () async {
      final signature = await chainkey.signWithHardwareKey(
        keyAlias: 'test_key',
        hash32: Uint8List(32),
      );
      expect(signature.r.length, 32);
      expect(signature.s.length, 32);
      expect(signature.compactBytes.length, 64);
    });

    test('deleteHardwareKey delegates to platform interface', () async {
      final result = await chainkey.deleteHardwareKey(keyAlias: 'test_key');
      expect(result, isTrue);
    });

    test('isHardwareIsolationSupported delegates to platform interface',
        () async {
      expect(
        await chainkey
            .isHardwareIsolationSupported(HardwareIsolationLevel.secureEnclave),
        isTrue,
      );
      expect(
        await chainkey
            .isHardwareIsolationSupported(HardwareIsolationLevel.strongBox),
        isFalse,
      );
    });
  });
}
