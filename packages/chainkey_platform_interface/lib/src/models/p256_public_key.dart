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
