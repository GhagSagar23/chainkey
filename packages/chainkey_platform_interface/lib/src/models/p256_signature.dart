import 'dart:typed_data';

/// Represents a normalized NIST P-256 (secp256r1) signature tuple (r, s).
class P256Signature {
  P256Signature({
    required this.r,
    required this.s,
    required this.rawDerSignature,
  })  : assert(r.length == 32, 'r scalar must be exactly 32 bytes'),
        assert(s.length == 32, 's scalar must be exactly 32 bytes');

  /// 32-byte big-endian `r` scalar.
  final Uint8List r;

  /// 32-byte big-endian `s` scalar (normalized to low-S per BIP-62/EIP-2).
  final Uint8List s;

  /// Original ASN.1 DER encoded signature output by the hardware enclave.
  final Uint8List rawDerSignature;

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

  /// Reconstructs a P256Signature from a 64-byte compact hex string `(r || s)`.
  /// The hex string may optionally start with '0x'.
  /// Note: `rawDerSignature` is constructed as an empty list since it cannot be fully recovered from a compact hex.
  factory P256Signature.fromHex(String hexString) {
    final cleanHex =
        hexString.startsWith('0x') ? hexString.substring(2) : hexString;
    if (cleanHex.length != 128) {
      throw ArgumentError(
        'Hex string must represent exactly 64 bytes (128 characters)',
      );
    }

    final compactBytes = Uint8List(64);
    for (var i = 0; i < 64; i++) {
      compactBytes[i] = int.parse(
        cleanHex.substring(i * 2, i * 2 + 2),
        radix: 16,
      );
    }

    final r = Uint8List.view(compactBytes.buffer, 0, 32);
    final s = Uint8List.view(compactBytes.buffer, 32, 32);

    return P256Signature(
      r: Uint8List.fromList(r),
      s: Uint8List.fromList(s),
      rawDerSignature: Uint8List(0),
    );
  }

  /// Returns the 64-byte compact signature `(r || s)`.
  Uint8List get compactBytes {
    final compact = Uint8List(64);
    compact.setRange(0, 32, r);
    compact.setRange(32, 64, s);
    return compact;
  }

  /// Returns a standard lowercase hex string (without 0x) of the compact 64-byte signature `(r || s)`.
  String toHex() {
    return compactBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Returns a standard lowercase hex string (without 0x) of the compact 64-byte signature `(r || s)`.
  String get compactHex => toHex();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is P256Signature &&
          runtimeType == other.runtimeType &&
          _listEquals(r, other.r) &&
          _listEquals(s, other.s) &&
          _listEquals(rawDerSignature, other.rawDerSignature);

  @override
  int get hashCode => _listHash(r) ^ _listHash(s) ^ _listHash(rawDerSignature);

  @override
  String toString() {
    return 'P256Signature(compactHex: ${toHex()})';
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
