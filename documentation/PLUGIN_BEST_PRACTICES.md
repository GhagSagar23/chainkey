# Flutter Plugin Architecture & Development Best Practices

## Document Overview
- **Project**: `chainkey`
- **Target Platforms**: Android (Kotlin), iOS (Swift), Web (Dart / JS-Interop)
- **Framework Target**: Flutter ≥ 3.22.0 (Dart SDK ≥ 3.5.0)
- **Monorepo Tooling**: Dart Pub Workspaces & Melos 8+

---

## 1. Package vs. Plugin: The Fundamental Distinction

In Flutter development, **Packages** and **Plugins** serve strictly differentiated architectural roles:

| Characteristic | Pure Dart Package | Flutter Plugin Package |
| :--- | :--- | :--- |
| **Scaffolding Command** | `flutter create --template=package <name>` | `flutter create --template=plugin --platforms=... <name>` |
| **Implementation Scope** | 100% pure Dart code (widgets, algorithms, data contracts). | Dart public API combined with platform-specific native implementations. |
| **Host OS Access** | Sandboxed in Dart VM; no direct access to OS services. | Full access to OS hardware & SDKs (Secure Enclave, StrongBox, Biometrics, Keychain). |
| **Bridge Mechanism** | Direct function calls within Dart VM. | Platform Channels (`MethodChannel`, `EventChannel`), **Pigeon** IPC, or **FFI** (`dart:ffi`). |
| **Native Build Tooling** | Handled purely by `pub`. | Android Gradle (`build.gradle.kts`), Apple SwiftPM (`Package.swift`) & CocoaPods (`.podspec`), Webpack/Wasm. |

> [!IMPORTANT]
> Because `chainkey` manages hardware-isolated cryptographic enclaves (Apple Secure Enclave, Android StrongBox/KeyMint, and W3C WebAuthn), it must be architected as a **Flutter Plugin**, not a pure Dart package.

---

## 2. Architectural Standard: Federated Plugins

For multi-platform plugins, monolithic plugin architectures (where one package bundles Android, iOS, and Web code) create tight coupling, dependency bloat, and brittle testing. Flutter's official standard is the **Federated Plugin Architecture**.

```
chainkey/ (Monorepo Root)
├── pubspec.yaml                       # Root Dart Pub Workspace & Melos config
├── packages/
│   ├── chainkey/                      # App-Facing Package (Public Dart API)
│   │   ├── lib/chainkey.dart          # Public facade exposing stable high-level API
│   │   └── example/                   # Unified example app & integration test harness
│   │
│   ├── chainkey_platform_interface/   # Platform Interface Contract
│   │   ├── lib/src/chainkey_platform_interface.dart # Abstract class extending PlatformInterface
│   │   ├── lib/src/method_channel_chainkey.dart     # Default MethodChannel implementation
│   │   └── lib/src/models/            # Shared cryptographic & domain models
│   │
│   ├── chainkey_android/              # Dedicated Android Implementation
│   │   ├── lib/chainkey_android.dart  # Registers ChainkeyAndroid with ChainkeyPlatform
│   │   └── android/                   # Kotlin native code (StrongBox / KeyMint)
│   │
│   ├── chainkey_ios/                  # Dedicated iOS Implementation
│   │   ├── lib/chainkey_ios.dart      # Registers ChainkeyIos with ChainkeyPlatform
│   │   └── ios/                       # Swift native code (Secure Enclave / CryptoKit)
│   │
│   └── chainkey_web/                  # Dedicated Web Implementation
│       ├── lib/chainkey_web.dart      # Registers ChainkeyWeb with ChainkeyPlatform
│       └── web/                       # W3C WebAuthn Credential Management API
```

### 2.1 The 4 Federated Tiers

1. **App-Facing Package (`chainkey`)**:
   - The entrypoint that end-users declare in their `pubspec.yaml`.
   - Never contains native code. Dispatches all calls through `ChainkeyPlatform.instance`.
   - Houses the canonical `example/` app.

2. **Platform Interface (`chainkey_platform_interface`)**:
   - Defines the abstract contract extending `PlatformInterface`.
   - **Token Verification**: Uses `PlatformInterface.verify(instance, _token)` in instance setters to prevent third parties from implementing the interface directly. Subclasses must *extend* the interface, ensuring newly added methods with default fallbacks do not introduce breaking changes.

