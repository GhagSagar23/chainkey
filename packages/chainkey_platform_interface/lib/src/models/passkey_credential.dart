import 'dart:typed_data';
import 'hardware_isolation_level.dart';
import 'p256_public_key.dart';

/// Represents a WebAuthn / Passkey credential created via OS Credential APIs.
class PasskeyCredential {
  const PasskeyCredential({
    required this.credentialId,
    required this.publicKey,
    required this.rawAttestationObject,
    required this.rawClientDataJson,
    this.isolationLevel = HardwareIsolationLevel.software,
  });

  /// Base64URL-encoded unique credential ID.
  final String credentialId;

  /// The parsed NIST P-256 public key associated with this credential.
  final P256PublicKey publicKey;

  /// Raw authenticator attestation object bytes.
  final Uint8List rawAttestationObject;

  /// Raw UTF-8 bytes of the clientDataJSON.
  final Uint8List rawClientDataJson;

  /// The hardware backing security tier.
  final HardwareIsolationLevel isolationLevel;

  Map<String, dynamic> toMap() => {
        'credentialId': credentialId,
        'publicKey': publicKey.toMap(),
        'rawAttestationObject': rawAttestationObject,
        'rawClientDataJson': rawClientDataJson,
        'isolationLevel': isolationLevel.name,
      };
}
