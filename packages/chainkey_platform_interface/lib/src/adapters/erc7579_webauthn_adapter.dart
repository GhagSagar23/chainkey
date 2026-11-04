import 'dart:typed_data';

import '../models/client_data_json.dart';
import '../models/p256_signature.dart';

/// ABI-encodes a WebAuthn assertion for ERC-7579 modular accounts
/// (ZeroDev Kernel v3, Biconomy Nexus, rhinestone modules).
///
/// Output layout matches the `WebAuthnAuth` struct:
/// ```solidity
/// struct WebAuthnAuth {
///   bytes authenticatorData;
///   string clientDataJSON;
///   uint256 responseTypeLocation;
///   uint256 challengeLocation;
///   uint256[2] rs;
/// }
/// ```
///
/// Note: `uint256[2] rs` is a static-sized array (inline, no offset).
/// `bytes` and `string` are dynamic (offset-referenced).
Uint8List encodeErc7579WebAuthnSignature({
  required P256Signature signature,
  required Uint8List authenticatorData,
  required Uint8List clientDataJson,
  required ClientDataJson clientDataParsed,
}) {
  final r = signature.r;
  final s = signature.s;
  final responseTypeLocation = clientDataParsed.typeOffset;
  final challengeLocation = clientDataParsed.challengeOffset;

  // Head: 6 slots (2 offsets + 2 uint256 + uint256[2])
  const headSize = 6 * 32;
  final authPadded = _padTo32(authenticatorData.length);
  final clientPadded = _padTo32(clientDataJson.length);

  final authDataOffset = headSize;
  final clientDataOffset = headSize + 32 + authPadded;

  final totalLen = clientDataOffset + 32 + clientPadded;
  final buf = Uint8List(totalLen);

  // Offset to authenticatorData
  _writeUint256(buf, 0, authDataOffset);
  // Offset to clientDataJSON
  _writeUint256(buf, 32, clientDataOffset);
  // responseTypeLocation
  _writeUint256(buf, 64, responseTypeLocation);
  // challengeLocation
  _writeUint256(buf, 96, challengeLocation);
  // rs[0] = r, rs[1] = s (inline, static array)
  buf.setRange(128, 160, r);
  buf.setRange(160, 192, s);

  // authenticatorData: length + padded bytes
  _writeUint256(buf, authDataOffset, authenticatorData.length);
  buf.setRange(authDataOffset + 32,
      authDataOffset + 32 + authenticatorData.length, authenticatorData);

  // clientDataJSON: length + padded bytes
  _writeUint256(buf, clientDataOffset, clientDataJson.length);
  buf.setRange(clientDataOffset + 32,
      clientDataOffset + 32 + clientDataJson.length, clientDataJson);

  return buf;
}

int _padTo32(int len) => ((len + 31) ~/ 32) * 32;

void _writeUint256(Uint8List buf, int offset, int value) {
  for (var i = 31; i >= 24; i--) {
    buf[offset + i] = value & 0xFF;
    value >>= 8;
  }
}
