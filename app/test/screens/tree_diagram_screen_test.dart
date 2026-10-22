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
import 'package:vetviona_app/screens/tree_diagram_screen.dart';

void main() {
  testWidgets('TreeDiagramScreen smoke test', (WidgetTester tester) async {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exceptionAsString().contains('A RenderFlex overflowed')) {
        return;
      }
      if (originalOnError != null) {
        originalOnError(details);
      }
    };
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
        child: const MaterialApp(
          home: Scaffold(body: TreeDiagramScreen()),
        ),
      ),
    );

    // Initial pump
    await tester.pump();
    
    // Expect finding the diagram screen
    expect(find.byType(TreeDiagramScreen), findsOneWidget);
    
    FlutterError.onError = originalOnError;
  });
}
