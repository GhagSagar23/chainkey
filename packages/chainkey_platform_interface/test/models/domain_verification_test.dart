import 'package:chainkey_platform_interface/chainkey_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('verifyAppleAppSiteAssociation', () {
    test('passes with valid webcredentials and matching app ID', () {
      final result = verifyAppleAppSiteAssociation(
        rpId: 'example.com',
        appId: 'ABCDE12345.com.example.wallet',
        json: {
          'webcredentials': {
            'apps': ['ABCDE12345.com.example.wallet'],
          },
        },
        contentType: 'application/json',
      );

      expect(result.allPassed, isTrue);
      expect(result.checks.length, 3);
    });

    test('fails when app ID not in apps array', () {
      final result = verifyAppleAppSiteAssociation(
        rpId: 'example.com',
        appId: 'ABCDE12345.com.example.wallet',
        json: {
          'webcredentials': {
            'apps': ['OTHER.com.other.app'],
          },
        },
      );

      expect(result.allPassed, isFalse);
      expect(
        result.checks.last.detail,
        contains('not in'),
      );
    });

    test('fails when webcredentials key missing', () {
      final result = verifyAppleAppSiteAssociation(
        rpId: 'example.com',
        appId: 'ABCDE12345.com.example.wallet',
        json: {'applinks': {}},
      );

      expect(result.allPassed, isFalse);
      expect(result.checks.last.detail, contains('Missing'));
    });

    test('fails when apps array missing', () {
      final result = verifyAppleAppSiteAssociation(
        rpId: 'example.com',
        appId: 'ABCDE12345.com.example.wallet',
        json: {
          'webcredentials': <String, dynamic>{},
        },
      );

      expect(result.allPassed, isFalse);
    });

    test('reports wrong Content-Type', () {
      final result = verifyAppleAppSiteAssociation(
        rpId: 'example.com',
        appId: 'ABCDE12345.com.example.wallet',
        json: {
          'webcredentials': {
            'apps': ['ABCDE12345.com.example.wallet'],
          },
        },
        contentType: 'text/html',
      );

      final ctCheck = result.checks.first;
      expect(ctCheck.label, 'Content-Type');
      expect(ctCheck.passed, isFalse);
    });

    test('accepts application/pkcs7-mime Content-Type', () {
      final result = verifyAppleAppSiteAssociation(
        rpId: 'example.com',
        appId: 'ABCDE12345.com.example.wallet',
        json: {
          'webcredentials': {
            'apps': ['ABCDE12345.com.example.wallet'],
          },
        },
        contentType: 'application/pkcs7-mime',
      );

      expect(result.checks.first.passed, isTrue);
    });

    test('multiple apps in array, match found', () {
      final result = verifyAppleAppSiteAssociation(
        rpId: 'example.com',
        appId: 'SECOND.com.example.app',
        json: {
          'webcredentials': {
            'apps': [
              'FIRST.com.other.app',
              'SECOND.com.example.app',
            ],
          },
        },
      );

      expect(result.allPassed, isTrue);
    });
  });

  group('verifyAssetLinks', () {
    test('passes with matching package and fingerprint', () {
      final result = verifyAssetLinks(
        rpId: 'example.com',
        packageName: 'com.example.wallet',
        sha256Fingerprint: 'AA:BB:CC:DD',
        json: [
          {
            'relation': ['delegate_permission/common.get_login_creds'],
            'target': {
              'namespace': 'android_app',
              'package_name': 'com.example.wallet',
              'sha256_cert_fingerprints': ['AA:BB:CC:DD'],
            },
          },
        ],
        contentType: 'application/json',
      );

      expect(result.allPassed, isTrue);
    });

    test('fingerprint comparison is case-insensitive', () {
      final result = verifyAssetLinks(
        rpId: 'example.com',
        packageName: 'com.example.wallet',
        sha256Fingerprint: 'aa:bb:cc:dd',
        json: [
          {
            'relation': ['delegate_permission/common.get_login_creds'],
            'target': {
              'namespace': 'android_app',
              'package_name': 'com.example.wallet',
              'sha256_cert_fingerprints': ['AA:BB:CC:DD'],
            },
          },
        ],
      );

      expect(result.allPassed, isTrue);
    });

    test('fails when package name does not match', () {
      final result = verifyAssetLinks(
        rpId: 'example.com',
        packageName: 'com.example.wallet',
        sha256Fingerprint: 'AA:BB:CC:DD',
        json: [
          {
            'relation': ['delegate_permission/common.get_login_creds'],
            'target': {
              'namespace': 'android_app',
              'package_name': 'com.other.app',
              'sha256_cert_fingerprints': ['AA:BB:CC:DD'],
            },
          },
        ],
      );

      expect(result.allPassed, isFalse);
    });

    test('fails when fingerprint does not match', () {
      final result = verifyAssetLinks(
        rpId: 'example.com',
        packageName: 'com.example.wallet',
        sha256Fingerprint: 'FF:FF:FF:FF',
        json: [
          {
            'relation': ['delegate_permission/common.get_login_creds'],
            'target': {
              'namespace': 'android_app',
              'package_name': 'com.example.wallet',
              'sha256_cert_fingerprints': ['AA:BB:CC:DD'],
            },
          },
        ],
      );

      expect(result.allPassed, isFalse);
    });

    test('fails on empty array', () {
      final result = verifyAssetLinks(
        rpId: 'example.com',
        packageName: 'com.example.wallet',
        sha256Fingerprint: 'AA:BB',
        json: [],
      );

      expect(result.allPassed, isFalse);
    });

    test('matches handle_all_urls permission too', () {
      final result = verifyAssetLinks(
        rpId: 'example.com',
        packageName: 'com.example.wallet',
        sha256Fingerprint: 'AA:BB',
        json: [
          {
            'relation': ['delegate_permission/common.handle_all_urls'],
            'target': {
              'namespace': 'android_app',
              'package_name': 'com.example.wallet',
              'sha256_cert_fingerprints': ['AA:BB'],
            },
          },
        ],
      );

      expect(result.allPassed, isTrue);
    });

    test('skips non-android_app entries', () {
      final result = verifyAssetLinks(
        rpId: 'example.com',
        packageName: 'com.example.wallet',
        sha256Fingerprint: 'AA:BB',
        json: [
          {
            'relation': ['delegate_permission/common.get_login_creds'],
            'target': {
              'namespace': 'web',
              'site': 'https://example.com',
            },
          },
        ],
      );

      expect(result.allPassed, isFalse);
    });

    test('reports wrong Content-Type', () {
      final result = verifyAssetLinks(
        rpId: 'example.com',
        packageName: 'com.example.wallet',
        sha256Fingerprint: 'AA:BB',
        json: [
          {
            'relation': ['delegate_permission/common.get_login_creds'],
            'target': {
              'namespace': 'android_app',
              'package_name': 'com.example.wallet',
              'sha256_cert_fingerprints': ['AA:BB'],
            },
          },
        ],
        contentType: 'text/plain',
      );

      final ctCheck = result.checks.first;
      expect(ctCheck.passed, isFalse);
    });

    test('toString produces readable output', () {
      final result = verifyAssetLinks(
        rpId: 'example.com',
        packageName: 'com.example.wallet',
        sha256Fingerprint: 'AA:BB',
        json: [
          {
            'relation': ['delegate_permission/common.get_login_creds'],
            'target': {
              'namespace': 'android_app',
              'package_name': 'com.example.wallet',
              'sha256_cert_fingerprints': ['AA:BB'],
            },
          },
        ],
      );

      expect(result.toString(), contains('example.com'));
      expect(result.toString(), contains('✓'));
    });
  });
}
