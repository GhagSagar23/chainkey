import Flutter
import UIKit
import AuthenticationServices

// MARK: - ASAuthorizationControllerDelegate

extension ChainkeyIosPlugin: ASAuthorizationControllerDelegate {
  public func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithAuthorization authorization: ASAuthorization
  ) {
    guard let result = pendingPasskeyResult else { return }
    pendingPasskeyResult = nil

    if let registration = authorization.credential
      as? ASAuthorizationPlatformPublicKeyCredentialRegistration {
      handleRegistrationResponse(registration, result: result)
    } else if let assertion = authorization.credential
      as? ASAuthorizationPlatformPublicKeyCredentialAssertion {
      handleAssertionResponse(assertion, result: result)
    } else {
      result(FlutterError(
        code: "PASSKEY_ERROR",
        message: "Unexpected credential type",
        details: nil
      ))
    }
  }

  public func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithError error: Error
  ) {
    guard let result = pendingPasskeyResult else { return }
    pendingPasskeyResult = nil
    result(Self.mapPasskeyError(error))
  }

  static func mapPasskeyError(_ error: Error) -> FlutterError {
    let nsError = error as NSError
    guard nsError.domain == ASAuthorizationError.errorDomain else {
      return FlutterError(
        code: "PASSKEY_ERROR",
        message: error.localizedDescription,
        details: nil
      )
    }
    switch ASAuthorizationError.Code(rawValue: nsError.code) {
    case .canceled:
      return FlutterError(
        code: "USER_CANCELLED",
        message: "User cancelled passkey operation",
        details: nil
      )
    default:
      return FlutterError(
        code: "PASSKEY_ERROR",
        message: error.localizedDescription,
        details: nil
      )
    }
  }

  func handleRegistrationResponse(
    _ reg: ASAuthorizationPlatformPublicKeyCredentialRegistration,
    result: @escaping FlutterResult
  ) {
    let credentialId = Self.base64ToBase64Url(reg.credentialID)
    let attestation = reg.rawAttestationObject ?? Data()
    let clientData = reg.rawClientDataJSON

    // ponytail: stub public key — real key is inside the CBOR
    // attestation object, extracted server-side.
    let stubX = FlutterStandardTypedData(bytes: Data(count: 32))
    let stubY = FlutterStandardTypedData(bytes: Data(count: 32))
    var stubUncompressed = Data(count: 65)
    stubUncompressed[0] = 0x04

    let publicKeyMap: [String: Any] = [
      "keyAlias": credentialId,
      "x": stubX,
      "y": stubY,
      "uncompressedBytes": FlutterStandardTypedData(
        bytes: stubUncompressed
      ),
      "isolationLevel": "secureEnclave"
    ]

    result([
      "credentialId": credentialId,
      "rawAttestationObject": FlutterStandardTypedData(
        bytes: attestation
      ),
      "rawClientDataJson": FlutterStandardTypedData(bytes: clientData),
      "publicKey": publicKeyMap,
      "isolationLevel": "secureEnclave"
    ] as [String: Any])
  }

  func handleAssertionResponse(
    _ assertion: ASAuthorizationPlatformPublicKeyCredentialAssertion,
    result: @escaping FlutterResult
  ) {
    let credentialId = Self.base64ToBase64Url(assertion.credentialID)
    guard let authData = assertion.rawAuthenticatorData as Data?,
          let clientData = assertion.rawClientDataJSON as Data?,
          let derSig = assertion.signature as Data? else {
      result(FlutterError(
        code: "PASSKEY_ERROR",
        message: "Assertion response missing required fields",
        details: nil
      ))
      return
    }

    do {
      let (rVal, sVal) = try DerParser.parseSignature(derSig)
      let sigMap: [String: Any] = [
        "r": FlutterStandardTypedData(bytes: rVal),
        "s": FlutterStandardTypedData(bytes: sVal),
        "rawDerSignature": FlutterStandardTypedData(bytes: derSig)
      ]

      var responseMap: [String: Any] = [
        "credentialId": credentialId,
        "authenticatorData": FlutterStandardTypedData(bytes: authData),
        "clientDataJson": FlutterStandardTypedData(bytes: clientData),
        "signature": sigMap
      ]

      if let userHandle = assertion.userID {
        responseMap["userHandle"] = FlutterStandardTypedData(
          bytes: userHandle
        )
      }

      result(responseMap)
    } catch {
      result(flutterError(from: error))
    }
  }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension ChainkeyIosPlugin:
  ASAuthorizationControllerPresentationContextProviding {
  public func presentationAnchor(
    for controller: ASAuthorizationController
  ) -> ASPresentationAnchor {
    guard let scene = UIApplication.shared.connectedScenes
      .first(where: { $0.activationState == .foregroundActive })
      as? UIWindowScene,
      let window = scene.windows.first(where: { $0.isKeyWindow })
    else {
      return UIWindow()
    }
    return window
  }
}

// MARK: - Base64URL Helpers

extension ChainkeyIosPlugin {
  static func base64UrlToBase64(_ base64Url: String) -> String {
    var base64 = base64Url
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    let remainder = base64.count % 4
    if remainder > 0 {
      base64.append(
        contentsOf: repeatElement("=", count: 4 - remainder)
      )
    }
    return base64
  }

  static func base64ToBase64Url(_ data: Data) -> String {
    return data.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}
