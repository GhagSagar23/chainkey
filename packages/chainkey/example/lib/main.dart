import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:chainkey/chainkey.dart';

void main() {
  runApp(const ChainkeyExampleApp());
}

class ChainkeyExampleApp extends StatelessWidget {
  const ChainkeyExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'chainkey Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD0BCFF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const ChainkeyHomeScreen(),
    );
  }
}

class ChainkeyHomeScreen extends StatefulWidget {
  const ChainkeyHomeScreen({super.key});

  @override
  State<ChainkeyHomeScreen> createState() => _ChainkeyHomeScreenState();
}

class _ChainkeyHomeScreenState extends State<ChainkeyHomeScreen> {
  final Chainkey _chainkey = const Chainkey();
  final String _keyAlias = 'dev.chainkey.demo_key';

  bool _isSecureEnclaveSupported = false;
  bool _isStrongBoxSupported = false;
  bool _isTeeSupported = false;

  P256PublicKey? _publicKey;
  P256Signature? _lastSignature;
  String? _statusMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkHardwareCapabilities();
  }

  Future<void> _checkHardwareCapabilities() async {
    try {
      final se = await _chainkey.isHardwareIsolationSupported(
        HardwareIsolationLevel.secureEnclave,
      );
      final sb = await _chainkey.isHardwareIsolationSupported(
        HardwareIsolationLevel.strongBox,
      );
      final tee = await _chainkey.isHardwareIsolationSupported(
        HardwareIsolationLevel.tee,
      );

      if (!mounted) return;
      setState(() {
        _isSecureEnclaveSupported = se;
        _isStrongBoxSupported = sb;
        _isTeeSupported = tee;
      });
    } catch (e) {
      setState(() => _statusMessage = 'Capability check error: $e');
    }
  }

  Future<void> _generateKey() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Generating hardware key...';
    });
    try {
      final key = await _chainkey.generateHardwareKey(
        keyAlias: _keyAlias,
        requireUserPresence: true,
      );
      setState(() {
        _publicKey = key;
        _statusMessage =
            'Key generated successfully!\nIsolation: ${key.isolationLevel.name}';
      });
    } catch (e) {
      setState(() => _statusMessage = 'Keygen failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signDigest() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Requesting biometric signature...';
    });
    try {
      // 32-byte sample digest (representing an ERC-4337 UserOpHash)
      final dummyHash = Uint8List.fromList(List.generate(32, (i) => i));

      final signature = await _chainkey.signWithHardwareKey(
        keyAlias: _keyAlias,
        hash32: dummyHash,
        promptOptions: const BiometricPromptOptions(
          title: 'Sign Web3 Transaction',
          subtitle: 'Authorize ERC-4337 UserOperation',
          description: 'Authenticate with biometric sensor to execute.',
        ),
      );

      setState(() {
        _lastSignature = signature;
        _statusMessage = 'Digest signed with hardware enclave!';
      });
    } catch (e) {
      setState(() => _statusMessage = 'Sign failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('chainkey Web3 Hardware Signer'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hardware Isolation Capabilities',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Apple Secure Enclave: ${_isSecureEnclaveSupported ? "Supported" : "Not Supported"}',
                  ),
                  Text(
                    '• Android StrongBox: ${_isStrongBoxSupported ? "Supported" : "Not Supported"}',
                  ),
                  Text(
                    '• Android TEE: ${_isTeeSupported ? "Supported" : "Not Supported"}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _generateKey,
                  icon: const Icon(Icons.key),
                  label: const Text('Generate Enclave Key'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _isLoading ? null : _signDigest,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Sign 32B Hash'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_statusMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _statusMessage!,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          if (_publicKey != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'P-256 Public Key (Uncompressed SEC1)',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      _publicKey!.uncompressedHex,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_lastSignature != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'P-256 Signature (r || s compact 64B)',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      _lastSignature!.compactHex,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
