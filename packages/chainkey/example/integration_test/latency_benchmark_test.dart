import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:chainkey/chainkey.dart';

/// Latency benchmark for hardware signing operations.
///
/// Generates a key WITHOUT biometric auth requirement (requireUserPresence: false)
/// to allow automated runs. Measures pure crypto latency: key generation and
/// sign operations through the hardware enclave, excluding biometric wait time.
///
/// For full biometric-inclusive benchmarks, set requireUserPresence: true
/// and run manually on a physical device.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const plugin = Chainkey();
  const keyAlias = 'chainkey_benchmark_key';
  const iterations = 20;

  testWidgets('key generation latency', (WidgetTester tester) async {
    // Clean up any prior key
    await plugin.deleteHardwareKey(keyAlias: keyAlias);

    final stopwatch = Stopwatch()..start();
    await plugin.generateHardwareKey(
      keyAlias: keyAlias,
      requireUserPresence: false,
    );
    stopwatch.stop();

    // ignore: avoid_print
    print('[BENCHMARK] Key generation: ${stopwatch.elapsedMilliseconds}ms');
    expect(stopwatch.elapsedMilliseconds, lessThan(2000));
  });

  testWidgets('signing latency P50/P95/P99 (no biometric)',
      (WidgetTester tester) async {
    // Ensure key exists without biometric requirement
    try {
      await plugin.generateHardwareKey(
        keyAlias: keyAlias,
        requireUserPresence: false,
      );
    } catch (_) {
      // Key may already exist from prior test
    }

    final hash32 = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      hash32[i] = i;
    }

    final latencies = <int>[];

    for (var i = 0; i < iterations; i++) {
      // Vary the hash slightly each iteration
      hash32[0] = i;
      final stopwatch = Stopwatch()..start();
      final sig = await plugin.signWithHardwareKey(
        keyAlias: keyAlias,
        hash32: hash32,
      );
      stopwatch.stop();
      latencies.add(stopwatch.elapsedMilliseconds);

      // Verify the signature is valid structure
      expect(sig.r.length, 32);
      expect(sig.s.length, 32);
    }

    latencies.sort();

    final p50 = latencies[latencies.length ~/ 2];
    final p95 = latencies[(latencies.length * 0.95).floor()];
    final p99 = latencies[(latencies.length * 0.99).floor()];
    final min = latencies.first;
    final max = latencies.last;
    final avg = latencies.reduce((a, b) => a + b) / latencies.length;

    // ignore: avoid_print
    print('[BENCHMARK] Sign latency over $iterations iterations:');
    // ignore: avoid_print
    print('  Min: ${min}ms  Avg: ${avg.toStringAsFixed(1)}ms  Max: ${max}ms');
    // ignore: avoid_print
    print('  P50: ${p50}ms  P95: ${p95}ms  P99: ${p99}ms');

    // KPI: P50 < 350ms (hardware signing without biometric wait)
    expect(p50, lessThan(350), reason: 'P50 signing latency must be < 350ms');
  });

  testWidgets('signing with prompt options (no biometric)',
      (WidgetTester tester) async {
    final hash32 = Uint8List(32)..fillRange(0, 32, 0xAB);

    final sig = await plugin.signWithHardwareKey(
      keyAlias: keyAlias,
      hash32: hash32,
      promptOptions: const BiometricPromptOptions(
        title: 'Confirm Transaction',
        subtitle: 'Sign UserOp hash',
        description: 'Authorize this blockchain transaction',
        negativeButtonText: 'Deny',
        confirmationRequired: false,
      ),
    );

    expect(sig.r.length, 32);
    expect(sig.s.length, 32);
  });

  testWidgets('cleanup benchmark key', (WidgetTester tester) async {
    final deleted = await plugin.deleteHardwareKey(keyAlias: keyAlias);
    expect(deleted, isTrue);
  });
}
