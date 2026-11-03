import Flutter
import UIKit
import LocalAuthentication
import Security

public class ChainkeyIosPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "dev.chainkey/chainkey_ios", binaryMessenger: registrar.messenger())
    let instance = ChainkeyIosPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isHardwareIsolationSupported":
      handleIsHardwareIsolationSupported(call: call, result: result)
    case "generateHardwareKey":
      handleGenerateHardwareKey(call: call, result: result)
    case "signWithHardwareKey":
      handleSignWithHardwareKey(call: call, result: result)
    case "deleteHardwareKey":
      handleDeleteHardwareKey(call: call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - isHardwareIsolationSupported

  private func handleIsHardwareIsolationSupported(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let level = args["level"] as? String else {
      result(false)
      return
    }

    switch level {
    case "secureEnclave":
      let context = LAContext()
      var error: NSError?
      let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
      result(canEvaluate)
    case "software":
      result(true)
    default:
      result(false)
    }
  }

  // MARK: - generateHardwareKey

  private func handleGenerateHardwareKey(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let keyAlias = args["keyAlias"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing keyAlias", details: nil))
      return
    }

    let requireUserPresence = args["requireUserPresence"] as? Bool ?? true

    DispatchQueue.global(qos: .userInitiated).async {
      do {
        let publicKey = try self.generateSecureEnclaveKey(
          keyAlias: keyAlias,
          requireUserPresence: requireUserPresence
        )
        DispatchQueue.main.async {
          result(publicKey)
        }
      } catch {
        DispatchQueue.main.async {
          result(self.flutterError(from: error))
        }
      }
    }
  }

  private func generateSecureEnclaveKey(keyAlias: String, requireUserPresence: Bool) throws -> [String: Any] {
    let deleteQuery: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecAttrApplicationTag as String: keyAlias.data(using: .utf8)!,
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom
    ]
    SecItemDelete(deleteQuery as CFDictionary)

    var accessControlFlags: SecAccessControlCreateFlags = [.privateKeyUsage]
    if requireUserPresence {
      accessControlFlags.insert(.biometryAny)
    }

    guard let accessControl = SecAccessControlCreateWithFlags(
      kCFAllocatorDefault,
      kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
      accessControlFlags,
      nil
    ) else {
      throw PlatformError(code: "ACCESS_CONTROL_ERROR", message: "Failed to create access control flags")
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
    guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
      let cfError = error?.takeRetainedValue()
      throw PlatformError(
        code: "KEY_GENERATION_ERROR",
        message: cfError?.localizedDescription ?? "Failed to generate Secure Enclave key"
      )
    }

    guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
      throw PlatformError(code: "KEY_GENERATION_ERROR", message: "Failed to extract public key")
    }

    return try extractPublicKeyMap(publicKey: publicKey, keyAlias: keyAlias)
  }

  // MARK: - signWithHardwareKey

  private func handleSignWithHardwareKey(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let keyAlias = args["keyAlias"] as? String,
          let hash32 = args["hash32"] as? FlutterStandardTypedData else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing keyAlias or hash32", details: nil))
      return
    }

    let hashData = hash32.data
    guard hashData.count == 32 else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "hash32 must be exactly 32 bytes", details: nil))
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
        DispatchQueue.main.async {
          result(signatureMap)
        }
      } catch {
        DispatchQueue.main.async {
          result(self.flutterError(from: error))
        }
      }
    }
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

    // Set LAContext with localizedReason for custom biometric prompt text
    if let options = promptOptions {
      let context = LAContext()
      let reason = options["title"] as? String ?? "Biometric Authentication"
      context.localizedReason = reason
      if let cancelTitle = options["negativeButtonText"] as? String {
        context.localizedCancelTitle = cancelTitle
      }
      query[kSecUseAuthenticationContext as String] = context
    }

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess,
          let keyRef = item else {
      if status == errSecItemNotFound {
        throw PlatformError(code: "KEY_NOT_FOUND", message: "No key found for alias: \(keyAlias)")
      }
      throw PlatformError(code: "KEYCHAIN_ERROR", message: "Keychain query failed with status: \(status)")
    }

    // ponytail: kSecKeyAlgorithmECDSASignatureDigestX962SHA256 signs a raw
    // 32-byte digest (the "SHA256" refers to curve params, not rehashing).
    let algorithm = SecKeyAlgorithm.ecdsaSignatureDigestX962SHA256
    // swiftlint:disable:next force_cast
    let secKey = keyRef as! SecKey

    guard SecKeyIsAlgorithmSupported(secKey, .sign, algorithm) else {
      throw PlatformError(code: "UNSUPPORTED_ALGORITHM", message: "ECDSA signing not supported for this key")
    }

    var error: Unmanaged<CFError>?
    guard let derSignature = SecKeyCreateSignature(
      secKey,
      algorithm,
      hash32 as CFData,
      &error
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

  // MARK: - deleteHardwareKey

  private func handleDeleteHardwareKey(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let keyAlias = args["keyAlias"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing keyAlias", details: nil))
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

  // MARK: - Helpers

  private func extractPublicKeyMap(publicKey: SecKey, keyAlias: String) throws -> [String: Any] {
    var error: Unmanaged<CFError>?
    guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
      throw PlatformError(code: "KEY_EXPORT_ERROR", message: "Failed to export public key")
    }

    // SecKeyCopyExternalRepresentation returns ANSI X9.63:
    // 0x04 || X (32 bytes) || Y (32 bytes) for uncompressed P-256 keys.
    guard publicKeyData.count == 65 && publicKeyData[0] == 0x04 else {
      throw PlatformError(code: "KEY_FORMAT_ERROR", message: "Unexpected public key format (expected 65-byte SEC1)")
    }

    let xCoord = publicKeyData.subdata(in: 1..<33)
    let yCoord = publicKeyData.subdata(in: 33..<65)

    return [
      "keyAlias": keyAlias,
      "x": FlutterStandardTypedData(bytes: xCoord),
      "y": FlutterStandardTypedData(bytes: yCoord),
      "uncompressedBytes": FlutterStandardTypedData(bytes: publicKeyData),
      "isolationLevel": "secureEnclave"
    ]
  }

  private static func mapSigningError(_ cfError: CFError?) -> PlatformError {
    let message = cfError.map { $0 as Error }.map { $0.localizedDescription } ?? "Signing failed"
    if let cfError = cfError {
      let nsError = cfError as Error as NSError
      if nsError.domain == LAErrorDomain {
        switch nsError.code {
        case LAError.userCancel.rawValue:
          return PlatformError(code: "USER_CANCELLED", message: "User cancelled biometric authentication")
        case LAError.biometryLockout.rawValue:
          return PlatformError(code: "BIOMETRICS_UNAVAILABLE", message: "Biometrics locked out")
        default:
          break
        }
      }
    }
    return PlatformError(code: "SIGNING_ERROR", message: message)
  }

  private func flutterError(from error: Error) -> FlutterError {
    if let platformError = error as? PlatformError {
      return FlutterError(code: platformError.code, message: platformError.message, details: nil)
    }
    return FlutterError(code: "UNKNOWN_ERROR", message: error.localizedDescription, details: nil)
  }
}

// MARK: - DER Parsing

private enum DerParser {
  static func parseSignature(_ der: Data) throws -> (Data, Data) {
    guard der.count >= 8,
          der[0] == 0x30 else {
      throw PlatformError(code: "DER_PARSE_ERROR", message: "Invalid DER signature format")
    }

    var offset = 2
    let rScalar = try readInteger(der, offset: &offset)
    let sScalar = try readInteger(der, offset: &offset)
    return (rScalar, sScalar)
  }

  static func readInteger(_ der: Data, offset: inout Int) throws -> Data {
    guard offset + 2 <= der.count,
          der[offset] == 0x02 else {
      throw PlatformError(code: "DER_PARSE_ERROR", message: "Expected INTEGER tag at offset \(offset)")
    }
    let length = Int(der[offset + 1])
    offset += 2

    guard offset + length <= der.count else {
      throw PlatformError(code: "DER_PARSE_ERROR", message: "INTEGER overflows DER buffer")
    }

    var start = offset
    let end = offset + length
    offset = end

    while start < end && der[start] == 0x00 {
      start += 1
    }
    let stripped = end - start
    guard stripped <= 32 else {
      throw PlatformError(code: "DER_PARSE_ERROR", message: "INTEGER value too large")
    }

    var result = Data(count: 32)
    result.replaceSubrange((32 - stripped)..<32, with: der[start..<end])
    return result
  }
}

/// Internal error type for structured error passing.
private struct PlatformError: Error {
  let code: String
  let message: String
}
