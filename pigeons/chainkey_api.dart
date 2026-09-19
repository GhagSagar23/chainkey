import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut:
        'packages/chainkey_platform_interface/lib/src/pigeon/chainkey_api.g.dart',
    dartOptions: DartOptions(),
    kotlinOut:
        'packages/chainkey_android/android/src/main/kotlin/dev/chainkey/chainkey_android/ChainkeyApi.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'dev.chainkey.chainkey_android',
    ),
    swiftOut:
        'packages/chainkey_ios/ios/chainkey_ios/Sources/chainkey_ios/ChainkeyApi.g.swift',
    swiftOptions: SwiftOptions(),
    dartPackageName: 'chainkey_platform_interface',
  ),
)

/// Hardware security isolation tier backing the cryptographic key.
enum EnclaveIsolationLevel {
  /// Apple Secure Enclave (SEP) hardware isolated environment.
  secureEnclave,

  /// Android StrongBox Keymaster/KeyMint dedicated hardware security chip.
  strongBox,

  /// Android Trusted Execution Environment (TEE).
  tee,

  /// Software-backed or browser-managed key (e.g. software sandbox or WebAuthn).
  software,
}

/// Format of hardware attestation certificate chain or assertion statement.
enum KeyAttestationFormat {
  /// Android KeyStore X.509 attestation certificate chain (ASN.1 DER encoded).
  androidKeyStore,

  /// Apple DeviceCheck / AppAttest assertion and CBOR attestation object.
  appleAppAttest,

  /// No hardware attestation format available.
  none,
}

/// Parameters for generating a non-exportable NIST P-256 hardware key.
class HardwareKeyOptions {
  HardwareKeyOptions({
    required this.keyAlias,
    required this.requireUserPresence,
    required this.requireStrongBox,
    required this.invalidatedByBiometricEnrollment,
    this.accessGroup,
  });

  /// Unique alias/identifier for the hardware key.
  String keyAlias;

  /// Whether user presence (biometric or device passcode) is required to use the key.
  bool requireUserPresence;

  /// On Android, request a dedicated StrongBox HSM chip. If false or unavailable, falls back to TEE.
  bool requireStrongBox;

  /// On Android, controls whether adding a new biometric enrollment permanently invalidates the key.
  /// Recommended: false to prevent accidental user lockout.
  bool invalidatedByBiometricEnrollment;

  /// On iOS, optional Keychain Access Group for cross-app sharing.
  String? accessGroup;
}

/// Configuration options for native biometric prompt dialogs (Face ID / Touch ID / BiometricPrompt).
class PromptOptions {
  PromptOptions({
    required this.title,
    this.subtitle,
    this.promptDescription,
    required this.negativeButtonText,
    required this.confirmationRequired,
  });

  /// Title displayed on the biometric prompt.
  String title;

  /// Optional subtitle displayed on the biometric prompt.
  String? subtitle;

  /// Description explaining the transaction or UserOperation to sign.
  String? promptDescription;

  /// Label for the negative button (e.g. "Cancel").
  String negativeButtonText;

  /// On Android, whether explicit confirmation (tapping confirm button after sensor match) is required.
  bool confirmationRequired;
}

/// A parsed NIST P-256 (secp256r1) public key representation.
class EnclavePublicKey {
  EnclavePublicKey({
    required this.keyAlias,
    required this.x,
    required this.y,
    required this.uncompressedBytes,
    required this.isolationLevel,
  });

  /// Unique alias/identifier for the hardware key.
  String keyAlias;

  /// 32-byte big-endian X coordinate on the NIST P-256 curve.
  Uint8List x;

  /// 32-byte big-endian Y coordinate on the NIST P-256 curve.
  Uint8List y;

  /// 65-byte uncompressed SEC1 point representation: `0x04 || X (32B) || Y (32B)`.
  Uint8List uncompressedBytes;

  /// Hardware isolation tier where the private key was generated.
  EnclaveIsolationLevel isolationLevel;
}

/// ASN.1 DER signature result and pre-unpacked (r, s) scalar components.
class DerSignatureResult {
  DerSignatureResult({
    required this.keyAlias,
    required this.rawDerSignature,
    required this.r,
    required this.s,
    required this.isLowS,
  });

  /// Unique alias/identifier for the hardware key that signed the digest.
  String keyAlias;

  /// Raw ASN.1 DER encoded ECDSA signature from hardware:
  /// `0x30 || length || 0x02 || r_length || r || 0x02 || s_length || s`.
  Uint8List rawDerSignature;

  /// 32-byte big-endian `r` scalar (leading zero padding stripped, padded to 32 bytes).
  Uint8List r;

  /// 32-byte big-endian `s` scalar.
  Uint8List s;

  /// True if `s` is normalized to low-S ($s \le n/2$) per BIP-62 / EIP-2.
  bool isLowS;
}

