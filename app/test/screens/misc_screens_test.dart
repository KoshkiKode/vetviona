import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vetviona_app/providers/tree_provider.dart';
import 'package:vetviona_app/providers/locale_provider.dart';
import 'package:vetviona_app/providers/theme_provider.dart';
import 'package:vetviona_app/services/license_backend_service.dart';
import 'package:vetviona_app/services/sync_service.dart';
import 'package:vetviona_app/services/bluetooth_sync_service.dart';
import 'package:vetviona_app/services/nfc_sync_service.dart';
import 'package:vetviona_app/services/purchase_service.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vetviona_app/screens/sources_page.dart';
import 'package:vetviona_app/screens/eula_screen.dart';
import 'package:vetviona_app/models/person.dart';

void main() {
  testWidgets('Misc Screens smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final mockClient = MockClient((request) async { return http.Response('{}', 200); });
    final licenseService = LicenseBackendService(client: mockClient, baseUrl: 'http://test.com');
    
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
          ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
          ChangeNotifierProvider<TreeProvider>(create: (_) => TreeProvider()),
          ChangeNotifierProxyProvider<TreeProvider, SyncService>(
            create: (_) => SyncService(),
            update: (_, treeProvider, syncService) {
              syncService!.treeProvider = treeProvider;
              return syncService;
            },
          ),
          ChangeNotifierProxyProvider<SyncService, BluetoothSyncService>(
            create: (_) => BluetoothSyncService(),
            update: (_, syncService, bleService) {
              bleService!.syncService = syncService;
              return bleService;
            },
          ),
          ChangeNotifierProvider<NfcSyncService>.value(value: NfcSyncService.instance),
          ChangeNotifierProvider<PurchaseService>(create: (_) => PurchaseService()),
          ChangeNotifierProvider<LicenseBackendService>.value(value: licenseService),
        ],
        child: MaterialApp(
          home: Scaffold(body: SourcesPage(person: Person(id: "1", name: "Test"))),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(SourcesPage), findsOneWidget);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
          ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
          ChangeNotifierProvider<TreeProvider>(create: (_) => TreeProvider()),
          ChangeNotifierProxyProvider<TreeProvider, SyncService>(
            create: (_) => SyncService(),
            update: (_, treeProvider, syncService) {
              syncService!.treeProvider = treeProvider;
              return syncService;
            },
          ),
          ChangeNotifierProxyProvider<SyncService, BluetoothSyncService>(
            create: (_) => BluetoothSyncService(),
            update: (_, syncService, bleService) {
              bleService!.syncService = syncService;
              return bleService;
            },
          ),
          ChangeNotifierProvider<NfcSyncService>.value(value: NfcSyncService.instance),
          ChangeNotifierProvider<PurchaseService>(create: (_) => PurchaseService()),
          ChangeNotifierProvider<LicenseBackendService>.value(value: licenseService),
        ],
        child: const MaterialApp(
          home: Scaffold(body: EulaScreen()),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(EulaScreen), findsOneWidget);

  });
}
