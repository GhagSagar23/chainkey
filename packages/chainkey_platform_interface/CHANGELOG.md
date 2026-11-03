## 0.4.0

* Add `registerPasskey()` and `assertPasskey()` abstract methods to `ChainkeyPlatform`.
* Add `PasskeyAssertionResult` model for WebAuthn assertion responses.
* Add `PasskeyCredential.fromMap()` factory with nested map casting for MethodChannel.
* Add `AuthenticatorData.parse()` binary parser for authenticator data bytes.
* Add `ClientDataJson.parse()` zero-copy UTF-8 byte offset scanner.
* Add `DomainVerificationResult`, `verifyAppleAppSiteAssociation()`, `verifyAssetLinks()` for RP domain validation.

## 0.3.0

* No API changes; version bump to align with native implementations.

## 0.2.0

* Add `P256Signature.fromDer` ASN.1 DER unpacker.
* Add BIP-62 / EIP-2 low-S normalizer for P-256 signatures.
* Add `P256PublicKey` SEC1 point formatter, SPKI parser, and on-curve validation.
* Add Wycheproof and EIP-7212 test vectors for all crypto primitives.

## 0.1.1

* Add typed exception hierarchy (`ChainkeyException`, `UserCancelledException`, `KeyPermanentlyInvalidatedException`, `BiometricsUnavailableException`, `HardwareEnclaveException`, `PasskeyException`).
* Add deterministic platform error mapping (`ChainkeyException.fromPlatformException`).
* Add core domain models for cryptographic primitives (`P256Signature`, `PasskeyCredential`, `BiometricPromptOptions`).
* Add Pigeon IDL contracts for `HardwareEnclaveHostApi` and `WebAuthnHostApi`.

## 0.1.0

* Initial release of chainkey federated plugin package.