3. **Platform Implementations (`chainkey_android`, `chainkey_ios`, `chainkey_web`)**:
   - Platform packages containing the native or platform-specific bindings.
   - Implement `static void registerWith(...)` to register themselves as `ChainkeyPlatform.instance` at runtime.
   - Declares `implements: chainkey` in their `pubspec.yaml`.

4. **Endorsed Dependencies**:
   - The app-facing package endorses platform implementations via `default_package`:
     ```yaml
     flutter:
       plugin:
         platforms:
           android:
             default_package: chainkey_android
           ios:
             default_package: chainkey_ios
           web:
             default_package: chainkey_web
     ```
   - Downstream consumers depend only on `chainkey`, and Flutter automatically bundles the endorsed platform implementations for the active compilation target.

---

## 3. Native Bridge & Inter-Process Communication (IPC)

### 3.1 Pigeon: Type-Safe Host ↔ Dart Code Generation
For complex plugins, avoid raw string-based `MethodChannel.invokeMethod('foo', args)` which causes runtime casting failures and untyped map serialization bugs.

- **Type Safety**: Pigeon takes a Dart definition file (`pigeons/chainkey_api.dart`) and auto-generates:
  - Dart client and host APIs.
  - Kotlin host protocols, data classes, and codec decoders.
  - Swift host protocols, structs, and binary decoders.
- **Modern Concurrency Annotations**:
  - `@async`: Generates native `suspend` functions in Kotlin and `async/await` methods in Swift.
  - `@TaskQueue`: Instructs the Flutter engine to execute platform channel invocations on background threads, preventing UI jank on long-running cryptographic operations.
- **Structured Error Handling**:
  - Automatically translates native exceptions (`FlutterError` in Kotlin, `PigeonError` in Swift) into standard Dart `PlatformException` objects.

### 3.2 Platform Channels vs. Dart FFI (`dart:ffi`)
- **Use Platform Channels / Pigeon** when communicating with operating system APIs, frameworks, and system dialogs (e.g., iOS `AuthenticationServices`, `LocalAuthentication`, `CryptoKit`, Android `CredentialManager`, `KeyStore`, Biometric Prompts).
- **Use Dart FFI (`--template=package_ffi`)** when bundling native C/C++/Rust mathematical engines (e.g. raw curve point scalar multiplication or ZK proof verification) where zero-overhead synchronous shared memory is mandatory.

### 3.3 Modern Web Interop (Wasm Compatibility)
- Do not use deprecated `dart:html` or `package:js`.
- Use **`dart:js_interop`** and **`package:web`** to ensure the plugin compiles cleanly to WebAssembly (`flutter build web --wasm`).

---

## 4. Platform-Specific Best Practices

### 4.1 Android (Kotlin & Modern Gradle)
1. **Lifecycle Management (`FlutterPlugin` & `ActivityAware`)**:
   - Register channels and listeners in `onAttachedToEngine(binding)`.
   - Clean up channels and remove handlers in `onDetachedFromEngine(binding)`.
   - When handling biometric UI prompts, implement `ActivityAware`. Store `Activity` references as `WeakReference<Activity>` and detach them in `onDetachedFromActivity()`. **Never leak an `Activity` reference.**
2. **Modern Gradle Standards**:
   - Use Kotlin DSL (`build.gradle.kts`).
   - Declare explicit `namespace = "dev.chainkey.chainkey_android"` (mandatory for AGP 8.0+).
   - Target modern `compileSdk 34+` / `35+`.
3. **Threading & Coroutine Governance**:
   - Never run cryptographic keygen or I/O on the Android Main thread.
   - Dispatch background work using Kotlin Coroutines (`withContext(Dispatchers.Default)` or `Dispatchers.IO`).
   - Always return channel callbacks (`result.success()`, `result.error()`) safely, guarding against duplicate invocations (`IllegalStateException: Reply already submitted`).
4. **Hardware Key Retention**:
   - When generating Android hardware keys, specify `setInvalidatedByBiometricEnrollment(false)` to prevent Android KeyStore from permanently destroying hardware keys when the user enrolls a secondary fingerprint.

