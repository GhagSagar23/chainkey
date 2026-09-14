## Description

<!-- Provide a brief description of what this PR introduces, modifies, or fixes. -->

---

## Type of Change

- [ ] `feat`: A new feature or public API capability
- [ ] `fix`: A bug fix
- [ ] `docs`: Documentation updates
- [ ] `style`: Formatting or whitespace adjustment (no code changes)
- [ ] `refactor`: Refactoring without functional changes
- [ ] `perf`: Performance optimization
- [ ] `test`: Adding or correcting tests
- [ ] `build` / `infra`: Build system, CI/CD, Melos, or repository automation
- [ ] `chore`: Maintenance, dependencies, or repository hygiene

---

## Affected Packages

- [ ] `packages/chainkey` (App-facing API)
- [ ] `packages/chainkey_platform_interface` (Common interface & data models)
- [ ] `packages/chainkey_android` (Android Keystore / StrongBox implementation)
- [ ] `packages/chainkey_ios` (Apple Secure Enclave implementation)
- [ ] `packages/chainkey_web` (W3C WebAuthn / WebCrypto implementation)
- [ ] `packages/chainkey/example` (Example Flutter app)
- [ ] `pigeons/` (Pigeon schema definitions)
- [ ] Root / Tooling / CI Workflows

---

## Platform Verification

- [ ] **Android**: Tested on emulator / physical device (minSdk 24+, StrongBox / TEE)
- [ ] **iOS**: Tested on simulator / physical device (iOS 15+, Secure Enclave)
- [ ] **Web**: Tested on Chrome / browser (WebAuthn / Passkeys)
- [ ] **Not Applicable** (docs, CI, or platform-agnostic changes)

---

## Pre-Submit Checklist

- [ ] Code follows repository style conventions and formatting (`melos run format:check`).
- [ ] Static analysis passes without fatal warnings or errors (`melos run analyze`).
- [ ] Unit and widget tests pass (`melos run test:coverage` and `melos run test:web`).
- [ ] Minimum test coverage threshold is maintained (`./scripts/check_coverage.sh`).
- [ ] If Pigeon schema (`pigeons/key_api.dart`) was updated, bindings were regenerated (`melos run pigeon`).
- [ ] Native static analysis passes (`swiftlint` for iOS, `ktlint` for Android).
- [ ] Documentation / comments updated where relevant.
- [ ] If changing a package's public API or behavior, `CHANGELOG.md` has been updated.

---

## Related Issues

<!-- Link related issues below using Closes #XX, Fixes #XX, or Ref #XX -->
Closes #
