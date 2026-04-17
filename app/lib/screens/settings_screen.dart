import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../utils/page_routes.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../config/build_metadata.dart';
import '../models/person.dart';
import '../providers/theme_provider.dart';
import '../providers/tree_provider.dart';
import '../services/license_backend_service.dart';
import '../services/purchase_service.dart';
import '../services/sound_service.dart';
import '../services/sync_service.dart';
import '../services/wikitree_service.dart';
import 'account_management_screen.dart';
import 'sync_screen.dart';
import 'wikitree_screen.dart';

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
  bool _soundEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final sync = context.read<SyncService>();
    await sync.loadSettings();
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _wifiSync = sync.wifiSyncEnabled;
      _bluetoothSync = sync.bluetoothSyncEnabled;
      _soundEnabled = prefs.getBool('soundEnabled') ?? true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final treeProvider = context.watch<TreeProvider>();
    final syncService = context.watch<SyncService>();
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
                          color: colorScheme.outline.withValues(alpha: 0.3)),
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

          // ── Sound ─────────────────────────────────────────────
          _SectionCard(
            icon: Icons.volume_up_outlined,
            title: 'Sound',
            children: [
              SwitchListTile(
                title: const Text('UI Sounds'),
                subtitle: const Text(
                    'Sync, success, failure and warning tones'),
                secondary: Icon(_soundEnabled
                    ? Icons.volume_up
                    : Icons.volume_off),
                value: _soundEnabled,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) async {
                  await SoundService.instance.setSoundEnabled(v);
                  setState(() => _soundEnabled = v);
                  if (v) SoundService.instance.playSuccess();
                },
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Display ───────────────────────────────────────────
          _SectionCard(
            icon: Icons.tune_outlined,
            title: 'Display',
            children: [
              if (treeProvider.persons.isNotEmpty) ...[
                const Text(
                  'Home Person',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 4),
                _PersonSearchDropdown(
                  persons: treeProvider.persons,
                  selectedId: treeProvider.homePersonId,
                  label: 'Tree focal point',
                  onSelected: (id) =>
                      context.read<TreeProvider>().setHomePersonId(id),
                ),
                const SizedBox(height: 12),
              ],
              // Advanced display options – collapsed by default so beginners
              // aren't overwhelmed, but easily accessible for power users.
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  leading: Icon(Icons.settings_outlined,
                      size: 20, color: colorScheme.primary),
                  title: const Text(
                    'Advanced Options',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: const Text(
                    'Date format, place name style',
                    style: TextStyle(fontSize: 12),
                  ),
                  children: [
                    const SizedBox(height: 8),
                    Tooltip(
                      message: 'Choose how dates appear throughout the app',
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Date Format'),
                        value: treeProvider.dateFormat,
                        items: const [
                          DropdownMenuItem(
                              value: 'dd MMM yyyy',
                              child: Text('01 Jan 2000 (recommended)')),
                          DropdownMenuItem(
                              value: 'MM/dd/yyyy',
                              child: Text('01/01/2000 (US style)')),
                          DropdownMenuItem(
                              value: 'yyyy-MM-dd',
                              child: Text('2000-01-01 (ISO 8601)')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            context.read<TreeProvider>().setDateFormat(v);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Tooltip(
                      message: 'Show historical or colonial place names alongside modern ones',
                      child: DropdownButtonFormField<int>(
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
                          if (v != null) {
                            context
                                .read<TreeProvider>()
                                .setColonizationLevel(v);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
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
                  fadeSlideRoute(builder: (_) => const SyncScreen()),
                ),
              ),
              const Divider(height: 24),
              ..._buildSyncChildren(context, syncService),
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

          // ── External Sources ───────────────────────────────────
          _SectionCard(
            icon: Icons.link_outlined,
            title: 'External Sources',
            children: [
              ListenableBuilder(
                listenable: WikiTreeService.instance,
                builder: (context, _) {
                  final svc = WikiTreeService.instance;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.account_tree_outlined,
                            size: 16,
                            color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          svc.isLoggedIn
                              ? 'WikiTree: ${svc.loggedInUser}'
                              : 'WikiTree: not logged in',
                          style: TextStyle(
                              color: svc.isLoggedIn
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text(
                            'Open WikiTree & Find A Grave Hub'),
                        onPressed: () => Navigator.push(
                          context,
                          fadeSlideRoute(
                              builder: (_) => const WikiTreeScreen()),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Backup & Restore ──────────────────────────────────
          _SectionCard(
            icon: Icons.backup_outlined,
            title: 'Backup & Restore',
            children: [
              Text(
                'Save all tree data to a JSON file or restore from a previous backup.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.upload_outlined),
                label: const Text('Create Backup'),
                onPressed: () => _createBackup(context, treeProvider),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.download_outlined),
                label: const Text('Restore from Backup'),
                onPressed: () => _restoreBackup(context, treeProvider),
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

          const SizedBox(height: 12),

          // ── License Account ───────────────────────────────────
          if (currentAppTier != AppTier.mobileFree) ...[
            _SectionCard(
              icon: Icons.manage_accounts_outlined,
              title: 'Vetviona License Account',
              children: [
                Consumer<LicenseBackendService>(
                  builder: (ctx, svc, _) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (svc.accountEmail != null) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.alternate_email,
                                size: 14,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  svc.accountEmail!,
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              if (!svc.emailVerified)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.errorContainer,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Unverified',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: colorScheme.onErrorContainer,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],
                        FilledButton.icon(
                          icon: const Icon(Icons.manage_accounts, size: 16),
                          label: const Text('Manage License Account'),
                          onPressed: () => Navigator.push(
                            context,
                            fadeSlideRoute(
                              builder: (_) =>
                                  const AccountManagementScreen(),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // ── Purchases (mobile only) ───────────────────────────
          if (currentAppTier != AppTier.desktopPro)
            _SectionCard(
              icon: Icons.storefront_outlined,
              title: 'Purchases',
              children: [
                Consumer<PurchaseService>(
                  builder: (ctx, purchaseService, _) {
                    if (purchaseService.isPurchased) {
                      return Row(
                        children: [
                          Icon(Icons.check_circle_outline,
                              color: colorScheme.primary, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Mobile Paid — purchased',
                            style: TextStyle(color: colorScheme.primary),
                          ),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Already purchased on another device? Restore your purchase here.',
                          style: Theme.of(ctx)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 10),
                        if (purchaseService.errorMessage != null) ...[
                          Text(
                            purchaseService.errorMessage!,
                            style: TextStyle(
                                color: colorScheme.error, fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                        ],
                        OutlinedButton.icon(
                          icon: purchaseService.isLoading
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child:
                                      CircularProgressIndicator.adaptive(),
                                )
                              : const Icon(Icons.restore, size: 18),
                          label: const Text('Restore Purchases'),
                          onPressed: purchaseService.isLoading
                              ? null
                              : () => purchaseService.restorePurchases(),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),

          if (currentAppTier != AppTier.desktopPro) const SizedBox(height: 12),

          // ── Privacy & Legal ───────────────────────────────────
          _SectionCard(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy & Legal',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy Policy'),
                trailing: const Icon(Icons.open_in_new, size: 16),
                onTap: () => _showUrl(
                  context,
                  'https://vetviona.koshkikode.com/privacy',
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.gavel_outlined),
                title: const Text('Terms of Service'),
                trailing: const Icon(Icons.open_in_new, size: 16),
                onTap: () => _showUrl(
                  context,
                  'https://vetviona.koshkikode.com/terms',
                ),
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

  Future<void> _showUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open $url'),
          action: SnackBarAction(label: 'OK', onPressed: () {}),
        ),
      );
    }
  }

  List<Widget> _buildSyncChildren(BuildContext context, SyncService syncService) {
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
              onChanged: (v) async {
                setState(() => _bluetoothSync = v);
                await syncService.setBluetoothSyncEnabled(v);
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
            'Automatically syncs when your devices are on the same WiFi network '
            'or Tailscale virtual network — no button press needed.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: onSurfaceVariant),
          ),
          SwitchListTile(
            title: const Text('WiFi Auto-Sync'),
            subtitle: const Text('Sync automatically on home network or Tailscale'),
            value: _wifiSync,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) async {
              setState(() => _wifiSync = v);
              await syncService.setWifiSyncEnabled(v);
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
                ? 'Tap to sync on demand — works over Bluetooth, WiFi, Tailscale, '
                    'AirDrop (iOS/macOS), or Nearby Share (Android).'
                : 'Tap to sync on demand — works over WiFi, Tailscale, '
                    'AirDrop (macOS), or any local connection you initiate.',
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
              onChanged: (v) async {
                setState(() => _bluetoothSync = v);
                await syncService.setBluetoothSyncEnabled(v);
              },
            ),
          const Divider(height: 16),
          Text(
            'AirDrop (iOS/macOS) and Nearby Share (Android) are available '
            'via the Share button on the Sync screen — no extra setup needed.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: onSurfaceVariant),
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
      builder: (ctx) => AlertDialog.adaptive(
        title: const Text('Clear All Data'),
        content: const Text(
            'This will delete all people, sources, and partnerships. Paired device credentials are preserved. This cannot be undone.'),
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

  Future<void> _createBackup(
      BuildContext context, TreeProvider provider) async {
    try {
      final json = await provider.exportBackupJson();
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/vetviona_backup_$timestamp.json');
      await file.writeAsString(json);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup saved to: ${file.path}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e')),
        );
      }
    }
  }

  Future<void> _restoreBackup(
      BuildContext context, TreeProvider provider) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.single.path == null) return;
      final file = File(result.files.single.path!);
      final json = await file.readAsString();
      await provider.importBackupJson(json);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup restored successfully.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
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
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
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

/// A searchable person picker that sorts names alphabetically and filters as
/// the user types. Used wherever a person needs to be selected from a list.
class _PersonSearchDropdown extends StatefulWidget {
  final List<Person> persons;
  final String? selectedId;
  final String label;
  final ValueChanged<String?> onSelected;

  const _PersonSearchDropdown({
    required this.persons,
    required this.selectedId,
    required this.label,
    required this.onSelected,
  });

  @override
  State<_PersonSearchDropdown> createState() => _PersonSearchDropdownState();
}

class _PersonSearchDropdownState extends State<_PersonSearchDropdown> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final initial = widget.persons
        .where((p) => p.id == widget.selectedId)
        .map((p) => p.name)
        .firstOrNull ?? '';
    _controller = TextEditingController(text: initial);
  }

  @override
  void didUpdateWidget(_PersonSearchDropdown old) {
    super.didUpdateWidget(old);
    if (old.selectedId != widget.selectedId) {
      final name = widget.persons
          .where((p) => p.id == widget.selectedId)
          .map((p) => p.name)
          .firstOrNull ?? '';
      _controller.text = name;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.persons]..sort((a, b) => a.name.compareTo(b.name));
    return LayoutBuilder(
      builder: (context, constraints) => DropdownMenu<String>(
        controller: _controller,
        width: constraints.maxWidth,
        enableFilter: true,
        enableSearch: true,
        label: Text(widget.label),
        initialSelection: widget.selectedId,
        dropdownMenuEntries: [
          const DropdownMenuEntry<String>(value: '', label: '— None —'),
          ...sorted.map(
            (p) => DropdownMenuEntry<String>(value: p.id, label: p.name),
          ),
        ],
        onSelected: (id) => widget.onSelected(id?.isEmpty ?? true ? null : id),
      ),
    );
  }
}
