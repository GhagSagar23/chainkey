import 'p256_public_key.dart';

/// Lifecycle status of a signer within a multi-device smart account.
enum SignerStatus {
  /// Key is active and can sign UserOperations.
  active,

  /// An on-chain add-owner/install-module UserOp has been submitted but not mined.
  pendingAddition,

  /// An on-chain remove-owner/uninstall-module UserOp has been submitted but not mined.
  pendingRevocation,

  /// Key has been revoked on-chain.
  revoked,
}

/// A single P-256 signer registered to a smart account.
class SignerEntry {
  const SignerEntry({
    required this.credentialId,
    required this.publicKey,
    this.status = SignerStatus.active,
    this.addedAt,
    this.label,
  });

  /// Base64URL credential ID (matches PasskeyCredential.credentialId).
  final String credentialId;

  /// The P-256 public key whose (x, y) coordinates are registered on-chain.
  final P256PublicKey publicKey;

  /// Current lifecycle status.
  final SignerStatus status;

  /// When the signer was first registered (local timestamp, not block time).
  final DateTime? addedAt;

  /// Human-readable device label (e.g. "iPhone 15", "Pixel 9").
  final String? label;

  SignerEntry copyWith({
    SignerStatus? status,
    String? label,
  }) =>
      SignerEntry(
        credentialId: credentialId,
        publicKey: publicKey,
        status: status ?? this.status,
        addedAt: addedAt,
        label: label ?? this.label,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SignerEntry &&
          credentialId == other.credentialId &&
          publicKey == other.publicKey &&
          status == other.status;

  @override
  int get hashCode => Object.hash(credentialId, publicKey, status);

  @override
  String toString() =>
      'SignerEntry($credentialId, ${status.name}, label: $label)';
}

/// Immutable snapshot of all signers registered to a smart account.
class MultiSignerState {
  const MultiSignerState(this.signers);

  const MultiSignerState.empty() : signers = const [];

  final List<SignerEntry> signers;

  List<SignerEntry> get active =>
      signers.where((s) => s.status == SignerStatus.active).toList();

  SignerEntry? byCredentialId(String credentialId) {
    for (final s in signers) {
      if (s.credentialId == credentialId) return s;
    }
    return null;
  }

  bool isRegistered(String credentialId) =>
      byCredentialId(credentialId) != null;

  MultiSignerState addSigner(SignerEntry entry) =>
      MultiSignerState([...signers, entry]);

  MultiSignerState updateStatus(String credentialId, SignerStatus status) =>
      MultiSignerState([
        for (final s in signers)
          if (s.credentialId == credentialId)
            s.copyWith(status: status)
          else
            s,
      ]);

  @override
  String toString() =>
      'MultiSignerState(${signers.length} signers, ${active.length} active)';
}
