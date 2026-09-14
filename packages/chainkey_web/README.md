# chainkey_web

Web implementation for the [`chainkey`](https://pub.dev/packages/chainkey) federated plugin.

This package provides browser-based hardware-isolated key generation, Passkey credential management, and WebAuthn signature assertion via the W3C Web Authentication and WebCrypto APIs.

---

## Features

- **W3C WebAuthn & Passkeys**: Utilizes browser platform authenticators (e.g., Apple Touch ID, Windows Hello, Android Biometrics, FIDO2 security keys) for hardware-backed credentials.
- **WASM-Ready**: Fully compatible with both `dart2js` and modern Flutter Web WebAssembly (`dart2wasm`) compilation pipelines.
- **Client Assertion Parsing**: Unpacks WebAuthn authenticator data, client data JSON, and DER-encoded signatures into standard `(r, s)` scalars suitable for ERC-4337 smart contract verification.

---

## Browser Support

- Google Chrome / Chromium 80+
- Apple Safari 14+
- Mozilla Firefox 70+
- Microsoft Edge 80+

> [!NOTE]
> WebAuthn requires a secure origin (`https://` or `http://localhost` during local development).

---

## Usage

This package is endorsed by the main [`chainkey`](https://pub.dev/packages/chainkey) package. When adding `chainkey` to your `pubspec.yaml`, `chainkey_web` is automatically included and registered:

```yaml
dependencies:
  chainkey: ^0.1.0
```

---

## Issues & Contributing

For bug reports, feature requests, and contributing guidelines, please visit the [Chainkey GitHub Repository](https://github.com/GhagSagar23/chainkey).
