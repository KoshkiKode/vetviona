import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetviona_app/screens/license_verification_screen.dart';
import 'package:vetviona_app/services/license_backend_service.dart';

Widget _buildApp(LicenseBackendService service) {
  return ChangeNotifierProvider<LicenseBackendService>.value(
    value: service,
    child: const MaterialApp(home: LicenseVerificationScreen()),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders form and claim gift entry point', (tester) async {
    final service = LicenseBackendService(
      client: MockClient((_) async => http.Response('{}', 200)),
      baseUrl: 'http://license.example',
    );
    await service.init();

    await tester.pumpWidget(_buildApp(service));

    expect(find.text('Verify Paid License'), findsOneWidget);
    expect(find.text('Vetviona account email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Verify license'), findsOneWidget);
    expect(find.text('Received a license gift? Claim it'), findsOneWidget);
  });

  testWidgets('shows validation errors for missing fields', (tester) async {
    final service = LicenseBackendService(
      client: MockClient((_) async => http.Response('{}', 200)),
      baseUrl: 'http://license.example',
    );
    await service.init();

    await tester.pumpWidget(_buildApp(service));
    await tester.tap(find.text('Verify license'));
    await tester.pump();

    expect(find.text('Email is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
  });

  testWidgets('validates malformed email', (tester) async {
    final service = LicenseBackendService(
      client: MockClient((_) async => http.Response('{}', 200)),
      baseUrl: 'http://license.example',
    );
    await service.init();

    await tester.pumpWidget(_buildApp(service));
    await tester.enterText(
      find.byType(TextFormField).first,
      'invalid-email',
    );
    await tester.enterText(find.byType(TextFormField).last, 'Password!1');
    await tester.tap(find.text('Verify license'));
    await tester.pump();

    expect(find.text('Enter a valid email.'), findsOneWidget);
  });

  testWidgets('submits trimmed email/password and shows backend error', (
    tester,
  ) async {
    String? seenEmail;
    String? seenPassword;

    final service = LicenseBackendService(
      client: MockClient((req) async {
        final payload = jsonDecode(req.body) as Map<String, dynamic>;
        seenEmail = payload['email']?.toString();
        seenPassword = payload['password']?.toString();
        return http.Response(
          jsonEncode({'ok': false, 'message': 'Invalid credentials.'}),
          401,
        );
      }),
      baseUrl: 'http://license.example',
    );
    await service.init();

    await tester.pumpWidget(_buildApp(service));
    await tester.enterText(
      find.byType(TextFormField).first,
      ' user@example.com ',
    );
    await tester.enterText(find.byType(TextFormField).last, 'Password!1');
    await tester.tap(find.text('Verify license'));
    await tester.pumpAndSettle();

    expect(seenEmail, 'user@example.com');
    expect(seenPassword, 'Password!1');
    expect(find.text('Invalid credentials.'), findsOneWidget);
  });

  testWidgets('toggles password visibility icon', (tester) async {
    final service = LicenseBackendService(
      client: MockClient((_) async => http.Response('{}', 200)),
      baseUrl: 'http://license.example',
    );
    await service.init();

    await tester.pumpWidget(_buildApp(service));
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();

    expect(find.byIcon(Icons.visibility_outlined), findsNothing);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
  });
}
