import 'dart:typed_data';

/// Minimal ERC-4337 v0.7 UserOperation struct builder.
///
/// This builds the hex-encoded fields that bundlers expect.
/// The actual signature is provided externally (from chainkey's
/// passkey assertion + adapter encoding).
class UserOperation {
  UserOperation({
    required this.sender,
    required this.nonce,
    required this.callData,
    this.initCode,
    this.paymasterAndData,
    this.signature,
    this.callGasLimit = 200000,
    this.verificationGasLimit = 500000,
    this.preVerificationGas = 50000,
    this.maxFeePerGas = 1000000000,
    this.maxPriorityFeePerGas = 1000000000,
  });

  final String sender;
  final int nonce;
  final Uint8List callData;
  final Uint8List? initCode;
  final Uint8List? paymasterAndData;
  Uint8List? signature;

  final int callGasLimit;
  final int verificationGasLimit;
  final int preVerificationGas;
  final int maxFeePerGas;
  final int maxPriorityFeePerGas;

  Map<String, String> toJson() => {
        'sender': sender,
        'nonce': _toHex(nonce),
        'callData': '0x${_hexEncode(callData)}',
        'initCode': '0x${_hexEncode(initCode ?? Uint8List(0))}',
        'paymasterAndData': '0x${_hexEncode(paymasterAndData ?? Uint8List(0))}',
        'signature': '0x${_hexEncode(signature ?? Uint8List(0))}',
        'callGasLimit': _toHex(callGasLimit),
        'verificationGasLimit': _toHex(verificationGasLimit),
        'preVerificationGas': _toHex(preVerificationGas),
        'maxFeePerGas': _toHex(maxFeePerGas),
        'maxPriorityFeePerGas': _toHex(maxPriorityFeePerGas),
      };

  @override
  String toString() => 'UserOperation(sender: $sender, nonce: $nonce)';
}

String _toHex(int value) => '0x${value.toRadixString(16)}';

String _hexEncode(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

Uint8List hexDecode(String hex) {
  final clean = hex.startsWith('0x') ? hex.substring(2) : hex;
  final bytes = Uint8List(clean.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}