### 4.2 iOS / macOS Darwin (Swift, SPM & Privacy Manifests)
1. **Swift Package Manager (SPM) + CocoaPods Dual Support**:
   - Flutter 3.44+ uses Swift Package Manager by default for iOS and macOS native dependencies, while CocoaPods transitions to maintenance mode (read-only by December 2026).
   - Production plugins must provide **both**:
     - `ios/chainkey_ios/Package.swift` (SwiftPM).
     - `ios/chainkey_ios.podspec` (CocoaPods).
2. **Apple Privacy Manifest (`PrivacyInfo.xcprivacy`)**:
   - Apple requires all published SDKs and plugins accessing sensitive APIs (file timestamps, user defaults, system boot time, disk space, keychain access) to declare an embedded `PrivacyInfo.xcprivacy` resource bundle in both `Package.swift` and `.podspec`.
3. **Multi-Engine Isolation**:
   - Host applications can spawn multiple `FlutterEngine` instances.
   - Do not maintain global static singleton state in Swift. Tie plugin state to the specific `FlutterPluginRegistrar` and channel instances.
4. **Swift Concurrency**:
   - Use modern `async/await` and `Task` blocks rather than nested callback closures.

---

## 5. Multi-Tier Testing Strategy

A production Flutter plugin requires testing across 4 complementary tiers:

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Native UI Tests (Espresso / XCUITest)                    │
│    - Test system biometric prompts & FaceID dialogs         │
├─────────────────────────────────────────────────────────────┤
│ 2. Device Integration Tests (package:integration_test)      │
│    - Runs in example app on real device or emulator         │
│    - Exercises Dart API -> Native Channel -> OS Hardware    │
├─────────────────────────────────────────────────────────────┤
│ 3. Native Unit Tests (JUnit / XCTest / Swift Testing)       │
│    - Tests Kotlin and Swift logic without Flutter engine    │
│    - Located in android/src/test/ and ios/RunnerTests/      │
├─────────────────────────────────────────────────────────────┤
│ 4. Dart Unit & Contract Tests (flutter test)                │
│    - Verifies PlatformInterface token verification          │
│    - Tests app-facing API against Mock PlatformInterface    │
│    - Tests pure Dart crypto (DER decoding, low-S math)      │
└─────────────────────────────────────────────────────────────┘
```

- **Running Dart Unit Tests**:
  `flutter test packages/chainkey/test/ packages/chainkey_platform_interface/test/`
- **Running Web Tests**:
  Web unit tests that import `flutter_web_plugins` or `dart:ui_web` must be executed with `--platform=chrome`:
  `flutter test --platform=chrome test/`
- **Running Integration Tests**:
  `cd packages/chainkey/example && flutter test integration_test/`
- **Static Analysis & Health Checks**:
  `dart analyze .` and `dart pub global run pana .` to maximize pub.dev scoring.

---

## 6. Monorepo & Tooling Setup

### 6.1 Dart Pub Workspaces (Dart 3.5+)
Dart 3.5+ natively supports monorepo workspaces:
- The root `pubspec.yaml` defines `workspace:` referencing all packages and example apps:
  ```yaml
  name: chainkey_workspace
  environment:
    sdk: ^3.5.0

  workspace:
    - packages/chainkey
    - packages/chainkey/example
    - packages/chainkey_platform_interface
    - packages/chainkey_android
    - packages/chainkey_ios
    - packages/chainkey_web
  ```
- Child packages declare `resolution: workspace`, allowing `flutter pub get` at root to resolve the entire dependency graph with shared locks and zero version mismatch errors.

### 6.2 Melos 8+ Integration
Melos orchestrates multi-package workflows across the workspace:
- **Scripts**: Run batch linting, formatting, testing, and versioning across all packages:
  ```bash
  melos run analyze    # Analyzes all 6 packages simultaneously
  melos run test       # Executes tests across all test-containing packages
  melos list           # Displays workspace package topology
  ```
- **Automated Versioning & Changelogs**: Tracks Conventional Commits to automatically bump semver versions and generate changelogs across federated packages during releases.
