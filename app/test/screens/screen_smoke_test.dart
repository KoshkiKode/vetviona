import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vetviona_app/models/person.dart';
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
import 'package:vetviona_app/screens/family_timeline_screen.dart';
import 'package:vetviona_app/screens/research_tasks_screen.dart';
import 'package:vetviona_app/screens/memories_screen.dart';
import 'package:vetviona_app/screens/account_management_screen.dart';
import 'package:vetviona_app/screens/license_verification_screen.dart';
import 'package:vetviona_app/screens/tree_screen.dart';
import 'package:vetviona_app/screens/family_tree_screen.dart';
import 'package:vetviona_app/screens/statistics_screen.dart';
import 'package:vetviona_app/screens/claim_gift_screen.dart';
import 'package:vetviona_app/screens/settings_screen.dart';
import 'package:vetviona_app/screens/relationship_finder_screen.dart';
import 'package:vetviona_app/screens/wikitree_screen.dart';
import 'package:vetviona_app/screens/medical_history_screen.dart';
import 'package:vetviona_app/screens/heritage_screen.dart';
import 'package:vetviona_app/screens/register_screen.dart';
import 'package:vetviona_app/screens/relationship_screen.dart';
import 'package:vetviona_app/screens/onboarding_screen.dart';
import 'package:vetviona_app/screens/duplicate_merge_screen.dart';
import 'package:vetviona_app/screens/person_detail_screen.dart';
import 'package:vetviona_app/screens/calendar_screen.dart';
import 'package:vetviona_app/screens/record_hints_screen.dart';
import 'package:vetviona_app/screens/login_screen.dart';
import 'package:vetviona_app/screens/wall_chart_screen.dart';
import 'package:vetviona_app/screens/source_detail_screen.dart';
import 'package:vetviona_app/screens/sync_screen.dart';
import 'package:vetviona_app/screens/relationship_certificate_screen.dart';
import 'package:vetviona_app/screens/timeline_screen.dart';
import 'package:vetviona_app/screens/on_this_day_screen.dart';
import 'package:vetviona_app/screens/home_screen.dart';
import 'package:vetviona_app/screens/conflict_resolver_screen.dart';
import 'package:vetviona_app/screens/record_search_screen.dart';

void main() {
  testWidgets('Smoke test for screens', (WidgetTester tester) async {
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
    final mockPerson = Person(id: '1', name: 'Test Person');
    final mockClient = MockClient((request) async { return http.Response('{}', 200); });
    final licenseService = LicenseBackendService(client: mockClient, baseUrl: 'http://test.com');
    
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    
    final screens = <String, Widget>{
      'FamilyTimelineScreen': FamilyTimelineScreen(),
      'ResearchTasksScreen': ResearchTasksScreen(),
      'MemoriesScreen': MemoriesScreen(person: mockPerson),
      'AccountManagementScreen': AccountManagementScreen(),
      'LicenseVerificationScreen': LicenseVerificationScreen(),
      'TreeScreen': TreeScreen(),
      'FamilyTreeScreen': FamilyTreeScreen(),
      'StatisticsScreen': StatisticsScreen(),
      'ClaimGiftScreen': ClaimGiftScreen(),
      'SettingsScreen': SettingsScreen(),
      'RelationshipFinderScreen': RelationshipFinderScreen(),
      'WikiTreeScreen': WikiTreeScreen(),
      'MedicalHistoryScreen': MedicalHistoryScreen(),
      'HeritageScreen': HeritageScreen(person: mockPerson),
      'RegisterScreen': RegisterScreen(),
      'RelationshipScreen': RelationshipScreen(person: mockPerson),
      'OnboardingScreen': OnboardingScreen(),
      'DuplicateMergeScreen': DuplicateMergeScreen(),
      'PersonDetailScreen': PersonDetailScreen(person: mockPerson),
      'CalendarScreen': CalendarScreen(),
      'RecordHintsScreen': RecordHintsScreen(),
      'LoginScreen': LoginScreen(),
      'WallChartScreen': WallChartScreen(),
      'SourceDetailScreen': SourceDetailScreen(person: mockPerson),
      'SyncScreen': SyncScreen(),
      'RelationshipCertificateScreen': RelationshipCertificateScreen(),
      'TimelineScreen': TimelineScreen(person: mockPerson),
      'OnThisDayScreen': OnThisDayScreen(),
      'HomeScreen': HomeScreen(),
      'ConflictResolverScreen': ConflictResolverScreen(),
      'RecordSearchScreen': RecordSearchScreen(),
    };
    
    for (final entry in screens.entries) {
      debugPrint('Pumping ${entry.key}');
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
            home: Scaffold(
              body: entry.value,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(entry.value.runtimeType), findsOneWidget);
    }
    FlutterError.onError = originalOnError;
  });
}
