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

    if (rpId == null ||
        userName == null ||
        userDisplayName == null ||
        userId == null ||
        challenge == null
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

    val requestJson =
        buildRegistrationJson(
            rpId,
            userName,
            userDisplayName,
            userId,
            challenge,
            requireUv,
        )

    val credentialManager = CredentialManager.create(fragmentActivity)
    val request = CreatePublicKeyCredentialRequest(requestJson)

    CoroutineScope(Dispatchers.Main).launch {
        try {
            val response =
                credentialManager.createCredential(
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
            val response =
                credentialManager.getCredential(
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
    val rpObj = JSONObject()
    rpObj.put("id", rpId)
    rpObj.put("name", rpId)

    val userObj = JSONObject()
    userObj.put("id", base64UrlEncode(userId))
    userObj.put("name", userName)
    userObj.put("displayName", userDisplayName)

    val es256 = JSONObject()
    es256.put("type", "public-key")
    es256.put("alg", -7)

    val uvStr = if (requireUv) "required" else "preferred"
    val authSelection = JSONObject()
    authSelection.put("authenticatorAttachment", "platform")
    authSelection.put("residentKey", "required")
    authSelection.put("userVerification", uvStr)

    val json = JSONObject()
    json.put("rp", rpObj)
    json.put("user", userObj)
    json.put("challenge", base64UrlEncode(challenge))
    json.put("pubKeyCredParams", JSONArray().put(es256))
    json.put("authenticatorSelection", authSelection)
    json.put("attestation", "none")
    return json.toString()
}

private fun buildAssertionJson(
    rpId: String,
    challenge: ByteArray,
    requireUv: Boolean,
    allowedIds: List<String>?,
): String {
    val uvStr = if (requireUv) "required" else "preferred"
    val json = JSONObject()
    json.put("challenge", base64UrlEncode(challenge))
    json.put("rpId", rpId)
    json.put("userVerification", uvStr)

    if (!allowedIds.isNullOrEmpty()) {
        val arr = JSONArray()
        for (credId in allowedIds) {
            val entry = JSONObject()
            entry.put("type", "public-key")
            entry.put("id", credId)
            arr.put(entry)
        }
        json.put("allowCredentials", arr)
    }
    return json.toString()
}

private fun parseRegistrationResponse(credential: PublicKeyCredential): Map<String, Any> {
    val json = JSONObject(credential.authenticationResponseJson)
    val responseObj = json.getJSONObject("response")

    val credentialId = json.getString("id")
    val attestationBytes = base64UrlDecode(responseObj.getString("attestationObject"))
    val clientDataBytes = base64UrlDecode(responseObj.getString("clientDataJSON"))

    // ponytail: stub public key — real key is in the CBOR attestation,
    // extracted server-side.
    val stubUncompressed = ByteArray(65).apply { this[0] = 0x04 }

    val publicKeyMap =
        mapOf(
            "keyAlias" to credentialId,
            "x" to ByteArray(32),
            "y" to ByteArray(32),
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

private fun parseAssertionResponse(credential: PublicKeyCredential): Map<String, Any> {
    val json = JSONObject(credential.authenticationResponseJson)
    val responseObj = json.getJSONObject("response")

    val credentialId = json.getString("id")
    val authDataBytes = base64UrlDecode(responseObj.getString("authenticatorData"))
    val clientDataBytes = base64UrlDecode(responseObj.getString("clientDataJSON"))
    val signatureBytes = base64UrlDecode(responseObj.getString("signature"))

    val (rBytes, sBytes) = parseDerSignature(signatureBytes)

    val signatureMap =
        mapOf(
            "r" to rBytes,
            "s" to sBytes,
            "rawDerSignature" to signatureBytes,
        )

    val responseMap =
        mutableMapOf<String, Any>(
            "credentialId" to credentialId,
            "authenticatorData" to authDataBytes,
            "clientDataJson" to clientDataBytes,
            "signature" to signatureMap,
        )

    if (responseObj.has("userHandle")) {
        responseMap["userHandle"] = base64UrlDecode(responseObj.getString("userHandle"))
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

private fun readDerInteger(
    der: ByteArray,
    offset: Int,
): Pair<ByteArray, Int> {
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
