import 'dart:typed_data';

/// Parsed representation of a WebAuthn authenticatorData binary buffer.
///
/// Layout (W3C §6.1):
///   [0..31]  rpIdHash    — SHA-256 of the RP ID
///   [32]     flags       — bit field (UP, UV, AT, ED, BE, BS)
///   [33..36] signCount   — big-endian uint32
///   [37..]   optional attested credential data + extensions
class AuthenticatorData {
  AuthenticatorData({
    required this.rpIdHash,
    required this.flags,
    required this.signCount,
    required this.raw,
  }) : assert(rpIdHash.length == 32, 'rpIdHash must be 32 bytes');

  /// SHA-256 hash of the Relying Party ID.
  final Uint8List rpIdHash;

  /// Raw flags byte.
  final int flags;

  /// Signature counter (big-endian uint32).
  final int signCount;

  /// The original raw authenticatorData bytes.
  final Uint8List raw;

  /// Bit 0 — User Present.
  bool get userPresent => flags & 0x01 != 0;

  /// Bit 2 — User Verified.
  bool get userVerified => flags & 0x04 != 0;

  /// Bit 3 — Backup Eligibility.
  bool get backupEligible => flags & 0x08 != 0;

  /// Bit 4 — Backup State.
  bool get backedUp => flags & 0x10 != 0;

  /// Bit 6 — Attested Credential Data included.
  bool get hasAttestedCredentialData => flags & 0x40 != 0;

  /// Bit 7 — Extension Data included.
  bool get hasExtensionData => flags & 0x80 != 0;

  /// Parses raw authenticatorData bytes (minimum 37 bytes).
  factory AuthenticatorData.parse(Uint8List data) {
    if (data.length < 37) {
      throw FormatException(
        'authenticatorData must be at least 37 bytes, got ${data.length}',
      );
    }

    final rpIdHash = Uint8List.fromList(data.sublist(0, 32));
    final flags = data[32];
    final signCount =
        (data[33] << 24) | (data[34] << 16) | (data[35] << 8) | data[36];

    return AuthenticatorData(
      rpIdHash: rpIdHash,
      flags: flags,
      signCount: signCount,
      raw: Uint8List.fromList(data),
    );
  }

  @override
  String toString() =>
      'AuthenticatorData(UP=$userPresent, UV=$userVerified, signCount=$signCount)';
}
