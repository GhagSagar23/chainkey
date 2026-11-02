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

    group('fromCoordinates', () {
      test('builds 0x04 || X || Y from raw coordinates', () {
        final x = Uint8List(32)..fillRange(0, 32, 0xAA);
        final y = Uint8List(32)..fillRange(0, 32, 0xBB);
        final key = P256PublicKey.fromCoordinates(x: x, y: y);

        expect(key.uncompressedBytes[0], 0x04);
        expect(key.uncompressedBytes.length, 65);
        expect(key.x, equals(x));
        expect(key.y, equals(y));
        expect(key.keyAlias, '');
        expect(key.isolationLevel, HardwareIsolationLevel.software);
      });

      test('passes through keyAlias and isolationLevel', () {
        final key = P256PublicKey.fromCoordinates(
          x: Uint8List(32),
          y: Uint8List(32),
          keyAlias: 'test',
          isolationLevel: HardwareIsolationLevel.secureEnclave,
        );
        expect(key.keyAlias, 'test');
        expect(key.isolationLevel, HardwareIsolationLevel.secureEnclave);
      });
    });

    group('isOnCurve', () {
      test('returns true for NIST P-256 generator point G', () {
        // G = (Gx, Gy) is the standard base point
        final key = P256PublicKey.fromHex(
          '046b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296'
          '4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5',
        );
        expect(key.isOnCurve, isTrue);
      });

      test('returns false for a fabricated off-curve point', () {
        // Flip one byte of Gy — almost certainly off-curve
        final key = P256PublicKey.fromHex(
          '046b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296'
          '4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f4',
        );
        expect(key.isOnCurve, isFalse);
      });

      test('returns false for zero point (0, 0)', () {
        final key = P256PublicKey.fromCoordinates(
          x: Uint8List(32),
          y: Uint8List(32),
        );
        expect(key.isOnCurve, isFalse);
      });
    });

    group('fromSpki', () {
      Uint8List hexToBytes(String hex) {
        final bytes = Uint8List(hex.length ~/ 2);
        for (var i = 0; i < bytes.length; i++) {
          bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
        }
        return bytes;
      }

      test('extracts generator point G from valid SPKI DER', () {
        final spki = hexToBytes(
          '3059301306072a8648ce3d020106082a8648ce3d030107'
          '034200046b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296'
          '4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5',
        );
        final key = P256PublicKey.fromSpki(spki, keyAlias: 'spki-test');

        expect(key.isOnCurve, isTrue);
        expect(key.keyAlias, 'spki-test');
        expect(key.uncompressedBytes[0], 0x04);

        final gKey = P256PublicKey.fromHex(
          '046b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296'
          '4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5',
        );
        expect(key.x, equals(gKey.x));
        expect(key.y, equals(gKey.y));
      });

      test('throws on missing ecPublicKey OID', () {
        // Valid structure but replace ecPublicKey OID with garbage
        final spki = hexToBytes(
          '3059301306070000000000000106082a8648ce3d030107'
          '034200046b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296'
          '4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5',
        );
        expect(
          () => P256PublicKey.fromSpki(spki),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws on missing prime256v1 OID', () {
        final spki = hexToBytes(
          '3059301306072a8648ce3d020106080000000000000000'
          '034200046b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296'
          '4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5',
        );
        expect(
          () => P256PublicKey.fromSpki(spki),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws on empty input', () {
        expect(
          () => P256PublicKey.fromSpki(Uint8List(0)),
          throwsA(isA<FormatException>()),
        );
      });
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

    group('fromDer', () {
      Uint8List buildDer(Uint8List rRaw, Uint8List sRaw) {
        // 0x30 || totalLen || 0x02 || rLen || r || 0x02 || sLen || s
        final total = 2 + rRaw.length + 2 + sRaw.length;
        final der = Uint8List(2 + total);
        der[0] = 0x30;
        der[1] = total;
        var o = 2;
        der[o++] = 0x02;
        der[o++] = rRaw.length;
        der.setRange(o, o + rRaw.length, rRaw);
        o += rRaw.length;
        der[o++] = 0x02;
        der[o++] = sRaw.length;
        der.setRange(o, o + sRaw.length, sRaw);
        return der;
      }

      test('decodes standard 32-byte integers', () {
        final r = Uint8List(32)..fillRange(0, 32, 0xAB);
        final s = Uint8List(32)..fillRange(0, 32, 0xCD);
        final der = buildDer(r, s);
        final sig = P256Signature.fromDer(der);

        expect(sig.r, equals(r));
        expect(sig.s, equals(s));
        expect(sig.rawDerSignature, equals(der));
      });

      test('strips 33-byte padded integers (leading 0x00)', () {
        // ASN.1 adds 0x00 prefix when high bit is set
        final rPadded = Uint8List(33);
        rPadded[0] = 0x00;
        rPadded.fillRange(1, 33, 0xFF);
        final sPadded = Uint8List(33);
        sPadded[0] = 0x00;
        sPadded.fillRange(1, 33, 0x80);

        final der = buildDer(rPadded, sPadded);
        final sig = P256Signature.fromDer(der);

        final expectedR = Uint8List(32)..fillRange(0, 32, 0xFF);
        final expectedS = Uint8List(32)..fillRange(0, 32, 0x80);
        expect(sig.r, equals(expectedR));
        expect(sig.s, equals(expectedS));
      });

      test('left-pads 31-byte short integers', () {
        final rShort = Uint8List(31)..fillRange(0, 31, 0x42);
        final s = Uint8List(32)..fillRange(0, 32, 0x01);

        final der = buildDer(rShort, s);
        final sig = P256Signature.fromDer(der);

        final expectedR = Uint8List(32);
        expectedR[0] = 0x00;
        expectedR.fillRange(1, 32, 0x42);
        expect(sig.r, equals(expectedR));
        expect(sig.s, equals(s));
      });

      test('handles mixed: 33-byte r + 31-byte s', () {
        final rPadded = Uint8List(33);
        rPadded[0] = 0x00;
        rPadded.fillRange(1, 33, 0xAA);

        final sShort = Uint8List(31)..fillRange(0, 31, 0xBB);

        final der = buildDer(rPadded, sShort);
        final sig = P256Signature.fromDer(der);

        final expectedR = Uint8List(32)..fillRange(0, 32, 0xAA);
        final expectedS = Uint8List(32);
        expectedS[0] = 0x00;
        expectedS.fillRange(1, 32, 0xBB);
        expect(sig.r, equals(expectedR));
        expect(sig.s, equals(expectedS));
      });

      test('throws on too-short input', () {
        expect(
          () => P256Signature.fromDer(Uint8List.fromList([0x30, 0x04, 0x02])),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws on wrong SEQUENCE tag', () {
        expect(
          () => P256Signature.fromDer(Uint8List.fromList(
              [0x31, 0x06, 0x02, 0x01, 0x01, 0x02, 0x01, 0x02])),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws on length mismatch', () {
        final der = buildDer(Uint8List(32), Uint8List(32));
        // Corrupt the total length
        der[1] = der[1] - 1;
        expect(
          () => P256Signature.fromDer(der),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws on wrong INTEGER tag', () {
        final der = buildDer(Uint8List(32), Uint8List(32));
        der[2] = 0x03; // corrupt first INTEGER tag
        expect(
          () => P256Signature.fromDer(der),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws on trailing bytes', () {
        final der = buildDer(Uint8List(32), Uint8List(32));
        // Append a trailing byte and fix outer length
        final corrupt = Uint8List(der.length + 1);
        corrupt.setRange(0, der.length, der);
        corrupt[1] = corrupt[1] + 1;
        expect(
          () => P256Signature.fromDer(corrupt),
          throwsA(isA<FormatException>()),
        );
      });

      test('decodes a real-world Secure Enclave DER signature', () {
        // Realistic DER: 0x30 0x45 (71 bytes total)
        // r: 33 bytes (0x00 padded), s: 32 bytes
        final der = Uint8List.fromList([
          0x30, 0x45,
          0x02, 0x21, 0x00, // r: 33 bytes with 0x00 pad
          ...List.filled(32, 0xDE),
          0x02, 0x20, // s: 32 bytes
          ...List.filled(32, 0xBE),
        ]);
        final sig = P256Signature.fromDer(der);
        expect(sig.r, equals(Uint8List(32)..fillRange(0, 32, 0xDE)));
        expect(sig.s, equals(Uint8List(32)..fillRange(0, 32, 0xBE)));
      });
    });

    group('normalizeToLowS', () {
      Uint8List hexToBytes(String hex) {
        final bytes = Uint8List(hex.length ~/ 2);
        for (var i = 0; i < bytes.length; i++) {
          bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
        }
        return bytes;
      }

      // n   = FFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551
      // n/2 = 7FFFFFFF800000007FFFFFFFFFFFFFFFDE737D56D38BCF4279DCE5617E3192A8
      //        (n is odd, so n/2 = floor(n/2); n = 2*(n/2) + 1)

      test('preserves already low-S signature (returns same instance)', () {
        final r = Uint8List(32)..fillRange(0, 32, 0x01);
        // s = 1 (well below n/2)
        final s = Uint8List(32)..[31] = 0x01;
        final sig = P256Signature(r: r, s: s, rawDerSignature: Uint8List(0));

        final normalized = sig.normalizeToLowS();
        expect(identical(normalized, sig), isTrue);
        expect(normalized.isLowS, isTrue);
      });

      test('preserves s exactly equal to n/2', () {
        final r = Uint8List(32)..fillRange(0, 32, 0x01);
        final s = hexToBytes(
          '7FFFFFFF800000007FFFFFFFFFFFFFFFDE737D56D38BCF4279DCE5617E3192A8',
        );
        final sig = P256Signature(r: r, s: s, rawDerSignature: Uint8List(0));

        expect(sig.isLowS, isTrue);
        final normalized = sig.normalizeToLowS();
        expect(identical(normalized, sig), isTrue);
      });

      test('normalizes s = n/2 + 1 (just above threshold)', () {
        final r = Uint8List(32)..fillRange(0, 32, 0x01);
        // s = n/2 + 1
        final s = hexToBytes(
          '7FFFFFFF800000007FFFFFFFFFFFFFFFDE737D56D38BCF4279DCE5617E3192A9',
        );
        final sig = P256Signature(r: r, s: s, rawDerSignature: Uint8List(0));

        expect(sig.isLowS, isFalse);
        final normalized = sig.normalizeToLowS();
        expect(normalized.isLowS, isTrue);
        // s' = n - (n/2 + 1) = n/2  (since n = 2*(n/2) + 1)
        expect(
          normalized.s,
          equals(hexToBytes(
            '7FFFFFFF800000007FFFFFFFFFFFFFFFDE737D56D38BCF4279DCE5617E3192A8',
          )),
        );
      });

      test('normalizes high-S = n - 1 to s = 1', () {
        final r = Uint8List(32)..fillRange(0, 32, 0xAA);
        // s = n - 1
        final s = hexToBytes(
          'FFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632550',
        );
        final sig = P256Signature(r: r, s: s, rawDerSignature: Uint8List(0));

        expect(sig.isLowS, isFalse);
        final normalized = sig.normalizeToLowS();
        expect(normalized.isLowS, isTrue);
        // n - (n-1) = 1
        final expectedS = Uint8List(32)..[31] = 0x01;
        expect(normalized.s, equals(expectedS));
      });

      test('normalized signature clears rawDerSignature', () {
        final r = Uint8List(32)..fillRange(0, 32, 0x01);
        final s = hexToBytes(
          'FFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632550',
        );
        final sig = P256Signature(
          r: r,
          s: s,
          rawDerSignature: Uint8List.fromList([0x30, 0x06]),
        );

        final normalized = sig.normalizeToLowS();
        expect(normalized.rawDerSignature.length, 0);
      });

      test('r is preserved unchanged through normalization', () {
        final r = Uint8List(32);
        for (var i = 0; i < 32; i++) {
          r[i] = i;
        }
        final s = hexToBytes(
          'FFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632550',
        );
        final sig = P256Signature(r: r, s: s, rawDerSignature: Uint8List(0));

        final normalized = sig.normalizeToLowS();
        expect(normalized.r, equals(r));
      });
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
