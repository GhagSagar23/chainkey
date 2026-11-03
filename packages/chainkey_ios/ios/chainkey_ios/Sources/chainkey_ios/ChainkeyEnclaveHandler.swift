import Flutter
import UIKit
import LocalAuthentication
import Security

// MARK: - Hardware Enclave Operations

extension ChainkeyIosPlugin {
  func handleIsHardwareIsolationSupported(
    call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard let args = call.arguments as? [String: Any],
          let level = args["level"] as? String else {
      result(false)
      return
    }

    switch level {
    case "secureEnclave":
      let context = LAContext()
      var error: NSError?
      let canEvaluate = context.canEvaluatePolicy(
        .deviceOwnerAuthenticationWithBiometrics,
        error: &error
      )
      result(canEvaluate)
    case "software":
      result(true)
    default:
      result(false)
    }
  }

  func handleGenerateHardwareKey(
    call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard let args = call.arguments as? [String: Any],
          let keyAlias = args["keyAlias"] as? String else {
      result(FlutterError(
        code: "INVALID_ARGUMENT",
        message: "Missing keyAlias",
        details: nil
      ))
      return
    }

    let requireUserPresence = args["requireUserPresence"] as? Bool ?? true

    DispatchQueue.global(qos: .userInitiated).async {
      do {
        let publicKey = try self.generateSecureEnclaveKey(
          keyAlias: keyAlias,
          requireUserPresence: requireUserPresence
        )
        DispatchQueue.main.async { result(publicKey) }
      } catch {
        DispatchQueue.main.async {
          result(self.flutterError(from: error))
        }
      }
    }
  }

  func handleSignWithHardwareKey(
    call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard let args = call.arguments as? [String: Any],
          let keyAlias = args["keyAlias"] as? String,
          let hash32 = args["hash32"] as? FlutterStandardTypedData
    else {
      result(FlutterError(
        code: "INVALID_ARGUMENT",
        message: "Missing keyAlias or hash32",
        details: nil
      ))
      return
    }

    let hashData = hash32.data
    guard hashData.count == 32 else {
      result(FlutterError(
        code: "INVALID_ARGUMENT",
        message: "hash32 must be exactly 32 bytes",
        details: nil
      ))
      return
    }

    let promptOptions = args["promptOptions"] as? [String: Any]

    DispatchQueue.global(qos: .userInitiated).async {
      do {
        let signatureMap = try self.signWithSecureEnclave(
          keyAlias: keyAlias,
          hash32: hashData,
          promptOptions: promptOptions
        )
        DispatchQueue.main.async { result(signatureMap) }
      } catch {
        DispatchQueue.main.async {
          result(self.flutterError(from: error))
        }
      }
    }
  }

  func handleDeleteHardwareKey(
    call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard let args = call.arguments as? [String: Any],
          let keyAlias = args["keyAlias"] as? String else {
      result(FlutterError(
        code: "INVALID_ARGUMENT",
        message: "Missing keyAlias",
        details: nil
      ))
      return
    }

    let query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecAttrApplicationTag as String: keyAlias.data(using: .utf8)!,
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom
    ]

    let status = SecItemDelete(query as CFDictionary)
    result(status == errSecSuccess || status == errSecItemNotFound)
  }

  // MARK: - Private Enclave Helpers

  private func generateSecureEnclaveKey(
    keyAlias: String,
    requireUserPresence: Bool
  ) throws -> [String: Any] {
    let deleteQuery: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecAttrApplicationTag as String: keyAlias.data(using: .utf8)!,
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom
    ]
    SecItemDelete(deleteQuery as CFDictionary)

    var flags: SecAccessControlCreateFlags = [.privateKeyUsage]
    if requireUserPresence { flags.insert(.biometryAny) }

    guard let accessControl = SecAccessControlCreateWithFlags(
      kCFAllocatorDefault,
      kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
      flags,
      nil
    ) else {
      throw PlatformError(
        code: "ACCESS_CONTROL_ERROR",
        message: "Failed to create access control flags"
      )
    }

    let attributes: [String: Any] = [
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecAttrKeySizeInBits as String: 256,
      kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
      kSecPrivateKeyAttrs as String: [
        kSecAttrIsPermanent as String: true,
        kSecAttrApplicationTag as String: keyAlias.data(using: .utf8)!,
        kSecAttrAccessControl as String: accessControl
      ] as [String: Any]
    ]

    var error: Unmanaged<CFError>?
    guard let privateKey = SecKeyCreateRandomKey(
      attributes as CFDictionary, &error
    ) else {
      let cfError = error?.takeRetainedValue()
      throw PlatformError(
        code: "KEY_GENERATION_ERROR",
        message: cfError?.localizedDescription
          ?? "Failed to generate Secure Enclave key"
      )
    }

    guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
      throw PlatformError(
        code: "KEY_GENERATION_ERROR",
        message: "Failed to extract public key"
      )
    }

    return try extractPublicKeyMap(
      publicKey: publicKey, keyAlias: keyAlias
    )
  }

  private func signWithSecureEnclave(
    keyAlias: String,
    hash32: Data,
    promptOptions: [String: Any]?
  ) throws -> [String: Any] {
    var query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecAttrApplicationTag as String: keyAlias.data(using: .utf8)!,
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecReturnRef as String: true
    ]

    if let options = promptOptions {
      let context = LAContext()
      context.localizedReason = options["title"] as? String
        ?? "Biometric Authentication"
      if let cancel = options["negativeButtonText"] as? String {
        context.localizedCancelTitle = cancel
      }
      query[kSecUseAuthenticationContext as String] = context
    }

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess, let keyRef = item else {
      if status == errSecItemNotFound {
        throw PlatformError(
          code: "KEY_NOT_FOUND",
          message: "No key found for alias: \(keyAlias)"
        )
      }
      throw PlatformError(
        code: "KEYCHAIN_ERROR",
        message: "Keychain query failed with status: \(status)"
      )
    }

    // ponytail: ecdsaSignatureDigestX962SHA256 signs a raw 32-byte
    // digest (the "SHA256" refers to curve params, not rehashing).
    let algorithm = SecKeyAlgorithm.ecdsaSignatureDigestX962SHA256
    // swiftlint:disable:next force_cast
    let secKey = keyRef as! SecKey

    guard SecKeyIsAlgorithmSupported(secKey, .sign, algorithm) else {
      throw PlatformError(
        code: "UNSUPPORTED_ALGORITHM",
        message: "ECDSA signing not supported for this key"
      )
    }

    var error: Unmanaged<CFError>?
    guard let derSignature = SecKeyCreateSignature(
      secKey, algorithm, hash32 as CFData, &error
    ) else {
      throw Self.mapSigningError(error?.takeRetainedValue())
    }

    let rawDer = derSignature as Data
    let (rScalar, sScalar) = try DerParser.parseSignature(rawDer)

    return [
      "r": FlutterStandardTypedData(bytes: rScalar),
      "s": FlutterStandardTypedData(bytes: sScalar),
      "rawDerSignature": FlutterStandardTypedData(bytes: rawDer)
    ]
  }
}
