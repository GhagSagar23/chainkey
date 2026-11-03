## 0.3.0

* Implement iOS Secure Enclave native P-256 keypair generation via `SecKeyCreateRandomKey` with `kSecAttrTokenIDSecureEnclave`.
* Implement raw 32-byte hash signing via `SecKeyCreateSignature` with `ecdsaSignatureDigestX962SHA256`.
* Wire `BiometricPromptOptions` → `LAContext.localizedReason` + `localizedCancelTitle` for custom biometric prompt text.
* Extract DER signature parser to `DerParser` enum, map `LAError` codes to typed exceptions.
* Remove duplicate `KeyApi.g.swift` causing symbol collisions.
* Add `dartPluginClass: ChainkeyIos` for correct auto-registration.

## 0.2.0

* Bump `chainkey_platform_interface` dependency to ^0.2.0.

## 0.1.1

* Map platform exceptions to typed `ChainkeyException` instances.
* Integrate updated `chainkey_platform_interface` dependency.

## 0.1.0

* Initial release of chainkey federated plugin package.
