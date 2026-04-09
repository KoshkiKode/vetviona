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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Theme ─────────────────────────────────────────────
          _SectionCard(
            icon: Icons.palette_outlined,
            title: 'Appearance',
            children: [
              const Text(
                'Primary Color',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 220,
                child: ColorPicker(
                  pickerColor: themeProvider.primaryColor,
                  onColorChanged: (color) =>
                      context.read<ThemeProvider>().setPrimaryColor(color),
                  pickerAreaHeightPercent: 0.75,
                  enableAlpha: false,
                  labelTypes: const [],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Current color: '),
                  const SizedBox(width: 8),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: themeProvider.primaryColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: colorScheme.outline.withOpacity(0.3)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => context
                        .read<ThemeProvider>()
                        .setPrimaryColor(const Color(0xFF1F6F50)),
                    child: const Text('Reset to default'),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Display ───────────────────────────────────────────
          _SectionCard(
            icon: Icons.tune_outlined,
            title: 'Display',
            children: [
              DropdownButtonFormField<String>(
                decoration:
                    const InputDecoration(labelText: 'Date Format'),
                value: treeProvider.dateFormat,
                items: const [
                  DropdownMenuItem(
                      value: 'dd MMM yyyy',
                      child: Text('01 Jan 2000')),
                  DropdownMenuItem(
                      value: 'MM/dd/yyyy',
                      child: Text('01/01/2000')),
                  DropdownMenuItem(
                      value: 'yyyy-MM-dd',
                      child: Text('2000-01-01')),
                ],
                onChanged: (v) {
                  if (v != null)
                    context.read<TreeProvider>().setDateFormat(v);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                    labelText: 'Historical Place Names'),
                value: treeProvider.colonizationLevel,
                items: const [
                  DropdownMenuItem(
                      value: 0, child: Text('Modern names only')),
                  DropdownMenuItem(
                      value: 1,
                      child: Text('Also show colonizer names')),
                  DropdownMenuItem(
                      value: 2,
                      child: Text('Also show indigenous names')),
                ],
                onChanged: (v) {
                  if (v != null)
                    context
                        .read<TreeProvider>()
                        .setColonizationLevel(v);
                },
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Sync ──────────────────────────────────────────────
          _SectionCard(
            icon: Icons.sync_outlined,
            title: 'RootLoop\u2122 Sync',
            children: [
              SwitchListTile(
                title: const Text('WiFi Sync'),
                subtitle:
                    const Text('Sync over local WiFi network'),
                value: _wifiSync,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) {
                  setState(() => _wifiSync = v);
                  _saveBool('wifiSync', v);
                },
              ),
              SwitchListTile(
                title: const Text('Bluetooth Sync'),
                subtitle:
                    const Text('Sync nearby via Bluetooth'),
                value: _bluetoothSync,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) {
                  setState(() => _bluetoothSync = v);
                  _saveBool('bluetoothSync', v);
                },
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Paired Devices ────────────────────────────────────
          _SectionCard(
            icon: Icons.devices_outlined,
            title: 'Paired Devices',
            children: [
              if (treeProvider.pairedDevices.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: Colors.grey),
                      SizedBox(width: 8),
                      Text('No paired devices.',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              else
                ...treeProvider.pairedDevices.map(
                  (d) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.devices),
                    title: Text(d.id),
                    subtitle: const Text('\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.red),
                      onPressed: () =>
                          treeProvider.removeDevice(d.id),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Danger Zone ───────────────────────────────────────
          _SectionCard(
            icon: Icons.warning_amber_outlined,
            title: 'Danger Zone',
            iconColor: Colors.red,
            titleColor: Colors.red,
            children: [
              Text(
                'Permanently delete all people, sources, and settings.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_forever,
                    color: Colors.red),
                label: const Text('Clear All Data',
                    style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () =>
                    _confirmClear(context, treeProvider),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Version ───────────────────────────────────────────
          Center(
            child: Column(
              children: [
                Text(
                  '${BuildMetadata.appName} ${BuildMetadata.appVersion}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey),
                ),
                Text(
                  '${BuildMetadata.syncTechName}\u2122 ${BuildMetadata.syncTechVersion}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey),
                ),
              ],
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
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: Colors.red),
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

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;
  final Color? iconColor;
  final Color? titleColor;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.children,
    this.iconColor,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveIconColor = iconColor ?? colorScheme.primary;
    final effectiveTitleColor = titleColor ?? colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: effectiveIconColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: effectiveTitleColor),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}
