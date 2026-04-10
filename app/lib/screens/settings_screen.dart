import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../config/build_metadata.dart';
import '../providers/theme_provider.dart';
import '../providers/tree_provider.dart';
import 'sync_screen.dart';

/// Whether Bluetooth sync is supported on the current platform.
bool get _bluetoothSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

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
              SwitchListTile(
                title: const Text('Dark Mode'),
                subtitle: Text(
                  themeProvider.isDarkMode
                      ? 'Forest green adapts for dark UI'
                      : 'Slavic bookish light palette',
                ),
                secondary: Icon(
                  themeProvider.isDarkMode
                      ? Icons.dark_mode
                      : Icons.light_mode,
                ),
                value: themeProvider.isDarkMode,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) =>
                    context.read<ThemeProvider>().setDarkMode(v),
              ),
              const Divider(height: 24),
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
                        .setPrimaryColor(
                          themeProvider.isDarkMode
                              ? VetvionaPalette.darkPrimary
                              : VetvionaPalette.lightPrimary,
                        ),
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
              FilledButton.icon(
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Open RootLoop\u2122 Sync'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SyncScreen()),
                ),
              ),
              const Divider(height: 24),
              ..._buildSyncChildren(context),
            ],
          ),

          const SizedBox(height: 12),

          // ── Paired Devices ────────────────────────────────────
          _SectionCard(
            icon: Icons.devices_outlined,
            title: 'Paired Devices',
            children: [
              if (treeProvider.pairedDevices.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text('No paired devices.',
                          style: TextStyle(color: colorScheme.onSurfaceVariant)),
                    ],
                  ),
                )
              else
                ...treeProvider.pairedDevices.map(
                  (d) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.devices),
                    title: Text(d.id),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('\u2022' * 16),
                        const SizedBox(height: 2),
                        _DeviceTierBadge(tier: d.tier),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline,
                          color: colorScheme.error),
                      onPressed: () =>
                          treeProvider.removeDevice(d.id),
                    ),
                  ),
                ),
              if (currentAppTier == AppTier.desktopPro &&
                  treeProvider.pairedDevices
                      .any((d) => d.tier == 'mobileFree'))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline,
                          size: 14, color: colorScheme.outlineVariant),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Free-tier mobile devices sync manually only, up to 100 people per sync.',
                          style: TextStyle(
                              fontSize: 12, color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Danger Zone ───────────────────────────────────────
          _SectionCard(
            icon: Icons.warning_amber_outlined,
            title: 'Danger Zone',
            iconColor: colorScheme.error,
            titleColor: colorScheme.error,
            children: [
              Text(
                'Permanently delete all people, sources, and settings.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: Icon(Icons.delete_forever,
                    color: colorScheme.error),
                label: Text('Clear All Data',
                    style: TextStyle(color: colorScheme.error)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: colorScheme.error),
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
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                Text(
                  '${BuildMetadata.syncTechName}\u2122 ${BuildMetadata.syncTechVersion}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  List<Widget> _buildSyncChildren(BuildContext context) {
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    switch (currentAppTier) {
      case AppTier.mobileFree:
        return [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'RootLoop\u2122 Manual',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            'Tap to sync when you are right in front of your computer — works over WiFi or Bluetooth on demand.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: onSurfaceVariant),
          ),
          if (_bluetoothSupported)
            SwitchListTile(
              title: const Text('Bluetooth Sync'),
              subtitle: const Text('Sync nearby via Bluetooth'),
              value: _bluetoothSync,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) {
                setState(() => _bluetoothSync = v);
                _saveBool('bluetoothSync', v);
              },
            ),
          const Divider(height: 16),
          Row(
            children: [
              Icon(Icons.people_outline, size: 14, color: onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                'Free tier: up to $freeMobilePersonLimit people per tree.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: onSurfaceVariant),
              ),
            ],
          ),
        ];

      case AppTier.mobilePaid:
      case AppTier.desktopPro:
        return [
          // RootLoop Auto
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'RootLoop\u2122 Auto',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            'Automatically syncs when your devices are on the same WiFi network — no button press needed.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: onSurfaceVariant),
          ),
          SwitchListTile(
            title: const Text('WiFi Auto-Sync'),
            subtitle: const Text('Sync automatically on home network'),
            value: _wifiSync,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) {
              setState(() => _wifiSync = v);
              _saveBool('wifiSync', v);
            },
          ),
          const Divider(height: 24),
          // RootLoop Manual
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'RootLoop\u2122 Manual',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            _bluetoothSupported
                ? 'Tap to sync on demand — works over Bluetooth or any local connection you initiate.'
                : 'Tap to sync on demand — works over WiFi on your local network.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: onSurfaceVariant),
          ),
          if (_bluetoothSupported)
            SwitchListTile(
              title: const Text('Bluetooth Sync'),
              subtitle: const Text('Sync nearby via Bluetooth'),
              value: _bluetoothSync,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) {
                setState(() => _bluetoothSync = v);
                _saveBool('bluetoothSync', v);
              },
            ),
          if (currentAppTier == AppTier.desktopPro) ...[
            const Divider(height: 16),
            Text(
              'Desktop Pro supports both free and paid mobile devices. '
              'Free-tier mobile devices sync manually only (up to $freeMobilePersonLimit people per sync).',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: onSurfaceVariant),
            ),
          ],
        ];
    }
  }

  Future<void> _confirmClear(
      BuildContext context, TreeProvider provider) async {
    final errorColor = Theme.of(context).colorScheme.error;
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
                FilledButton.styleFrom(backgroundColor: errorColor),
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

class _DeviceTierBadge extends StatelessWidget {
  final String tier;
  const _DeviceTierBadge({required this.tier});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = switch (tier) {
      'mobilePaid' => 'Mobile Paid',
      'desktopPro' => 'Desktop Pro',
      _ => 'Mobile Free',
    };
    final color = switch (tier) {
      'mobilePaid' => colorScheme.tertiary,
      'desktopPro' => colorScheme.primary,
      _ => colorScheme.secondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
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
