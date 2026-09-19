import 'dart:typed_data';
import 'package:chainkey_platform_interface/src/models/p256_public_key.dart';
import 'package:chainkey_platform_interface/src/models/p256_signature.dart';
import 'package:chainkey_platform_interface/src/models/passkey_credential.dart';
import 'package:chainkey_platform_interface/src/models/biometric_prompt_options.dart';
import 'package:chainkey_platform_interface/src/models/hardware_isolation_level.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P256PublicKey', () {
    test('Constructor validates lengths', () {
      final validX = Uint8List(32);
      final validY = Uint8List(32);
      final validUncompressed = Uint8List(65)..[0] = 0x04;

      expect(
        () => P256PublicKey(
          keyAlias: 'alias',
          x: validX,
          y: validY,
          uncompressedBytes: validUncompressed,
          isolationLevel: HardwareIsolationLevel.software,
        ),
        returnsNormally,
      );

      // Invalid X
      expect(
        () => P256PublicKey(
          keyAlias: 'alias',
          x: Uint8List(31),
          y: validY,
          uncompressedBytes: validUncompressed,
          isolationLevel: HardwareIsolationLevel.software,
        ),
        throwsA(isA<AssertionError>()),
      );

      // Invalid uncompressedBytes length
      expect(
        () => P256PublicKey(
          keyAlias: 'alias',
          x: validX,
          y: validY,
          uncompressedBytes: Uint8List(64),
          isolationLevel: HardwareIsolationLevel.software,
        ),
        throwsA(isA<AssertionError>()),
      );

      // Invalid uncompressedBytes starting byte
      expect(
        () => P256PublicKey(
          keyAlias: 'alias',
          x: validX,
          y: validY,
          uncompressedBytes: Uint8List(65)..[0] = 0x05,
          isolationLevel: HardwareIsolationLevel.software,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('Hex encoding and decoding', () {
      final pubBytes = Uint8List(65);
      pubBytes[0] = 0x04;
      for (int i = 1; i < 65; i++) {
        pubBytes[i] = i;
      }

      final pubKey = P256PublicKey(
        keyAlias: 'test_alias',
        x: Uint8List.view(pubBytes.buffer, 1, 32),
        y: Uint8List.view(pubBytes.buffer, 33, 32),
        uncompressedBytes: pubBytes,
        isolationLevel: HardwareIsolationLevel.tee,
      );

      final hex = pubKey.toHex();
      expect(hex.length, 130);
      expect(hex.startsWith('04'), isTrue);

      final decoded = P256PublicKey.fromHex(hex,
          keyAlias: 'test_alias', isolationLevel: HardwareIsolationLevel.tee);

      expect(decoded, equals(pubKey));

      // With 0x prefix
      final decodedWithPrefix = P256PublicKey.fromHex('0x$hex',
          keyAlias: 'test_alias', isolationLevel: HardwareIsolationLevel.tee);
      expect(decodedWithPrefix, equals(pubKey));
    });

    test('Equality and HashCode', () {
      final validX = Uint8List(32);
      final validY = Uint8List(32);
      final validUncompressed = Uint8List(65)..[0] = 0x04;

      final key1 = P256PublicKey(
          keyAlias: 'alias',
          x: validX,
          y: validY,
          uncompressedBytes: validUncompressed,
          isolationLevel: HardwareIsolationLevel.software);

      final key2 = P256PublicKey(
          keyAlias: 'alias',
          x: validX,
          y: validY,
          uncompressedBytes: validUncompressed,
          isolationLevel: HardwareIsolationLevel.software);

      expect(key1, equals(key2));
      expect(key1.hashCode, equals(key2.hashCode));
    });
  });

  group('P256Signature', () {
    test('Constructor validates lengths', () {
      final validR = Uint8List(32);
      final validS = Uint8List(32);

      expect(
        () =>
            P256Signature(r: validR, s: validS, rawDerSignature: Uint8List(0)),
        returnsNormally,
      );

      expect(
        () => P256Signature(
            r: Uint8List(31), s: validS, rawDerSignature: Uint8List(0)),
        throwsA(isA<AssertionError>()),
      );
    });

    test('Hex encoding and decoding', () {
      final r = Uint8List(32)..fillRange(0, 32, 1);
      final s = Uint8List(32)..fillRange(0, 32, 2);
      final sig = P256Signature(r: r, s: s, rawDerSignature: Uint8List(0));

      final hex = sig.toHex();
      expect(hex.length, 128);

      final decoded = P256Signature.fromHex(hex);
      expect(decoded, equals(sig));

      final decodedWithPrefix = P256Signature.fromHex('0x$hex');
      expect(decodedWithPrefix, equals(sig));
    });

    test('Equality and HashCode', () {
      final validR = Uint8List(32);
      final validS = Uint8List(32);

      final sig1 =
          P256Signature(r: validR, s: validS, rawDerSignature: Uint8List(0));
      final sig2 =
          P256Signature(r: validR, s: validS, rawDerSignature: Uint8List(0));

      expect(sig1, equals(sig2));
      expect(sig1.hashCode, equals(sig2.hashCode));
    });
  });

  group('PasskeyCredential', () {
    test('Equality and HashCode', () {
      final pubBytes = Uint8List(65)..[0] = 0x04;
      final pubKey = P256PublicKey(
          keyAlias: 'alias',
          x: Uint8List(32),
          y: Uint8List(32),
          uncompressedBytes: pubBytes,
          isolationLevel: HardwareIsolationLevel.software);

      final cred1 = PasskeyCredential(
        credentialId: 'id123',
        publicKey: pubKey,
        rawAttestationObject: Uint8List.fromList([1, 2, 3]),
        rawClientDataJson: Uint8List.fromList([4, 5, 6]),
        isolationLevel: HardwareIsolationLevel.software,
      );

      final cred2 = PasskeyCredential(
        credentialId: 'id123',
        publicKey: pubKey,
        rawAttestationObject: Uint8List.fromList([1, 2, 3]),
        rawClientDataJson: Uint8List.fromList([4, 5, 6]),
        isolationLevel: HardwareIsolationLevel.software,
      );

      expect(cred1, equals(cred2));
      expect(cred1.hashCode, equals(cred2.hashCode));
    });
  });

  group('BiometricPromptOptions', () {
    test('Equality and HashCode', () {
      final opt1 = BiometricPromptOptions(
          title: 'Title',
          subtitle: 'Sub',
          description: 'Desc',
          negativeButtonText: 'Cancel',
          confirmationRequired: true);
      final opt2 = BiometricPromptOptions(
          title: 'Title',
          subtitle: 'Sub',
          description: 'Desc',
          negativeButtonText: 'Cancel',
          confirmationRequired: true);

      expect(opt1, equals(opt2));
      expect(opt1.hashCode, equals(opt2.hashCode));
    });
  });
}
