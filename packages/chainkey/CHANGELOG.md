## 0.6.0

* Add ERC-4337 UserOp `callData` helpers for multi-device key registration and revocation (Safe `addOwner`/`removeOwner`, ERC-7579 `installModule`/`uninstallModule`).
* Add `MultiSignerState`, `SignerEntry`, `SignerStatus` for multi-device signer lifecycle tracking.
* Add `KeyRecoveryHandler` for automatic detection and recovery from `KeyPermanentlyInvalidatedException`.
* Add `KeyInvalidationEvent` and `OnKeyInvalidated` callback type.
* Add live testnet integration test harness for Base Sepolia and Arbitrum Sepolia.
* Rewrite example app as production-grade reference (seedless onboarding, USDC transfer signing, key recovery).
* Update README with complete API documentation.

## 0.5.0

* Export `encodeSafePasskeySignature`, `encodeErc7579WebAuthnSignature`, `encodeEip7212Payload`, and `eip7212PrecompileAddress` from platform interface.
* Bump all platform dependencies to ^0.5.0.

## 0.4.0

* Cross-platform WebAuthn passkey registration and assertion (iOS, Android, Web).
* Export `AuthenticatorData`, `ClientDataJson`, `PasskeyAssertionResult`, `PasskeyCredential` from platform interface.
* Export domain verification utilities (`verifyAppleAppSiteAssociation`, `verifyAssetLinks`).
* Add CLI tool: `dart run chainkey:verify_domain` for RP domain association validation.
* Bump all platform dependencies to ^0.4.0.

## 0.3.0

* Native hardware key generation and signing now functional on iOS (Secure Enclave) and Android (KeyStore/StrongBox).
* Biometric prompt customization via `BiometricPromptOptions` on both platforms.
* Latency benchmark integration test (P50: 42ms, KPI < 350ms).

## 0.2.0

* Re-export new crypto primitives from `chainkey_platform_interface` 0.2.0.

## 0.1.1

* Re-export typed exception hierarchy (`ChainkeyException`, `UserCancelledException`, `KeyPermanentlyInvalidatedException`, `BiometricsUnavailableException`, `HardwareEnclaveException`, `PasskeyException`).
* Re-export core domain models (`P256Signature`, `PasskeyCredential`, `BiometricPromptOptions`).

## 0.1.0

* Initial release of chainkey federated plugin package.
