import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';

const bool isPaidVersion = bool.fromEnvironment('PAID', defaultValue: false);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _RootWidget());
}

class _RootWidget extends StatelessWidget {
  const _RootWidget();

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = !kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    if (isDesktop && !isPaidVersion) {
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
