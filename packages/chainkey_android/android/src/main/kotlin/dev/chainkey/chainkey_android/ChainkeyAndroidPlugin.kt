package dev.chainkey.chainkey_android

import android.app.Activity
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.Signature
import java.security.interfaces.ECPublicKey
import java.security.spec.ECGenParameterSpec

/** ChainkeyAndroidPlugin */
class ChainkeyAndroidPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private var activity: FragmentActivity? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "dev.chainkey/chainkey_android")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "isHardwareIsolationSupported" -> handleIsHardwareIsolationSupported(call, result)
            "generateHardwareKey" -> handleGenerateHardwareKey(call, result)
            "signWithHardwareKey" -> handleSignWithHardwareKey(call, result)
            "deleteHardwareKey" -> handleDeleteHardwareKey(call, result)
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    // region ActivityAware

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity as? FragmentActivity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity as? FragmentActivity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    // endregion

    // region isHardwareIsolationSupported

    private fun handleIsHardwareIsolationSupported(call: MethodCall, result: Result) {
        val level = call.argument<String>("level")
        when (level) {
            "strongBox" -> result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.P)
            "tee", "software" -> result.success(true)
            else -> result.success(false)
        }
    }

    // endregion

    // region generateHardwareKey

    private fun handleGenerateHardwareKey(call: MethodCall, result: Result) {
        val keyAlias = call.argument<String>("keyAlias")
        if (keyAlias == null) {
            result.error("INVALID_ARGUMENT", "Missing keyAlias", null)
            return
        }
        val requireUserPresence = call.argument<Boolean>("requireUserPresence") ?: true

        try {
            val publicKeyMap = generateKeyStoreKey(keyAlias, requireUserPresence)
            result.success(publicKeyMap)
        } catch (e: Exception) {
            result.error("KEY_GENERATION_ERROR", e.message, null)
        }
    }

    private fun generateKeyStoreKey(
        keyAlias: String,
        requireUserPresence: Boolean,
    ): Map<String, Any> {
        val keyStore = KeyStore.getInstance("AndroidKeyStore")
        keyStore.load(null)
        if (keyStore.containsAlias(keyAlias)) {
            keyStore.deleteEntry(keyAlias)
        }

        val specBuilder =
            KeyGenParameterSpec
                .Builder(
                    keyAlias,
                    KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY,
                ).apply {
                    setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
                    setDigests(KeyProperties.DIGEST_NONE, KeyProperties.DIGEST_SHA256)
                    if (requireUserPresence) {
                        setUserAuthenticationRequired(true)
                        setInvalidatedByBiometricEnrollment(false)
                    }
                }

        val keyPairGenerator =
            KeyPairGenerator.getInstance(
                KeyProperties.KEY_ALGORITHM_EC,
                "AndroidKeyStore",
            )

        var isolationLevel = "tee"

        // Attempt StrongBox on API 28+; fall back to TEE on any failure
        // (some devices accept the spec but fail at generateKeyPair)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            try {
                specBuilder.setIsStrongBoxBacked(true)
                keyPairGenerator.initialize(specBuilder.build())
                val keyPair = keyPairGenerator.generateKeyPair()
                val ecPublicKey = keyPair.public as ECPublicKey
                return extractPublicKeyMap(ecPublicKey, keyAlias, "strongBox")
            } catch (_: Exception) {
                // StrongBox unavailable or failed; clean up and retry with TEE
                if (keyStore.containsAlias(keyAlias)) {
                    keyStore.deleteEntry(keyAlias)
                }
                specBuilder.setIsStrongBoxBacked(false)
            }
        }

        keyPairGenerator.initialize(specBuilder.build())
        val keyPair = keyPairGenerator.generateKeyPair()
        val ecPublicKey = keyPair.public as ECPublicKey

        return extractPublicKeyMap(ecPublicKey, keyAlias, isolationLevel)
    }

    // endregion

    // region signWithHardwareKey

    @Suppress("UNCHECKED_CAST")
    private fun handleSignWithHardwareKey(call: MethodCall, result: Result) {
        val keyAlias = call.argument<String>("keyAlias")
        val hash32 = call.argument<ByteArray>("hash32")

        if (keyAlias == null || hash32 == null) {
            result.error("INVALID_ARGUMENT", "Missing keyAlias or hash32", null)
            return
        }
        if (hash32.size != 32) {
            result.error("INVALID_ARGUMENT", "hash32 must be exactly 32 bytes", null)
            return
        }

        val promptOptions = call.argument<Map<String, Any>>("promptOptions")

        try {
            val signature = prepareSignature(keyAlias)

            if (promptOptions != null && activity != null) {
                signWithBiometricPrompt(signature, hash32, promptOptions, result)
            } else {
                // No prompt customization or no activity — use direct signing
                // (triggers system biometric prompt for auth-protected keys)
                val signedResult = executeSign(signature, hash32)
                result.success(signedResult)
            }
        } catch (e: KeyPermanentlyInvalidatedException) {
            result.error(
                "KEY_PERMANENTLY_INVALIDATED",
                "Key has been permanently invalidated: ${e.message}",
                null,
            )
        } catch (e: Exception) {
            result.error("SIGNING_ERROR", e.message, null)
        }
    }

    private fun prepareSignature(keyAlias: String): Signature {
        val keyStore = KeyStore.getInstance("AndroidKeyStore")
        keyStore.load(null)

        val privateKey =
            keyStore.getKey(keyAlias, null)
                ?: throw IllegalStateException("No key found for alias: $keyAlias")

        val signature = Signature.getInstance("NONEwithECDSA")
        signature.initSign(privateKey as java.security.PrivateKey)
        return signature
    }

    private fun signWithBiometricPrompt(
        signature: Signature,
        hash32: ByteArray,
        promptOptions: Map<String, Any>,
        result: Result,
    ) {
        val fragmentActivity =
            activity ?: run {
                result.error("NO_ACTIVITY", "No activity available for biometric prompt", null)
                return
            }

        val title = promptOptions["title"] as? String ?: "Biometric Authentication"
        val subtitle = promptOptions["subtitle"] as? String
        val description = promptOptions["description"] as? String
        val negativeText = promptOptions["negativeButtonText"] as? String ?: "Cancel"

        val promptInfoBuilder =
            BiometricPrompt.PromptInfo
                .Builder()
                .setTitle(title)
                .setNegativeButtonText(negativeText)

        if (subtitle != null) promptInfoBuilder.setSubtitle(subtitle)
        if (description != null) promptInfoBuilder.setDescription(description)

        val confirmationRequired = promptOptions["confirmationRequired"] as? Boolean ?: true
        promptInfoBuilder.setConfirmationRequired(confirmationRequired)

        val executor = ContextCompat.getMainExecutor(fragmentActivity)
        val cryptoObject = BiometricPrompt.CryptoObject(signature)

        val biometricPrompt =
            BiometricPrompt(
                fragmentActivity,
                executor,
                object : BiometricPrompt.AuthenticationCallback() {
                    override fun onAuthenticationSucceeded(authResult: BiometricPrompt.AuthenticationResult) {
                        try {
                            val authedSig =
                                authResult.cryptoObject?.signature
                                    ?: throw IllegalStateException("CryptoObject lost after auth")
                            val signedResult = executeSign(authedSig, hash32)
                            result.success(signedResult)
                        } catch (e: Exception) {
                            result.error("SIGNING_ERROR", e.message, null)
                        }
                    }

                    override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                        val code =
                            when (errorCode) {
                                BiometricPrompt.ERROR_USER_CANCELED,
                                BiometricPrompt.ERROR_NEGATIVE_BUTTON,
                                -> "USER_CANCELLED"

                                BiometricPrompt.ERROR_LOCKOUT,
                                BiometricPrompt.ERROR_LOCKOUT_PERMANENT,
                                -> "BIOMETRICS_UNAVAILABLE"

                                else -> "BIOMETRIC_ERROR"
                            }
                        result.error(code, errString.toString(), null)
                    }

                    override fun onAuthenticationFailed() {
                        // Called on each failed attempt; prompt stays open.
                        // No action needed — Android retries automatically.
                    }
                },
            )

        biometricPrompt.authenticate(promptInfoBuilder.build(), cryptoObject)
    }

    private fun executeSign(signature: Signature, hash32: ByteArray): Map<String, Any> {
        signature.update(hash32)
        val derBytes = signature.sign()
        val (rBytes, sBytes) = parseDerSignature(derBytes)
        return mapOf(
            "r" to rBytes,
            "s" to sBytes,
            "rawDerSignature" to derBytes,
        )
    }

    // endregion

    // region deleteHardwareKey

    private fun handleDeleteHardwareKey(call: MethodCall, result: Result) {
        val keyAlias = call.argument<String>("keyAlias")
        if (keyAlias == null) {
            result.error("INVALID_ARGUMENT", "Missing keyAlias", null)
            return
        }

        try {
            val keyStore = KeyStore.getInstance("AndroidKeyStore")
            keyStore.load(null)
            if (keyStore.containsAlias(keyAlias)) {
                keyStore.deleteEntry(keyAlias)
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("KEYSTORE_ERROR", e.message, null)
        }
    }

    // endregion

    // region Helpers

    private fun extractPublicKeyMap(
        ecPublicKey: ECPublicKey,
        keyAlias: String,
        isolationLevel: String,
    ): Map<String, Any> {
        val point = ecPublicKey.w
        val xBytes = point.affineX.toByteArray().padOrTrimTo32()
        val yBytes = point.affineY.toByteArray().padOrTrimTo32()

        val uncompressed = ByteArray(65)
        uncompressed[0] = 0x04
        System.arraycopy(xBytes, 0, uncompressed, 1, 32)
        System.arraycopy(yBytes, 0, uncompressed, 33, 32)

        return mapOf(
            "keyAlias" to keyAlias,
            "x" to xBytes,
            "y" to yBytes,
            "uncompressedBytes" to uncompressed,
            "isolationLevel" to isolationLevel,
        )
    }

    private fun parseDerSignature(der: ByteArray): Pair<ByteArray, ByteArray> {
        require(der.size >= 8 && der[0] == 0x30.toByte()) { "Invalid DER signature" }

        var offset = 2
        val rBytes = readDerInteger(der, offset)
        offset = rBytes.second
        val sBytes = readDerInteger(der, offset)

        return Pair(rBytes.first, sBytes.first)
    }

    private fun readDerInteger(der: ByteArray, offset: Int): Pair<ByteArray, Int> {
        require(offset + 2 <= der.size && der[offset] == 0x02.toByte()) {
            "Expected INTEGER tag at offset $offset"
        }
        val length = der[offset + 1].toInt() and 0xFF
        val valueStart = offset + 2
        val valueEnd = valueStart + length
        require(valueEnd <= der.size) { "INTEGER overflows buffer" }

        var start = valueStart
        while (start < valueEnd && der[start] == 0x00.toByte()) {
            start++
        }
        val stripped = valueEnd - start
        require(stripped <= 32) { "INTEGER value too large" }

        val result = ByteArray(32)
        System.arraycopy(der, start, result, 32 - stripped, stripped)
        return Pair(result, valueEnd)
    }

    /**
     * BigInteger.toByteArray() may return 33 bytes (leading 0x00 for sign)
     * or fewer than 32; this normalizes to exactly 32 bytes.
     */
    private fun ByteArray.padOrTrimTo32(): ByteArray =
        when {
            this.size == 32 -> this
            this.size > 32 -> this.copyOfRange(this.size - 32, this.size)
            else -> ByteArray(32 - this.size) + this
        }

    // endregion
}
