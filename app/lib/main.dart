import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'config/build_metadata.dart';
import 'providers/theme_provider.dart';
import 'services/sound_service.dart';
import 'services/wikitree_service.dart';
import 'utils/platform_utils.dart';

// ignore_for_file: unawaited_futures

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final packageInfo = await PackageInfo.fromPlatform();
  BuildMetadata.appVersion = packageInfo.version;
  // Android: draw behind the system navigation bar so the app is truly
  // edge-to-edge and the nav bar blends with the scaffold background.
  if (isAndroid) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
  await SoundService.instance.init();
  // Pre-load stored WikiTree credentials so the service is ready before
  // any screen opens.
  unawaited(WikiTreeService.instance.loadCredentials());
  runApp(const _RootWidget());
}

class _RootWidget extends StatelessWidget {
  const _RootWidget();

  @override
  Widget build(BuildContext context) {
    // Desktop is always a paid product. Show a lock screen if the build was
    // not compiled with --dart-define=PAID=true.
    if (currentAppTier == AppTier.desktopPro && !isPaidDesktop) {
      return MaterialApp(
        title: 'Vetviona',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: VetvionaPalette.lightPrimary,
          ),
        ),
        home: const _DesktopLockScreen(),
      );
    }

    return const VetvionaApp();
  }
}

class _DesktopLockScreen extends StatelessWidget {
  const _DesktopLockScreen();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: VetvionaPalette.lightLinen,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lock_outlined,
                      size: 44, color: colorScheme.onPrimaryContainer),
                ),
                const SizedBox(height: 24),
                Text(
                  '${BuildMetadata.appName} Desktop Pro',
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'This build requires a Desktop Pro license.\n'
                  'Run with --dart-define=PAID=true, or purchase a license at:',
                  style: TextStyle(
                      fontSize: 15, color: Colors.grey.shade700, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SelectableText(
                  'https://${BuildMetadata.websiteDomain}',
                  style: TextStyle(
                    fontSize: 15,
                    color: colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  icon: const Icon(Icons.open_in_browser, size: 18),
                  label: const Text('Get Desktop Pro'),
                  onPressed: () async {
                    final uri = Uri.parse(BuildMetadata.paidAppUrl);
                    if (!await launchUrl(uri,
                        mode: LaunchMode.externalApplication)) {
                      // If the launcher fails there is no BuildContext here,
                      // so silently ignore — the selectable URL above still
                      // lets the user copy and open it manually.
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
