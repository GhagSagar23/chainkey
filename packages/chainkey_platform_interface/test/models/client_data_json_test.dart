import 'dart:convert';
import 'dart:typed_data';

import 'package:chainkey_platform_interface/chainkey_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _utf8(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  group('ClientDataJson.parse', () {
    test('parses standard Chrome clientDataJSON', () {
      final json = _utf8(
        '{"type":"webauthn.get","challenge":"dGVzdC1jaGFsbGVuZ2U",'
        '"origin":"https://example.com","crossOrigin":false}',
      );
      final parsed = ClientDataJson.parse(json);

      expect(parsed.type, 'webauthn.get');
      expect(parsed.challenge, 'dGVzdC1jaGFsbGVuZ2U');
      expect(parsed.typeOffset, greaterThan(0));
      expect(parsed.challengeOffset, greaterThan(0));
    });

    test('parses webauthn.create type', () {
      final json = _utf8(
        '{"type":"webauthn.create","challenge":"YWJj","origin":"https://example.com"}',
      );
      final parsed = ClientDataJson.parse(json);

      expect(parsed.type, 'webauthn.create');
      expect(parsed.challenge, 'YWJj');
    });

    test('handles reversed key order (challenge before type)', () {
      final json = _utf8(
        '{"challenge":"Zm9v","type":"webauthn.get","origin":"https://example.com"}',
      );
      final parsed = ClientDataJson.parse(json);

      expect(parsed.challenge, 'Zm9v');
      expect(parsed.type, 'webauthn.get');
    });

    test('handles keys separated by other fields', () {
      final json = _utf8(
        '{"origin":"https://example.com","crossOrigin":false,'
        '"type":"webauthn.get","tokenBinding":{"status":"supported"},'
        '"challenge":"QUJD"}',
      );
      final parsed = ClientDataJson.parse(json);

      expect(parsed.challenge, 'QUJD');
      expect(parsed.type, 'webauthn.get');
    });

    test('handles whitespace around colons', () {
      final json = _utf8(
        '{"type" : "webauthn.get" , "challenge" : "eHl6"}',
      );
      final parsed = ClientDataJson.parse(json);

      expect(parsed.type, 'webauthn.get');
      expect(parsed.challenge, 'eHl6');
    });

    test('handles newlines and tabs in whitespace', () {
      final json = _utf8(
        '{\n\t"type"\t:\t"webauthn.get",\n\t"challenge"\t:\t"YQ"\n}',
      );
      final parsed = ClientDataJson.parse(json);

      expect(parsed.type, 'webauthn.get');
      expect(parsed.challenge, 'YQ');
    });

    test('offset points to first byte of value (after opening quote)', () {
      // Build a known string and verify exact byte offsets
      const jsonStr = '{"type":"webauthn.get","challenge":"AAAA"}';
      final json = _utf8(jsonStr);
      final parsed = ClientDataJson.parse(json);

      // "type":" starts at index 8 → value starts at 9
      expect(
          jsonStr.substring(
              parsed.typeOffset, parsed.typeOffset + parsed.typeLength),
          'webauthn.get');
      expect(
          jsonStr.substring(parsed.challengeOffset,
              parsed.challengeOffset + parsed.challengeLength),
          'AAAA');
    });

    test('handles base64url challenge with hyphens and underscores', () {
      final json = _utf8(
        '{"type":"webauthn.get","challenge":"abc-def_ghi"}',
      );
      final parsed = ClientDataJson.parse(json);

      expect(parsed.challenge, 'abc-def_ghi');
    });

    test('handles empty challenge string', () {
      final json = _utf8('{"type":"webauthn.get","challenge":""}');
      final parsed = ClientDataJson.parse(json);

      expect(parsed.challenge, '');
      expect(parsed.challengeLength, 0);
    });

    test('handles escaped characters in other fields', () {
      final json = _utf8(
        r'{"origin":"https:\/\/example.com","type":"webauthn.get","challenge":"Zm9v"}',
      );
      final parsed = ClientDataJson.parse(json);

      expect(parsed.type, 'webauthn.get');
      expect(parsed.challenge, 'Zm9v');
    });

    test('throws FormatException when challenge field missing', () {
      final json =
          _utf8('{"type":"webauthn.get","origin":"https://example.com"}');
      expect(
        () => ClientDataJson.parse(json),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('"challenge"'),
          ),
        ),
      );
    });

    test('throws FormatException when type field missing', () {
      final json = _utf8('{"challenge":"AAAA","origin":"https://example.com"}');
      expect(
        () => ClientDataJson.parse(json),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('"type"'),
          ),
        ),
      );
    });

    test('throws FormatException on empty input', () {
      expect(
        () => ClientDataJson.parse(Uint8List(0)),
        throwsFormatException,
      );
    });

    test('preserves raw bytes', () {
      final json = _utf8('{"type":"webauthn.get","challenge":"YQ"}');
      final parsed = ClientDataJson.parse(json);
      expect(parsed.raw, json);
    });

    test('long challenge value', () {
      final longChallenge = 'A' * 200;
      final json =
          _utf8('{"type":"webauthn.get","challenge":"$longChallenge"}');
      final parsed = ClientDataJson.parse(json);

      expect(parsed.challenge, longChallenge);
      expect(parsed.challengeLength, 200);
    });
  });
}
