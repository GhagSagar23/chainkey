# Security Policy

`chainkey` is a cryptographic infrastructure library providing hardware-isolated key management (Apple Secure Enclave, Android StrongBox/TEE, and W3C WebAuthn) for Web3 and account-abstraction (ERC-4337 / EIP-7212) applications. The security and integrity of private key isolation, biometric authorization, and cryptographic signature serialization are our highest priorities.

## Supported Versions

Only the latest release of `chainkey` is actively supported with security patches:

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |
| < 0.1.0 | :x:                |

---

## Reporting a Vulnerability

**DO NOT create a public GitHub issue for suspected security vulnerabilities.**

If you discover a security issue, vulnerability, or potential exploit in `chainkey`, please report it privately through one of the following channels:

1. **GitHub Security Advisory (Preferred)**:
   - Submit via [GitHub Private Vulnerability Reporting](https://github.com/GhagSagar23/chainkey/security/advisories/new).
2. **Encrypted / Direct Email**:
   - Send details to **Sagar Ghag** at [`sagar.ghag23@yahoo.com`](mailto:sagar.ghag23@yahoo.com) with the subject prefix `[SECURITY] chainkey - <short summary>`.

### Information to Include in Your Report

To help us triage and resolve the issue swiftly, please include:
- A clear description of the vulnerability and its potential impact.
- Affected components (e.g., `chainkey_android`, `chainkey_ios`, `chainkey_platform_interface`, `chainkey_web`, or `chainkey`).
- Platform and OS version (e.g., iOS 17.4 with Secure Enclave, Android 14 with StrongBox, Chrome WebAuthn).
- Step-by-step instructions or minimal reproducible proof-of-concept (PoC) code.
- Any potential remediations or patch suggestions if known.

---

## Security Scope & Cryptographic Focus Areas

We specifically invite responsible disclosure on issues involving:

- **Hardware Enclave Isolation & Key Extraction**:
  - Any mechanism allowing private key exfiltration from the Apple Secure Enclave (SEP), Android StrongBox Keymaster/KeyMint, or Android TEE.
- **Biometric / Authentication Bypass**:
  - Bypassing user presence checks, device passcode fallback, or `LAContext` / `BiometricPrompt` policies.
  - Flaws in `invalidatedByBiometricEnrollment` handling.
- **Signature Integrity & Malleability**:
  - ECDSA P-256 signature malleability issues (failing low-S normalization per BIP-62 / EIP-2).
  - ASN.1 DER decoding or encoding vulnerabilities.
  - Incorrect scalar packing/unpacking `(r, s)` for EIP-7212 precompiles.
- **Hardware Attestation Verification**:
  - Replay attacks, bypass of server-provided challenge nonces, or improper certificate chain validation.
- **Memory & Ephemeral Data Leakage**:
  - Sensitive cryptographic material retained unzeroed in application memory or system logs.

---

## Response & Disclosure Process

1. **Initial Acknowledgment**: We will acknowledge receipt of your vulnerability report within **48 hours**.
2. **Triage & Assessment**: Within **5 business days**, we will investigate and confirm the reproducibility and severity of the vulnerability.
3. **Patch Development & Testing**: A fix will be developed in a private security branch and validated against multi-platform test suites.
4. **Coordinated Disclosure**:
   - We follow standard coordinated vulnerability disclosure timelines (typically within **30 to 90 days** from initial report, or sooner for critical active exploits).
   - Once a patched release is published to `pub.dev`, a public [GitHub Security Advisory](https://github.com/GhagSagar23/chainkey/security/advisories) will be published crediting the reporter (unless anonymity is requested).
