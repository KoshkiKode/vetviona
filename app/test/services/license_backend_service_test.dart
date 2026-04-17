import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetviona_app/services/license_backend_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LicenseBackendService.init', () {
    test('loads cached verification state', () async {
      SharedPreferences.setMockInitialValues({
        'license_backend_account_email': 'paid@example.com',
        'license_backend_mobile_verified': true,
        'license_backend_desktop_verified': true,
        'license_backend_mobile_entitled': true,
        'license_backend_desktop_entitled': true,
        'license_backend_devices': jsonEncode([
          {
            'id': 'dev-1',
            'appType': 'desktop',
            'os': 'linux',
            'firstVerifiedAt': '2026-01-01T00:00:00.000Z',
            'lastVerifiedAt': '2026-01-02T00:00:00.000Z',
          },
        ]),
      });

      final service = LicenseBackendService(
        client: MockClient((_) async => http.Response('{}', 200)),
        baseUrl: 'http://localhost:8080',
      );
      await service.init();

      expect(service.isInitialized, isTrue);
      expect(service.accountEmail, 'paid@example.com');
      expect(service.devices, hasLength(1));
      expect(service.devices.first.id, 'dev-1');
      expect(service.isCurrentTierVerified, isTrue);
    });
  });

  group('LicenseBackendService.verifyLicense', () {
    test('persists verification when backend approves entitlement', () async {
      final service = LicenseBackendService(
        client: MockClient((request) async {
          expect(request.url.path, '/v1/license/verify');
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          expect(payload['appType'], 'desktop');
          return http.Response(
            jsonEncode({
              'ok': true,
              'entitlements': {'mobile': true, 'desktop': true},
              'devices': [
                {
                  'id': payload['deviceId'],
                  'appType': 'desktop',
                  'os': 'linux',
                  'firstVerifiedAt': '2026-01-01T00:00:00.000Z',
                  'lastVerifiedAt': '2026-01-01T00:00:00.000Z',
                },
              ],
            }),
            200,
          );
        }),
        baseUrl: 'http://license.example',
      );

      await service.init();
      final ok = await service.verifyLicense(
        email: 'paid@example.com',
        password: 'StrongPassword!',
      );

      expect(ok, isTrue);
      expect(service.errorMessage, isNull);
      expect(service.accountEmail, 'paid@example.com');
      expect(service.isCurrentTierVerified, isTrue);
      expect(service.devices, isNotEmpty);
    });

    test('returns error when account lacks desktop entitlement', () async {
      final service = LicenseBackendService(
        client: MockClient((_) async {
          return http.Response(
            jsonEncode({
              'ok': true,
              'entitlements': {'mobile': true, 'desktop': false},
              'devices': [],
            }),
            200,
          );
        }),
        baseUrl: 'http://license.example',
      );

      await service.init();
      final ok = await service.verifyLicense(
        email: 'mobile-only@example.com',
        password: 'StrongPassword!',
      );

      expect(ok, isFalse);
      expect(service.isCurrentTierVerified, isFalse);
      expect(service.errorMessage, contains('desktop license'));
    });
  });
}
