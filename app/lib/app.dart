import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/tree_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'config/build_metadata.dart';

class VetvionaApp extends StatefulWidget {
  const VetvionaApp({super.key});

  @override
  State<VetvionaApp> createState() => _VetvionaAppState();
}

class _VetvionaAppState extends State<VetvionaApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TreeProvider>().loadPersons();
      context.read<ThemeProvider>().loadTheme();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TreeProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
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
