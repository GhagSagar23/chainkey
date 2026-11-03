# Changelog

## 0.4.0

### Added

- **WebAuthn Passkey Engine** — cross-platform passkey registration and assertion via iOS AuthenticationServices, Android CredentialManager, and Web `navigator.credentials` (`dart:js_interop`).
- **AuthenticatorData parser** — binary parser for rpIdHash, flags (UP/UV/BE/BS/AT/ED), signCount.
- **ClientDataJSON scanner** — zero-copy UTF-8 byte offset scanner for `challenge` and `type` fields (Solady/Safe contract compatible).
- **Domain verification CLI** — `dart run chainkey:verify_domain` validates `apple-app-site-association` and `assetlinks.json` for WebAuthn RP binding.

## 0.3.0

### Added

- **iOS Secure Enclave** — native P-256 keypair generation and raw 32-byte hash signing via `SecKeyCreateRandomKey`/`SecKeyCreateSignature`.
- **Android KeyStore/StrongBox** — native P-256 key generation with StrongBox → TEE fallback, `NONEwithECDSA` raw signing, `KeyPermanentlyInvalidatedException` mapping.
- **Biometric prompt customization** — iOS `LAContext.localizedReason`, Android `BiometricPrompt.PromptInfo` with title/subtitle/description/negativeButtonText/confirmationRequired.
- **Latency benchmark suite** — integration test measuring P50/P95/P99 sign latency (42ms P50, well under 350ms KPI).

### Fixed

- Added `dartPluginClass` to iOS/Android pubspec for correct auto-registration.
- Removed duplicate `KeyApi.g.swift`/`KeyApi.g.kt` causing symbol collisions.

## 0.2.0

### Added

- **DER signature unpacker** — `P256Signature.fromDer` parses ASN.1 DER-encoded ECDSA signatures.
- **Low-S normalizer** — BIP-62 / EIP-2 canonical low-S enforcement for P-256 signatures.
- **SEC1 point formatter** — `P256PublicKey` SEC1 compressed/uncompressed encoding, SPKI parser, on-curve validation.
- **Wycheproof test vectors** — EIP-7212 and Wycheproof vectors covering all crypto primitives.

## 0.1.1

- Initial release with P-256 key generation and signing.
