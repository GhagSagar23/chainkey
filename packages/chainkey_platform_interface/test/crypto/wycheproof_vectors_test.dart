import 'dart:typed_data';
import 'package:chainkey_platform_interface/src/models/hardware_isolation_level.dart';
import 'package:chainkey_platform_interface/src/models/p256_public_key.dart';
import 'package:chainkey_platform_interface/src/models/p256_signature.dart';
import 'package:flutter_test/flutter_test.dart';

/// Comprehensive cryptographic test suite against Wycheproof-style,
/// EIP-7212, and crafted edge-case vectors for the chainkey pure-Dart
/// crypto layer.

Uint8List _hex(String hex) {
  final clean = hex.replaceAll(' ', '');
  final bytes = Uint8List(clean.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}

/// Builds a valid ASN.1 DER ECDSA signature from raw r and s byte arrays.
Uint8List _buildDer(Uint8List rRaw, Uint8List sRaw) {
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

/// DER-encodes a 32-byte integer value, adding 0x00 pad if high bit set.
Uint8List _derInt(Uint8List value) {
  if (value[0] >= 0x80) {
    final padded = Uint8List(33);
    padded[0] = 0x00;
    padded.setRange(1, 33, value);
    return padded;
  }
  // Strip leading zeros (but keep at least 1 byte)
  var start = 0;
  while (start < value.length - 1 && value[start] == 0x00) {
    start++;
  }
  return Uint8List.fromList(value.sublist(start));
}

void main() {
  // ---------------------------------------------------------------------------
  // DER Signature Parsing — Wycheproof-style vectors
  // ---------------------------------------------------------------------------
  group('DER parsing — Wycheproof vectors', () {
    test('valid: both r and s are 32 bytes, no padding needed', () {
      final r = Uint8List(32)..fillRange(0, 32, 0x42);
      final s = Uint8List(32)..fillRange(0, 32, 0x37);
      final der = _buildDer(r, s);
      final sig = P256Signature.fromDer(der);
      expect(sig.r, equals(r));
      expect(sig.s, equals(s));
      expect(sig.rawDerSignature, equals(der));
    });

    test('valid: r has 0x00 pad (33 bytes), s is 32 bytes', () {
      final r32 = Uint8List(32)..fillRange(0, 32, 0xFF);
      final s32 = Uint8List(32)..fillRange(0, 32, 0x42);
      final der = _buildDer(_derInt(r32), _derInt(s32));
      final sig = P256Signature.fromDer(der);
      expect(sig.r, equals(r32));
      expect(sig.s, equals(s32));
    });

    test('valid: both r and s are 33 bytes (0x00 padded)', () {
      final r32 = Uint8List(32)..fillRange(0, 32, 0xFF);
      final s32 = Uint8List(32)..fillRange(0, 32, 0x80);
      final der = _buildDer(_derInt(r32), _derInt(s32));
      final sig = P256Signature.fromDer(der);
      expect(sig.r, equals(r32));
      expect(sig.s, equals(s32));
    });

    test('valid: r is 1 byte (short integer, left-padded to 32)', () {
      final rShort = Uint8List.fromList([0x01]);
      final s = Uint8List(32)..fillRange(0, 32, 0xAB);
      final der = _buildDer(rShort, s);
      final sig = P256Signature.fromDer(der);
      final expectedR = Uint8List(32)..[31] = 0x01;
      expect(sig.r, equals(expectedR));
      expect(sig.s, equals(s));
    });

    test('valid: r is 31 bytes (left-padded to 32)', () {
      final rShort = Uint8List(31)..fillRange(0, 31, 0x42);
      final s = Uint8List(32)..fillRange(0, 32, 0x01);
      final der = _buildDer(rShort, s);
      final sig = P256Signature.fromDer(der);
      final expectedR = Uint8List(32);
      expectedR[0] = 0x00;
      expectedR.fillRange(1, 32, 0x42);
      expect(sig.r, equals(expectedR));
    });

    test('valid: zero-value r (single 0x00 byte)', () {
      final der = _buildDer(
        Uint8List.fromList([0x00]),
        Uint8List(32)..[31] = 0x01,
      );
      final sig = P256Signature.fromDer(der);
      expect(sig.r, equals(Uint8List(32)));
    });

    test('valid: mixed 33-byte r + 31-byte s', () {
      final r32 = Uint8List(32)..fillRange(0, 32, 0xAA);
      final sShort = Uint8List(31)..fillRange(0, 31, 0xBB);
      final der = _buildDer(_derInt(r32), sShort);
      final sig = P256Signature.fromDer(der);
      expect(sig.r, equals(r32));
      final expectedS = Uint8List(32);
      expectedS[0] = 0x00;
      expectedS.fillRange(1, 32, 0xBB);
      expect(sig.s, equals(expectedS));
    });

    // --- Invalid DER vectors ---

    test('rejects empty input', () {
      expect(
        () => P256Signature.fromDer(Uint8List(0)),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects too-short input (< 8 bytes)', () {
      expect(
        () => P256Signature.fromDer(Uint8List.fromList([0x30, 0x04, 0x02])),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects wrong SEQUENCE tag (SET 0x31)', () {
      final valid = _buildDer(Uint8List(32), Uint8List(32));
      valid[0] = 0x31;
      expect(
        () => P256Signature.fromDer(valid),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects outer length mismatch (too short)', () {
      final der = _buildDer(Uint8List(32), Uint8List(32));
      der[1] = der[1] - 1; // claims 1 byte less
      expect(
        () => P256Signature.fromDer(der),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects outer length mismatch (too long)', () {
      final der = _buildDer(Uint8List(32), Uint8List(32));
      der[1] = der[1] + 1; // claims 1 byte more
      expect(
        () => P256Signature.fromDer(der),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects wrong INTEGER tag (BIT STRING 0x03)', () {
      final der = _buildDer(Uint8List(32), Uint8List(32));
      der[2] = 0x03; // corrupt r's tag
      expect(
        () => P256Signature.fromDer(der),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects wrong second INTEGER tag', () {
      final r = Uint8List(32);
      final s = Uint8List(32);
      final der = _buildDer(r, s);
      der[2 + 2 + 32] = 0x04; // corrupt s's tag
      expect(
        () => P256Signature.fromDer(der),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects integer claiming more bytes than available', () {
      final der = _buildDer(Uint8List(32), Uint8List(32));
      der[3] = 64; // r claims 64 bytes
      expect(
        () => P256Signature.fromDer(der),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects integer > 32 bytes after stripping padding', () {
      // 34 non-zero bytes
      final bigR = Uint8List(34)..fillRange(0, 34, 0x01);
      final der = _buildDer(bigR, Uint8List(32));
      expect(
        () => P256Signature.fromDer(der),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects trailing bytes after s', () {
      final r = Uint8List(32);
      final s = Uint8List(32);
      final der = _buildDer(r, s);
      // Extend buffer by 1 byte and fix outer length
      final corrupt = Uint8List(der.length + 1);
      corrupt.setRange(0, der.length, der);
      corrupt[1] = corrupt[1] + 1; // outer length accounts for extra byte
      expect(
        () => P256Signature.fromDer(corrupt),
        throwsA(isA<FormatException>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Low-S normalization — boundary and EIP-2 vectors
  // ---------------------------------------------------------------------------
  group('Low-S normalization — EIP-2 boundary vectors', () {
    // n   = FFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551
    // n/2 = 7FFFFFFF800000007FFFFFFFFFFFFFFFDE737D56D38BCF4279DCE5617E3192A8
    final halfN = _hex(
      '7FFFFFFF800000007FFFFFFFFFFFFFFFDE737D56D38BCF4279DCE5617E3192A8',
    );
    final halfNPlus1 = _hex(
      '7FFFFFFF800000007FFFFFFFFFFFFFFFDE737D56D38BCF4279DCE5617E3192A9',
    );
    final nMinus1 = _hex(
      'FFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632550',
    );

    test('s = 1 is low-S', () {
      final sig = P256Signature(
        r: Uint8List(32),
        s: Uint8List(32)..[31] = 0x01,
        rawDerSignature: Uint8List(0),
      );
      expect(sig.isLowS, isTrue);
      expect(identical(sig.normalizeToLowS(), sig), isTrue);
    });

    test('s = n/2 is low-S (boundary)', () {
      final sig = P256Signature(
        r: Uint8List(32),
        s: halfN,
        rawDerSignature: Uint8List(0),
      );
      expect(sig.isLowS, isTrue);
    });

    test('s = n/2 + 1 is high-S', () {
      final sig = P256Signature(
        r: Uint8List(32),
        s: halfNPlus1,
        rawDerSignature: Uint8List(0),
      );
      expect(sig.isLowS, isFalse);
      final norm = sig.normalizeToLowS();
      expect(norm.isLowS, isTrue);
      // n - (n/2 + 1) = n/2 since n is odd
      expect(norm.s, equals(halfN));
    });

    test('s = n - 1 normalizes to 1', () {
      final sig = P256Signature(
        r: Uint8List(32),
        s: nMinus1,
        rawDerSignature: Uint8List(0),
      );
      expect(sig.isLowS, isFalse);
      final norm = sig.normalizeToLowS();
      expect(norm.s, equals(Uint8List(32)..[31] = 0x01));
    });

    test('double normalization is idempotent', () {
      final sig = P256Signature(
        r: Uint8List(32)..fillRange(0, 32, 0xAA),
        s: nMinus1,
        rawDerSignature: Uint8List(0),
      );
      final norm1 = sig.normalizeToLowS();
      final norm2 = norm1.normalizeToLowS();
      expect(identical(norm1, norm2), isTrue);
      expect(norm2.isLowS, isTrue);
    });

    test('normalization preserves r bytes exactly', () {
      final r = Uint8List(32);
      for (var i = 0; i < 32; i++) {
        r[i] = i;
      }
      final sig = P256Signature(
        r: r,
        s: nMinus1,
        rawDerSignature: Uint8List(0),
      );
      final norm = sig.normalizeToLowS();
      expect(norm.r, equals(r));
    });

    test('normalized signature clears rawDerSignature', () {
      final sig = P256Signature(
        r: Uint8List(32),
        s: nMinus1,
        rawDerSignature: Uint8List.fromList([0x30, 0x44]),
      );
      final norm = sig.normalizeToLowS();
      expect(norm.rawDerSignature.length, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // On-curve validation — verified P-256 points
  // ---------------------------------------------------------------------------
  group('On-curve validation — verified points', () {
    // NIST P-256 generator point G
    test('generator point G is on curve', () {
      final key = P256PublicKey.fromHex(
        '04'
        '6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296'
        '4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5',
      );
      expect(key.isOnCurve, isTrue);
    });

    // 2G — computed via point doubling
    test('2G (double of generator) is on curve', () {
      final key = P256PublicKey.fromHex(
        '04'
        '7cf27b188d034f7e8a52380304b51ac3c08969e277f21b35a60b48fc47669978'
        '07775510db8ed040293d9ac69f7430dbba7dade63ce982299e04b79d227873d1',
      );
      expect(key.isOnCurve, isTrue);
    });

    // 3G — computed via point addition G + 2G
    test('3G is on curve', () {
      final key = P256PublicKey.fromHex(
        '04'
        '5ecbe4d1a6330a44c8f7ef951d4bf165e6c6b721efada985fb41661bc6e7fd6c'
        '8734640c4998ff7e374b06ce1a64a2ecd82ab036384fb83d9a79b127a27d5032',
      );
      expect(key.isOnCurve, isTrue);
    });

    // Off-curve: G with y's last byte flipped
    test('G with y last byte -1 is off curve', () {
      final key = P256PublicKey.fromHex(
        '04'
        '6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296'
        '4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f4',
      );
      expect(key.isOnCurve, isFalse);
    });

    // Off-curve: (0, 0) — the zero point
    test('zero point (0, 0) is off curve', () {
      final key = P256PublicKey.fromCoordinates(
        x: Uint8List(32),
        y: Uint8List(32),
      );
      expect(key.isOnCurve, isFalse);
    });

    // Off-curve: x = 0, y = 1
    test('(0, 1) is off curve', () {
      final key = P256PublicKey.fromCoordinates(
        x: Uint8List(32),
        y: Uint8List(32)..[31] = 0x01,
      );
      expect(key.isOnCurve, isFalse);
    });

    // Off-curve: x = 1, y = 1
    test('(1, 1) is off curve', () {
      final key = P256PublicKey.fromCoordinates(
        x: Uint8List(32)..[31] = 0x01,
        y: Uint8List(32)..[31] = 0x01,
      );
      expect(key.isOnCurve, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // SPKI parsing — edge cases
  // ---------------------------------------------------------------------------
  group('SPKI parsing — edge cases', () {
    // Standard 91-byte SPKI for generator point G
    final validSpki = _hex(
      '3059301306072a8648ce3d020106082a8648ce3d030107'
      '034200046b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296'
      '4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5',
    );

    test('round-trips SPKI → fromCoordinates → hex', () {
      final key = P256PublicKey.fromSpki(validSpki);
      expect(key.isOnCurve, isTrue);
      expect(
        key.toHex(),
        '04'
        '6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296'
        '4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5',
      );
    });

    test('passes through keyAlias and isolationLevel', () {
      final key = P256PublicKey.fromSpki(
        validSpki,
        keyAlias: 'my-key',
        isolationLevel: HardwareIsolationLevel.strongBox,
      );
      expect(key.keyAlias, 'my-key');
      expect(key.isolationLevel, HardwareIsolationLevel.strongBox);
    });

    test('rejects corrupted ecPublicKey OID', () {
      final corrupt = Uint8List.fromList(validSpki);
      corrupt[9] = 0x00; // break OID
      expect(
        () => P256PublicKey.fromSpki(corrupt),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects corrupted prime256v1 OID', () {
      final corrupt = Uint8List.fromList(validSpki);
      corrupt[18] = 0x00; // break OID
      expect(
        () => P256PublicKey.fromSpki(corrupt),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects truncated SPKI (cut in BIT STRING)', () {
      expect(
        () => P256PublicKey.fromSpki(
          Uint8List.fromList(validSpki.sublist(0, 50)),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects empty input', () {
      expect(
        () => P256PublicKey.fromSpki(Uint8List(0)),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects random garbage bytes', () {
      expect(
        () => P256PublicKey.fromSpki(Uint8List.fromList(List.filled(91, 0xDE))),
        throwsA(isA<FormatException>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // DER → low-S end-to-end pipeline
  // ---------------------------------------------------------------------------
  group('DER → low-S end-to-end pipeline', () {
    test('fromDer + normalizeToLowS on high-S signature', () {
      final r = Uint8List(32)..fillRange(0, 32, 0xAA);
      // s = n - 1 (high-S)
      final sHigh = _hex(
        'FFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632550',
      );
      final der = _buildDer(_derInt(r), _derInt(sHigh));

      final sig = P256Signature.fromDer(der);
      expect(sig.isLowS, isFalse);

      final norm = sig.normalizeToLowS();
      expect(norm.isLowS, isTrue);
      expect(norm.r, equals(r));
      expect(norm.compactBytes.length, 64);
    });

    test('fromDer preserves already low-S without mutation', () {
      final r = Uint8List(32)..fillRange(0, 32, 0x42);
      final s = Uint8List(32)..[31] = 0x01;
      final der = _buildDer(r, s);

      final sig = P256Signature.fromDer(der);
      expect(sig.isLowS, isTrue);
      expect(identical(sig.normalizeToLowS(), sig), isTrue);
    });

    test('fromDer + normalizeToLowS + hex round-trip', () {
      final r = Uint8List(32);
      for (var i = 0; i < 32; i++) {
        r[i] = i;
      }
      final sHigh = _hex(
        'FFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632550',
      );
      final der = _buildDer(_derInt(r), _derInt(sHigh));

      final sig = P256Signature.fromDer(der);
      final norm = sig.normalizeToLowS();
      final hex = norm.toHex();
      final recovered = P256Signature.fromHex(hex);
      expect(recovered.r, equals(norm.r));
      expect(recovered.s, equals(norm.s));
      expect(recovered.isLowS, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // fromCoordinates
  // ---------------------------------------------------------------------------
  group('fromCoordinates', () {
    test('builds correct 0x04 || X || Y and validates on known point', () {
      final x = _hex(
        '6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296',
      );
      final y = _hex(
        '4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5',
      );
      final key = P256PublicKey.fromCoordinates(x: x, y: y);
      expect(key.uncompressedBytes[0], 0x04);
      expect(key.uncompressedBytes.length, 65);
      expect(key.isOnCurve, isTrue);
    });
  });
}
