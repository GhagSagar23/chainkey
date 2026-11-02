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

  /// Decodes an ASN.1 DER-encoded ECDSA signature into exact 32-byte (r, s).
  ///
  /// Handles variable-length integers: strips leading 0x00 padding and
  /// left-pads short integers to guarantee 32-byte big-endian buffers.
  factory P256Signature.fromDer(Uint8List der) {
    if (der.length < 8) {
      throw FormatException('DER signature too short: ${der.length} bytes');
    }
    if (der[0] != 0x30) {
      throw FormatException(
        'Expected SEQUENCE tag 0x30, got 0x${der[0].toRadixString(16).padLeft(2, '0')}',
      );
    }

    final totalLen = der[1];
    if (totalLen + 2 != der.length) {
      throw FormatException(
        'DER length mismatch: header says ${totalLen + 2}, got ${der.length}',
      );
    }

    var offset = 2;
    final r = _readDerInteger(der, offset);
    offset = r.nextOffset;
    final s = _readDerInteger(der, offset);

    if (s.nextOffset != der.length) {
      throw FormatException(
        'Trailing bytes after s integer at offset ${s.nextOffset}',
      );
    }

    return P256Signature(
      r: r.bytes,
      s: s.bytes,
      rawDerSignature: Uint8List.fromList(der),
    );
  }

  static ({Uint8List bytes, int nextOffset}) _readDerInteger(
    Uint8List der,
    int offset,
  ) {
    if (offset + 2 > der.length) {
      throw FormatException('Unexpected end of DER at offset $offset');
    }
    if (der[offset] != 0x02) {
      throw FormatException(
        'Expected INTEGER tag 0x02 at offset $offset, '
        'got 0x${der[offset].toRadixString(16).padLeft(2, '0')}',
      );
    }
    final len = der[offset + 1];
    final valueStart = offset + 2;
    final valueEnd = valueStart + len;
    if (valueEnd > der.length) {
      throw FormatException(
        'INTEGER at offset $offset claims $len bytes but only '
        '${der.length - valueStart} remain',
      );
    }

    // Strip leading zero padding, then left-pad to exactly 32 bytes.
    var start = valueStart;
    while (start < valueEnd && der[start] == 0x00) {
      start++;
    }
    final stripped = valueEnd - start;
    if (stripped > 32) {
      throw FormatException(
        'INTEGER value is $stripped bytes after stripping padding; max 32',
      );
    }
    final result = Uint8List(32);
    result.setRange(32 - stripped, 32, der, start);
    return (bytes: result, nextOffset: valueEnd);
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

  // NIST P-256 curve order n.
  static final BigInt _n = BigInt.parse(
    'FFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551',
    radix: 16,
  );

  // n/2 — threshold for low-S check.
  static final BigInt _halfN = _n >> 1;

  static BigInt _bytesToBigInt(Uint8List bytes) {
    var result = BigInt.zero;
    for (final b in bytes) {
      result = (result << 8) | BigInt.from(b);
    }
    return result;
  }

  static Uint8List _bigIntToBytes32(BigInt value) {
    final result = Uint8List(32);
    var v = value;
    for (var i = 31; i >= 0; i--) {
      result[i] = (v & BigInt.from(0xFF)).toInt();
      v >>= 8;
    }
    return result;
  }

  /// Whether this signature's `s` value is already in low-S form (s <= n/2).
  bool get isLowS => _bytesToBigInt(s) <= _halfN;

  /// Returns a new signature with `s` normalized to low-S per BIP-62 / EIP-2.
  ///
  /// If `s > n/2`, returns a copy with `s' = n - s`. Already-valid signatures
  /// are returned unchanged (same instance).
  P256Signature normalizeToLowS() {
    final sBig = _bytesToBigInt(s);
    if (sBig <= _halfN) return this;
    return P256Signature(
      r: Uint8List.fromList(r),
      s: _bigIntToBytes32(_n - sBig),
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
