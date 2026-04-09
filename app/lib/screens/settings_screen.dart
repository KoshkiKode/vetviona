import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/build_metadata.dart';
import '../providers/theme_provider.dart';
import '../providers/tree_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _wifiSync = true;
  bool _bluetoothSync = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _wifiSync = prefs.getBool('wifiSync') ?? true;
      _bluetoothSync = prefs.getBool('bluetoothSync') ?? false;
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final treeProvider = context.watch<TreeProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Theme ─────────────────────────────────────────────────────────
          _SectionHeader('Theme'),
          const SizedBox(height: 8),
          const Text('Primary Color'),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: ColorPicker(
              pickerColor: themeProvider.primaryColor,
              onColorChanged: (color) =>
                  context.read<ThemeProvider>().setPrimaryColor(color),
              pickerAreaHeightPercent: 0.7,
            ),
          ),

          const SizedBox(height: 16),

          // ── Date Format ────────────────────────────────────────────────────
          _SectionHeader('Display'),
          DropdownButtonFormField<String>(
            decoration:
                const InputDecoration(labelText: 'Date Format'),
            value: treeProvider.dateFormat,
            items: const [
              DropdownMenuItem(
                  value: 'dd MMM yyyy', child: Text('DD MMM YYYY (e.g. 01 Jan 2000)')),
              DropdownMenuItem(
                  value: 'MM/dd/yyyy', child: Text('MM/DD/YYYY (e.g. 01/01/2000)')),
              DropdownMenuItem(
                  value: 'yyyy-MM-dd', child: Text('YYYY-MM-DD (e.g. 2000-01-01)')),
            ],
            onChanged: (v) {
              if (v != null) context.read<TreeProvider>().setDateFormat(v);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            decoration: const InputDecoration(
                labelText: 'Historical / Colonization Info'),
            value: treeProvider.colonizationLevel,
            items: const [
              DropdownMenuItem(value: 0, child: Text('None \u2013 modern names only')),
              DropdownMenuItem(
                  value: 1, child: Text('Level 1 \u2013 also show colonizer names')),
              DropdownMenuItem(
                  value: 2, child: Text('Level 2 \u2013 also show indigenous / native names')),
            ],
            onChanged: (v) {
              if (v != null) context.read<TreeProvider>().setColonizationLevel(v);
            },
          ),

          const SizedBox(height: 16),

          // ── Sync ───────────────────────────────────────────────────────────
          _SectionHeader('RootLoop\u2122 Sync'),
          SwitchListTile(
            title: const Text('WiFi Sync'),
            subtitle: const Text('Sync over local WiFi network'),
            value: _wifiSync,
            onChanged: (v) {
              setState(() => _wifiSync = v);
              _saveBool('wifiSync', v);
            },
          ),
          SwitchListTile(
            title: const Text('Bluetooth Sync'),
            subtitle: const Text('Sync via Bluetooth'),
            value: _bluetoothSync,
            onChanged: (v) {
              setState(() => _bluetoothSync = v);
              _saveBool('bluetoothSync', v);
            },
          ),

          const SizedBox(height: 16),

          // ── Paired Devices ────────────────────────────────────────────────
          _SectionHeader('Paired Devices'),
          if (treeProvider.pairedDevices.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No paired devices.',
                  style: TextStyle(color: Colors.grey)),
            )
          else
            ...treeProvider.pairedDevices.map(
              (d) => ListTile(
                leading: const Icon(Icons.devices),
                title: Text(d.id),
                subtitle: const Text('••••••••••••••••'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => treeProvider.removeDevice(d.id),
                ),
              ),
            ),

          const SizedBox(height: 16),

          // ── Danger Zone ───────────────────────────────────────────────────
          _SectionHeader('Danger Zone'),
          OutlinedButton.icon(
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            label: const Text('Clear All Data',
                style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red)),
            onPressed: () => _confirmClear(context, treeProvider),
          ),

          const SizedBox(height: 24),

          // ── Version ───────────────────────────────────────────────────────
          Center(
            child: Text(
              '${BuildMetadata.appName} ${BuildMetadata.appVersion}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Center(
            child: Text(
              '${BuildMetadata.syncTechName}\u2122 ${BuildMetadata.syncTechVersion}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _confirmClear(
      BuildContext context, TreeProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
            'This will delete all people, sources, and devices. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await provider.clearDatabase();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All data cleared.')));
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}
