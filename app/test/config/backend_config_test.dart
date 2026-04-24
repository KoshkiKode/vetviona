import 'package:flutter_test/flutter_test.dart';
import 'package:vetviona_app/config/backend_config.dart';

void main() {
  group('BackendConfig', () {
    group('productionBaseUrl', () {
      test('is a non-empty string', () {
        expect(BackendConfig.productionBaseUrl, isNotEmpty);
      });

      test('uses https://', () {
        expect(BackendConfig.productionBaseUrl, startsWith('https://'));
      });

      test('does not end with a trailing slash', () {
        expect(BackendConfig.productionBaseUrl, isNot(endsWith('/')));
      });
    });

    group('baseUrl', () {
      test('returns a non-empty string', () {
        expect(BackendConfig.baseUrl, isNotEmpty);
      });

      test('does not end with a trailing slash', () {
        expect(BackendConfig.baseUrl, isNot(endsWith('/')));
      });

      test('starts with https:// in the test environment (no http:// override)', () {
        // Tests run without --dart-define=LICENSE_BACKEND_URL, so the
        // production URL is used, which must use HTTPS.
        expect(BackendConfig.baseUrl, startsWith('https://'));
      });

      test('equals productionBaseUrl when no compile-time override is provided', () {
        // In the test runner no --dart-define override is set, so baseUrl
        // falls back to productionBaseUrl.
        expect(BackendConfig.baseUrl, equals(BackendConfig.productionBaseUrl));
      });
    });

    group('isHttps', () {
      test('returns true when baseUrl uses https://', () {
        // Production URL always uses HTTPS, so this must be true in tests.
        expect(BackendConfig.isHttps, isTrue);
      });

      test('returns a bool', () {
        expect(BackendConfig.isHttps, isA<bool>());
      });
    });

    group('requestTimeout', () {
      test('is a Duration', () {
        expect(BackendConfig.requestTimeout, isA<Duration>());
      });

      test('is positive', () {
        expect(BackendConfig.requestTimeout.inSeconds, greaterThan(0));
      });

      test('is at most 60 seconds to avoid excessive blocking', () {
        expect(BackendConfig.requestTimeout.inSeconds, lessThanOrEqualTo(60));
      });
    });

    group('versionCheckTimeout', () {
      test('is a Duration', () {
        expect(BackendConfig.versionCheckTimeout, isA<Duration>());
      });

      test('is positive', () {
        expect(BackendConfig.versionCheckTimeout.inSeconds, greaterThan(0));
      });

      test('is shorter than requestTimeout (opportunistic ping)', () {
        expect(
          BackendConfig.versionCheckTimeout,
          lessThan(BackendConfig.requestTimeout),
        );
      });
    });
  });
}
