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
