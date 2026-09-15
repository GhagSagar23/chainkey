import 'dart:typed_data';
import 'hardware_isolation_level.dart';
import 'p256_public_key.dart';

/// Represents a WebAuthn / Passkey credential created via OS Credential APIs.
class PasskeyCredential {
  PasskeyCredential({
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PasskeyCredential &&
          runtimeType == other.runtimeType &&
          credentialId == other.credentialId &&
          publicKey == other.publicKey &&
          _listEquals(rawAttestationObject, other.rawAttestationObject) &&
          _listEquals(rawClientDataJson, other.rawClientDataJson) &&
          isolationLevel == other.isolationLevel;

  @override
  int get hashCode =>
      credentialId.hashCode ^
      publicKey.hashCode ^
      _listHash(rawAttestationObject) ^
      _listHash(rawClientDataJson) ^
      isolationLevel.hashCode;

  @override
  String toString() {
    return 'PasskeyCredential(credentialId: $credentialId, isolationLevel: $isolationLevel)';
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
