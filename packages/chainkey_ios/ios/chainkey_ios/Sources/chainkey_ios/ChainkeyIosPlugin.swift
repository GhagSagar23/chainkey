import Flutter
import UIKit
import LocalAuthentication
import Security
import AuthenticationServices

public class ChainkeyIosPlugin: NSObject, FlutterPlugin {
  var pendingPasskeyResult: FlutterResult?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "dev.chainkey/chainkey_ios",
      binaryMessenger: registrar.messenger()
    )
    let instance = ChainkeyIosPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    switch call.method {
    case "isHardwareIsolationSupported":
      handleIsHardwareIsolationSupported(call: call, result: result)
    case "generateHardwareKey":
      handleGenerateHardwareKey(call: call, result: result)
    case "signWithHardwareKey":
      handleSignWithHardwareKey(call: call, result: result)
    case "deleteHardwareKey":
      handleDeleteHardwareKey(call: call, result: result)
    case "registerPasskey":
      handleRegisterPasskey(call: call, result: result)
    case "assertPasskey":
      handleAssertPasskey(call: call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - registerPasskey

  func handleRegisterPasskey(
    call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard let args = call.arguments as? [String: Any],
          let rpId = args["relyingPartyId"] as? String,
          let userName = args["userName"] as? String,
          let displayName = args["userDisplayName"] as? String,
          let userId = args["userId"] as? FlutterStandardTypedData,
          let challenge = args["challenge"] as? FlutterStandardTypedData
    else {
      result(FlutterError(
        code: "INVALID_ARGUMENT",
        message: "Missing passkey registration parameters",
        details: nil
      ))
      return
    }

    let requireUv = args["requireUserVerification"] as? Bool ?? true

    let provider =
      ASAuthorizationPlatformPublicKeyCredentialProvider(
        relyingPartyIdentifier: rpId
      )
    let request = provider.createCredentialRegistrationRequest(
      challenge: challenge.data,
      name: userName,
      userID: userId.data
    )
    request.displayName = displayName
    request.userVerificationPreference = requireUv
      ? .required : .preferred

    let controller = ASAuthorizationController(
      authorizationRequests: [request]
    )
    controller.delegate = self
    controller.presentationContextProvider = self
    pendingPasskeyResult = result
    controller.performRequests()
  }

  // MARK: - assertPasskey

  func handleAssertPasskey(
    call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard let args = call.arguments as? [String: Any],
          let rpId = args["relyingPartyId"] as? String,
          let challenge = args["challenge"] as? FlutterStandardTypedData
    else {
      result(FlutterError(
        code: "INVALID_ARGUMENT",
        message: "Missing passkey assertion parameters",
        details: nil
      ))
      return
    }

    let requireUv = args["requireUserVerification"] as? Bool ?? true
    let allowedIds = args["allowedCredentialIds"] as? [String]

    let provider =
      ASAuthorizationPlatformPublicKeyCredentialProvider(
        relyingPartyIdentifier: rpId
      )
    let request = provider.createCredentialAssertionRequest(
      challenge: challenge.data
    )
    request.userVerificationPreference = requireUv
      ? .required : .preferred

    if let allowedIds = allowedIds {
      request.allowedCredentials = allowedIds.compactMap { credId in
        guard let data = Data(
          base64Encoded: Self.base64UrlToBase64(credId)
        ) else { return nil }
        return ASAuthorizationPlatformPublicKeyCredentialDescriptor(
          credentialID: data
        )
      }
    }

    let controller = ASAuthorizationController(
      authorizationRequests: [request]
    )
    controller.delegate = self
    controller.presentationContextProvider = self
    pendingPasskeyResult = result
    controller.performRequests()
  }

  // MARK: - Shared Helpers

  func extractPublicKeyMap(
    publicKey: SecKey,
    keyAlias: String
  ) throws -> [String: Any] {
    var error: Unmanaged<CFError>?
    guard let data = SecKeyCopyExternalRepresentation(
      publicKey, &error
    ) as Data? else {
      throw PlatformError(
        code: "KEY_EXPORT_ERROR",
        message: "Failed to export public key"
      )
    }

    guard data.count == 65 && data[0] == 0x04 else {
      throw PlatformError(
        code: "KEY_FORMAT_ERROR",
        message: "Unexpected public key format (expected 65-byte SEC1)"
      )
    }

    return [
      "keyAlias": keyAlias,
      "x": FlutterStandardTypedData(bytes: data.subdata(in: 1..<33)),
      "y": FlutterStandardTypedData(bytes: data.subdata(in: 33..<65)),
      "uncompressedBytes": FlutterStandardTypedData(bytes: data),
      "isolationLevel": "secureEnclave"
    ]
  }

  static func mapSigningError(_ cfError: CFError?) -> PlatformError {
    let message = cfError.map { ($0 as Error).localizedDescription }
      ?? "Signing failed"
    if let cfError = cfError {
      let nsError = cfError as Error as NSError
      if nsError.domain == LAErrorDomain {
        switch nsError.code {
        case LAError.userCancel.rawValue:
          return PlatformError(
            code: "USER_CANCELLED",
            message: "User cancelled biometric authentication"
          )
        case LAError.biometryLockout.rawValue:
          return PlatformError(
            code: "BIOMETRICS_UNAVAILABLE",
            message: "Biometrics locked out"
          )
        default:
          break
        }
      }
    }
    return PlatformError(code: "SIGNING_ERROR", message: message)
  }

  func flutterError(from error: Error) -> FlutterError {
    if let platformError = error as? PlatformError {
      return FlutterError(
        code: platformError.code,
        message: platformError.message,
        details: nil
      )
    }
    return FlutterError(
      code: "UNKNOWN_ERROR",
      message: error.localizedDescription,
      details: nil
    )
  }
}

// MARK: - DER Parsing

enum DerParser {
  static func parseSignature(_ der: Data) throws -> (Data, Data) {
    guard der.count >= 8, der[0] == 0x30 else {
      throw PlatformError(
        code: "DER_PARSE_ERROR",
        message: "Invalid DER signature format"
      )
    }

    var offset = 2
    let rScalar = try readInteger(der, offset: &offset)
    let sScalar = try readInteger(der, offset: &offset)
    return (rScalar, sScalar)
  }

  static func readInteger(
    _ der: Data,
    offset: inout Int
  ) throws -> Data {
    guard offset + 2 <= der.count, der[offset] == 0x02 else {
      throw PlatformError(
        code: "DER_PARSE_ERROR",
        message: "Expected INTEGER tag at offset \(offset)"
      )
    }
    let length = Int(der[offset + 1])
    offset += 2

    guard offset + length <= der.count else {
      throw PlatformError(
        code: "DER_PARSE_ERROR",
        message: "INTEGER overflows DER buffer"
      )
    }

    var start = offset
    let end = offset + length
    offset = end

    while start < end && der[start] == 0x00 { start += 1 }
    let stripped = end - start
    guard stripped <= 32 else {
      throw PlatformError(
        code: "DER_PARSE_ERROR",
        message: "INTEGER value too large"
      )
    }

    var result = Data(count: 32)
    result.replaceSubrange((32 - stripped)..<32, with: der[start..<end])
    return result
  }
}

/// Internal error type for structured error passing.
struct PlatformError: Error {
  let code: String
  let message: String
}
