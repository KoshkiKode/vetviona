import 'package:flutter/material.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'providers/theme_provider.dart';
import 'services/sound_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SoundService.instance.init();
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
        home: Scaffold(
          backgroundColor: VetvionaPalette.lightLinen,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock, size: 100, color: VetvionaPalette.lightDust),
                const SizedBox(height: 20),
                Text(
                  'Desktop Version Requires Pro',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Upgrade to Vetviona Pro to use the app on desktop.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const VetvionaApp();
  }
}
