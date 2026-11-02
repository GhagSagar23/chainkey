import 'dart:typed_data';
import 'hardware_isolation_level.dart';

/// Represents a NIST P-256 (secp256r1) public key.
class P256PublicKey {
  P256PublicKey({
    required this.keyAlias,
    required this.x,
    required this.y,
    required this.uncompressedBytes,
    required this.isolationLevel,
  })  : assert(x.length == 32, 'X coordinate must be exactly 32 bytes'),
        assert(y.length == 32, 'Y coordinate must be exactly 32 bytes'),
        assert(
          uncompressedBytes.length == 65,
          'Uncompressed public key must be exactly 65 bytes',
        ),
        assert(
          uncompressedBytes[0] == 0x04,
          'Uncompressed public key must start with 0x04',
        );

  /// The unique alias or identifier of the key stored in the hardware enclave.
  final String keyAlias;

  /// 32-byte big-endian X coordinate of the elliptic curve point.
  final Uint8List x;

  /// 32-byte big-endian Y coordinate of the elliptic curve point.
  final Uint8List y;

  /// 65-byte uncompressed SEC1 encoded public key point: `0x04 || X (32B) || Y (32B)`.
  final Uint8List uncompressedBytes;

  /// The hardware isolation tier where the private key is held.
  final HardwareIsolationLevel isolationLevel;

  Map<String, dynamic> toMap() => {
        'keyAlias': keyAlias,
        'x': x,
        'y': y,
        'uncompressedBytes': uncompressedBytes,
        'isolationLevel': isolationLevel.name,
      };

  factory P256PublicKey.fromMap(Map<String, dynamic> map) {
    return P256PublicKey(
      keyAlias: map['keyAlias'] as String,
      x: map['x'] as Uint8List,
      y: map['y'] as Uint8List,
      uncompressedBytes: map['uncompressedBytes'] as Uint8List,
      isolationLevel: HardwareIsolationLevel.values.firstWhere(
        (e) => e.name == map['isolationLevel'],
        orElse: () => HardwareIsolationLevel.software,
      ),
    );
  }

  // NIST P-256 curve parameters for on-curve validation.
  static final BigInt _p = BigInt.parse(
    'FFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF',
    radix: 16,
  );
  static final BigInt _b = BigInt.parse(
    '5AC635D8AA3A93E7B3EBBD55769886BC651D06B0CC53B0F63BCE3C3E27D2604B',
    radix: 16,
  );
  static final BigInt _a = _p - BigInt.from(3); // a = -3 mod p

  static BigInt _bytesToBigInt(Uint8List bytes) {
    var result = BigInt.zero;
    for (final b in bytes) {
      result = (result << 8) | BigInt.from(b);
    }
    return result;
  }

  /// Whether this point lies on the NIST P-256 curve: y² ≡ x³ + ax + b (mod p).
  bool get isOnCurve {
    final xBig = _bytesToBigInt(x);
    final yBig = _bytesToBigInt(y);
    final lhs = (yBig * yBig) % _p;
    final rhs = (xBig.modPow(BigInt.from(3), _p) + _a * xBig + _b) % _p;
    return lhs == rhs;
  }

  /// Constructs a P256PublicKey from raw 32-byte x and y coordinates.
  factory P256PublicKey.fromCoordinates({
    required Uint8List x,
    required Uint8List y,
    String keyAlias = '',
    HardwareIsolationLevel isolationLevel = HardwareIsolationLevel.software,
  }) {
    final uncompressed = Uint8List(65);
    uncompressed[0] = 0x04;
    uncompressed.setRange(1, 33, x);
    uncompressed.setRange(33, 65, y);
    return P256PublicKey(
      keyAlias: keyAlias,
      x: Uint8List.fromList(x),
      y: Uint8List.fromList(y),
      uncompressedBytes: uncompressed,
      isolationLevel: isolationLevel,
    );
  }

