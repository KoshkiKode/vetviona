import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/tree_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'config/build_metadata.dart';

class AncestryApp extends StatefulWidget {
  const AncestryApp({super.key});

  @override
  State<AncestryApp> createState() => _AncestryAppState();
}

class _AncestryAppState extends State<AncestryApp> {
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
