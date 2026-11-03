import 'dart:typed_data';
import 'p256_signature.dart';

/// Result of a WebAuthn / Passkey assertion (authentication / signing).
class PasskeyAssertionResult {
  PasskeyAssertionResult({
    required this.credentialId,
    required this.authenticatorData,
    required this.clientDataJson,
    required this.signature,
    this.userHandle,
  });

  /// Base64URL-encoded credential ID that signed the assertion.
  final String credentialId;

  /// Raw authenticator data bytes containing RP ID hash, flags, and sign counter.
  final Uint8List authenticatorData;

  /// Raw UTF-8 bytes of clientDataJSON.
  final Uint8List clientDataJson;

  /// DER signature with pre-unpacked (r, s) scalars.
  final P256Signature signature;

  /// Optional user handle returned by the authenticator.
  final Uint8List? userHandle;

  factory PasskeyAssertionResult.fromMap(Map<String, dynamic> map) {
    final rawSig = map['signature'];
    final sigMap = rawSig is Map<String, dynamic>
        ? rawSig
        : Map<String, dynamic>.from(rawSig as Map);
    return PasskeyAssertionResult(
      credentialId: map['credentialId'] as String,
      authenticatorData: map['authenticatorData'] as Uint8List,
      clientDataJson: map['clientDataJson'] as Uint8List,
      signature: P256Signature.fromMap(sigMap),
      userHandle: map['userHandle'] as Uint8List?,
    );
  }

  Map<String, dynamic> toMap() => {
        'credentialId': credentialId,
        'authenticatorData': authenticatorData,
        'clientDataJson': clientDataJson,
        'signature': signature.toMap(),
        'userHandle': userHandle,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PasskeyAssertionResult &&
          runtimeType == other.runtimeType &&
          credentialId == other.credentialId &&
          _listEquals(authenticatorData, other.authenticatorData) &&
          _listEquals(clientDataJson, other.clientDataJson) &&
          signature == other.signature;

  @override
  int get hashCode =>
      credentialId.hashCode ^
      _listHash(authenticatorData) ^
      _listHash(clientDataJson) ^
      signature.hashCode;

  @override
  String toString() => 'PasskeyAssertionResult(credentialId: $credentialId)';

  bool _listEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  int _listHash(Uint8List list) =>
      list.fold(0, (hash, value) => hash ^ value.hashCode);
}
