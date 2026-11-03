package dev.chainkey.chainkey_android

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import io.flutter.embedding.engine.plugins.FlutterPlugin
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
class ChainkeyAndroidPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel

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
        // Delete existing key if present
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

        // StrongBox requires API 28+; fall back to TEE silently
        var isolationLevel = "tee"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            try {
                specBuilder.setIsStrongBoxBacked(true)
                isolationLevel = "strongBox"
            } catch (_: Exception) {
                // StrongBox not available on this device, continue with TEE
                isolationLevel = "tee"
            }
        }

        val keyPairGenerator =
            KeyPairGenerator.getInstance(
                KeyProperties.KEY_ALGORITHM_EC,
                "AndroidKeyStore",
            )

        try {
            keyPairGenerator.initialize(specBuilder.build())
        } catch (e: Exception) {
            // StrongBox init failed; retry without it
            if (isolationLevel == "strongBox" && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                specBuilder.setIsStrongBoxBacked(false)
                isolationLevel = "tee"
                keyPairGenerator.initialize(specBuilder.build())
            } else {
                throw e
            }
        }

        val keyPair = keyPairGenerator.generateKeyPair()
        val ecPublicKey = keyPair.public as ECPublicKey

        return extractPublicKeyMap(ecPublicKey, keyAlias, isolationLevel)
    }

    // endregion

    // region signWithHardwareKey

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

        try {
            val signatureMap = signWithKeyStore(keyAlias, hash32)
            result.success(signatureMap)
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

    private fun signWithKeyStore(keyAlias: String, hash32: ByteArray): Map<String, Any> {
        val keyStore = KeyStore.getInstance("AndroidKeyStore")
        keyStore.load(null)

        val privateKey =
            keyStore.getKey(keyAlias, null)
                ?: throw IllegalStateException("No key found for alias: $keyAlias")

        // NONEwithECDSA signs raw bytes without hashing
        val signature = Signature.getInstance("NONEwithECDSA")
        signature.initSign(privateKey as java.security.PrivateKey)
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

        // Strip leading zero padding
        var start = valueStart
        while (start < valueEnd && der[start] == 0x00.toByte()) {
            start++
        }
        val stripped = valueEnd - start
        require(stripped <= 32) { "INTEGER value too large" }

        // Left-pad to exactly 32 bytes
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
