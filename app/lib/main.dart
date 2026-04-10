import 'package:flutter/material.dart';

import 'app.dart';
import 'config/app_config.dart';
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
      return const MaterialApp(
        title: 'Vetviona',
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock, size: 100, color: Colors.grey),
                SizedBox(height: 20),
                Text(
                  'Desktop Version Requires Pro',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
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
