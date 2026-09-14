# chainkey

[![pub package](https://img.shields.io/pub/v/chainkey.svg)](https://pub.dev/packages/chainkey)
[![license](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)
[![CI](https://github.com/GhagSagar23/chainkey/actions/workflows/ci.yml/badge.svg)](https://github.com/GhagSagar23/chainkey/actions/workflows/ci.yml)

A turnkey Flutter federated plugin for **seedless Web3 authentication** and **smart contract account abstraction**.

`chainkey` enables applications to generate non-exportable cryptographic keypairs directly inside hardware security enclaves (**Apple Secure Enclave** and **Android StrongBox / TEE**) and web authenticators (**W3C WebAuthn / Passkeys**). Private keys never leave the hardware chip and require user biometric presence (Face ID, Touch ID, Fingerprint) for every signature.

Signatures are emitted with pre-unpacked, low-$S$ normalized `(r, s)` scalar components ready for on-chain verification via **EIP-7212** precompiles or **ERC-4337** smart contract wallets.

---

## Monorepo Packages

This repository is organized as a [Melos](https://melos.invertase.dev/) monorepo with the following federated packages:

| Package | Directory | Description |
| :--- | :--- | :--- |
| **`chainkey`** | [`packages/chainkey`](packages/chainkey) | App-facing public API for Flutter developers |
| **`chainkey_platform_interface`** | [`packages/chainkey_platform_interface`](packages/chainkey_platform_interface) | Common platform interface, contracts, and data models |
| **`chainkey_android`** | [`packages/chainkey_android`](packages/chainkey_android) | Android implementation (StrongBox Keymaster/KeyMint & BiometricPrompt) |
| **`chainkey_ios`** | [`packages/chainkey_ios`](packages/chainkey_ios) | iOS implementation (Apple Secure Enclave & LocalAuthentication) |
| **`chainkey_web`** | [`packages/chainkey_web`](packages/chainkey_web) | Web implementation (W3C WebAuthn, Passkeys & WebCrypto) |
| **`example`** | [`packages/chainkey/example`](packages/chainkey/example) | Example Flutter app demonstrating key generation & signing |

---

## Supported Platforms & Hardware Tiers

| Platform | Hardware Isolation Tier | Biometric Technology | Key Curve |
| :--- | :--- | :--- | :--- |
| **iOS** | Apple Secure Enclave (SEP) | Face ID / Touch ID (`LAContext`) | NIST P-256 (`secp256r1`) |
| **Android** | StrongBox HSM / ARM TrustZone TEE | Android `BiometricPrompt` | NIST P-256 (`secp256r1`) |
| **Web** | Platform Authenticator / Security Keys | Passkeys / WebAuthn / WebCrypto | NIST P-256 (`secp256r1`) |

---

## Quick Start

```yaml
# pubspec.yaml
dependencies:
  chainkey: ^0.1.0
```

```dart
import 'package:chainkey/chainkey.dart';

// 1. Generate hardware key in Secure Enclave / StrongBox
final key = await Chainkey.instance.generateHardwareKey(
  alias: 'account_key_1',
  requireUserPresence: true,
  requireStrongBox: true,
);

// 2. Sign a 32-byte digest (e.g. ERC-4337 UserOpHash) with biometric prompt
final signature = await Chainkey.instance.signWithHardwareKey(
  alias: 'account_key_1',
  hash32: userOpHash,
  promptOptions: BiometricPromptOptions(
    title: 'Confirm Transaction',
    negativeButtonText: 'Cancel',
  ),
);

// Ready for EIP-7212 verification on-chain
print('r: ${signature.r}, s: ${signature.s}');
```

---

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for local development setup, Melos commands, and PR guidelines, as well as our [Code of Conduct](CODE_OF_CONDUCT.md).

---

## Security

For coordinated vulnerability disclosure guidelines, please see our [Security Policy](SECURITY.md).

---

## License

This project is licensed under the Apache-2.0 License - see the [LICENSE](LICENSE) file for details.
