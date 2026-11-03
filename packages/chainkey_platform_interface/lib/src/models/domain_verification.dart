/// Result of verifying a WebAuthn Relying Party domain association file.
class DomainVerificationResult {
  DomainVerificationResult({
    required this.rpId,
    required this.checks,
  });

  final String rpId;
  final List<DomainCheck> checks;

  bool get allPassed => checks.every((c) => c.passed);

  @override
  String toString() {
    final buf = StringBuffer('Domain verification for $rpId:\n');
    for (final check in checks) {
      buf.writeln(
          '  ${check.passed ? "✓" : "✗"} ${check.label}: ${check.detail}');
    }
    return buf.toString();
  }
}

/// A single pass/fail check within domain verification.
class DomainCheck {
  DomainCheck({
    required this.label,
    required this.passed,
    required this.detail,
  });

  final String label;
  final bool passed;
  final String detail;
}

/// Validates an iOS `apple-app-site-association` JSON structure for WebAuthn.
///
/// Checks that `webcredentials.apps` contains the given [appId]
/// (format: `<TeamID>.<BundleID>`).
DomainVerificationResult verifyAppleAppSiteAssociation({
  required String rpId,
  required String appId,
  required Map<String, dynamic> json,
  String? contentType,
}) {
  final checks = <DomainCheck>[];

  // Content-Type check
  if (contentType != null) {
    final isJson = contentType.contains('application/json') ||
        contentType.contains('application/pkcs7-mime');
    checks.add(DomainCheck(
      label: 'Content-Type',
      passed: isJson,
      detail:
          isJson ? contentType : 'Expected application/json, got: $contentType',
    ));
  }

  // webcredentials key exists
  final wc = json['webcredentials'];
  if (wc == null || wc is! Map) {
    checks.add(DomainCheck(
      label: 'webcredentials',
      passed: false,
      detail: 'Missing "webcredentials" object',
    ));
    return DomainVerificationResult(rpId: rpId, checks: checks);
  }

  checks.add(DomainCheck(
    label: 'webcredentials',
    passed: true,
    detail: 'Present',
  ));

  // apps array contains appId
  final apps = wc['apps'];
  if (apps == null || apps is! List) {
    checks.add(DomainCheck(
      label: 'webcredentials.apps',
      passed: false,
      detail: 'Missing "apps" array',
    ));
    return DomainVerificationResult(rpId: rpId, checks: checks);
  }

  final appsList = apps.cast<String>();
  final found = appsList.contains(appId);
  checks.add(DomainCheck(
    label: 'App ID match',
    passed: found,
    detail: found ? 'Found "$appId"' : '"$appId" not in $appsList',
  ));

  return DomainVerificationResult(rpId: rpId, checks: checks);
}

/// Validates an Android `assetlinks.json` structure for WebAuthn.
///
/// Checks that at least one entry has `delegate_permission/common.get_login_creds`
/// and matches the given [packageName] and [sha256Fingerprint].
DomainVerificationResult verifyAssetLinks({
  required String rpId,
  required String packageName,
  required String sha256Fingerprint,
  required List<dynamic> json,
  String? contentType,
}) {
  final checks = <DomainCheck>[];

  // Content-Type check
  if (contentType != null) {
    final isJson = contentType.contains('application/json');
    checks.add(DomainCheck(
      label: 'Content-Type',
      passed: isJson,
      detail:
          isJson ? contentType : 'Expected application/json, got: $contentType',
    ));
  }

  if (json.isEmpty) {
    checks.add(DomainCheck(
      label: 'assetlinks.json',
      passed: false,
      detail: 'Empty array',
    ));
    return DomainVerificationResult(rpId: rpId, checks: checks);
  }

  checks.add(DomainCheck(
    label: 'assetlinks.json',
    passed: true,
    detail: '${json.length} entries',
  ));

  // Find matching entry
  final normalizedFp = sha256Fingerprint.toUpperCase();
  var found = false;

  for (final entry in json) {
    if (entry is! Map) continue;
    final relation = entry['relation'];
    if (relation is! List) continue;
    final hasPermission = relation.any(
      (r) =>
          r == 'delegate_permission/common.handle_all_urls' ||
          r == 'delegate_permission/common.get_login_creds',
    );
    if (!hasPermission) continue;

    final target = entry['target'];
    if (target is! Map) continue;
    if (target['namespace'] != 'android_app') continue;
    if (target['package_name'] != packageName) continue;

    final fingerprints = target['sha256_cert_fingerprints'];
    if (fingerprints is! List) continue;
    if (fingerprints.any((f) => (f as String).toUpperCase() == normalizedFp)) {
      found = true;
      break;
    }
  }

  checks.add(DomainCheck(
    label: 'Package + fingerprint match',
    passed: found,
    detail: found
        ? 'Found $packageName with matching SHA-256'
        : 'No entry for $packageName with fingerprint $normalizedFp',
  ));

  return DomainVerificationResult(rpId: rpId, checks: checks);
}
