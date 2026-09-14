# chainkey_ios

iOS platform implementation for the [`chainkey`](https://pub.dev/packages/chainkey) federated plugin.

This package provides native Apple Secure Enclave integration, Keychain hardware security services, and LocalAuthentication (Face ID / Touch ID) biometric prompts.

---

## Features

- **Apple Secure Enclave (SEP)**: Generates and protects non-exportable NIST P-256 (`secp256r1`) private keys inside Apple's hardware Secure Enclave.
- **Biometric Authentication**: Seamlessly prompts for Face ID or Touch ID using Apple's `LocalAuthentication` framework (`LAContext`) before signing digests.
- **ERC-4337 & EIP-7212 Compliance**: Produces hardware ASN.1 DER signatures and pre-unpacks low-$S$ normalized scalar components `(r, s)` compatible with smart contract verifiers and precompiles.
- **Cross-App Sharing**: Supports Keychain Access Groups for sharing enclave keys across related apps in an Apple developer team.

---

## Minimum Requirements

- **iOS Deployment Target**: `iOS 15.0+`
- **Xcode**: `15.0+`
- **Swift**: `5.9+`

---

## Info.plist Configuration

When using biometric authentication, add the `NSFaceIDUsageDescription` key to your iOS project's `ios/Runner/Info.plist`:

```xml
<key>NSFaceIDUsageDescription</key>
<string>Authenticate using Face ID to access your hardware-secured Web3 wallet.</string>
```

---

## Usage

This package is endorsed by the main [`chainkey`](https://pub.dev/packages/chainkey) package. When adding `chainkey` to your `pubspec.yaml`, `chainkey_ios` is automatically included and registered:

```yaml
dependencies:
  chainkey: ^0.1.0
```

---

## Issues & Contributing

For bug reports, feature requests, and contributing guidelines, please visit the [Chainkey GitHub Repository](https://github.com/GhagSagar23/chainkey).
