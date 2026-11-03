import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:chainkey_platform_interface/chainkey_platform_interface.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

/// The Web implementation of [ChainkeyPlatform].
class ChainkeyWeb extends ChainkeyPlatform {
  /// Registers this class as the default instance of [ChainkeyPlatform].
  static void registerWith(Registrar registrar) {
    ChainkeyPlatform.instance = ChainkeyWeb();
  }

  @override
  Future<P256PublicKey> generateHardwareKey({
    required String keyAlias,
    bool requireUserPresence = true,
  }) async {
    throw const PasskeyException(
      'Direct hardware keygen is not available on web; use WebAuthn passkey registration.',
    );
  }

  @override
  Future<P256Signature> signWithHardwareKey({
    required String keyAlias,
    required Uint8List hash32,
    BiometricPromptOptions? promptOptions,
  }) async {
    throw const PasskeyException(
      'Direct hardware signing is not available on web; use WebAuthn assertion.',
    );
  }

  @override
  Future<bool> deleteHardwareKey({required String keyAlias}) async {
    return false;
  }

  @override
  Future<bool> isHardwareIsolationSupported(
      HardwareIsolationLevel level) async {
    return level == HardwareIsolationLevel.software;
  }

  @override
  Future<PasskeyCredential> registerPasskey({
    required String relyingPartyId,
    required String userName,
    required String userDisplayName,
    required Uint8List userId,
    required Uint8List challenge,
    bool requireUserVerification = true,
  }) async {
    _assertWebAuthnSupported();

    final uvStr = requireUserVerification ? 'required' : 'preferred';

    final options = web.CredentialCreationOptions(
      publicKey: web.PublicKeyCredentialCreationOptions(
        rp: web.PublicKeyCredentialRpEntity(
            name: relyingPartyId, id: relyingPartyId),
        user: web.PublicKeyCredentialUserEntity(
          name: userName,
          id: _toBufferSource(userId),
          displayName: userDisplayName,
        ),
        challenge: _toBufferSource(challenge),
        pubKeyCredParams: [
          web.PublicKeyCredentialParameters(type: 'public-key', alg: -7),
        ].toJS,
        authenticatorSelection: web.AuthenticatorSelectionCriteria(
          authenticatorAttachment: 'platform',
          residentKey: 'required',
          userVerification: uvStr,
        ),
        attestation: 'none',
      ),
    );

    final web.PublicKeyCredential credential;
    try {
      final result =
          await web.window.navigator.credentials.create(options).toDart;
      credential = result! as web.PublicKeyCredential;
    } on Object catch (e) {
      _throwMapped(e, 'registration');
    }

    return _parseRegistrationResponse(credential);
  }

  @override
  Future<PasskeyAssertionResult> assertPasskey({
    required String relyingPartyId,
    required Uint8List challenge,
    List<String>? allowedCredentialIds,
    bool requireUserVerification = true,
  }) async {
    _assertWebAuthnSupported();

    final uvStr = requireUserVerification ? 'required' : 'preferred';

    final pkOptions = web.PublicKeyCredentialRequestOptions(
      challenge: _toBufferSource(challenge),
      rpId: relyingPartyId,
      userVerification: uvStr,
    );

    if (allowedCredentialIds != null && allowedCredentialIds.isNotEmpty) {
      pkOptions.allowCredentials = allowedCredentialIds
          .map(
            (id) => web.PublicKeyCredentialDescriptor(
              type: 'public-key',
              id: _toBufferSource(_base64UrlDecode(id)),
            ),
          )
          .toList()
          .toJS;
    }

    final options = web.CredentialRequestOptions(publicKey: pkOptions);

    final web.PublicKeyCredential credential;
    try {
      final result = await web.window.navigator.credentials.get(options).toDart;
      credential = result! as web.PublicKeyCredential;
    } on Object catch (e) {
      _throwMapped(e, 'assertion');
    }

    return _parseAssertionResponse(credential);
  }

  void _assertWebAuthnSupported() {
    if (!_isWebAuthnAvailable) {
      throw const PasskeyException(
        'WebAuthn is not supported in this browser',
      );
    }
  }

  bool get _isWebAuthnAvailable =>
      web.window.navigator.has('credentials') &&
      web.window.has('PublicKeyCredential');

  PasskeyCredential _parseRegistrationResponse(
    web.PublicKeyCredential credential,
  ) {
    final credentialId =
        _base64UrlEncode(credential.rawId.toDart.asUint8List());

    final attestation =
        credential.response as web.AuthenticatorAttestationResponse;
    final attestationObject =
        attestation.attestationObject.toDart.asUint8List();
    final clientDataJson = attestation.clientDataJSON.toDart.asUint8List();

    // ponytail: stub public key — real key is in CBOR attestation, extracted server-side
    P256PublicKey? publicKey;
    final spkiBuffer = attestation.getPublicKey();
    if (spkiBuffer != null) {
      try {
        publicKey = P256PublicKey.fromSpki(
          spkiBuffer.toDart.asUint8List(),
          keyAlias: credentialId,
          isolationLevel: HardwareIsolationLevel.software,
        );
      } on FormatException {
        // non-P256 or unparseable — fall through to stub
      }
    }
    publicKey ??= P256PublicKey(
      keyAlias: credentialId,
      x: Uint8List(32),
      y: Uint8List(32),
      uncompressedBytes: Uint8List(65)..[0] = 0x04,
      isolationLevel: HardwareIsolationLevel.software,
    );

    return PasskeyCredential(
      credentialId: credentialId,
      publicKey: publicKey,
      rawAttestationObject: attestationObject,
      rawClientDataJson: clientDataJson,
      isolationLevel: HardwareIsolationLevel.software,
    );
  }

  PasskeyAssertionResult _parseAssertionResponse(
    web.PublicKeyCredential credential,
  ) {
    final credentialId =
        _base64UrlEncode(credential.rawId.toDart.asUint8List());

    final assertion = credential.response as web.AuthenticatorAssertionResponse;
    final authenticatorData = assertion.authenticatorData.toDart.asUint8List();
    final clientDataJson = assertion.clientDataJSON.toDart.asUint8List();
    final signatureBytes = assertion.signature.toDart.asUint8List();

    final signature = P256Signature.fromDer(signatureBytes);

    Uint8List? userHandle;
    final userHandleBuffer = assertion.userHandle;
    if (userHandleBuffer != null) {
      userHandle = userHandleBuffer.toDart.asUint8List();
    }

    return PasskeyAssertionResult(
      credentialId: credentialId,
      authenticatorData: authenticatorData,
      clientDataJson: clientDataJson,
      signature: signature,
      userHandle: userHandle,
    );
  }
}

Never _throwMapped(Object error, String operation) {
  final msg = error.toString();
  if (msg.contains('AbortError') ||
      msg.contains('NotAllowedError') ||
      msg.contains('not allowed')) {
    throw UserCancelledException('User cancelled passkey $operation');
  }
  throw PasskeyException('Passkey $operation failed: $msg');
}

JSObject _toBufferSource(Uint8List data) => data.toJS;

String _base64UrlEncode(Uint8List bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

Uint8List _base64UrlDecode(String input) {
  final padded = input.padRight((input.length + 3) & ~3, '=');
  return base64Url.decode(padded);
}

extension on web.Window {
  bool has(String name) => _hasProp(this as JSObject, name);
}

extension on web.Navigator {
  bool has(String name) => _hasProp(this as JSObject, name);
}

@JS('Reflect.has')
external bool _hasProp(JSObject obj, String name);
