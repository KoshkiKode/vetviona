import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/tree_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'config/build_metadata.dart';
import 'services/bluetooth_sync_service.dart';
import 'services/purchase_service.dart';
import 'services/sync_service.dart';

class VetvionaApp extends StatelessWidget {
  const VetvionaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final provider = TreeProvider();
            provider.loadPersons();
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final provider = ThemeProvider();
            provider.loadTheme();
            return provider;
          },
        ),
        // SyncService keeps a live reference to TreeProvider so it can
        // read/write tree data during sync operations.
        ChangeNotifierProxyProvider<TreeProvider, SyncService>(
          create: (_) {
            final service = SyncService();
            service.loadSettings();
            return service;
          },
          update: (_, treeProvider, syncService) {
            syncService!.treeProvider = treeProvider;
            return syncService;
          },
        ),
        // BluetoothSyncService keeps a reference to SyncService so it can
        // delegate WiFi data transfer after BLE peer discovery.
        ChangeNotifierProxyProvider<SyncService, BluetoothSyncService>(
          create: (_) => BluetoothSyncService(),
          update: (_, syncService, bleService) {
            bleService!.syncService = syncService;
            return bleService;
          },
        ),
        // PurchaseService manages one-time IAP for Mobile Paid upgrade.
        ChangeNotifierProvider(
          create: (_) {
            final service = PurchaseService();
            service.init();
            return service;
          },
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) => MaterialApp(
          title: BuildMetadata.appName,
          theme: themeProvider.theme,
          home: const _StartupRouter(),
        ),
      ),
    );
  }
}


class _StartupRouter extends StatefulWidget {
  const _StartupRouter();

  @override
  State<_StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<_StartupRouter> {
  bool? _onboardingDone;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _onboardingDone = prefs.getBool('onboardingDone') ?? false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_onboardingDone == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_onboardingDone!) {
      return const OnboardingScreen();
    }
    return const HomeScreen();
  }
}
