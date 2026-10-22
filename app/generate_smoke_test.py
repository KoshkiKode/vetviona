import os
import re

# Get all files in lib/screens
screens_dir = "lib/screens"
dart_files = [f for f in os.listdir(screens_dir) if f.endswith(".dart")]

imports = [
    "import 'package:flutter/material.dart';",
    "import 'package:flutter_test/flutter_test.dart';",
    "import 'package:provider/provider.dart';",
    "import 'package:vetviona_app/models/person.dart';",
    "import 'package:vetviona_app/providers/tree_provider.dart';",
    "import 'package:vetviona_app/providers/locale_provider.dart';",
    "import 'package:vetviona_app/providers/theme_provider.dart';",
    "import 'package:vetviona_app/services/license_backend_service.dart';",
    "import 'package:vetviona_app/services/sync_service.dart';",
    "import 'package:vetviona_app/services/bluetooth_sync_service.dart';",
    "import 'package:vetviona_app/services/nfc_sync_service.dart';",
    "import 'package:vetviona_app/services/purchase_service.dart';",
    "import 'package:http/testing.dart';",
    "import 'package:http/http.dart' as http;",
    "import 'package:shared_preferences/shared_preferences.dart';",
]

screen_instantiations = []

for file in dart_files:
    if file in ["sources_page.dart", "gift_license_wizard.dart", "map_picker_screen.dart", "place_picker_screen.dart", "eula_screen.dart", "splash_screen.dart", "tree_diagram_screen.dart"]:
        continue
    imports.append(f"import 'package:vetviona_app/screens/{file}';")
    path = os.path.join(screens_dir, file)
    with open(path, "r") as f:
        content = f.read()
        match = re.search(r"class ([a-zA-Z0-9_]+) extends (StatefulWidget|StatelessWidget)", content)
        if match:
            class_name = match.group(1)
            # Find constructor
            constructor_match = re.search(r"const " + class_name + r"\({.*?(required this\.person).*?}\)", content)
            if constructor_match:
                screen_instantiations.append(f"      '{class_name}': {class_name}(person: mockPerson),")
            else:
                constructor_match_2 = re.search(r"const " + class_name + r"\({.*?}\)", content)
                if constructor_match_2:
                     screen_instantiations.append(f"      '{class_name}': {class_name}(),")

with open("test/screens/screen_smoke_test.dart", "w") as f:
    f.write("\n".join(imports) + "\n\n")
    f.write("void main() {\n")
    f.write("  testWidgets('Smoke test for screens', (WidgetTester tester) async {\n")
    f.write("    final originalOnError = FlutterError.onError;\n")
    f.write("    FlutterError.onError = (FlutterErrorDetails details) {\n")
    f.write("      if (details.exceptionAsString().contains('A RenderFlex overflowed')) {\n")
    f.write("        return;\n")
    f.write("      }\n")
    f.write("      if (originalOnError != null) {\n")
    f.write("        originalOnError(details);\n")
    f.write("      }\n")
    f.write("    };\n")
    f.write("    SharedPreferences.setMockInitialValues({});\n")
    f.write("    final mockPerson = Person(id: '1', name: 'Test Person');\n")
    f.write("    final mockClient = MockClient((request) async { return http.Response('{}', 200); });\n")
    f.write("    final licenseService = LicenseBackendService(client: mockClient, baseUrl: 'http://test.com');\n")
    f.write("    \n")
    f.write("    tester.view.physicalSize = const Size(1080, 1920);\n")
    f.write("    tester.view.devicePixelRatio = 1.0;\n")
    f.write("    \n")
    f.write("    final screens = <String, Widget>{\n")
    for s in screen_instantiations:
        f.write(s + "\n")
    f.write("    };\n")
    f.write("    \n")
    f.write("    for (final entry in screens.entries) {\n")
    f.write("      print('Pumping ${entry.key}');\n")
    f.write("      await tester.pumpWidget(\n")
    f.write("        MultiProvider(\n")
    f.write("          providers: [\n")
    f.write("            ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),\n")
    f.write("            ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),\n")
    f.write("            ChangeNotifierProvider<TreeProvider>(create: (_) => TreeProvider()),\n")
    f.write("            ChangeNotifierProxyProvider<TreeProvider, SyncService>(\n")
    f.write("              create: (_) => SyncService(),\n")
    f.write("              update: (_, treeProvider, syncService) {\n")
    f.write("                syncService!.treeProvider = treeProvider;\n")
    f.write("                return syncService;\n")
    f.write("              },\n")
    f.write("            ),\n")
    f.write("            ChangeNotifierProxyProvider<SyncService, BluetoothSyncService>(\n")
    f.write("              create: (_) => BluetoothSyncService(),\n")
    f.write("              update: (_, syncService, bleService) {\n")
    f.write("                bleService!.syncService = syncService;\n")
    f.write("                return bleService;\n")
    f.write("              },\n")
    f.write("            ),\n")
    f.write("            ChangeNotifierProvider<NfcSyncService>.value(value: NfcSyncService.instance),\n")
    f.write("            ChangeNotifierProvider<PurchaseService>(create: (_) => PurchaseService()),\n")
    f.write("            ChangeNotifierProvider<LicenseBackendService>.value(value: licenseService),\n")
    f.write("          ],\n")
    f.write("          child: MaterialApp(\n")
    f.write("            home: Scaffold(\n")
    f.write("              body: entry.value,\n")
    f.write("            ),\n")
    f.write("          ),\n")
    f.write("        ),\n")
    f.write("      );\n")
    f.write("      await tester.pump();\n")
    f.write("      expect(find.byType(entry.value.runtimeType), findsOneWidget);\n")
    f.write("    }\n")
    f.write("    FlutterError.onError = originalOnError;\n")
    f.write("  });\n")
    f.write("}\n")