  /// Extracts the public key from an X.509 SubjectPublicKeyInfo (SPKI) DER structure.
  ///
  /// SPKI layout: SEQUENCE { SEQUENCE { OID(ecPublicKey) OID(prime256v1) } BIT STRING { 0x04||X||Y } }
  /// The ecPublicKey OID is 1.2.840.10045.2.1 and prime256v1 is 1.2.840.10045.3.1.7.
  factory P256PublicKey.fromSpki(
    Uint8List spki, {
    String keyAlias = '',
    HardwareIsolationLevel isolationLevel = HardwareIsolationLevel.software,
  }) {
    // Strategy: scan for the 65-byte uncompressed point (0x04 prefix) inside
    // the BIT STRING. We validate the SPKI OIDs for safety.

    // ecPublicKey OID: 06 07 2A 86 48 CE 3D 02 01
    const ecPubKeyOid = [0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01];
    // prime256v1 OID: 06 08 2A 86 48 CE 3D 03 01 07
    const p256Oid = [
      0x06,
      0x08,
      0x2A,
      0x86,
      0x48,
      0xCE,
      0x3D,
      0x03,
      0x01,
      0x07
    ];

    if (!_containsSequence(spki, ecPubKeyOid)) {
      throw FormatException('SPKI missing ecPublicKey OID (1.2.840.10045.2.1)');
    }
    if (!_containsSequence(spki, p256Oid)) {
      throw FormatException(
          'SPKI missing prime256v1 OID (1.2.840.10045.3.1.7)');
    }

    // Find BIT STRING tag (0x03) followed by length and 0x00 padding byte,
    // then 0x04 (uncompressed point marker).
    for (var i = 0; i < spki.length - 67; i++) {
      if (spki[i] == 0x03) {
        final len = spki[i + 1];
        // BIT STRING content: 1 byte padding (0x00) + 65 bytes point = 66
        if (len == 66 && spki[i + 2] == 0x00 && spki[i + 3] == 0x04) {
          final pointStart = i + 3;
          return P256PublicKey.fromCoordinates(
            x: Uint8List.fromList(
                spki.sublist(pointStart + 1, pointStart + 33)),
            y: Uint8List.fromList(
                spki.sublist(pointStart + 33, pointStart + 65)),
            keyAlias: keyAlias,
            isolationLevel: isolationLevel,
          );
        }
      }
    }
    throw FormatException(
        'No uncompressed P-256 point found in SPKI structure');
  }

  static bool _containsSequence(Uint8List haystack, List<int> needle) {
    outer:
    for (var i = 0; i <= haystack.length - needle.length; i++) {
      for (var j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) continue outer;
      }
      return true;
    }
    return false;
  }

  /// Reconstructs a P256PublicKey from a hex string representing the 65-byte uncompressed public key.
  /// The hex string may optionally start with '0x'.
  factory P256PublicKey.fromHex(
    String hexString, {
    String keyAlias = '',
    HardwareIsolationLevel isolationLevel = HardwareIsolationLevel.software,
  }) {
    final cleanHex =
        hexString.startsWith('0x') ? hexString.substring(2) : hexString;
    if (cleanHex.length != 130) {
      throw ArgumentError(
        'Hex string must represent exactly 65 bytes (130 characters)',
      );
    }

    final uncompressedBytes = Uint8List(65);
    for (var i = 0; i < 65; i++) {
      uncompressedBytes[i] = int.parse(
        cleanHex.substring(i * 2, i * 2 + 2),
        radix: 16,
      );
    }

    final x = Uint8List.view(uncompressedBytes.buffer, 1, 32);
    final y = Uint8List.view(uncompressedBytes.buffer, 33, 32);

    return P256PublicKey(
      keyAlias: keyAlias,
      x: Uint8List.fromList(x),
      y: Uint8List.fromList(y),
      uncompressedBytes: uncompressedBytes,
      isolationLevel: isolationLevel,
    );
  }

  /// Returns a standard lowercase hex string (without 0x) of the uncompressed public key.
  String toHex() {
    return uncompressedBytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// Returns a standard lowercase hex string (without 0x) of the uncompressed public key.
  String get uncompressedHex => toHex();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is P256PublicKey &&
          runtimeType == other.runtimeType &&
          keyAlias == other.keyAlias &&
          _listEquals(x, other.x) &&
          _listEquals(y, other.y) &&
          _listEquals(uncompressedBytes, other.uncompressedBytes) &&
          isolationLevel == other.isolationLevel;

  @override
  int get hashCode =>
      keyAlias.hashCode ^
      _listHash(x) ^
      _listHash(y) ^
      _listHash(uncompressedBytes) ^
      isolationLevel.hashCode;

  @override
  String toString() {
    return 'P256PublicKey(keyAlias: $keyAlias, isolationLevel: $isolationLevel, uncompressedHex: ${toHex()})';
  }

  bool _listEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  int _listHash(Uint8List list) {
    return list.fold(0, (hash, value) => hash ^ value.hashCode);
  }
}
