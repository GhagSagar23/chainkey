import 'dart:convert';
import 'dart:io';

import 'package:chainkey_platform_interface/chainkey_platform_interface.dart';

/// CLI tool to verify WebAuthn domain association files.
///
/// Usage:
///   dart run chainkey:verify_domain --rp-id example.com --ios-app-id TEAMID.com.example.app
///   dart run chainkey:verify_domain --rp-id example.com --android-package com.example.app --android-fingerprint AA:BB:...
void main(List<String> args) async {
  final parsed = _parseArgs(args);
  if (parsed == null) {
    _printUsage();
    exit(1);
  }

  final rpId = parsed['rp-id']!;
  var hasErrors = false;

  if (parsed.containsKey('ios-app-id')) {
    final result = await _verifyiOS(rpId, parsed['ios-app-id']!);
    _printResult(result);
    if (!result.allPassed) hasErrors = true;
  }

  if (parsed.containsKey('android-package')) {
    final fingerprint = parsed['android-fingerprint'];
    if (fingerprint == null) {
      stderr.writeln(
          'Error: --android-fingerprint required with --android-package');
      exit(1);
    }
    final result =
        await _verifyAndroid(rpId, parsed['android-package']!, fingerprint);
    _printResult(result);
    if (!result.allPassed) hasErrors = true;
  }

  if (!parsed.containsKey('ios-app-id') &&
      !parsed.containsKey('android-package')) {
    stderr.writeln('Error: specify --ios-app-id and/or --android-package');
    exit(1);
  }

  exit(hasErrors ? 1 : 0);
}

Future<DomainVerificationResult> _verifyiOS(String rpId, String appId) async {
  final url = 'https://$rpId/.well-known/apple-app-site-association';
  stdout.writeln('Fetching $url ...');

  try {
    final client = HttpClient();
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    final contentType = response.headers.contentType?.toString();

    if (response.statusCode != 200) {
      return DomainVerificationResult(rpId: rpId, checks: [
        DomainCheck(
          label: 'HTTP status',
          passed: false,
          detail: 'Got ${response.statusCode} (expected 200)',
        ),
      ]);
    }

    final json = jsonDecode(body);
    if (json is! Map<String, dynamic>) {
      return DomainVerificationResult(rpId: rpId, checks: [
        DomainCheck(
          label: 'JSON structure',
          passed: false,
          detail: 'Expected JSON object, got ${json.runtimeType}',
        ),
      ]);
    }

    client.close();
    return verifyAppleAppSiteAssociation(
      rpId: rpId,
      appId: appId,
      json: json,
      contentType: contentType,
    );
  } on SocketException catch (e) {
    return DomainVerificationResult(rpId: rpId, checks: [
      DomainCheck(label: 'TLS/Connection', passed: false, detail: e.message),
    ]);
  } on HandshakeException catch (e) {
    return DomainVerificationResult(rpId: rpId, checks: [
      DomainCheck(label: 'TLS handshake', passed: false, detail: e.message),
    ]);
  } on FormatException catch (e) {
    return DomainVerificationResult(rpId: rpId, checks: [
      DomainCheck(label: 'JSON parse', passed: false, detail: e.message),
    ]);
  }
}

Future<DomainVerificationResult> _verifyAndroid(
  String rpId,
  String packageName,
  String fingerprint,
) async {
  final url = 'https://$rpId/.well-known/assetlinks.json';
  stdout.writeln('Fetching $url ...');

  try {
    final client = HttpClient();
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    final contentType = response.headers.contentType?.toString();

    if (response.statusCode != 200) {
      return DomainVerificationResult(rpId: rpId, checks: [
        DomainCheck(
          label: 'HTTP status',
          passed: false,
          detail: 'Got ${response.statusCode} (expected 200)',
        ),
      ]);
    }

    final json = jsonDecode(body);
    if (json is! List) {
      return DomainVerificationResult(rpId: rpId, checks: [
        DomainCheck(
          label: 'JSON structure',
          passed: false,
          detail: 'Expected JSON array, got ${json.runtimeType}',
        ),
      ]);
    }

    client.close();
    return verifyAssetLinks(
      rpId: rpId,
      packageName: packageName,
      sha256Fingerprint: fingerprint,
      json: json,
      contentType: contentType,
    );
  } on SocketException catch (e) {
    return DomainVerificationResult(rpId: rpId, checks: [
      DomainCheck(label: 'TLS/Connection', passed: false, detail: e.message),
    ]);
  } on HandshakeException catch (e) {
    return DomainVerificationResult(rpId: rpId, checks: [
      DomainCheck(label: 'TLS handshake', passed: false, detail: e.message),
    ]);
  } on FormatException catch (e) {
    return DomainVerificationResult(rpId: rpId, checks: [
      DomainCheck(label: 'JSON parse', passed: false, detail: e.message),
    ]);
  }
}

void _printResult(DomainVerificationResult result) {
  stdout.writeln(result);
}

Map<String, String>? _parseArgs(List<String> args) {
  final result = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--help' || args[i] == '-h') return null;
    if (args[i].startsWith('--') && i + 1 < args.length) {
      result[args[i].substring(2)] = args[i + 1];
      i++;
    }
  }
  if (!result.containsKey('rp-id')) return null;
  return result;
}

void _printUsage() {
  stderr.writeln('''
Usage: dart run chainkey:verify_domain --rp-id <domain> [options]

Options:
  --rp-id <domain>              Relying Party domain (required)
  --ios-app-id <TeamID.BundleID>  Verify apple-app-site-association
  --android-package <package>    Verify assetlinks.json
  --android-fingerprint <SHA256> SHA-256 cert fingerprint (AA:BB:CC:...)
  --help                        Show this help

Examples:
  dart run chainkey:verify_domain --rp-id wallet.example.com \\
    --ios-app-id ABCDE12345.com.example.wallet

  dart run chainkey:verify_domain --rp-id wallet.example.com \\
    --android-package com.example.wallet \\
    --android-fingerprint AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99''');
}
