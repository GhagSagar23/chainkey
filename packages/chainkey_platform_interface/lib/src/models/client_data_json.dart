import 'dart:typed_data';

/// Parsed byte-offset locations within a raw `clientDataJSON` UTF-8 buffer.
///
/// Smart-contract verifiers (Solady WebAuthn.sol, Safe WebAuthn Signer) require
/// callers to supply pre-parsed byte offsets for `"challenge"` and `"type"`
/// field values to avoid expensive in-contract string scanning.
class ClientDataJson {
  ClientDataJson({
    required this.challengeOffset,
    required this.challengeLength,
    required this.typeOffset,
    required this.typeLength,
    required this.raw,
  });

  /// Byte offset where the base64url challenge VALUE string starts (after the opening quote).
  final int challengeOffset;

  /// Length in bytes of the base64url challenge value (between quotes).
  final int challengeLength;

  /// Byte offset where the type VALUE string starts (after the opening quote).
  final int typeOffset;

  /// Length in bytes of the type value string (between quotes).
  final int typeLength;

  /// The original raw UTF-8 bytes.
  final Uint8List raw;

  /// The challenge base64url string extracted from the raw bytes.
  String get challenge => String.fromCharCodes(
      raw, challengeOffset, challengeOffset + challengeLength);

  /// The type string extracted from the raw bytes (e.g. "webauthn.create" or "webauthn.get").
  String get type =>
      String.fromCharCodes(raw, typeOffset, typeOffset + typeLength);

  /// Scans raw `clientDataJSON` UTF-8 bytes for `"challenge"` and `"type"` field value locations.
  ///
  /// Finds the byte offsets and lengths of the string values (not the keys).
  /// Handles arbitrary JSON key ordering and optional whitespace around colons.
  factory ClientDataJson.parse(Uint8List data) {
    int? challengeOff;
    int? challengeLen;
    int? typeOff;
    int? typeLen;

    // Scan for "challenge":<ws>?"<value>" and "type":<ws>?"<value>"
    const challengeKey = [
      0x22, 0x63, 0x68, 0x61, 0x6C, 0x6C, 0x65, 0x6E, 0x67, 0x65,
      0x22, // "challenge"
    ];
    const typeKey = [
      0x22, 0x74, 0x79, 0x70, 0x65, 0x22, // "type"
    ];

    challengeOff = _findValueOffset(data, challengeKey);
    if (challengeOff != null) {
      challengeLen = _findStringEnd(data, challengeOff);
    }

    typeOff = _findValueOffset(data, typeKey);
    if (typeOff != null) {
      typeLen = _findStringEnd(data, typeOff);
    }

    if (challengeOff == null || challengeLen == null) {
      throw FormatException(
        'clientDataJSON missing "challenge" field',
      );
    }
    if (typeOff == null || typeLen == null) {
      throw FormatException(
        'clientDataJSON missing "type" field',
      );
    }

    return ClientDataJson(
      challengeOffset: challengeOff,
      challengeLength: challengeLen,
      typeOffset: typeOff,
      typeLength: typeLen,
      raw: Uint8List.fromList(data),
    );
  }
}

/// Searches [data] for [key] bytes, then skips `:<ws>?"` to return the offset
/// of the first byte of the string value (after the opening quote).
int? _findValueOffset(Uint8List data, List<int> key) {
  for (var i = 0; i <= data.length - key.length; i++) {
    if (_matchesAt(data, i, key)) {
      // Found key at i. Skip past key, then colon, optional whitespace, opening quote.
      var j = i + key.length;
      // Skip whitespace
      while (j < data.length && _isWhitespace(data[j])) {
        j++;
      }
      // Expect colon
      if (j >= data.length || data[j] != 0x3A) continue; // ':'
      j++;
      // Skip whitespace
      while (j < data.length && _isWhitespace(data[j])) {
        j++;
      }
      // Expect opening quote
      if (j >= data.length || data[j] != 0x22) continue; // '"'
      j++;
      return j;
    }
  }
  return null;
}

/// Returns the length of the string value starting at [offset] (after the opening quote).
/// Handles escaped characters.
int? _findStringEnd(Uint8List data, int offset) {
  var i = offset;
  while (i < data.length) {
    if (data[i] == 0x5C) {
      // backslash — skip escaped char
      i += 2;
      continue;
    }
    if (data[i] == 0x22) {
      // closing quote
      return i - offset;
    }
    i++;
  }
  return null;
}

bool _matchesAt(Uint8List data, int offset, List<int> pattern) {
  if (offset + pattern.length > data.length) return false;
  for (var i = 0; i < pattern.length; i++) {
    if (data[offset + i] != pattern[i]) return false;
  }
  return true;
}

bool _isWhitespace(int byte) =>
    byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D;
