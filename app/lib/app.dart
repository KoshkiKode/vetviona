import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/tree_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'screens/license_verification_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'config/build_metadata.dart';
import 'services/bluetooth_sync_service.dart';
import 'services/license_backend_service.dart';
import 'services/purchase_service.dart';
import 'services/sync_service.dart';
import 'utils/platform_utils.dart';

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
        // License backend verification for paid tiers.
        ChangeNotifierProvider(
          create: (_) {
            final service = LicenseBackendService();
            service.init();
            return service;
          },
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          final app = MaterialApp(
            title: BuildMetadata.appName,
            theme: themeProvider.theme,
            debugShowCheckedModeBanner: false,
            // iOS/macOS gets elastic over-scroll; Android/desktop gets clamping.
            scrollBehavior: _VetvionaScrollBehavior(),
            home: const _StartupRouter(),
          );
          // macOS: wrap with the native menu bar so the app gets a proper
          // "File / Edit / View" menu at the top of the screen.
          if (!isMacOS) return app;
          return PlatformMenuBar(
            menus: [
              PlatformMenu(
                label: BuildMetadata.appName,
                menus: [
                  PlatformMenuItem(
                    label: 'About ${BuildMetadata.appName}',
                    onSelected: () {},
                  ),
                  const PlatformMenuItemGroup(
                    members: [
                      PlatformProvidedMenuItem(
                        type: PlatformProvidedMenuItemType.quit,
                      ),
                    ],
                  ),
                ],
              ),
              PlatformMenu(
                label: 'File',
                menus: [
                  PlatformMenuItem(
                    label: 'New Person',
                    shortcut: const SingleActivator(
                      LogicalKeyboardKey.keyN,
                      meta: true,
                    ),
                    onSelected: () {
                      // Intent dispatched — picked up by HomeScreen Actions
                      // if HomeScreen is the current route.  Using the root
                      // navigator avoids tight coupling to HomeScreen state.
                    },
                  ),
                  PlatformMenuItem(label: 'Import GEDCOM…', onSelected: () {}),
                  PlatformMenuItem(
                    label: 'Settings…',
                    shortcut: const SingleActivator(
                      LogicalKeyboardKey.comma,
                      meta: true,
                    ),
                    onSelected: () {},
                  ),
                ],
              ),
              PlatformMenu(
                label: 'View',
                menus: [
                  PlatformMenuItem(
                    label: themeProvider.isDarkMode
                        ? 'Switch to Light Mode'
                        : 'Switch to Dark Mode',
                    onSelected: () =>
                        themeProvider.setDarkMode(!themeProvider.isDarkMode),
                  ),
                ],
              ),
            ],
            child: app,
          );
        },
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

  /// Returns the correct destination widget once both the onboarding check
  /// and the data load have completed.  Only called when [_onboardingDone]
  /// is non-null.
  Widget _destination() {
    if (!_onboardingDone!) {
      return const OnboardingScreen(key: ValueKey('onboarding'));
    }
    if (!context.read<LicenseBackendService>().isCurrentTierVerified) {
      return const LicenseVerificationScreen(key: ValueKey('license-verify'));
    }
    return const HomeScreen(key: ValueKey('home'));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TreeProvider>();
    final purchaseService = context.watch<PurchaseService>();
    final licenseService = context.watch<LicenseBackendService>();

    // Show the splash screen until both the tree data AND the onboarding
    // check have finished.
    final ready =
        provider.isLoaded &&
        _onboardingDone != null &&
        purchaseService.isInitialized &&
        licenseService.isInitialized;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: ready
          ? _destination()
          : const SplashScreen(key: ValueKey('splash')),
    );
  }
}

// ── Adaptive scroll behaviour ──────────────────────────────────────────────

/// Uses [BouncingScrollPhysics] on iOS/macOS (matching native elastic
/// over-scroll) and [ClampingScrollPhysics] on Android/desktop.
class _VetvionaScrollBehavior extends MaterialScrollBehavior {
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      adaptiveScrollPhysics();
}
