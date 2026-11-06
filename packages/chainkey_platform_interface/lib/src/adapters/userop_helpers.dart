import 'dart:typed_data';

import '../models/p256_public_key.dart';

// ---------------------------------------------------------------------------
// Function selectors (first 4 bytes of keccak256 of canonical signature)
// ---------------------------------------------------------------------------

/// `addOwnerWithThreshold(address,uint256)` — Safe core OwnerManager
const _safeAddOwnerSelector = [0x0d, 0x58, 0x2f, 0x13];

/// `removeOwner(address,address,uint256)` — Safe core OwnerManager
const _safeRemoveOwnerSelector = [0xf8, 0xdc, 0x5d, 0xd9];

/// `installModule(uint256,address,bytes)` — IERC7579Account
const _erc7579InstallSelector = [0x95, 0x17, 0xe2, 0x9f];

/// `uninstallModule(uint256,address,bytes)` — IERC7579Account
const _erc7579UninstallSelector = [0xa7, 0x1d, 0x63, 0xa8];

/// ERC-7579 module type ID for validator modules.
const int erc7579ValidatorTypeId = 1;

// ---------------------------------------------------------------------------
// Safe UserOp callData encoders
// ---------------------------------------------------------------------------

/// Encodes `addOwnerWithThreshold(address owner, uint256 threshold)` callData.
///
/// [ownerAddress] is the 20-byte Ethereum address of the deployed WebAuthn
/// signer contract (created via SafeWebAuthnSignerFactory).
Uint8List encodeSafeAddOwnerCallData({
  required Uint8List ownerAddress,
  int threshold = 1,
}) {
  _assertAddress(ownerAddress, 'ownerAddress');
  // selector(4) + address(32) + uint256(32) = 68 bytes
  final buf = Uint8List(68);
  buf.setAll(0, _safeAddOwnerSelector);
  _writeAddress(buf, 4, ownerAddress);
  _writeUint256(buf, 36, threshold);
  return buf;
}

/// Encodes `removeOwner(address prevOwner, address owner, uint256 threshold)` callData.
///
/// [prevOwner] is the owner entry that points to [owner] in Safe's linked list.
/// Use address(0x1) (SENTINEL) if [owner] is the first in the list.
Uint8List encodeSafeRemoveOwnerCallData({
  required Uint8List prevOwner,
  required Uint8List owner,
  int threshold = 1,
}) {
  _assertAddress(prevOwner, 'prevOwner');
  _assertAddress(owner, 'owner');
  // selector(4) + address(32) + address(32) + uint256(32) = 100 bytes
  final buf = Uint8List(100);
  buf.setAll(0, _safeRemoveOwnerSelector);
  _writeAddress(buf, 4, prevOwner);
  _writeAddress(buf, 36, owner);
  _writeUint256(buf, 68, threshold);
  return buf;
}

// ---------------------------------------------------------------------------
// ERC-7579 UserOp callData encoders
// ---------------------------------------------------------------------------

/// Encodes `installModule(1, module, abi.encode(x, y))` callData for a
/// P-256 validator module on ERC-7579 accounts (ZeroDev Kernel v3, Biconomy Nexus).
///
/// The [initData] is `abi.encode(uint256 x, uint256 y)` — the 64-byte
/// coordinate pair from [publicKey].
Uint8List encodeErc7579InstallP256ValidatorCallData({
  required Uint8List moduleAddress,
  required P256PublicKey publicKey,
}) {
  _assertAddress(moduleAddress, 'moduleAddress');
  final initData = _encodeP256Coordinates(publicKey);
  return _encodeErc7579ModuleCall(
    _erc7579InstallSelector,
    erc7579ValidatorTypeId,
    moduleAddress,
    initData,
  );
}

/// Encodes `uninstallModule(1, module, deInitData)` callData.
///
/// [deInitData] is module-specific teardown data (often empty or the
/// previous owner in a linked-list validator).
Uint8List encodeErc7579UninstallValidatorCallData({
  required Uint8List moduleAddress,
  Uint8List? deInitData,
}) {
  _assertAddress(moduleAddress, 'moduleAddress');
  return _encodeErc7579ModuleCall(
    _erc7579UninstallSelector,
    erc7579ValidatorTypeId,
    moduleAddress,
    deInitData ?? Uint8List(0),
  );
}

// ---------------------------------------------------------------------------
// Internals
// ---------------------------------------------------------------------------

Uint8List _encodeErc7579ModuleCall(
  List<int> selector,
  int moduleTypeId,
  Uint8List moduleAddress,
  Uint8List data,
) {
  // selector(4) + uint256(32) + address(32) + offset(32) + length(32) + padded data
  final dataPadded = _padTo32(data.length);
  final totalLen = 4 + 32 + 32 + 32 + 32 + dataPadded;
  final buf = Uint8List(totalLen);

  buf.setAll(0, selector);
  _writeUint256(buf, 4, moduleTypeId);
  _writeAddress(buf, 36, moduleAddress);
  // offset to `bytes` data = 3 * 32 = 96 (relative to params start)
  _writeUint256(buf, 68, 96);
  // bytes length
  _writeUint256(buf, 100, data.length);
  // bytes content
  if (data.isNotEmpty) {
    buf.setRange(132, 132 + data.length, data);
  }
  return buf;
}

Uint8List _encodeP256Coordinates(P256PublicKey publicKey) {
  // abi.encode(uint256 x, uint256 y) = 64 bytes
  final buf = Uint8List(64);
  buf.setRange(0, 32, publicKey.x);
  buf.setRange(32, 64, publicKey.y);
  return buf;
}

void _assertAddress(Uint8List addr, String name) {
  if (addr.length != 20) {
    throw ArgumentError.value(addr.length, name, 'must be exactly 20 bytes');
  }
}

void _writeAddress(Uint8List buf, int offset, Uint8List addr) {
  // ABI-encode address: right-aligned in 32-byte slot (12 zero bytes + 20 address bytes)
  buf.setRange(offset + 12, offset + 32, addr);
}

void _writeUint256(Uint8List buf, int offset, int value) {
  for (var i = 31; i >= 24; i--) {
    buf[offset + i] = value & 0xFF;
    value >>= 8;
  }
}

int _padTo32(int len) => ((len + 31) ~/ 32) * 32;
