## 0.1.1

* Add typed exception hierarchy (`ChainkeyException`, `UserCancelledException`, `KeyPermanentlyInvalidatedException`, `BiometricsUnavailableException`, `HardwareEnclaveException`, `PasskeyException`).
* Add deterministic platform error mapping (`ChainkeyException.fromPlatformException`).
* Add core domain models for cryptographic primitives (`P256Signature`, `PasskeyCredential`, `BiometricPromptOptions`).
* Add Pigeon IDL contracts for `HardwareEnclaveHostApi` and `WebAuthnHostApi`.

## 0.1.0

* Initial release of chainkey federated plugin package.
