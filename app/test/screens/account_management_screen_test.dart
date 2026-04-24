// Tests for AccountManagementScreen.
//
// Covers three render states:
//   • signed-out   → sign-in prompt
//   • signed-in but no cached password (re-auth)  → re-auth card
//   • fully authenticated (canManageAccount=true)  → full management view
//
// Also exercises:
//   • license status tiles
//   • email verification section visibility
//   • outgoing / incoming gift tiles
//   • change-password form validation
//   • sign-out dialog

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vetviona_app/screens/account_management_screen.dart';
import 'package:vetviona_app/services/license_backend_service.dart';

// ── Fixture helpers ────────────────────────────────────────────────────────────

/// A [LicenseBackendService] with email stored but NO cached password —
/// simulates app-restart after a prior login (isSignedIn=true, canManageAccount=false).
Future<LicenseBackendService> _signedInNoPasswordService() async {
  SharedPreferences.setMockInitialValues({
    'license_backend_account_email': 'alice@example.com',
    'license_backend_desktop_verified': true,
    'license_backend_desktop_entitled': true,
    'license_backend_email_verified': true,
  });
  FlutterSecureStorage.setMockInitialValues({});
  final svc = LicenseBackendService(
    client: MockClient((_) async => http.Response('{}', 200)),
    baseUrl: 'http://license.example',
  );
  await svc.init();
  return svc;
}

/// A [LicenseBackendService] that is fully signed in with password cached and
/// all three licenses active.  Accepts an optional [overrideHandler] for
/// subsequent requests after the initial verify.
Future<LicenseBackendService> _fullyAuthedService({
  Map<String, String> licensesDetail = const {
    'apple': 'active',
    'android': 'active',
    'desktop': 'active',
  },
  Map<String, bool> entitlements = const {
    'apple': true,
    'android': true,
    'desktop': true,
  },
  bool emailVerified = true,
  List<Map<String, dynamic>> outgoingGifts = const [],
  List<Map<String, dynamic>> incomingGifts = const [],
  http.Response Function(http.Request)? overrideHandler,
}) async {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});

  http.Response syncResponse(http.Request _) {
    return http.Response(
      jsonEncode({
        'ok': true,
        'account': {
          'id': 'acct-1',
          'email': 'alice@example.com',
          'emailVerified': emailVerified,
          'entitlements': entitlements,
          'licensesDetail': licensesDetail,
          'outgoingGifts': outgoingGifts,
          'devices': [],
        },
        'incomingGifts': incomingGifts,
      }),
      200,
    );
  }

  final svc = LicenseBackendService(
    client: MockClient((req) async {
      if (req.url.path == '/v1/license/verify') {
        return http.Response(
          jsonEncode({
            'ok': true,
            'entitlements': entitlements,
            'emailVerified': emailVerified,
            'licensesDetail': licensesDetail,
            'devices': [],
          }),
          200,
        );
      }
      if (overrideHandler != null) return overrideHandler(req);
      return syncResponse(req);
    }),
    baseUrl: 'http://license.example',
  );
  await svc.init();
  await svc.verifyLicense(email: 'alice@example.com', password: 'Pw!1');
  return svc;
}

