## 0.5.0

* Bump `chainkey_platform_interface` dependency to ^0.5.0.

## 0.4.0

* Implement passkey registration and assertion via `dart:js_interop` W3C `navigator.credentials` API.
* Use typed `web` package WebAuthn bindings (`PublicKeyCredentialCreationOptions`, `AuthenticatorAssertionResponse`).
* Extract real SPKI public key via `getPublicKey()` when available.
* DER signature parsing via `P256Signature.fromDer()`.
* Map `NotAllowedError`/`AbortError` to `UserCancelledException`.
* Bump `chainkey_platform_interface` dependency to ^0.4.0.

## 0.3.0

* Bump `chainkey_platform_interface` dependency to ^0.3.0.

## 0.2.0

* Bump `chainkey_platform_interface` dependency to ^0.2.0.

## 0.1.1

* Integrate updated `chainkey_platform_interface` dependency.

## 0.1.0

* Initial release of chainkey federated plugin package.
