import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut:
        'packages/chainkey_platform_interface/lib/src/pigeon/key_api.g.dart',
    dartOptions: DartOptions(),
    kotlinOut:
        'packages/chainkey_android/android/src/main/kotlin/dev/chainkey/chainkey_android/KeyApi.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'dev.chainkey.chainkey_android',
    ),
    swiftOut:
        'packages/chainkey_ios/ios/chainkey_ios/Sources/chainkey_ios/KeyApi.g.swift',
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

/// Parameters for generating a non-exportable NIST P-256 keypair.
class KeyGenerationRequest {
  KeyGenerationRequest({
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

  /// On Android, controls whether adding a new fingerprint permanently invalidates the key.
  /// Recommended: false to prevent accidental user lockout.
  bool invalidatedByBiometricEnrollment;

  /// On iOS, optional Keychain Access Group for cross-app sharing.
  String? accessGroup;
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

/// Configuration options for native biometric prompt dialogs (Face ID / Touch ID / BiometricPrompt).
class PlatformPromptOptions {
  PlatformPromptOptions({
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

/// Request to sign a raw 32-byte digest (e.g. ERC-4337 UserOpHash) directly with a hardware key.
class SignDigestRequest {
  SignDigestRequest({
    required this.keyAlias,
    required this.hash32,
    this.promptOptions,
  });

  /// Unique alias/identifier for the hardware key.
  String keyAlias;

  /// Exact 32-byte digest to sign.
  Uint8List hash32;

  /// Optional native biometric prompt customization.
  PlatformPromptOptions? promptOptions;
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

/// Request for cryptographic hardware attestation.
class AttestationRequest {
  AttestationRequest({
    required this.keyAlias,
    required this.challenge,
  });

  /// Unique alias/identifier for the hardware key to attest.
  String keyAlias;

  /// Server/contract provided challenge nonce to prevent replay attacks.
  Uint8List challenge;
}

/// Hardware attestation verification payload.
class AttestationResult {
  AttestationResult({
    required this.keyAlias,
    required this.certificateChain,
    required this.format,
    required this.isolationLevel,
  });

  /// Unique alias/identifier for the attested key.
  String keyAlias;

  /// X.509 certificate chain in ASN.1 DER encoding (leaf certificate first).
  List<Uint8List> certificateChain;

  /// Attestation statement format.
  KeyAttestationFormat format;

  /// Hardware isolation tier confirmed by the hardware.
  EnclaveIsolationLevel isolationLevel;
}

/// Host API for direct hardware enclave operations (NIST P-256 keygen, attestation, and ASN.1 DER signing).
@HostApi()
abstract class HardwareKeyHostApi {
  /// Checks whether a specific hardware isolation tier is available on the physical device.
  bool isHardwareIsolationSupported(EnclaveIsolationLevel level);

  /// Generates a non-exportable NIST P-256 keypair inside the hardware security enclave
  /// (Secure Enclave on iOS, StrongBox/TEE on Android).
  @async
  EnclavePublicKey generateKeyPair(KeyGenerationRequest request);

  /// Signs a raw 32-byte digest (e.g. ERC-4337 UserOpHash) directly using the hardware key.
  /// Returns the raw ASN.1 DER signature along with pre-unpacked (r, s) scalars.
  @async
  DerSignatureResult signDigest(SignDigestRequest request);

  /// Requests hardware attestation for the key, embedding [request.challenge] into the certificate
  /// chain to verify hardware backing.
  @async
  AttestationResult attestKey(AttestationRequest request);

  /// Retrieves the public key coordinates for an existing keypair by [keyAlias].
  EnclavePublicKey getPublicKey(String keyAlias);

  /// Checks if a keypair exists for the specified [keyAlias].
  bool hasKey(String keyAlias);

  /// Deletes the keypair identified by [keyAlias] from the hardware keystore.
  bool deleteKey(String keyAlias);
}
