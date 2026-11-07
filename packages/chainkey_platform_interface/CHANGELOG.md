## 0.6.0

* Add `encodeSafeAddOwnerCallData()` and `encodeSafeRemoveOwnerCallData()` for Safe multi-owner management.
* Add `encodeErc7579InstallP256ValidatorCallData()` and `encodeErc7579UninstallValidatorCallData()` for ERC-7579 modular accounts.
* Add `erc7579ValidatorTypeId` constant.
* Add `MultiSignerState`, `SignerEntry`, `SignerStatus` models for multi-device signer lifecycle.
* Add `KeyInvalidationEvent` model.
* Add `KeyRecoveryHandler` with `signWithRecovery()` and `rotateKey()`.
* Add `OnKeyInvalidated` callback typedef.
* Add live testnet integration test harness (tagged `testnet`, skipped by default).

## 0.5.0

* Add `encodeSafePasskeySignature()` ABI encoder for Safe 4337 WebAuthn Signer module.
* Add `encodeErc7579WebAuthnSignature()` ABI encoder for ZeroDev Kernel v3 and Biconomy Nexus modular accounts.
* Add `encodeEip7212Payload()` 160-byte serializer for the EIP-7212 secp256r1 precompile.
* Add `eip7212PrecompileAddress` constant.

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
