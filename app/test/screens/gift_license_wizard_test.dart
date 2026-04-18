// Tests for GiftLicenseWizard — exercises all four steps:
//   0: Pick License    1: Enter Recipient    2: Review    3: Success
//
// Approach: build a minimal MaterialApp with a mocked LicenseBackendService
// that is already in the "verified / signed-in" state required by the wizard.
// HTTP is intercepted via http/testing.dart.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vetviona_app/screens/gift_license_wizard.dart';
import 'package:vetviona_app/services/license_backend_service.dart';

// ── Fixture helpers ────────────────────────────────────────────────────────────

/// Returns a [LicenseBackendService] that is already verified (all three
/// licenses active) via a mocked HTTP client, and can accept custom [handler]
/// callbacks for subsequent requests.
Future<LicenseBackendService> _verifiedService({
  required FutureOr<http.Response> Function(http.Request) handler,
}) async {
  SharedPreferences.setMockInitialValues({});
  final svc = LicenseBackendService(
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
      return handler(req);
    }),
    baseUrl: 'http://license.example',
  );
  await svc.init();
  await svc.verifyLicense(email: 'alice@example.com', password: 'Pw!1');
  return svc;
}

Widget _buildApp(Widget child, LicenseBackendService svc) {
  return ChangeNotifierProvider<LicenseBackendService>.value(
    value: svc,
    child: MaterialApp(home: child),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ── Step 0: Pick License ──────────────────────────────────────────────────

  group('GiftLicenseWizard — step 0: pick license', () {
    testWidgets('shows all three license options when all are active',
        (tester) async {
      final svc = await _verifiedService(
        handler: (_) async => http.Response('{}', 200),
      );

      await tester.pumpWidget(_buildApp(const GiftLicenseWizard(), svc));
      await tester.pump();

      expect(find.text('Apple (iOS)'), findsOneWidget);
      expect(find.text('Android'), findsOneWidget);
      expect(find.text('Desktop'), findsOneWidget);
      expect(find.text('Which license do you want to gift?'), findsOneWidget);
    });

    testWidgets('shows "Not owned" pill for licenses with status none',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final svc = LicenseBackendService(
        client: MockClient((req) async {
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
        }),
        baseUrl: 'http://license.example',
      );
      await svc.init();
      await svc.verifyLicense(email: 'alice@example.com', password: 'Pw!1');

      await tester.pumpWidget(_buildApp(const GiftLicenseWizard(), svc));
      await tester.pump();

      // Two "Not owned" pills for apple + android.
      expect(find.text('Not owned'), findsNWidgets(2));
    });

    testWidgets('shows "Pending" pill for gifted_out license', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final svc = LicenseBackendService(
        client: MockClient((_) async {
          return http.Response(
            jsonEncode({
              'ok': true,
              'entitlements': {
                'apple': false,
                'android': true,
                'desktop': true,
              },
              'emailVerified': true,
              'licensesDetail': {
                'apple': 'gifted_out',
                'android': 'active',
                'desktop': 'active',
              },
              'devices': [],
            }),
            200,
          );
        }),
        baseUrl: 'http://license.example',
      );
      await svc.init();
      await svc.verifyLicense(email: 'alice@example.com', password: 'Pw!1');

      await tester.pumpWidget(_buildApp(const GiftLicenseWizard(), svc));
      await tester.pump();

      expect(find.text('Pending'), findsOneWidget);
    });

    testWidgets('tapping an active license advances to step 1', (tester) async {
      final svc = await _verifiedService(
        handler: (_) async => http.Response('{}', 200),
      );

      await tester.pumpWidget(_buildApp(const GiftLicenseWizard(), svc));
      await tester.pump();

      await tester.tap(find.text('Desktop'));
      await tester.pumpAndSettle();

      expect(find.text("Who will receive this license?"), findsOneWidget);
    });
  });

  // ── preselectedType skips step 0 ─────────────────────────────────────────

  group('GiftLicenseWizard — preselectedType', () {
    testWidgets('starts at step 1 when preselectedType is provided',
        (tester) async {
      final svc = await _verifiedService(
        handler: (_) async => http.Response('{}', 200),
      );

      await tester.pumpWidget(
        _buildApp(
          const GiftLicenseWizard(preselectedType: 'desktop'),
          svc,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Who will receive this license?"), findsOneWidget);
      // License header chip should show the selected type.
      expect(find.text('Desktop'), findsOneWidget);
    });
  });

  // ── Step 1: Enter Recipient ───────────────────────────────────────────────

  group('GiftLicenseWizard — step 1: enter recipient', () {
    testWidgets('validates empty email', (tester) async {
      final svc = await _verifiedService(
        handler: (_) async => http.Response('{}', 200),
      );

      await tester.pumpWidget(
        _buildApp(const GiftLicenseWizard(preselectedType: 'desktop'), svc),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(find.text('Email is required.'), findsOneWidget);
    });

    testWidgets('validates malformed email', (tester) async {
      final svc = await _verifiedService(
        handler: (_) async => http.Response('{}', 200),
      );

      await tester.pumpWidget(
        _buildApp(const GiftLicenseWizard(preselectedType: 'desktop'), svc),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'not-an-email');
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(find.text('Enter a valid email address.'), findsOneWidget);
    });

    testWidgets('valid email advances to step 2 (review)', (tester) async {
      final svc = await _verifiedService(
        handler: (_) async => http.Response('{}', 200),
      );

      await tester.pumpWidget(
        _buildApp(const GiftLicenseWizard(preselectedType: 'desktop'), svc),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextFormField), 'bob@example.com',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Review your transfer'), findsOneWidget);
    });
  });

  // ── Step 2: Review ────────────────────────────────────────────────────────

  group('GiftLicenseWizard — step 2: review', () {
    testWidgets('shows license, recipient email, and expiry on review page',
        (tester) async {
      final svc = await _verifiedService(
        handler: (_) async => http.Response('{}', 200),
      );

      await tester.pumpWidget(
        _buildApp(const GiftLicenseWizard(preselectedType: 'desktop'), svc),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextFormField), 'bob@example.com',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Desktop'), findsAtLeastNWidgets(1));
      expect(find.text('bob@example.com'), findsAtLeastNWidgets(1));
      expect(find.text('After 72 hours'), findsOneWidget);
      expect(find.text('Send Transfer'), findsOneWidget);
    });

    testWidgets('successful submit advances to step 3 (success)',
        (tester) async {
      final svc = await _verifiedService(
        handler: (req) async {
          return http.Response(
            jsonEncode({
              'ok': true,
              'gift': {
                'id': 'gift-99',
                'licenseType': 'desktop',
                'toEmail': 'bob@example.com',
                'expiresAt': '2099-01-01T00:00:00.000Z',
              },
              'account': {
                'id': 'acct-1',
                'email': 'alice@example.com',
                'emailVerified': true,
                'entitlements': {
                  'apple': true,
                  'android': true,
                  'desktop': false,
                },
                'licensesDetail': {
                  'apple': 'active',
                  'android': 'active',
                  'desktop': 'gifted_out',
                },
                'outgoingGifts': [
                  {
                    'id': 'gift-99',
                    'licenseType': 'desktop',
                    'toEmail': 'bob@example.com',
                    'expiresAt': '2099-01-01T00:00:00.000Z',
                    'createdAt': '2026-04-17T00:00:00.000Z',
                  },
                ],
                'devices': [],
              },
              'incomingGifts': [],
            }),
            200,
          );
        },
      );

      await tester.pumpWidget(
        _buildApp(const GiftLicenseWizard(preselectedType: 'desktop'), svc),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextFormField), 'bob@example.com',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Send Transfer'));
      await tester.pumpAndSettle();

      expect(find.text('Transfer initiated!'), findsOneWidget);
      expect(find.textContaining('bob@example.com'), findsAtLeastNWidgets(1));
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('failed submit shows error snackbar and stays on review',
        (tester) async {
      final svc = await _verifiedService(
        handler: (_) async {
          return http.Response(
            jsonEncode({'ok': false, 'message': 'Transfer blocked.'}),
            400,
          );
        },
      );

      await tester.pumpWidget(
        _buildApp(const GiftLicenseWizard(preselectedType: 'desktop'), svc),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextFormField), 'bob@example.com',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Send Transfer'));
      await tester.pumpAndSettle();

      expect(find.text('Transfer blocked.'), findsOneWidget);
      // Still on review page.
      expect(find.text('Review your transfer'), findsOneWidget);
    });
  });

  // ── Step 3: Success ───────────────────────────────────────────────────────

  group('GiftLicenseWizard — step 3: success', () {
    Future<void> _advanceToSuccess(WidgetTester tester,
        LicenseBackendService svc) async {
      await tester.pumpWidget(
        _buildApp(const GiftLicenseWizard(preselectedType: 'desktop'), svc),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byType(TextFormField), 'bob@example.com',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send Transfer'));
      await tester.pumpAndSettle();
    }

    testWidgets('success page shows correct recipient info', (tester) async {
      final svc = await _verifiedService(
        handler: (_) async => http.Response(
          jsonEncode({
            'ok': true,
            'gift': {
              'id': 'gift-1',
              'licenseType': 'desktop',
              'toEmail': 'bob@example.com',
              'expiresAt': '2099-01-01T00:00:00.000Z',
            },
            'account': {
              'id': 'acct-1',
              'email': 'alice@example.com',
              'emailVerified': true,
              'entitlements': {
                'apple': true,
                'android': true,
                'desktop': false,
              },
              'licensesDetail': {
                'apple': 'active',
                'android': 'active',
                'desktop': 'gifted_out',
              },
              'outgoingGifts': [
                {
                  'id': 'gift-1',
                  'licenseType': 'desktop',
                  'toEmail': 'bob@example.com',
                  'expiresAt': '2099-01-01T00:00:00.000Z',
                  'createdAt': '2026-04-17T00:00:00.000Z',
                },
              ],
              'devices': [],
            },
            'incomingGifts': [],
          }),
          200,
        ),
      );

      await _advanceToSuccess(tester, svc);

      expect(find.text('Transfer initiated!'), findsOneWidget);
      expect(find.textContaining('bob@example.com'), findsAtLeastNWidgets(1));
    });

    testWidgets('Done button is present on success page', (tester) async {
      final svc = await _verifiedService(
        handler: (_) async => http.Response(
          jsonEncode({
            'ok': true,
            'gift': {
              'id': 'gift-2',
              'licenseType': 'desktop',
              'toEmail': 'bob@example.com',
              'expiresAt': '2099-01-01T00:00:00.000Z',
            },
            'account': {
              'id': 'acct-1',
              'email': 'alice@example.com',
              'emailVerified': true,
              'entitlements': {
                'apple': true,
                'android': true,
                'desktop': false,
              },
              'licensesDetail': {
                'apple': 'active',
                'android': 'active',
                'desktop': 'gifted_out',
              },
              'outgoingGifts': [],
              'devices': [],
            },
            'incomingGifts': [],
          }),
          200,
        ),
      );

      await _advanceToSuccess(tester, svc);

      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('back button is hidden on success page', (tester) async {
      final svc = await _verifiedService(
        handler: (_) async => http.Response(
          jsonEncode({
            'ok': true,
            'gift': {
              'id': 'gift-3',
              'licenseType': 'desktop',
              'toEmail': 'bob@example.com',
              'expiresAt': '2099-01-01T00:00:00.000Z',
            },
            'account': {
              'id': 'acct-1',
              'email': 'alice@example.com',
              'emailVerified': true,
              'entitlements': {
                'apple': true,
                'android': true,
                'desktop': false,
              },
              'licensesDetail': {
                'apple': 'active',
                'android': 'active',
                'desktop': 'gifted_out',
              },
              'outgoingGifts': [],
              'devices': [],
            },
            'incomingGifts': [],
          }),
          200,
        ),
      );

      await _advanceToSuccess(tester, svc);

      // AppBar back button replaced with SizedBox.shrink() on success page.
      expect(find.byType(BackButton), findsNothing);
    });
  });
}
