import 'dart:typed_data';
import 'hardware_isolation_level.dart';

/// Represents a NIST P-256 (secp256r1) public key.
class P256PublicKey {
  const P256PublicKey({
    required this.keyAlias,
    required this.x,
    required this.y,
    required this.uncompressedBytes,
    required this.isolationLevel,
  });

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

  /// Uncompressed public key formatted as a 0x-prefixed hex string.
  String get uncompressedHex =>
      '0x${uncompressedBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';

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
}