Widget _buildApp(LicenseBackendService svc) {
  return ChangeNotifierProvider<LicenseBackendService>.value(
    value: svc,
    child: const MaterialApp(home: AccountManagementScreen()),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  // ── Signed-out view ───────────────────────────────────────────────────────

  group('AccountManagementScreen — signed out', () {
    testWidgets('shows sign-in prompt and Verify License button', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final svc = LicenseBackendService(
        client: MockClient((_) async => http.Response('{}', 200)),
        baseUrl: 'http://license.example',
      );
      await svc.init();

      await tester.pumpWidget(_buildApp(svc));
      await tester.pump();

      expect(
        find.text('Sign in to manage your Vetviona license account.'),
        findsOneWidget,
      );
      expect(find.text('Verify License'), findsOneWidget);
    });
  });

  // ── Re-auth view ──────────────────────────────────────────────────────────
  //
  // After Phase 2, canManageAccount == isSignedIn, so a service initialised from
  // SharedPreferences alone (without a fresh verifyLicense call) goes straight to
  // the full management view.  The tests below confirm that behaviour.

  group('AccountManagementScreen — re-auth (email stored, no password)', () {
    testWidgets('shows full account view when email is stored', (tester) async {
      final svc = await _signedInNoPasswordService();

      await tester.pumpWidget(_buildApp(svc));
      await tester.pump();

      // Full management view is shown — NOT the sign-in prompt or re-auth card.
      expect(find.text('alice@example.com'), findsAtLeastNWidgets(1));
      expect(
        find.text('Sign in to manage your Vetviona license account.'),
        findsNothing,
      );
    });

    testWidgets('does not show verify-license prompt when email is stored',
        (tester) async {
      final svc = await _signedInNoPasswordService();

      await tester.pumpWidget(_buildApp(svc));
      await tester.pump();

      expect(find.text('Verify License'), findsNothing);
    });
  });

  // ── Fully authenticated view ──────────────────────────────────────────────

  group('AccountManagementScreen — fully authenticated', () {
    testWidgets('renders account email in account section', (tester) async {
      final svc = await _fullyAuthedService();

      await tester.pumpWidget(_buildApp(svc));
      await tester.pump();

      expect(find.text('alice@example.com'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows My Licenses section with three tiles', (tester) async {
      final svc = await _fullyAuthedService();

      await tester.pumpWidget(_buildApp(svc));
      await tester.pump();

      expect(find.text('My Licenses'), findsOneWidget);
      expect(find.text('Apple (iOS)'), findsAtLeastNWidgets(1));
      expect(find.text('Android'), findsAtLeastNWidgets(1));
      expect(find.text('Desktop'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows Active status for active licenses', (tester) async {
      final svc = await _fullyAuthedService();

      await tester.pumpWidget(_buildApp(svc));
      await tester.pump();

      expect(find.text('Active'), findsNWidgets(3));
    });

    testWidgets('shows Transfer pending for gifted_out license', (tester) async {
      final svc = await _fullyAuthedService(
        entitlements: {
          'apple': false,
          'android': true,
          'desktop': true,
        },
        licensesDetail: {
          'apple': 'gifted_out',
          'android': 'active',
          'desktop': 'active',
        },
      );

      await tester.pumpWidget(_buildApp(svc));
      await tester.pump();

      expect(find.text('Transfer pending'), findsOneWidget);
    });

    testWidgets('hides email verification section when email is verified',
        (tester) async {
      final svc = await _fullyAuthedService(emailVerified: true);

      await tester.pumpWidget(_buildApp(svc));
      await tester.pump();

      expect(find.text('Verify your email'), findsNothing);
    });

    testWidgets('shows email verification section when email is unverified',
        (tester) async {
      final svc = await _fullyAuthedService(emailVerified: false);

      await tester.pumpWidget(_buildApp(svc));
      await tester.pump();

      expect(find.text('Verify your email'), findsOneWidget);
    });

    testWidgets('shows outgoing gift tile when outgoingGifts is non-empty',
        (tester) async {
      final svc = await _fullyAuthedService(
        entitlements: {
          'apple': false,
          'android': true,
          'desktop': true,
        },
        licensesDetail: {
          'apple': 'gifted_out',
          'android': 'active',
          'desktop': 'active',
        },
        outgoingGifts: [
          {
            'id': 'gift-1',
            'licenseType': 'apple',
            'toEmail': 'bob@example.com',
            'expiresAt': '2099-12-31T00:00:00.000Z',
            'createdAt': '2026-01-01T00:00:00.000Z',
          },
        ],
        // Provide sync handler so syncAccount() called on initState succeeds.
        overrideHandler: (req) => http.Response(
          jsonEncode({
            'ok': true,
            'account': {
              'id': 'acct-1',
              'email': 'alice@example.com',
              'emailVerified': true,
              'entitlements': {
                'apple': false,
                'android': true,
                'desktop': true,
              },
              'licensesDetail': {
                'apple': 'gifted_out',
                'android': 'active',
                'desktop': 'active',
              },
              'outgoingGifts': [
                {
                  'id': 'gift-1',
                  'licenseType': 'apple',
                  'toEmail': 'bob@example.com',
                  'expiresAt': '2099-12-31T00:00:00.000Z',
                  'createdAt': '2026-01-01T00:00:00.000Z',
                },
              ],
              'devices': [],
            },
            'incomingGifts': [],
          }),
          200,
        ),
      );

      await tester.pumpWidget(_buildApp(svc));
      await tester.pumpAndSettle();

      expect(find.text('Outgoing Transfers'), findsOneWidget);
      expect(find.text('→ bob@example.com'), findsOneWidget);
    });

    testWidgets('shows incoming gift tile when incomingGifts is non-empty',
        (tester) async {
      final svc = await _fullyAuthedService(
        incomingGifts: [
          {
            'id': 'gift-42',
            'licenseType': 'android',
            'fromEmail': 'carol@example.com',
            'expiresAt': '2099-12-31T00:00:00.000Z',
            'createdAt': '2026-01-01T00:00:00.000Z',
          },
        ],
        overrideHandler: (req) => http.Response(
          jsonEncode({
            'ok': true,
            'account': {
              'id': 'acct-1',
              'email': 'alice@example.com',
              'emailVerified': true,
              'entitlements': {
                'apple': true,
                'android': true,
                'desktop': true,
              },
              'licensesDetail': {
                'apple': 'active',
                'android': 'active',
                'desktop': 'active',
              },
              'outgoingGifts': [],
              'devices': [],
            },
            'incomingGifts': [
              {
                'id': 'gift-42',
                'licenseType': 'android',
                'fromEmail': 'carol@example.com',
                'expiresAt': '2099-12-31T00:00:00.000Z',
                'createdAt': '2026-01-01T00:00:00.000Z',
              },
            ],
          }),
          200,
        ),
      );

      await tester.pumpWidget(_buildApp(svc));
      await tester.pumpAndSettle();

      expect(find.text('Incoming Gifts'), findsOneWidget);
      expect(find.text('From carol@example.com'), findsOneWidget);
      expect(find.text('Claim'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows Claim a License Gift section', (tester) async {
      final svc = await _fullyAuthedService();

      await tester.pumpWidget(_buildApp(svc));
      await tester.pump();

      expect(find.text('Claim a License Gift'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows Change Password section', (tester) async {
      final svc = await _fullyAuthedService();

      await tester.pumpWidget(_buildApp(svc));
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -1500));
      await tester.pump();

      expect(find.text('Change Password'), findsOneWidget);
    });

    testWidgets('shows Sign Out section', (tester) async {
      final svc = await _fullyAuthedService();

      await tester.pumpWidget(_buildApp(svc));
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pump();

      expect(find.text('Sign Out'), findsAtLeastNWidgets(1));
    });
  });

  group('AccountManagementScreen — change password form', () {
    testWidgets('expands change password panel and validates short password',
        (tester) async {
      final svc = await _fullyAuthedService();

      await tester.pumpWidget(_buildApp(svc));
      await tester.pump();

      // Scroll down to reach the Change Password section.
      await tester.drag(find.byType(ListView), const Offset(0, -1500));
      await tester.pump();

      // Expand the ExpansionTile.
      await tester.tap(find.text('Update password'));
      await tester.pumpAndSettle();

      // Find the three password TextFormFields that appear inside the expansion.
      // Enter "short" into the new-password field.
      final fields = find.byType(TextFormField);
      // fields order: current, new, confirm
      await tester.enterText(fields.at(0), 'OldPw!1');
      await tester.enterText(fields.at(1), 'short');
      await tester.enterText(fields.at(2), 'short');

      await tester.tap(find.widgetWithText(FilledButton, 'Change Password'));
      await tester.pump();

      expect(find.text('At least 8 characters.'), findsOneWidget);
    });

    testWidgets('validates password mismatch', (tester) async {
      final svc = await _fullyAuthedService();

      await tester.pumpWidget(_buildApp(svc));
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -1500));
      await tester.pump();

      await tester.tap(find.text('Update password'));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'OldPw!1');
      await tester.enterText(fields.at(1), 'NewPassword!1');
      await tester.enterText(fields.at(2), 'DifferentPassword!1');

      await tester.tap(find.widgetWithText(FilledButton, 'Change Password'));
      await tester.pump();

      expect(find.text('Passwords do not match.'), findsOneWidget);
    });

    testWidgets('successful password change shows success snackbar',
        (tester) async {
      final svc = await _fullyAuthedService(
        overrideHandler: (req) {
          if (req.url.path == '/v1/account/change-password') {
            return http.Response(
              jsonEncode({'ok': true, 'message': 'Password changed.'}),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'ok': true,
              'account': {
                'id': 'acct-1',
                'email': 'alice@example.com',
                'emailVerified': true,
                'entitlements': {
                  'apple': true,
                  'android': true,
                  'desktop': true,
                },
                'licensesDetail': {
                  'apple': 'active',
                  'android': 'active',
                  'desktop': 'active',
                },
                'outgoingGifts': [],
                'devices': [],
              },
              'incomingGifts': [],
            }),
            200,
          );
        },
      );

      await tester.pumpWidget(_buildApp(svc));
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -1500));
      await tester.pump();

      await tester.tap(find.text('Update password'));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'OldPw!1');
      await tester.enterText(fields.at(1), 'NewPassword!1');
      await tester.enterText(fields.at(2), 'NewPassword!1');

      await tester.tap(find.widgetWithText(FilledButton, 'Change Password'));
      await tester.pumpAndSettle();

      expect(find.text('Password changed successfully.'), findsOneWidget);
    });
  });

  // ── Sign out ──────────────────────────────────────────────────────────────

  group('AccountManagementScreen — sign out', () {
    testWidgets('sign out shows confirmation dialog', (tester) async {
      final svc = await _fullyAuthedService();

      await tester.pumpWidget(_buildApp(svc));
      await tester.pump();

      // Scroll down to reach the Sign Out section.
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pump();

      await tester.tap(find.text('Sign Out').last);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('remove your license from this device'),
        findsOneWidget,
      );
    });

    testWidgets('cancelling sign-out dialog keeps screen open', (tester) async {
      final svc = await _fullyAuthedService();

      await tester.pumpWidget(_buildApp(svc));
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pump();

      await tester.tap(find.text('Sign Out').last);
      await tester.pumpAndSettle();

      // Tap Cancel in the dialog.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Screen remains, not popped.
      expect(find.text('License Account'), findsOneWidget);
    });
  });
}
