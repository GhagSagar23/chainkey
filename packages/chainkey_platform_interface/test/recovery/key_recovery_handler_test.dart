import 'dart:typed_data';

import 'package:chainkey_platform_interface/chainkey_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake platform that can be configured to throw on sign.
class _FakePlatform extends ChainkeyPlatform {
  bool shouldThrowInvalidated = false;
  bool deleteWasCalled = false;
  bool generateWasCalled = false;
  String? lastDeletedAlias;
  String? lastGeneratedAlias;

  final _stubKey = P256PublicKey.fromCoordinates(
    x: Uint8List(32)..[0] = 0x01,
    y: Uint8List(32)..[0] = 0x02,
    keyAlias: 'rotated',
  );

  final _stubSig = P256Signature(
    r: Uint8List(32)..[31] = 1,
    s: Uint8List(32)..[31] = 2,
    rawDerSignature: Uint8List(0),
  );

  @override
  Future<P256Signature> signWithHardwareKey({
    required String keyAlias,
    required Uint8List hash32,
    BiometricPromptOptions? promptOptions,
  }) async {
    if (shouldThrowInvalidated) {
      throw const KeyPermanentlyInvalidatedException();
    }
    return _stubSig;
  }

  @override
  Future<bool> deleteHardwareKey({required String keyAlias}) async {
    deleteWasCalled = true;
    lastDeletedAlias = keyAlias;
    return true;
  }

  @override
  Future<P256PublicKey> generateHardwareKey({
    required String keyAlias,
    bool requireUserPresence = true,
  }) async {
    generateWasCalled = true;
    lastGeneratedAlias = keyAlias;
    return _stubKey;
  }
}

void main() {
  late _FakePlatform platform;
  late List<KeyInvalidationEvent> receivedEvents;
  late KeyRecoveryHandler handler;

  setUp(() {
    platform = _FakePlatform();
    receivedEvents = [];
    handler = KeyRecoveryHandler(
      platform: platform,
      onKeyInvalidated: (event) async {
        receivedEvents.add(event);
      },
    );
  });

  group('signWithRecovery', () {
    test('returns signature when key is valid', () async {
      final sig = await handler.signWithRecovery(
        keyAlias: 'k1',
        hash32: Uint8List(32),
      );
      expect(sig, isA<P256Signature>());
      expect(receivedEvents, isEmpty);
    });

    test('fires callback and rethrows on key invalidation', () async {
      platform.shouldThrowInvalidated = true;

      expect(
        () => handler.signWithRecovery(
          keyAlias: 'k1',
          hash32: Uint8List(32),
        ),
        throwsA(isA<KeyPermanentlyInvalidatedException>()),
      );

      // Allow microtask to fire callback
      await Future<void>.delayed(Duration.zero);
      expect(receivedEvents, hasLength(1));
      expect(receivedEvents.first.keyAlias, 'k1');
      expect(
        receivedEvents.first.exception,
        isA<KeyPermanentlyInvalidatedException>(),
      );
    });

    test('does not fire callback for other exceptions', () async {
      platform = _OtherErrorPlatform();
      handler = KeyRecoveryHandler(
        platform: platform,
        onKeyInvalidated: (event) async {
          receivedEvents.add(event);
        },
      );

      expect(
        () => handler.signWithRecovery(
          keyAlias: 'k1',
          hash32: Uint8List(32),
        ),
        throwsA(isA<HardwareEnclaveException>()),
      );

      await Future<void>.delayed(Duration.zero);
      expect(receivedEvents, isEmpty);
    });

    test('passes promptOptions through', () async {
      final sig = await handler.signWithRecovery(
        keyAlias: 'k1',
        hash32: Uint8List(32),
        promptOptions: const BiometricPromptOptions(
          title: 'Sign transaction',
        ),
      );
      expect(sig, isA<P256Signature>());
    });
  });

  group('rotateKey', () {
    test('deletes old key and generates new one', () async {
      final newKey = await handler.rotateKey(keyAlias: 'k1');

      expect(platform.deleteWasCalled, isTrue);
      expect(platform.lastDeletedAlias, 'k1');
      expect(platform.generateWasCalled, isTrue);
      expect(platform.lastGeneratedAlias, 'k1');
      expect(newKey, isA<P256PublicKey>());
    });

    test('propagates delete failure', () async {
      platform = _DeleteFailsPlatform();
      handler = KeyRecoveryHandler(
        platform: platform,
        onKeyInvalidated: (_) async {},
      );

      expect(
        () => handler.rotateKey(keyAlias: 'k1'),
        throwsA(isA<HardwareEnclaveException>()),
      );
    });
  });

  group('end-to-end recovery flow', () {
    test('sign fails → callback fires → rotate succeeds', () async {
      platform.shouldThrowInvalidated = true;

      // Step 1: sign fails, callback fires
      KeyPermanentlyInvalidatedException? caught;
      try {
        await handler.signWithRecovery(
          keyAlias: 'k1',
          hash32: Uint8List(32),
        );
      } on KeyPermanentlyInvalidatedException catch (e) {
        caught = e;
      }
      expect(caught, isNotNull);
      expect(receivedEvents, hasLength(1));

      // Step 2: rotate the key
      platform.shouldThrowInvalidated = false;
      final newKey = await handler.rotateKey(keyAlias: 'k1');
      expect(newKey, isA<P256PublicKey>());
      expect(platform.deleteWasCalled, isTrue);
      expect(platform.generateWasCalled, isTrue);

      // Step 3: signing works again with new key
      final sig = await handler.signWithRecovery(
        keyAlias: 'k1',
        hash32: Uint8List(32),
      );
      expect(sig, isA<P256Signature>());
    });
  });
}

class _OtherErrorPlatform extends _FakePlatform {
  @override
  Future<P256Signature> signWithHardwareKey({
    required String keyAlias,
    required Uint8List hash32,
    BiometricPromptOptions? promptOptions,
  }) async {
    throw const HardwareEnclaveException('KeyStore corrupted');
  }
}

class _DeleteFailsPlatform extends _FakePlatform {
  @override
  Future<bool> deleteHardwareKey({required String keyAlias}) async {
    throw const HardwareEnclaveException('Cannot delete key');
  }
}
