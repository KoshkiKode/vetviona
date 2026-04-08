  @override
  Widget build(BuildContext context) {
    if ((Platform.isWindows || Platform.isMacOS || Platform.isLinux) && !isPaidVersion) {
      return const MaterialApp(
        title: 'Ancestry App',
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
                  'Upgrade to the paid version to use Ancestry App on desktop.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TreeProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) => MaterialApp(
          title: 'Ancestry App',
          theme: themeProvider.theme,
          home: Stack(
            children: [
              const HomeScreen(),
              if (!isPaidVersion) const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Material(
                  color: Colors.orange,
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Free Version - Upgrade to Pro for full features',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
