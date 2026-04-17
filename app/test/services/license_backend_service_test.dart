import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetviona_app/services/license_backend_service.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Map<String, dynamic> _fullAccount({
  String email = 'paid@example.com',
  bool emailVerified = true,
  Map<String, bool>? entitlements,
  Map<String, String>? licensesDetail,
  List<Map<String, dynamic>>? outgoingGifts,
  List<Map<String, dynamic>>? devices,
}) {
  return {
    'id': 'acct-1',
    'email': email,
    'emailVerified': emailVerified,
    'entitlements':
        entitlements ?? {'apple': true, 'android': true, 'desktop': true},
    'licensesDetail':
        licensesDetail ??
        {'apple': 'active', 'android': 'active', 'desktop': 'active'},
    'outgoingGifts': outgoingGifts ?? [],
    'devices': devices ?? [],
  };
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ── init ──────────────────────────────────────────────────────────────────
  group('LicenseBackendService.init', () {
    test('loads cached three-license verification state', () async {
      SharedPreferences.setMockInitialValues({
        'license_backend_account_email': 'paid@example.com',
        'license_backend_apple_verified': true,
        'license_backend_android_verified': true,
        'license_backend_desktop_verified': true,
        'license_backend_apple_entitled': true,
        'license_backend_android_entitled': true,
        'license_backend_desktop_entitled': true,
        'license_backend_email_verified': true,
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
      expect(service.emailVerified, isTrue);
      expect(service.appleEntitled, isTrue);
      expect(service.androidEntitled, isTrue);
      expect(service.desktopEntitled, isTrue);
      expect(service.devices, hasLength(1));
      expect(service.devices.first.id, 'dev-1');
      // On the test host (Linux desktop) the tier is desktopPro, which is verified.
      expect(service.isCurrentTierVerified, isTrue);
    });
  });

  // ── verifyLicense ─────────────────────────────────────────────────────────
  group('LicenseBackendService.verifyLicense', () {
    test(
      'persists desktop verification when backend approves entitlement',
      () async {
        final service = LicenseBackendService(
          client: MockClient((request) async {
            expect(request.url.path, '/v1/license/verify');
            final payload = jsonDecode(request.body) as Map<String, dynamic>;
            expect(payload['appType'], 'desktop');
            return http.Response(
              jsonEncode({
                'ok': true,
                'entitlements': {
                  'apple': true,
                  'android': true,
                  'desktop': true,
                },
                'emailVerified': true,
                'licensesDetail': {
                  'apple': 'active',
                  'android': 'active',
                  'desktop': 'active',
                },
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
        expect(service.emailVerified, isTrue);
        expect(service.appleLicenseStatus, 'active');
        expect(service.desktopLicenseStatus, 'active');
        expect(service.devices, isNotEmpty);
        expect(service.canManageAccount, isTrue);
      },
    );

    test('returns error when account lacks desktop entitlement', () async {
      final service = LicenseBackendService(
        client: MockClient((_) async {
          return http.Response(
            jsonEncode({
              'ok': true,
              'entitlements': {
                'apple': true,
                'android': true,
                'desktop': false,
              },
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

  // ── syncAccount ───────────────────────────────────────────────────────────
  group('LicenseBackendService.syncAccount', () {
    test('updates entitlements and gifts from sync response', () async {
      final service = LicenseBackendService(
        client: MockClient((request) async {
          if (request.url.path == '/v1/license/verify') {
            return http.Response(
              jsonEncode({
                'ok': true,
                'entitlements': {
                  'apple': true,
                  'android': false,
                  'desktop': true,
                },
                'emailVerified': true,
                'licensesDetail': {
                  'apple': 'active',
                  'android': 'none',
                  'desktop': 'active',
                },
                'devices': [],
              }),
              200,
            );
          }
          // sync call
          return http.Response(
            jsonEncode({
              'ok': true,
              'account': _fullAccount(
                entitlements: {
                  'apple': false,
                  'android': false,
                  'desktop': true,
                },
                licensesDetail: {
                  'apple': 'gifted_out',
                  'android': 'none',
                  'desktop': 'active',
                },
                outgoingGifts: [
                  {
                    'id': 'gift-1',
                    'licenseType': 'apple',
                    'toEmail': 'bob@example.com',
                    'expiresAt': '2026-04-20T00:00:00.000Z',
                    'createdAt': '2026-04-17T00:00:00.000Z',
                  },
                ],
              ),
              'incomingGifts': [],
            }),
            200,
          );
        }),
        baseUrl: 'http://license.example',
      );

      await service.init();
      await service.verifyLicense(
        email: 'paid@example.com',
        password: 'StrongPassword!',
      );
      final syncOk = await service.syncAccount();

      expect(syncOk, isTrue);
      expect(service.appleLicenseStatus, 'gifted_out');
      expect(service.desktopLicenseStatus, 'active');
      expect(service.androidLicenseStatus, 'none');
      expect(service.outgoingGifts, hasLength(1));
      expect(service.outgoingGifts.first.licenseType, 'apple');
      expect(service.outgoingGifts.first.toEmail, 'bob@example.com');
      expect(service.incomingGifts, isEmpty);
    });

    test('fails gracefully when not signed in', () async {
      final service = LicenseBackendService(
        client: MockClient((_) async => http.Response('{}', 200)),
        baseUrl: 'http://license.example',
      );

      await service.init();
      final ok = await service.syncAccount();

      expect(ok, isFalse);
      expect(service.errorMessage, contains('signed in'));
    });
  });

  // ── gift flows ────────────────────────────────────────────────────────────
  group('LicenseBackendService gift flows', () {
    Future<LicenseBackendService> _signedInService({
      required Map<String, dynamic> Function(String path) handler,
    }) async {
      final service = LicenseBackendService(
        client: MockClient((req) async {
          final body = handler(req.url.path);
          return http.Response(
            jsonEncode(body),
            body['ok'] == true ? 200 : 400,
          );
        }),
        baseUrl: 'http://license.example',
      );
      await service.init();
      // Fake a prior verifyLicense to populate email+cached password.
      SharedPreferences.setMockInitialValues({
        'license_backend_account_email': 'alice@example.com',
        'license_backend_desktop_verified': true,
        'license_backend_desktop_entitled': true,
        'license_backend_email_verified': true,
      });
      await service.init();
      // Manually set the cached password via verifyLicense mock response.
      return service;
    }

    test('initiateGift updates outgoing gifts on success', () async {
      int callCount = 0;
      final service = LicenseBackendService(
        client: MockClient((req) async {
          callCount++;
          if (req.url.path == '/v1/license/verify') {
            return http.Response(
              jsonEncode({
                'ok': true,
                'entitlements': {
                  'apple': false,
                  'android': false,
                  'desktop': true,
                },
                'emailVerified': true,
                'licensesDetail': {
                  'apple': 'none',
                  'android': 'none',
                  'desktop': 'active',
                },
                'devices': [],
              }),
              200,
            );
          }
          // gift initiate
          return http.Response(
            jsonEncode({
              'ok': true,
              'gift': {
                'id': 'gift-1',
                'licenseType': 'desktop',
                'toEmail': 'bob@example.com',
                'expiresAt': '2026-04-20T00:00:00.000Z',
              },
              'account': _fullAccount(
                entitlements: {
                  'apple': false,
                  'android': false,
                  'desktop': false,
                },
                licensesDetail: {
                  'apple': 'none',
                  'android': 'none',
                  'desktop': 'gifted_out',
                },
                outgoingGifts: [
                  {
                    'id': 'gift-1',
                    'licenseType': 'desktop',
                    'toEmail': 'bob@example.com',
                    'expiresAt': '2026-04-20T00:00:00.000Z',
                    'createdAt': '2026-04-17T00:00:00.000Z',
                  },
                ],
              ),
              'incomingGifts': [],
            }),
            200,
          );
        }),
        baseUrl: 'http://license.example',
      );

      await service.init();
      await service.verifyLicense(
        email: 'alice@example.com',
        password: 'Password!1',
      );
      final ok = await service.initiateGift(
        licenseType: 'desktop',
        toEmail: 'bob@example.com',
      );

      expect(ok, isTrue);
      expect(service.desktopLicenseStatus, 'gifted_out');
      expect(service.outgoingGifts, hasLength(1));
      expect(service.outgoingGifts.first.toEmail, 'bob@example.com');
    });

    test('initiateGift sends requested licenseType for each license kind', () async {
      const licenseTypes = <String>['apple', 'android', 'desktop'];

      for (final licenseType in licenseTypes) {
        String? seenLicenseType;
        final service = LicenseBackendService(
          client: MockClient((req) async {
            if (req.url.path == '/v1/license/verify') {
              return http.Response(
                jsonEncode({
                  'ok': true,
                  'entitlements': {
                    'apple': true,
                    'android': true,
                    'desktop': true,
                  },
                  'emailVerified': true,
                  'licensesDetail': {
                    'apple': 'active',
                    'android': 'active',
                    'desktop': 'active',
                  },
                  'devices': [],
                }),
                200,
              );
            }

            final payload = jsonDecode(req.body) as Map<String, dynamic>;
            seenLicenseType = payload['licenseType']?.toString();
            expect(payload['toEmail'], 'target@example.com');

            final giftedOut = seenLicenseType;
            final entitlements = {
              'apple': giftedOut != 'apple',
              'android': giftedOut != 'android',
              'desktop': giftedOut != 'desktop',
            };
            final licensesDetail = {
              'apple': giftedOut == 'apple' ? 'gifted_out' : 'active',
              'android': giftedOut == 'android' ? 'gifted_out' : 'active',
              'desktop': giftedOut == 'desktop' ? 'gifted_out' : 'active',
            };

            return http.Response(
              jsonEncode({
                'ok': true,
                'gift': {
                  'id': 'gift-$giftedOut',
                  'licenseType': giftedOut,
                  'toEmail': 'target@example.com',
                  'expiresAt': '2026-04-20T00:00:00.000Z',
                },
                'account': _fullAccount(
                  entitlements: entitlements,
                  licensesDetail: licensesDetail,
                  outgoingGifts: [
                    {
                      'id': 'gift-$giftedOut',
                      'licenseType': giftedOut,
                      'toEmail': 'target@example.com',
                      'expiresAt': '2026-04-20T00:00:00.000Z',
                      'createdAt': '2026-04-17T00:00:00.000Z',
                    },
                  ],
                ),
                'incomingGifts': [],
              }),
              200,
            );
          }),
          baseUrl: 'http://license.example',
        );

        await service.init();
        await service.verifyLicense(
          email: 'alice@example.com',
          password: 'Password!1',
        );
        final ok = await service.initiateGift(
          licenseType: licenseType,
          toEmail: 'target@example.com',
        );

        expect(ok, isTrue);
        expect(seenLicenseType, licenseType);
        expect(service.outgoingGifts, hasLength(1));
        expect(service.outgoingGifts.first.licenseType, licenseType);
      }
    });

    test('claimGift by token succeeds', () async {
      final service = LicenseBackendService(
        client: MockClient((req) async {
          if (req.url.path == '/v1/license/verify') {
            return http.Response(
              jsonEncode({
                'ok': true,
                'entitlements': {
                  'apple': false,
                  'android': false,
                  'desktop': true,
                },
                'emailVerified': true,
                'licensesDetail': {
                  'apple': 'none',
                  'android': 'none',
                  'desktop': 'active',
                },
                'devices': [],
              }),
              200,
            );
          }
          // claim
          final payload = jsonDecode(req.body) as Map<String, dynamic>;
          expect(payload['token'], 'ABCD1234');
          return http.Response(
            jsonEncode({
              'ok': true,
              'message': 'apple license claimed successfully.',
              'account': _fullAccount(
                entitlements: {
                  'apple': true,
                  'android': false,
                  'desktop': true,
                },
                licensesDetail: {
                  'apple': 'active',
                  'android': 'none',
                  'desktop': 'active',
                },
              ),
              'incomingGifts': [],
            }),
            200,
          );
        }),
        baseUrl: 'http://license.example',
      );

      await service.init();
      await service.verifyLicense(
        email: 'bob@example.com',
        password: 'Password!1',
      );
      final ok = await service.claimGift(token: 'ABCD1234');

      expect(ok, isTrue);
      expect(service.appleLicenseStatus, 'active');
      expect(service.appleEntitled, isTrue);
    });

    test('cancelGift forwards provided licenseType for each license kind', () async {
      const licenseTypes = <String>['apple', 'android', 'desktop'];

      for (final licenseType in licenseTypes) {
        String? seenLicenseType;
        final service = LicenseBackendService(
          client: MockClient((req) async {
            if (req.url.path == '/v1/license/verify') {
              return http.Response(
                jsonEncode({
                  'ok': true,
                  'entitlements': {
                    'apple': true,
                    'android': true,
                    'desktop': true,
                  },
                  'emailVerified': true,
                  'licensesDetail': {
                    'apple': 'active',
                    'android': 'active',
                    'desktop': 'active',
                  },
                  'devices': [],
                }),
                200,
              );
            }

            final payload = jsonDecode(req.body) as Map<String, dynamic>;
            seenLicenseType = payload['licenseType']?.toString();
            return http.Response(
              jsonEncode({
                'ok': true,
                'account': _fullAccount(
                  entitlements: {
                    'apple': true,
                    'android': true,
                    'desktop': true,
                  },
                  licensesDetail: {
                    'apple': 'active',
                    'android': 'active',
                    'desktop': 'active',
                  },
                  outgoingGifts: [],
                ),
                'incomingGifts': [],
              }),
              200,
            );
          }),
          baseUrl: 'http://license.example',
        );

        await service.init();
        await service.verifyLicense(
          email: 'alice@example.com',
          password: 'Password!1',
        );
        final ok = await service.cancelGift(licenseType: licenseType);

        expect(ok, isTrue);
        expect(seenLicenseType, licenseType);
      }
    });
  });

  // ── signOut ───────────────────────────────────────────────────────────────
  group('LicenseBackendService.signOut', () {
    test('clears all persisted verification state', () async {
      SharedPreferences.setMockInitialValues({
        'license_backend_account_email': 'paid@example.com',
        'license_backend_desktop_verified': true,
        'license_backend_desktop_entitled': true,
        'license_backend_email_verified': true,
      });

      final service = LicenseBackendService(
        client: MockClient((_) async => http.Response('{}', 200)),
        baseUrl: 'http://localhost:8080',
      );
      await service.init();
      expect(service.isSignedIn, isTrue);

      await service.signOut();

      expect(service.isSignedIn, isFalse);
      expect(service.isCurrentTierVerified, isFalse);
      expect(service.emailVerified, isFalse);
      expect(service.desktopEntitled, isFalse);

      // SharedPreferences should also be cleared.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('license_backend_account_email'), isNull);
      expect(prefs.getBool('license_backend_desktop_verified'), isNull);
    });
  });

  // ── changePassword ────────────────────────────────────────────────────────
  group('LicenseBackendService.changePassword', () {
    test('updates cachedPassword on success', () async {
      final service = LicenseBackendService(
        client: MockClient((req) async {
          if (req.url.path == '/v1/license/verify') {
            return http.Response(
              jsonEncode({
                'ok': true,
                'entitlements': {
                  'apple': false,
                  'android': false,
                  'desktop': true,
                },
                'emailVerified': true,
                'licensesDetail': {
                  'apple': 'none',
                  'android': 'none',
                  'desktop': 'active',
                },
                'devices': [],
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'ok': true,
              'message': 'Password changed successfully.',
            }),
            200,
          );
        }),
        baseUrl: 'http://license.example',
      );

      await service.init();
      await service.verifyLicense(
        email: 'user@example.com',
        password: 'OldPassword!',
      );
      expect(service.canManageAccount, isTrue);

      final ok = await service.changePassword(
        currentPassword: 'OldPassword!',
        newPassword: 'NewPassword!1',
      );

      expect(ok, isTrue);
      expect(service.canManageAccount, isTrue);
    });
  });
}
