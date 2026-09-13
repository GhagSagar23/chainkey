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
      if let args = call.arguments as? [String: Any],
         let level = args["level"] as? String {
        if level == "secureEnclave" {
          // Check Secure Enclave availability via LAContext
          let context = LAContext()
          var error: NSError?
          let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
          result(canEvaluate)
        } else if level == "software" {
          result(true)
        } else {
          result(false)
        }
      } else {
        result(false)
      }
    case "generateHardwareKey":
      result(FlutterMethodNotImplemented)
    case "signWithHardwareKey":
      result(FlutterMethodNotImplemented)
    case "deleteHardwareKey":
      result(FlutterMethodNotImplemented)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
