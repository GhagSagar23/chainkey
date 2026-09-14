# Contributing to Chainkey

Thank you for your interest in contributing to `chainkey`!
`chainkey` is an open-source, federated Flutter plugin for hardware-isolated, biometric-secured Web3 key generation, WebAuthn attestation, and EIP-7212/ERC-4337 signature serialization.

This document guides you through setting up your local development environment, repository conventions, code generation, and submitting pull requests.

---

## Code of Conduct

All contributors and maintainers are expected to follow our [Code of Conduct](CODE_OF_CONDUCT.md). Please read it before participating in discussions or submitting code.

---

## Repository Architecture

`chainkey` is organized as a federated Flutter monorepo managed with [Melos](https://melos.invertase.dev/):

```
chainkey/
├── packages/
│   ├── chainkey/                     # App-facing public API
│   │   └── example/                  # Example Flutter application
│   ├── chainkey_platform_interface/  # Common platform interface & data models
│   ├── chainkey_android/             # Android implementation (StrongBox / Keystore)
│   ├── chainkey_ios/                 # iOS implementation (Apple Secure Enclave)
│   └── chainkey_web/                 # Web implementation (W3C WebAuthn / WebCrypto)
├── pigeons/
│   └── key_api.dart                  # Pigeon type-safe host API definition
└── scripts/                          # CI and verification helper scripts
```

---

## Local Development Setup

### 1. Prerequisites

- **Flutter SDK**: `>=3.22.0` (Dart SDK `>=3.5.0`)
- **Git**: `>=2.30.0`
- **iOS Development**: macOS with Xcode 15+ and CocoaPods installed
- **Android Development**: Android Studio, JDK 17, and Android SDK (API level 24–36)
- **Web Development**: Google Chrome (for running web platform tests)

### 2. Clone and Bootstrap

Clone the repository and bootstrap dependencies across all federated sub-packages:

```bash
# Clone the repository
git clone https://github.com/GhagSagar23/chainkey.git
cd chainkey

# Install Melos globally
dart pub global activate melos

# Bootstrap the monorepo workspace
melos bootstrap
```

`melos bootstrap` links local federated packages together via Pub workspaces so that changes in `chainkey_platform_interface` are immediately reflected across platform packages.

---

## Pigeon Code Generation

Type-safe communication between Flutter and native host platforms (iOS Swift and Android Kotlin) is defined using **Pigeon**.

- **Definition File**: [`pigeons/key_api.dart`](pigeons/key_api.dart)
- **Generated Outputs**:
  - Dart: `packages/chainkey_platform_interface/lib/src/pigeon/key_api.g.dart`
  - Android (Kotlin): `packages/chainkey_android/android/src/main/kotlin/dev/chainkey/chainkey_android/KeyApi.g.kt`
  - iOS (Swift): `packages/chainkey_ios/ios/chainkey_ios/Sources/chainkey_ios/KeyApi.g.swift`

### Regenerating Code

Whenever you modify `pigeons/key_api.dart`, regenerate the platform bindings by running:

```bash
melos run pigeon
```

> [!WARNING]
> Never manually edit the generated `*.g.dart`, `*.g.kt`, or `*.g.swift` files. All changes must be made to `pigeons/key_api.dart` followed by code regeneration.

---

## Code Quality & Style Standards

Before pushing your branch or opening a pull request, ensure all linters and formatting checks pass.

### 1. Dart Formatting & Static Analysis

```bash
# Check formatting without modifying files
melos run format:check

# Auto-format all Dart code
melos run format

# Run static analysis with fatal infos
melos run analyze
```

### 2. Native Static Analysis

- **iOS (SwiftLint)**:
  - Configuration: [`.swiftlint.yml`](.swiftlint.yml)
  - Run locally (on macOS with SwiftLint installed):
    ```bash
    swiftlint lint --strict --config .swiftlint.yml packages/chainkey_ios/ios
    ```
- **Android (ktlint)**:
  - Configuration: [`.editorconfig`](.editorconfig)
  - Run locally:
    ```bash
    ktlint "packages/chainkey_android/android/src/**/*.kt" "!packages/chainkey_android/android/src/**/KeyApi.g.kt" --editorconfig=.editorconfig
    ```

---

## Running Tests

### 1. VM Unit Tests (Non-Web Packages)

Run unit and widget tests with code coverage generation:

```bash
melos run test:coverage
```

### 2. Web Platform Tests

The `chainkey_web` package requires a browser environment:

```bash
melos run test:web
```

### 3. Coverage Threshold Verification

Verify that your changes meet the required test coverage baseline:

```bash
./scripts/check_coverage.sh
```

---

## Git Workflow & Pull Request Guidelines

### 1. Branching Model

- `master`: Production release branch. Releases and tags (`v*.*.*`) are published from here.
- `develop`: Primary integration branch. All feature and bugfix PRs must target `develop`.
- **Feature Branches**: Branch off `develop` using the following naming convention:
  - `GH-<issue>/<short-description>` (e.g., `GH-29/governance-standards`)
  - `task/<short-description>` (for ad-hoc tasks)

### 2. Conventional Commits

We enforce the [Conventional Commits](https://www.conventionalcommits.org/) standard for PR titles and commit messages:

- `feat:` A new feature or capability
- `fix:` A bug fix
- `docs:` Documentation-only changes
- `style:` Code styling, whitespace, or formatting changes
- `refactor:` Code refactoring without changing public behavior
- `perf:` Performance improvements
- `test:` Adding or updating tests
- `infra:` CI/CD, build tools, or repository governance
- `chore:` Dependency bumps, repo maintenance, or miscellaneous tasks

Example:
```
feat(android): implement StrongBox hardware key generation
fix(ios): resolve low-S normalization in ECDSA signature parsing
docs: add pigeon regeneration steps to CONTRIBUTING.md
```

### 3. Submitting a Pull Request

1. Push your branch to GitHub.
2. Open a Pull Request targeting `develop`.
3. Fill out the PR description with:
   - Reference to the GitHub issue (e.g., `Closes #29`).
   - Summary of changes and rationale.
   - Confirmation that all automated checks (CI, Pana, linters) pass.
4. Keep PRs focused on a single responsibility to facilitate thorough review.
