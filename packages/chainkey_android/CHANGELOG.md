## 0.3.0

* Implement Android KeyStore/StrongBox native P-256 key generation with `setIsStrongBoxBacked(true)` and graceful TEE fallback.
* Implement raw 32-byte hash signing via `NONEwithECDSA` with `KeyPermanentlyInvalidatedException` mapping.
* Set `setInvalidatedByBiometricEnrollment(false)` to prevent key destruction on new fingerprint enrollment.
* Add `ActivityAware` + `androidx.biometric:biometric` for `BiometricPrompt` with custom `PromptInfo` (title/subtitle/description/negativeButtonText/confirmationRequired).
* Remove duplicate `KeyApi.g.kt` causing symbol collisions.
* Add `dartPluginClass: ChainkeyAndroid` for correct auto-registration.

## 0.2.0

* Bump `chainkey_platform_interface` dependency to ^0.2.0.

## 0.1.1

* Map platform exceptions to typed `ChainkeyException` instances.
* Integrate updated `chainkey_platform_interface` dependency.

## 0.1.0

* Initial release of chainkey federated plugin package.
