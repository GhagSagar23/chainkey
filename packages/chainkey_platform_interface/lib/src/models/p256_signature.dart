import 'dart:typed_data';

/// Represents a normalized NIST P-256 (secp256r1) signature tuple (r, s).
class P256Signature {
  const P256Signature({
    required this.r,
    required this.s,
    required this.rawDerSignature,
  });

  /// 32-byte big-endian `r` scalar.
  final Uint8List r;

  /// 32-byte big-endian `s` scalar (normalized to low-S per BIP-62/EIP-2).
  final Uint8List s;

  /// Original ASN.1 DER encoded signature output by the hardware enclave.
  final Uint8List rawDerSignature;

  /// Combined 64-byte IEEE P1363 signature `(r || s)`.
  Uint8List get compactBytes {
    final bytes = Uint8List(64);
    bytes.setRange(0, 32, r);
    bytes.setRange(32, 64, s);
    return bytes;
  }

  /// Compact 64-byte signature formatted as a 0x-prefixed hex string.
  String get compactHex =>
      '0x${compactBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';

  Map<String, dynamic> toMap() => {
        'r': r,
        's': s,
        'rawDerSignature': rawDerSignature,
      };

  factory P256Signature.fromMap(Map<String, dynamic> map) {
    return P256Signature(
      r: map['r'] as Uint8List,
      s: map['s'] as Uint8List,
      rawDerSignature: map['rawDerSignature'] as Uint8List,
    );
  }
}
