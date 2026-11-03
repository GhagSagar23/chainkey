package dev.chainkey.chainkey_android

import android.util.Base64
import androidx.credentials.CreatePublicKeyCredentialRequest
import androidx.credentials.CredentialManager
import androidx.credentials.GetCredentialRequest
import androidx.credentials.GetPublicKeyCredentialOption
import androidx.credentials.PublicKeyCredential
import androidx.credentials.exceptions.CreateCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.NoCredentialException
import androidx.fragment.app.FragmentActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject

internal fun ChainkeyAndroidPlugin.handleRegisterPasskey(
    call: MethodCall,
    result: Result,
) {
    val rpId = call.argument<String>("relyingPartyId")
    val userName = call.argument<String>("userName")
    val userDisplayName = call.argument<String>("userDisplayName")
    val userId = call.argument<ByteArray>("userId")
    val challenge = call.argument<ByteArray>("challenge")

    if (rpId == null || userName == null || userDisplayName == null ||
        userId == null || challenge == null
    ) {
        result.error(
            "INVALID_ARGUMENT",
            "Missing passkey registration parameters",
            null,
        )
        return
    }

    val requireUv = call.argument<Boolean>("requireUserVerification") ?: true
    val fragmentActivity = getActivity()
    if (fragmentActivity == null) {
        result.error("NO_ACTIVITY", "No activity for CredentialManager", null)
        return
    }

    val requestJson = buildRegistrationJson(
        rpId, userName, userDisplayName, userId, challenge, requireUv,
    )

    val credentialManager = CredentialManager.create(fragmentActivity)
    val request = CreatePublicKeyCredentialRequest(requestJson)

    CoroutineScope(Dispatchers.Main).launch {
        try {
            val response = credentialManager.createCredential(
                fragmentActivity,
                request,
            )
            val pkCred = response as? PublicKeyCredential
            if (pkCred == null) {
                result.error(
                    "PASSKEY_ERROR",
                    "Unexpected credential type",
                    null,
                )
                return@launch
            }
            val responseMap = parseRegistrationResponse(pkCred)
            result.success(responseMap)
        } catch (e: CreateCredentialCancellationException) {
            result.error("USER_CANCELLED", "User cancelled passkey registration", null)
        } catch (e: Exception) {
            result.error("PASSKEY_ERROR", e.message, null)
        }
    }
}

internal fun ChainkeyAndroidPlugin.handleAssertPasskey(
    call: MethodCall,
    result: Result,
) {
    val rpId = call.argument<String>("relyingPartyId")
    val challenge = call.argument<ByteArray>("challenge")

    if (rpId == null || challenge == null) {
        result.error(
            "INVALID_ARGUMENT",
            "Missing passkey assertion parameters",
            null,
        )
        return
    }

    val requireUv = call.argument<Boolean>("requireUserVerification") ?: true
    val allowedIds = call.argument<List<String>>("allowedCredentialIds")
    val fragmentActivity = getActivity()
    if (fragmentActivity == null) {
        result.error("NO_ACTIVITY", "No activity for CredentialManager", null)
        return
    }

    val requestJson = buildAssertionJson(rpId, challenge, requireUv, allowedIds)
    val credentialManager = CredentialManager.create(fragmentActivity)
    val option = GetPublicKeyCredentialOption(requestJson)
    val request = GetCredentialRequest(listOf(option))

    CoroutineScope(Dispatchers.Main).launch {
        try {
            val response = credentialManager.getCredential(
                fragmentActivity,
                request,
            )
            val pkCred = response.credential as? PublicKeyCredential
            if (pkCred == null) {
                result.error(
                    "PASSKEY_ERROR",
                    "Unexpected credential type",
                    null,
                )
                return@launch
            }
            val responseMap = parseAssertionResponse(pkCred)
            result.success(responseMap)
        } catch (e: GetCredentialCancellationException) {
            result.error("USER_CANCELLED", "User cancelled passkey assertion", null)
        } catch (e: NoCredentialException) {
            result.error("PASSKEY_ERROR", "No matching credentials found", null)
        } catch (e: Exception) {
            result.error("PASSKEY_ERROR", e.message, null)
        }
    }
}

private fun base64UrlEncode(data: ByteArray): String =
    Base64.encodeToString(data, Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP)

private fun base64UrlDecode(str: String): ByteArray =
    Base64.decode(str, Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP)

