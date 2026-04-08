import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../providers/tree_provider.dart';
import 'tree_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.watch<TreeProvider>().isLoggedIn;

    if (!isLoggedIn) {
      return const LoginScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ancestry App'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _importGEDCOM(context),
              child: const Text('Import GEDCOM'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TreeScreen()),
                );
              },
              child: const Text('View Family Tree'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _syncData(context),
              child: const Text('Sync Data'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importGEDCOM(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ged'],
    );
    if (result != null) {
      final filePath = result.files.single.path!;
      await context.read<TreeProvider>().importGEDCOM(filePath);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GEDCOM imported successfully')),
      );
    }
  }

  Future<void> _syncData(BuildContext context) async {
    await context.read<TreeProvider>().syncWithServer();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Data synced')),
    );
  }
}
