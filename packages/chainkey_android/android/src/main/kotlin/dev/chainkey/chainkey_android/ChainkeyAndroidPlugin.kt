package dev.chainkey.chainkey_android

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** ChainkeyAndroidPlugin */
class ChainkeyAndroidPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "dev.chainkey/chainkey_android")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "isHardwareIsolationSupported" -> {
                // Initial baseline capability check
                val level = call.argument<String>("level")
                if (level == "tee" || level == "software") {
                    result.success(true)
                } else {
                    result.success(false)
                }
            }
            "generateHardwareKey" -> {
                result.notImplemented()
            }
            "signWithHardwareKey" -> {
                result.notImplemented()
            }
            "deleteHardwareKey" -> {
                result.notImplemented()
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