private fun buildRegistrationJson(
    rpId: String,
    userName: String,
    userDisplayName: String,
    userId: ByteArray,
    challenge: ByteArray,
    requireUv: Boolean,
): String {
    val json = JSONObject().apply {
        put("rp", JSONObject().apply {
            put("id", rpId)
            put("name", rpId)
        })
        put("user", JSONObject().apply {
            put("id", base64UrlEncode(userId))
            put("name", userName)
            put("displayName", userDisplayName)
        })
        put("challenge", base64UrlEncode(challenge))
        put("pubKeyCredParams", JSONArray().apply {
            put(JSONObject().apply {
                put("type", "public-key")
                put("alg", -7) // ES256
            })
        })
        put("authenticatorSelection", JSONObject().apply {
            put("authenticatorAttachment", "platform")
            put("residentKey", "required")
            put(
                "userVerification",
                if (requireUv) "required" else "preferred",
            )
        })
        put("attestation", "none")
    }
    return json.toString()
}

private fun buildAssertionJson(
    rpId: String,
    challenge: ByteArray,
    requireUv: Boolean,
    allowedIds: List<String>?,
): String {
    val json = JSONObject().apply {
        put("challenge", base64UrlEncode(challenge))
        put("rpId", rpId)
        put(
            "userVerification",
            if (requireUv) "required" else "preferred",
        )
        if (!allowedIds.isNullOrEmpty()) {
            put("allowCredentials", JSONArray().apply {
                for (credId in allowedIds) {
                    put(JSONObject().apply {
                        put("type", "public-key")
                        put("id", credId)
                    })
                }
            })
        }
    }
    return json.toString()
}

private fun parseRegistrationResponse(
    credential: PublicKeyCredential,
): Map<String, Any> {
    val json = JSONObject(credential.authenticationResponseJson)
    val responseObj = json.getJSONObject("response")

    val credentialId = json.getString("id")
    val attestationB64 = responseObj.getString("attestationObject")
    val clientDataB64 = responseObj.getString("clientDataJSON")

    val attestationBytes = base64UrlDecode(attestationB64)
    val clientDataBytes = base64UrlDecode(clientDataB64)

    // ponytail: stub public key — real key is in the CBOR attestation,
    // extracted server-side.
    val stubX = ByteArray(32)
    val stubY = ByteArray(32)
    val stubUncompressed = ByteArray(65).apply { this[0] = 0x04 }

    val publicKeyMap = mapOf(
        "keyAlias" to credentialId,
        "x" to stubX,
        "y" to stubY,
        "uncompressedBytes" to stubUncompressed,
        "isolationLevel" to "software",
    )

    return mapOf(
        "credentialId" to credentialId,
        "rawAttestationObject" to attestationBytes,
        "rawClientDataJson" to clientDataBytes,
        "publicKey" to publicKeyMap,
        "isolationLevel" to "software",
    )
}

private fun parseAssertionResponse(
    credential: PublicKeyCredential,
): Map<String, Any> {
    val json = JSONObject(credential.authenticationResponseJson)
    val responseObj = json.getJSONObject("response")

    val credentialId = json.getString("id")
    val authDataB64 = responseObj.getString("authenticatorData")
    val clientDataB64 = responseObj.getString("clientDataJSON")
    val signatureB64 = responseObj.getString("signature")

    val authDataBytes = base64UrlDecode(authDataB64)
    val clientDataBytes = base64UrlDecode(clientDataB64)
    val signatureBytes = base64UrlDecode(signatureB64)

    val (rBytes, sBytes) = parseDerSignature(signatureBytes)

    val signatureMap = mapOf(
        "r" to rBytes,
        "s" to sBytes,
        "rawDerSignature" to signatureBytes,
    )

    val responseMap = mutableMapOf<String, Any>(
        "credentialId" to credentialId,
        "authenticatorData" to authDataBytes,
        "clientDataJson" to clientDataBytes,
        "signature" to signatureMap,
    )

    if (responseObj.has("userHandle")) {
        val userHandleB64 = responseObj.getString("userHandle")
        responseMap["userHandle"] = base64UrlDecode(userHandleB64)
    }

    return responseMap
}

private fun parseDerSignature(der: ByteArray): Pair<ByteArray, ByteArray> {
    require(der.size >= 8 && der[0] == 0x30.toByte()) { "Invalid DER signature" }

    var offset = 2
    val rResult = readDerInteger(der, offset)
    offset = rResult.second
    val sResult = readDerInteger(der, offset)

    return Pair(rResult.first, sResult.first)
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
    while (start < valueEnd && der[start] == 0x00.toByte()) { start++ }
    val stripped = valueEnd - start
    require(stripped <= 32) { "INTEGER value too large" }

    val result = ByteArray(32)
    System.arraycopy(der, start, result, 32 - stripped, stripped)
    return Pair(result, valueEnd)
}
