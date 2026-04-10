import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/tree_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'config/build_metadata.dart';

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
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) => MaterialApp(
          title: BuildMetadata.appName,
          theme: themeProvider.theme,
          home: const HomeScreen(),
        ),
      ),
    );
  }
}
