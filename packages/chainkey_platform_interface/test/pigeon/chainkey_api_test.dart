import 'package:chainkey_platform_interface/chainkey_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class MockBinaryMessenger extends BinaryMessenger {
  final Map<String, MessageHandler> handlers = {};
  final List<ByteData?> sentMessages = [];

  @override
  Future<void> handlePlatformMessage(
    String channel,
    ByteData? data,
    PlatformMessageResponseCallback? callback,
  ) async {
    final handler = handlers[channel];
    if (handler != null) {
      final response = await handler(data);
      callback?.call(response);
    } else {
      callback?.call(null);
    }
  }

  @override
  Future<ByteData?> send(String channel, ByteData? message) async {
    sentMessages.add(message);
    final handler = handlers[channel];
    if (handler != null) {
      return await handler(message);
    }
    return null;
  }

  @override
  void setMessageHandler(String channel, MessageHandler? handler) {
    if (handler == null) {
      handlers.remove(channel);
    } else {
      handlers[channel] = handler;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pigeon Chainkey API Data Classes & Codec Tests', () {
    test('HardwareKeyOptions serialization roundtrip', () {
      final options = HardwareKeyOptions(
        keyAlias: 'test-key-alias',
        requireUserPresence: true,
        requireStrongBox: true,
        invalidatedByBiometricEnrollment: false,
        accessGroup: 'group.com.chainkey',
      );

      final encoded = options.encode();
      final decoded = HardwareKeyOptions.decode(encoded);

      expect(decoded.keyAlias, equals('test-key-alias'));
      expect(decoded.requireUserPresence, isTrue);
      expect(decoded.requireStrongBox, isTrue);
      expect(decoded.invalidatedByBiometricEnrollment, isFalse);
      expect(decoded.accessGroup, equals('group.com.chainkey'));
      expect(decoded, equals(options));
      expect(decoded.hashCode, equals(options.hashCode));
      expect(decoded.toString(), contains('test-key-alias'));
    });

    test('PromptOptions serialization roundtrip', () {
      final prompt = PromptOptions(
        title: 'Authorize Op',
        subtitle: 'Sub',
        promptDescription: 'Desc',
        negativeButtonText: 'Cancel',
        confirmationRequired: true,
      );

      final encoded = prompt.encode();
      final decoded = PromptOptions.decode(encoded);

      expect(decoded.title, equals('Authorize Op'));
      expect(decoded.subtitle, equals('Sub'));
      expect(decoded.promptDescription, equals('Desc'));
      expect(decoded.negativeButtonText, equals('Cancel'));
      expect(decoded.confirmationRequired, isTrue);
      expect(decoded, equals(prompt));
      expect(decoded.hashCode, equals(prompt.hashCode));
      expect(decoded.toString(), contains('Authorize Op'));
    });

    test('EnclavePublicKey serialization roundtrip', () {
      final x = Uint8List(32)..[0] = 1;
      final y = Uint8List(32)..[0] = 2;
      final uncompressed = Uint8List(65)..[0] = 4;

      final pubKey = EnclavePublicKey(
        keyAlias: 'pub-alias',
        x: x,
        y: y,
        uncompressedBytes: uncompressed,
        isolationLevel: EnclaveIsolationLevel.secureEnclave,
      );

      final encoded = pubKey.encode();
      final decoded = EnclavePublicKey.decode(encoded);

      expect(decoded.keyAlias, equals('pub-alias'));
      expect(decoded.x, equals(x));
      expect(decoded.y, equals(y));
      expect(decoded.uncompressedBytes, equals(uncompressed));
      expect(
          decoded.isolationLevel, equals(EnclaveIsolationLevel.secureEnclave));
      expect(decoded, equals(pubKey));
      expect(decoded.hashCode, equals(pubKey.hashCode));
      expect(decoded.toString(), contains('pub-alias'));
    });

    test('DerSignatureResult serialization roundtrip', () {
      final r = Uint8List(32)..[31] = 10;
      final s = Uint8List(32)..[31] = 20;
      final rawDer =
          Uint8List.fromList([0x30, 0x06, 0x02, 0x01, 10, 0x02, 0x01, 20]);

      final sig = DerSignatureResult(
        keyAlias: 'sig-alias',
        rawDerSignature: rawDer,
        r: r,
        s: s,
        isLowS: true,
      );

      final encoded = sig.encode();
      final decoded = DerSignatureResult.decode(encoded);

      expect(decoded.keyAlias, equals('sig-alias'));
      expect(decoded.rawDerSignature, equals(rawDer));
      expect(decoded.r, equals(r));
      expect(decoded.s, equals(s));
      expect(decoded.isLowS, isTrue);
      expect(decoded, equals(sig));
      expect(decoded.hashCode, equals(sig.hashCode));
      expect(decoded.toString(), contains('sig-alias'));
    });

    test('PasskeyCreationRequest & Response serialization roundtrip', () {
      final challenge = Uint8List(32)..[0] = 99;
      final userId = Uint8List.fromList([1, 2, 3, 4]);

      final request = PasskeyCreationRequest(
        relyingPartyId: 'chainkey.dev',
        userName: 'alice@chainkey.dev',
        userDisplayName: 'Alice',
        userId: userId,
        challenge: challenge,
        requireUserVerification: true,
        origin: 'https://chainkey.dev',
      );

      final reqDecoded = PasskeyCreationRequest.decode(request.encode());
      expect(reqDecoded.relyingPartyId, equals('chainkey.dev'));
      expect(reqDecoded.userName, equals('alice@chainkey.dev'));
      expect(reqDecoded.userDisplayName, equals('Alice'));
      expect(reqDecoded.userId, equals(userId));
      expect(reqDecoded.challenge, equals(challenge));
      expect(reqDecoded.requireUserVerification, isTrue);
      expect(reqDecoded.origin, equals('https://chainkey.dev'));
      expect(reqDecoded, equals(request));
      expect(reqDecoded.hashCode, equals(request.hashCode));

      final x = Uint8List(32)..[0] = 1;
      final y = Uint8List(32)..[0] = 2;
      final uncompressed = Uint8List(65)..[0] = 4;
      final pubKey = EnclavePublicKey(
        keyAlias: 'pk-alias',
        x: x,
        y: y,
        uncompressedBytes: uncompressed,
        isolationLevel: EnclaveIsolationLevel.software,
      );

      final response = PasskeyCreationResponse(
        credentialId: 'cred-12345',
        rawAttestationObject: Uint8List.fromList([1, 2, 3]),
        rawClientDataJson: Uint8List.fromList([4, 5, 6]),
        publicKey: pubKey,
        isolationLevel: EnclaveIsolationLevel.software,
      );

      final resDecoded = PasskeyCreationResponse.decode(response.encode());
      expect(resDecoded.credentialId, equals('cred-12345'));
      expect(resDecoded.rawAttestationObject,
          equals(Uint8List.fromList([1, 2, 3])));
      expect(
          resDecoded.rawClientDataJson, equals(Uint8List.fromList([4, 5, 6])));
      expect(resDecoded.publicKey.keyAlias, equals('pk-alias'));
      expect(resDecoded.isolationLevel, equals(EnclaveIsolationLevel.software));
      expect(resDecoded, equals(response));
      expect(resDecoded.hashCode, equals(response.hashCode));
    });

    test('PasskeyAssertionRequest & Response serialization roundtrip', () {
      final challenge = Uint8List(32)..[1] = 42;
      final request = PasskeyAssertionRequest(
        relyingPartyId: 'chainkey.dev',
        challenge: challenge,
        allowedCredentialIds: ['cred-1', 'cred-2'],
        requireUserVerification: true,
      );

      final reqDecoded = PasskeyAssertionRequest.decode(request.encode());
      expect(reqDecoded.relyingPartyId, equals('chainkey.dev'));
      expect(reqDecoded.challenge, equals(challenge));
      expect(reqDecoded.allowedCredentialIds, equals(['cred-1', 'cred-2']));
      expect(reqDecoded.requireUserVerification, isTrue);
      expect(reqDecoded, equals(request));
      expect(reqDecoded.hashCode, equals(request.hashCode));

      final r = Uint8List(32)..[31] = 1;
      final s = Uint8List(32)..[31] = 2;
      final rawDer =
          Uint8List.fromList([0x30, 0x06, 0x02, 0x01, 1, 0x02, 0x01, 2]);
      final sig = DerSignatureResult(
        keyAlias: 'sig-alias',
        rawDerSignature: rawDer,
        r: r,
        s: s,
        isLowS: true,
      );

      final response = PasskeyAssertionResponse(
        credentialId: 'cred-1',
        authenticatorData: Uint8List.fromList([10, 20]),
        clientDataJson: Uint8List.fromList([30, 40]),
        signature: sig,
        userHandle: Uint8List.fromList([9, 8, 7]),
      );

      final resDecoded = PasskeyAssertionResponse.decode(response.encode());
      expect(resDecoded.credentialId, equals('cred-1'));
      expect(
          resDecoded.authenticatorData, equals(Uint8List.fromList([10, 20])));
      expect(resDecoded.clientDataJson, equals(Uint8List.fromList([30, 40])));
      expect(resDecoded.signature.keyAlias, equals('sig-alias'));
      expect(resDecoded.userHandle, equals(Uint8List.fromList([9, 8, 7])));
      expect(resDecoded, equals(response));
      expect(resDecoded.hashCode, equals(response.hashCode));
    });
  });

  group('HardwareEnclaveHostApi & WebAuthnHostApi Client Messaging Tests', () {
    test('HardwareEnclaveHostApi generateKey sends over BasicMessageChannel',
        () async {
      final mockMessenger = MockBinaryMessenger();
      final api = HardwareEnclaveHostApi(binaryMessenger: mockMessenger);

      final x = Uint8List(32)..[0] = 5;
      final y = Uint8List(32)..[0] = 6;
      final uncompressed = Uint8List(65)..[0] = 4;
      final expectedKey = EnclavePublicKey(
        keyAlias: 'test-alias',
        x: x,
        y: y,
        uncompressedBytes: uncompressed,
        isolationLevel: EnclaveIsolationLevel.strongBox,
      );

      const channelName =
          'dev.flutter.pigeon.chainkey_platform_interface.HardwareEnclaveHostApi.generateKey';

      mockMessenger.setMessageHandler(channelName, (ByteData? message) async {
        return HardwareEnclaveHostApi.pigeonChannelCodec
            .encodeMessage(<Object?>[expectedKey]);
      });

      final options = HardwareKeyOptions(
        keyAlias: 'test-alias',
        requireUserPresence: true,
        requireStrongBox: true,
        invalidatedByBiometricEnrollment: false,
      );

      final result = await api.generateKey(options);
      expect(result.keyAlias, equals('test-alias'));
      expect(result.isolationLevel, equals(EnclaveIsolationLevel.strongBox));
    });

    test('HardwareEnclaveHostApi deleteKey and getIsolationLevel', () async {
      final mockMessenger = MockBinaryMessenger();
      final api = HardwareEnclaveHostApi(binaryMessenger: mockMessenger);

      const deleteChannel =
          'dev.flutter.pigeon.chainkey_platform_interface.HardwareEnclaveHostApi.deleteKey';
      const isolationChannel =
          'dev.flutter.pigeon.chainkey_platform_interface.HardwareEnclaveHostApi.getIsolationLevel';

      mockMessenger.setMessageHandler(deleteChannel, (ByteData? message) async {
        return HardwareEnclaveHostApi.pigeonChannelCodec
            .encodeMessage(<Object?>[true]);
      });

      mockMessenger.setMessageHandler(isolationChannel,
          (ByteData? message) async {
        return HardwareEnclaveHostApi.pigeonChannelCodec
            .encodeMessage(<Object?>[
          EnclaveIsolationLevel.secureEnclave,
        ]);
      });

      final deleteResult = await api.deleteKey('my-key');
      expect(deleteResult, isTrue);

      final isolation = await api.getIsolationLevel('my-key');
      expect(isolation, equals(EnclaveIsolationLevel.secureEnclave));
    });

    test(
        'WebAuthnHostApi registerPasskey & assertPasskey send expected messages',
        () async {
      final mockMessenger = MockBinaryMessenger();
      final api = WebAuthnHostApi(binaryMessenger: mockMessenger);

      const registerChannel =
          'dev.flutter.pigeon.chainkey_platform_interface.WebAuthnHostApi.registerPasskey';
      const assertChannel =
          'dev.flutter.pigeon.chainkey_platform_interface.WebAuthnHostApi.assertPasskey';

      final pubKey = EnclavePublicKey(
        keyAlias: 'webauthn-key',
        x: Uint8List(32),
        y: Uint8List(32),
        uncompressedBytes: Uint8List(65)..[0] = 4,
        isolationLevel: EnclaveIsolationLevel.software,
      );

      final expectedCreation = PasskeyCreationResponse(
        credentialId: 'cred-999',
        rawAttestationObject: Uint8List(10),
        rawClientDataJson: Uint8List(20),
        publicKey: pubKey,
        isolationLevel: EnclaveIsolationLevel.software,
      );

      mockMessenger.setMessageHandler(registerChannel,
          (ByteData? message) async {
        return WebAuthnHostApi.pigeonChannelCodec
            .encodeMessage(<Object?>[expectedCreation]);
      });

      final creationResult = await api.registerPasskey(
        PasskeyCreationRequest(
          relyingPartyId: 'chainkey.dev',
          userName: 'alice',
          userDisplayName: 'Alice',
          userId: Uint8List(16),
          challenge: Uint8List(32),
          requireUserVerification: true,
        ),
      );
      expect(creationResult.credentialId, equals('cred-999'));

      final sig = DerSignatureResult(
        keyAlias: 'webauthn-key',
        rawDerSignature: Uint8List(64),
        r: Uint8List(32),
        s: Uint8List(32),
        isLowS: true,
      );

      final expectedAssertion = PasskeyAssertionResponse(
        credentialId: 'cred-999',
        authenticatorData: Uint8List(37),
        clientDataJson: Uint8List(50),
        signature: sig,
      );

      mockMessenger.setMessageHandler(assertChannel, (ByteData? message) async {
        return WebAuthnHostApi.pigeonChannelCodec
            .encodeMessage(<Object?>[expectedAssertion]);
      });

      final assertionResult = await api.assertPasskey(
        PasskeyAssertionRequest(
          relyingPartyId: 'chainkey.dev',
          challenge: Uint8List(32),
          requireUserVerification: true,
        ),
      );
      expect(assertionResult.credentialId, equals('cred-999'));
      expect(assertionResult.signature.isLowS, isTrue);
    });
  });
}
