import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Minimal JSON-RPC 2.0 client for Ethereum and ERC-4337 bundler calls.
class JsonRpcClient {
  JsonRpcClient(this.url) : _client = HttpClient();

  final String url;
  final HttpClient _client;
  int _id = 0;

  Future<dynamic> call(String method, [List<dynamic>? params]) async {
    final id = ++_id;
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'method': method,
      'params': params ?? [],
      'id': id,
    });

    final request = await _client.postUrl(Uri.parse(url));
    request.headers.contentType = ContentType.json;
    request.write(body);
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    final json = jsonDecode(responseBody) as Map<String, dynamic>;

    if (json.containsKey('error')) {
      final err = json['error'] as Map<String, dynamic>;
      throw JsonRpcException(
        code: err['code'] as int? ?? -1,
        message: err['message'] as String? ?? 'Unknown RPC error',
        data: err['data'],
      );
    }
    return json['result'];
  }

  /// `eth_call` to a contract. Returns hex-encoded result.
  Future<String> ethCall({
    required String to,
    required Uint8List data,
    String block = 'latest',
  }) async {
    final result = await call('eth_call', [
      {'to': to, 'data': '0x${_hexEncode(data)}'},
      block,
    ]);
    return result as String;
  }

  /// Submit a UserOperation to an ERC-4337 bundler.
  Future<String> sendUserOperation({
    required Map<String, String> userOp,
    required String entryPoint,
  }) async {
    final result = await call('eth_sendUserOperation', [userOp, entryPoint]);
    return result as String;
  }

  /// Poll for UserOperation receipt.
  Future<Map<String, dynamic>?> getUserOperationReceipt(
    String userOpHash,
  ) async {
    final result = await call('eth_getUserOperationReceipt', [userOpHash]);
    return result as Map<String, dynamic>?;
  }

  /// `eth_getTransactionReceipt` for gas analysis.
  Future<Map<String, dynamic>?> getTransactionReceipt(String txHash) async {
    final result = await call('eth_getTransactionReceipt', [txHash]);
    return result as Map<String, dynamic>?;
  }

  /// `eth_chainId` — returns the chain ID as int.
  Future<int> chainId() async {
    final result = await call('eth_chainId');
    return int.parse((result as String).substring(2), radix: 16);
  }

  void close() => _client.close();
}

class JsonRpcException implements Exception {
  const JsonRpcException({
    required this.code,
    required this.message,
    this.data,
  });

  final int code;
  final String message;
  final dynamic data;

  @override
  String toString() => 'JsonRpcException($code): $message';
}

String _hexEncode(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