/// Request parameters for creating a WebAuthn / Passkey credential.
class PasskeyCreationRequest {
  PasskeyCreationRequest({
    required this.relyingPartyId,
    required this.userName,
    required this.userDisplayName,
    required this.userId,
    required this.challenge,
    required this.requireUserVerification,
    this.origin,
  });

  /// Relying Party identifier (e.g. "wallet.example.com").
  String relyingPartyId;

  /// User account name (e.g. "user@example.com").
  String userName;

  /// Friendly display name for the user.
  String userDisplayName;

  /// Unique user entity identifier bytes.
  Uint8List userId;

  /// Cryptographic challenge bytes (e.g. 32-byte random challenge or UserOpHash).
  Uint8List challenge;

  /// Whether user verification (biometrics / PIN) is required ("required", "preferred", "discouraged").
  bool requireUserVerification;

  /// Optional origin URL (useful for Web/hybrid environments).
  String? origin;
}

/// WebAuthn / Passkey credential creation response.
class PasskeyCreationResponse {
  PasskeyCreationResponse({
    required this.credentialId,
    required this.rawAttestationObject,
    required this.rawClientDataJson,
    required this.publicKey,
    required this.isolationLevel,
  });

  /// Base64URL-encoded unique credential ID.
  String credentialId;

  /// Raw authenticator attestation object bytes.
  Uint8List rawAttestationObject;

  /// Raw UTF-8 bytes of clientDataJSON.
  Uint8List rawClientDataJson;

  /// Parsed NIST P-256 public key.
  EnclavePublicKey publicKey;

  /// Security isolation tier backing the credential.
  EnclaveIsolationLevel isolationLevel;
}

/// Request parameters for WebAuthn / Passkey assertion (authentication / signing).
class PasskeyAssertionRequest {
  PasskeyAssertionRequest({
    required this.relyingPartyId,
    required this.challenge,
    this.allowedCredentialIds,
    required this.requireUserVerification,
  });

  /// Relying Party identifier (e.g. "wallet.example.com").
  String relyingPartyId;

  /// Cryptographic challenge bytes (e.g. 32-byte UserOpHash).
  Uint8List challenge;

  /// Optional list of credential IDs allowed to assert.
  List<String>? allowedCredentialIds;

  /// Whether user verification (biometrics / PIN) is required.
  bool requireUserVerification;
}

/// WebAuthn / Passkey assertion response.
class PasskeyAssertionResponse {
  PasskeyAssertionResponse({
    required this.credentialId,
    required this.authenticatorData,
    required this.clientDataJson,
    required this.signature,
    this.userHandle,
  });

  /// Base64URL-encoded credential ID that signed the assertion.
  String credentialId;

  /// Raw authenticator data bytes containing flags and counters.
  Uint8List authenticatorData;

  /// Raw UTF-8 bytes of clientDataJSON.
  Uint8List clientDataJson;

  /// ASN.1 DER signature along with pre-unpacked (r, s) scalars.
  DerSignatureResult signature;

  /// Optional user handle returned by authenticator.
  Uint8List? userHandle;
}

/// Host API for direct hardware enclave operations (NIST P-256 keygen, raw hash signing, key deletion).
@HostApi()
abstract class HardwareEnclaveHostApi {
  /// Generates a non-exportable NIST P-256 keypair inside the hardware security enclave
  /// (Secure Enclave on iOS, StrongBox/TEE on Android).
  @async
  EnclavePublicKey generateKey(HardwareKeyOptions options);

  /// Signs a raw 32-byte digest (e.g. ERC-4337 UserOpHash) directly using the hardware key.
  /// Returns the raw ASN.1 DER signature along with pre-unpacked (r, s) scalars.
  @async
  DerSignatureResult signRawHash(
    String keyAlias,
    Uint8List hash32,
    PromptOptions prompt,
  );

  /// Deletes the keypair identified by [keyAlias] from the hardware keystore.
  bool deleteKey(String keyAlias);

  /// Returns the hardware isolation level for an existing key identified by [keyAlias].
  EnclaveIsolationLevel getIsolationLevel(String keyAlias);

  /// Checks whether a specific hardware isolation tier is available on the physical device.
  bool isHardwareIsolationSupported(EnclaveIsolationLevel level);

  /// Retrieves the public key coordinates for an existing keypair by [keyAlias].
  EnclavePublicKey getPublicKey(String keyAlias);

  /// Checks if a keypair exists for the specified [keyAlias].
  bool hasKey(String keyAlias);
}

/// Host API for W3C WebAuthn / Passkey operations (registration and assertion).
@HostApi()
abstract class WebAuthnHostApi {
  /// Registers a new Passkey credential via native Credential Manager / ASAuthorization.
  @async
  PasskeyCreationResponse registerPasskey(PasskeyCreationRequest request);

  /// Asserts an existing Passkey credential to authenticate or sign a challenge.
  @async
  PasskeyAssertionResponse assertPasskey(PasskeyAssertionRequest request);
}
