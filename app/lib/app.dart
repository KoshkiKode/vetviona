import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/tree_provider.dart';
import 'screens/home_screen.dart';

class AncestryApp extends StatelessWidget {
  const AncestryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TreeProvider()),
      ],
      child: MaterialApp(
        title: 'Ancestry App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
