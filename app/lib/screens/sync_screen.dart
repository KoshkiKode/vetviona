import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../models/device.dart';
import '../providers/tree_provider.dart';
import '../services/bluetooth_sync_service.dart';
import '../services/share_sync_service.dart';
import '../services/sync_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Whether Bluetooth sync is supported on the current platform.
bool get _bluetoothSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// Whether camera-based QR scanning is supported on the current platform.
bool get _qrScanSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

// ─────────────────────────────────────────────────────────────────────────────
// Main screen
// ─────────────────────────────────────────────────────────────────────────────

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '4982');
  final _secretController = TextEditingController();

  StreamSubscription<MedicalConsentEvent>? _consentSub;

  @override
  void initState() {
    super.initState();
    // Rebuild when the secret field changes so the Pair button enables/disables.
    _secretController.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to incoming medical consent events. We do this here (not
    // initState) so the BuildContext is available for showDialog.
    _consentSub?.cancel();
    final sync = context.read<SyncService>();
    _consentSub = sync.medicalConsentEvents.listen(_onConsentEvent);
  }

  @override
  void dispose() {
    _consentSub?.cancel();
    _hostController.dispose();
    _portController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  /// Handles an incoming [MedicalConsentEvent] from a remote peer.
  Future<void> _onConsentEvent(MedicalConsentEvent event) async {
    if (!mounted) return;
    final sync = context.read<SyncService>();

    if (event.step == 1) {
      // Show step-1 dialog with a 15-second countdown.
      final accepted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _MedicalConsentRequestDialog(peerLabel: event.peerLabel),
      );
      sync.respondToMedicalRequest(accepted ?? false);
    } else if (event.step == 3) {
      // Show step-3 final confirmation (no countdown — user already accepted).
      if (!mounted) return;
      final ready = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.medical_services_outlined, size: 36),
          title: const Text('Confirm Medical Sync'),
          content: Text(
            '${event.peerLabel} has confirmed. Grant full medical history '
            'sync with this device?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Deny'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Allow'),
            ),
          ],
        ),
      );
      sync.respondToMedicalConfirm(ready ?? false);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();
    final ble = context.watch<BluetoothSyncService>();
    final tree = context.watch<TreeProvider>();
    final cs = Theme.of(context).colorScheme;
    final wifiEnabled = sync.wifiSyncEnabled;
    final bluetoothEnabled = sync.bluetoothSyncEnabled;

    return Scaffold(
      appBar: AppBar(
        title: const Text('RootLoop\u2122 Sync'),
        actions: [
          if (sync.isServerRunning)
            TextButton.icon(
              icon: Icon(Icons.stop_circle_outlined, color: cs.onPrimary),
              label: Text('Stop', style: TextStyle(color: cs.onPrimary)),
              onPressed: () async {
                await sync.stopServer();
                await ble.stopAdvertising();
              },
            )
          else
            TextButton.icon(
              icon: Icon(Icons.play_circle_outlined, color: cs.onPrimary),
              label: Text('Go Online', style: TextStyle(color: cs.onPrimary)),
              // All tiers can start the server:
              //   Free  → QR code + manual connect (no mDNS broadcast)
              //   Pro   → QR code + manual + mDNS auto-discovery
              onPressed: wifiEnabled
                  ? () async {
                      await sync.startServer();
                      // BLE advertising for peer discovery is Pro-only.
                      if (isProTier && bluetoothEnabled && sync.isServerRunning) {
                        await ble.startAdvertising(
                          serverPort: sync.serverPort,
                          deviceId: tree.localDeviceId,
                        );
                      }
                    }
                  : null,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Status banner ────────────────────────────────────────────
          _StatusBanner(sync: sync),
          const SizedBox(height: 12),

          // ── My device ────────────────────────────────────────────────
          _SyncCard(
            icon: Icons.phone_android_outlined,
            title: 'My Device',
            children: [
              _LabeledRow(
                label: 'Device ID',
                value: tree.localDeviceId.isNotEmpty
                    ? '${tree.localDeviceId.substring(0, 8)}\u2026'
                    : '\u2014',
              ),
              const SizedBox(height: 12),
              Text(
                sync.isServerRunning
                    ? 'Server is online. Share the QR code or pairing code '
                        'below to connect another device.'
                    : 'Tap \u201cGo Online\u201d to start accepting connections, '
                        'then share the QR code or pairing code with another device.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.add_link),
                label: const Text('Generate Pairing Code'),
                onPressed: () => _generatePairingCode(context, tree),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Pair with code ───────────────────────────────────────────
          _SyncCard(
            icon: Icons.key_outlined,
            title: 'Pair with Code',
            children: [
              Text(
                'Enter the pairing code shown on the other device.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _secretController,
                decoration: const InputDecoration(
                  labelText: 'Pairing Code',
                  hintText: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
                ),
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.handshake_outlined),
                label: const Text('Pair'),
                onPressed: _secretController.text.trim().isNotEmpty
                    ? () => _pairWithCode(context, tree)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── QR Code Scanner (all tiers, mobile only) ─────────────────
          if (_qrScanSupported) ...[
            _QrScannerCard(
              hostController: _hostController,
              portController: _portController,
              secretController: _secretController,
            ),
            const SizedBox(height: 12),
          ],

          // ── Nearby devices (mDNS) ────────────────────────────────────
          _SyncCard(
            icon: Icons.wifi_find_outlined,
            title: 'Nearby Devices (Auto-Scan)',
            trailing: sync.isDiscovering
                ? TextButton(
                    onPressed: () => sync.stopDiscovery(),
                    child: const Text('Stop'),
                  )
                : TextButton(
                    onPressed: wifiEnabled && isProTier
                        ? () => sync.startDiscovery()
                        : null,
                    child: const Text('Scan'),
                  ),
            children: [
              if (!isProTier)
                _ProGateBanner(
                  message:
                      'WiFi Auto-Scan requires Mobile Paid or Desktop Pro. '
                      'Use QR Code Pairing or Manual Connect for free.',
                  onUpgrade: () => _showUpgradeDialog(context),
                )
              else if (sync.discoveredPeers.isEmpty)
                Text(
                  !wifiEnabled
                      ? 'WiFi Auto-Sync is disabled in Settings.'
                      : sync.isDiscovering
                          ? 'Scanning for Vetviona devices on this network\u2026'
                          : 'No devices found. Tap Scan to start.\n'
                              'Discovers phones, tablets, laptops, and desktops '
                              'running Vetviona on the same network.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                )
              else
                ...sync.discoveredPeers.map(
                  (peer) => _PeerTile(
                    peer: peer,
                    treeProvider: tree,
                    syncService: sync,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Nearby devices (BLE) ─────────────────────────────────────
          if (bluetoothEnabled && _bluetoothSupported) ...[
            _SyncCard(
              icon: Icons.bluetooth_searching,
              title: 'Nearby via Bluetooth',
              trailing: ble.isScanning
                  ? TextButton(
                      onPressed: () => ble.stopScan(),
                      child: const Text('Stop'),
                    )
                  : TextButton(
                      onPressed: isProTier ? () => ble.startScan() : null,
                      child: const Text('Scan'),
                    ),
              children: [
                if (!isProTier)
                  _ProGateBanner(
                    message:
                        'Bluetooth Sync requires Mobile Paid or Desktop Pro.',
                    onUpgrade: () => _showUpgradeDialog(context),
                  )
                else ...[
                  if (ble.statusMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        ble.statusMessage!,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                  if (ble.discoveredPeers.isEmpty)
                    Text(
                      ble.isScanning
                          ? 'Scanning for nearby Vetviona devices\u2026'
                          : 'No BLE devices found. Tap Scan to search.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    )
                  else
                    ...ble.discoveredPeers.map(
                      (peer) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.bluetooth),
                        title: Text(peer.deviceName.isNotEmpty
                            ? peer.deviceName
                            : peer.deviceId),
                        subtitle: Text('${peer.host}:${peer.port}'),
                        trailing: FilledButton.tonal(
                          onPressed: () =>
                              _syncWithBlePeer(context, ble, tree, peer),
                          child: const Text('Sync'),
                        ),
                      ),
                    ),
                ],
              ],
            ),
            const SizedBox(height: 12),
          ],

          // ── AirDrop / Nearby Share / file share ──────────────────────
          _SyncCard(
            icon: Icons.share_outlined,
            title: 'AirDrop · Nearby Share · File Share',
            children: [
              Text(
                'Export your tree as a .vetviona file and send it to another '
                'device using your system share sheet.\n\n'
                '• iOS / macOS: AirDrop\n'
                '• Android: Nearby Share, Google Drive, email\u2026\n'
                '• Desktop: email, Dropbox, USB drive\u2026\n\n'
                'The recipient opens the file in Vetviona to merge it.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.ios_share),
                label: const Text('Share Family Tree\u2026'),
                onPressed: () => _shareTree(context, tree),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Manual connect ───────────────────────────────────────────
          _SyncCard(
            icon: Icons.lan_outlined,
            title: 'Manual Connect',
            children: [
              Text(
                wifiEnabled || bluetoothEnabled
                    ? 'Connect directly if discovery does not work on your network.'
                    : 'Enable WiFi Auto-Sync or Bluetooth Sync in Settings to sync.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _hostController,
                      decoration:
                          const InputDecoration(labelText: 'Host / IP'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _portController,
                      decoration:
                          const InputDecoration(labelText: 'Port'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _secretController,
                decoration: const InputDecoration(
                  labelText: 'Pairing Code',
                  hintText: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
                ),
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.sync),
                label: const Text('Sync Now'),
                onPressed: (wifiEnabled || bluetoothEnabled)
                    ? () => _manualSync(context, sync)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Paired devices ───────────────────────────────────────────
          _SyncCard(
            icon: Icons.devices_outlined,
            title: 'Paired Devices',
            children: [
              if (tree.pairedDevices.isEmpty)
                Text(
                  'No paired devices yet.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                )
              else
                ...tree.pairedDevices.map((d) => _PairedDeviceTile(
                      device: d,
                      syncService: sync,
                      treeProvider: tree,
                    )),
            ],
          ),

          // ── Server info ──────────────────────────────────────────────
          if (sync.isServerRunning) ...[
            const SizedBox(height: 12),
            _SyncCard(
              icon: Icons.info_outline,
              title: 'Server Info',
              children: [
                _LabeledRow(
                  label: 'Port',
                  value: '${sync.serverPort}',
                ),
                const SizedBox(height: 4),
                Text(
                  'Other devices can connect to your local IP address on this port.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),

            // ── Tailscale info ────────────────────────────────────────
            const SizedBox(height: 12),
            _TailscaleCard(
              tailscaleIp: sync.tailscaleIp,
              serverPort: sync.serverPort,
            ),

            // ── QR code ───────────────────────────────────────────────
            const SizedBox(height: 12),
            _QrCodeCard(
              sync: sync,
              tree: tree,
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _shareTree(BuildContext context, TreeProvider tree) async {
    final success = await ShareSyncService.instance.shareTree(tree);
    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not share tree file.')),
      );
    }
  }

  void _showUpgradeDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pro Feature'),
        content: const Text(
          'WiFi Auto-Scan (mDNS) and Bluetooth peer discovery require the '
          'Mobile Paid or Desktop Pro tier.\n\n'
          'Free tier includes:\n'
          '• QR Code Pairing (scan to connect over WiFi)\n'
          '• Manual Connect (enter IP:port + pairing code)\n'
          '• AirDrop / Nearby Share file export\n\n'
          'Upgrade to unlock automatic nearby-device discovery and '
          'Bluetooth scanning.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _generatePairingCode(
      BuildContext context, TreeProvider tree) async {
    final device = Device.create(tier: tree.currentAppTierString);
    await tree.addDevice(device);
    if (!context.mounted) return;

    final cs = Theme.of(context).colorScheme;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pairing Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Share this code with the other device and have them enter it under \u201cPair with Code\u201d.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      device.sharedSecret,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 13),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    tooltip: 'Copy',
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: device.sharedSecret));
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                            content: Text('Code copied to clipboard')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'A new code is generated each time. Each code can only be used once.',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontSize: 11,
                  ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _pairWithCode(
      BuildContext context, TreeProvider tree) async {
    final secret = _secretController.text.trim();
    if (secret.isEmpty) return;

    if (tree.pairedDevices.any((d) => d.sharedSecret == secret)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Already paired with this code.')),
      );
      return;
    }

    final device = Device(
      id: 'pending_${const Uuid().v4()}',
      sharedSecret: secret,
      tier: 'mobileFree',
    );
    await tree.addDevice(device);
    _secretController.clear();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Paired! Tap Sync on a discovered device or use Manual Connect.')),
      );
    }
  }

  Future<void> _manualSync(BuildContext context, SyncService sync) async {
    final host = _hostController.text.trim();
    final portText = _portController.text.trim();
    final secret = _secretController.text.trim();

    if (host.isEmpty || portText.isEmpty || secret.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Fill in host, port, and pairing code.')),
      );
      return;
    }

    final port = int.tryParse(portText);
    if (port == null || port < 1 || port > 65535) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid port number.')),
      );
      return;
    }

    await sync.syncWithPeer(
        host: host, port: port, sharedSecret: secret);
  }

  Future<void> _syncWithBlePeer(
    BuildContext context,
    BluetoothSyncService ble,
    TreeProvider tree,
    BleSyncPeer peer,
  ) async {
    // Find the matching paired device by device ID prefix.
    final device = tree.pairedDevices.where((d) {
      final prefixLen = d.id.length.clamp(0, 8);
      return d.id == peer.deviceId ||
          d.id.startsWith(peer.deviceId) ||
          peer.deviceId.startsWith(d.id.substring(0, prefixLen));
    }).firstOrNull;

    if (device == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Device not paired. Generate a pairing code and pair first.'),
        ),
      );
      return;
    }

    await ble.syncWithPeer(peer, device.sharedSecret);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QR Code Scanner card (mobile only)
// ─────────────────────────────────────────────────────────────────────────────

/// Lets the user point their camera at a Vetviona QR code to auto-fill the
/// Manual Connect host, port, and pairing-code fields.
///
/// Expected QR payload format: `vetviona://<host>:<port>?secret=<sharedSecret>`
///
/// Only shown on mobile platforms (Android / iOS) where a camera is available.
/// Camera permission must be declared in the platform manifest:
///   - Android: `<uses-permission android:name="android.permission.CAMERA"/>`
///   - iOS: `NSCameraUsageDescription` in Info.plist
class _QrScannerCard extends StatefulWidget {
  final TextEditingController hostController;
  final TextEditingController portController;
  final TextEditingController secretController;

  const _QrScannerCard({
    required this.hostController,
    required this.portController,
    required this.secretController,
  });

  @override
  State<_QrScannerCard> createState() => _QrScannerCardState();
}

class _QrScannerCardState extends State<_QrScannerCard> {
  bool _scanning = false;
  String? _lastResult;
  final MobileScannerController _cameraController = MobileScannerController();

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      final parsed = _parseVetvionaUrl(raw);
      if (parsed == null) continue;

      try {
        await _cameraController.stop();
      } catch (_) {
        // Ignore stop errors — the camera may already be stopped.
      }
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _lastResult = raw;
      });

      widget.hostController.text = parsed['host']!;
      widget.portController.text = parsed['port']!;
      widget.secretController.text = parsed['secret']!;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'QR scanned! Fields filled — tap Sync Now in Manual Connect.'),
        ),
      );
      return;
    }
  }

  /// Parses a `vetviona://host:port?secret=xxx` URL.
  /// Returns a map with keys `host`, `port`, `secret`, or `null` on failure.
  static Map<String, String>? _parseVetvionaUrl(String raw) {
    try {
      final uri = Uri.parse(raw);
      if (uri.scheme != 'vetviona') return null;
      final host = uri.host;
      final port = uri.port.toString();
      final secret = uri.queryParameters['secret'];
      if (host.isEmpty || secret == null || secret.isEmpty) return null;
      return {'host': host, 'port': port, 'secret': secret};
    } catch (_) {
      return null;
    }
  }

  Future<void> _stopScanning() async {
    try {
      await _cameraController.stop();
    } catch (_) {
      // Ignore stop errors — the camera may already be stopped.
    }
    if (mounted) setState(() => _scanning = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return _SyncCard(
      icon: Icons.qr_code_scanner,
      title: 'Scan QR Code',
      children: [
        Text(
          'Scan the QR code shown on another device to auto-fill the '
          'connection details below.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        if (_scanning) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 240,
              child: MobileScanner(
                controller: _cameraController,
                onDetect: _onDetect,
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.stop),
            label: const Text('Stop Scanning'),
            onPressed: _stopScanning,
          ),
        ] else ...[
          if (_lastResult != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Last scan: fields filled \u2714',
                style: TextStyle(color: cs.tertiary, fontSize: 12),
              ),
            ),
          FilledButton.icon(
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Start Camera Scan'),
            onPressed: () async {
              // Show scanning state immediately, then await camera start.
              setState(() => _scanning = true);
              try {
                await _cameraController.start();
              } catch (e) {
                if (mounted) {
                  setState(() => _scanning = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Camera unavailable: $e')),
                  );
                }
              }
            },
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Peer tile — mDNS discovered device
// ─────────────────────────────────────────────────────────────────────────────

class _PeerTile extends StatelessWidget {
  final DiscoveredPeer peer;
  final TreeProvider treeProvider;
  final SyncService syncService;

  const _PeerTile({
    required this.peer,
    required this.treeProvider,
    required this.syncService,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pairedDevice = treeProvider.pairedDevices
        .where((d) => d.id == peer.deviceId)
        .firstOrNull;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: cs.primaryContainer,
        child:
            Icon(Icons.devices, color: cs.onPrimaryContainer, size: 18),
      ),
      title: Text(peer.name),
      subtitle: Text(
        '${peer.host}:${peer.port}  \u2022  ${_tierLabel(peer.tier)}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: pairedDevice != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.sync, size: 16),
                  label: const Text('Sync'),
                  onPressed: () => syncService.syncWithPeer(
                    host: peer.host,
                    port: peer.port,
                    sharedSecret: pairedDevice.sharedSecret,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    Icons.medical_services_outlined,
                    color: syncService.isMedicalConsentedPeer(
                            '${peer.host}:${peer.port}')
                        ? Colors.green
                        : null,
                  ),
                  tooltip: syncService.isMedicalConsentedPeer(
                          '${peer.host}:${peer.port}')
                      ? 'Medical sync active'
                      : 'Request medical history sync',
                  onPressed: () => _requestMedicalSync(
                      context, pairedDevice.sharedSecret),
                ),
              ],
            )
          : OutlinedButton.icon(
              icon: const Icon(Icons.handshake_outlined, size: 16),
              label: const Text('Pair'),
              onPressed: () => _showPairDialog(context),
            ),
    );
  }

  Future<void> _requestMedicalSync(
      BuildContext context, String sharedSecret) async {
    // Step 2 callback: show a local confirmation dialog to the initiating user.
    Future<bool> localConfirm() async {
      if (!context.mounted) return false;
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.medical_services_outlined, size: 36),
          title: const Text('Medical History Sync'),
          content: Text(
            '${peer.name} has accepted your request.\n\n'
            'Confirm to share the full medical history of all non-private '
            'family members with this device.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
      return ok ?? false;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Requesting medical sync with ${peer.name}…'),
        duration: const Duration(seconds: 30),
      ),
    );

    final result = await syncService.requestMedicalConsent(
      host: peer.host,
      port: peer.port,
      sharedSecret: sharedSecret,
      localConfirmCallback: localConfirm,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();

    final msg = switch (result) {
      MedicalConsentResult.granted =>
        'Medical history sync with ${peer.name} is now active ✓',
      MedicalConsentResult.denied =>
        '${peer.name} did not allow medical sync.',
      MedicalConsentResult.cancelledLocally => 'Cancelled.',
      MedicalConsentResult.networkError =>
        'Could not complete medical sync request.',
    };
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _showPairDialog(BuildContext context) async {
    final codeController = TextEditingController();
    final confirmed = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pair with ${peer.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Enter the pairing code shown on the other device.'),
            const SizedBox(height: 12),
            TextField(
              controller: codeController,
              decoration:
                  const InputDecoration(labelText: 'Pairing Code'),
              style: const TextStyle(fontFamily: 'monospace'),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(ctx, codeController.text.trim()),
              child: const Text('Pair & Sync')),
        ],
      ),
    );
    codeController.dispose();
    if (confirmed == null || confirmed.isEmpty || !context.mounted) return;

    final alreadyPaired =
        treeProvider.pairedDevices.any((d) => d.sharedSecret == confirmed);
    if (!alreadyPaired) {
      final device = Device(
        id: peer.deviceId ?? 'pending_${const Uuid().v4()}',
        sharedSecret: confirmed,
        tier: peer.tier ?? 'mobileFree',
      );
      await treeProvider.addDevice(device);
    }

    if (!context.mounted) return;
    await syncService.syncWithPeer(
        host: peer.host, port: peer.port, sharedSecret: confirmed);
  }

  static String _tierLabel(String? tier) => switch (tier) {
        'mobilePaid' => 'Mobile Paid',
        'desktopPro' => 'Desktop Pro',
        _ => 'Mobile Free',
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Paired device tile
// ─────────────────────────────────────────────────────────────────────────────

class _PairedDeviceTile extends StatelessWidget {
  final Device device;
  final SyncService syncService;
  final TreeProvider treeProvider;

  const _PairedDeviceTile({
    required this.device,
    required this.syncService,
    required this.treeProvider,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPending = device.id.startsWith('pending_');

    // Check if this device is currently visible via mDNS.
    final discovered = syncService.discoveredPeers
        .where((p) => p.deviceId == device.id)
        .firstOrNull;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: discovered != null
            ? cs.primaryContainer
            : cs.surfaceContainerHighest,
        child: Icon(
          Icons.devices,
          color: discovered != null
              ? cs.onPrimaryContainer
              : cs.onSurfaceVariant,
          size: 18,
        ),
      ),
      title: Text(
        isPending
            ? 'Pending\u2026'
            : '${device.id.substring(0, 8)}\u2026',
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TierBadge(tier: device.tier),
          if (discovered != null)
            Text(
              'Online \u2014 ${discovered.host}:${discovered.port}',
              style: TextStyle(fontSize: 11, color: cs.primary),
            ),
        ],
      ),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (discovered != null) ...[
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: 'Sync Now',
              onPressed: () => syncService.syncWithPeer(
                host: discovered.host,
                port: discovered.port,
                sharedSecret: device.sharedSecret,
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.medical_services_outlined,
                color: syncService.isMedicalConsentedPeer(
                        '${discovered.host}:${discovered.port}') ||
                        syncService.isMedicalConsentedPeer(device.id)
                    ? Colors.green
                    : null,
              ),
              tooltip: syncService.isMedicalConsentedPeer(
                      '${discovered.host}:${discovered.port}') ||
                      syncService.isMedicalConsentedPeer(device.id)
                  ? 'Medical sync active'
                  : 'Request medical history sync',
              onPressed: () => _requestMedicalSync(context, discovered),
            ),
          ],
          IconButton(
            icon: Icon(Icons.delete_outline, color: cs.error),
            tooltip: 'Remove',
            onPressed: () => treeProvider.removeDevice(device.id),
          ),
        ],
      ),
    );
  }

  Future<void> _requestMedicalSync(
      BuildContext context, DiscoveredPeer discovered) async {
    Future<bool> localConfirm() async {
      if (!context.mounted) return false;
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.medical_services_outlined, size: 36),
          title: const Text('Medical History Sync'),
          content: const Text(
            'The other device has accepted your request.\n\n'
            'Confirm to share the full medical history of all non-private '
            'family members with this device.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
      return ok ?? false;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Requesting medical sync…'),
        duration: Duration(seconds: 35),
      ),
    );

    final result = await syncService.requestMedicalConsent(
      host: discovered.host,
      port: discovered.port,
      sharedSecret: device.sharedSecret,
      localConfirmCallback: localConfirm,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();

    final msg = switch (result) {
      MedicalConsentResult.granted =>
        'Medical history sync is now active ✓',
      MedicalConsentResult.denied =>
        'The other device did not allow medical sync.',
      MedicalConsentResult.cancelledLocally => 'Cancelled.',
      MedicalConsentResult.networkError =>
        'Could not complete medical sync request.',
    };
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status banner
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final SyncService sync;
  const _StatusBanner({required this.sync});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final (icon, color, message) = switch (sync.status) {
      SyncStatus.idle => (
          Icons.cloud_off_outlined,
          cs.onSurfaceVariant,
          sync.lastMessage ?? 'Server offline'
        ),
      SyncStatus.advertising => (
          Icons.wifi_tethering,
          cs.primary,
          sync.lastMessage ?? 'Advertising on local network'
        ),
      SyncStatus.discovering => (
          Icons.search,
          cs.tertiary,
          sync.lastMessage ?? 'Scanning\u2026'
        ),
      SyncStatus.syncing => (
          Icons.sync,
          cs.primary,
          sync.lastMessage ?? 'Syncing\u2026'
        ),
      SyncStatus.success => (
          Icons.check_circle_outline,
          cs.tertiary,
          sync.lastMessage ?? 'Sync complete'
        ),
      SyncStatus.error => (
          Icons.error_outline,
          cs.error,
          sync.lastMessage ?? 'Error'
        ),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              sync.status == SyncStatus.syncing ||
                      sync.status == SyncStatus.discovering
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: color),
                    )
                  : Icon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(message,
                    style: TextStyle(color: color, fontSize: 13)),
              ),
            ],
          ),
        ),
        // Live-sync indicator — shown when at least one peer is active.
        if (sync.isLiveSyncActive) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.primary.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                _PulsingDot(color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Live sync active — edits push automatically to '
                    '${sync.activePeerCount} '
                    'device${sync.activePeerCount == 1 ? '' : 's'}',
                    style: TextStyle(
                        color: cs.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Pulsing dot for live-sync indicator ───────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SyncCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;
  final Widget? trailing;

  const _SyncCard({
    required this.icon,
    required this.title,
    required this.children,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style:
                        Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: cs.primary,
                            ),
                  ),
                ),
                if (trailing != null) trailing!,
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

class _LabeledRow extends StatelessWidget {
  final String label;
  final String value;

  const _LabeledRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500)),
        Text(value,
            style: const TextStyle(fontFamily: 'monospace')),
      ],
    );
  }
}

class _TierBadge extends StatelessWidget {
  final String tier;
  const _TierBadge({required this.tier});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = switch (tier) {
      'mobilePaid' => 'Mobile Paid',
      'desktopPro' => 'Desktop Pro',
      _ => 'Mobile Free',
    };
    final color = switch (tier) {
      'mobilePaid' => cs.tertiary,
      'desktopPro' => cs.primary,
      _ => cs.secondary,
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

// ─────────────────────────────────────────────────────────────────────────────
// Pro-gate banner
// ─────────────────────────────────────────────────────────────────────────────

/// Shown inside a [_SyncCard] when a feature requires a paid tier.
class _ProGateBanner extends StatelessWidget {
  final String message;
  final VoidCallback onUpgrade;

  const _ProGateBanner({required this.message, required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.secondary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 16, color: cs.secondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.onSecondaryContainer),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onUpgrade,
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tailscale info card
// ─────────────────────────────────────────────────────────────────────────────

/// Shows Tailscale connection details when the server is running.
///
/// If a Tailscale IP is detected, it displays the address so users can
/// connect from any device on their Tailscale network.  If no Tailscale
/// interface is found, it shows guidance on how to set it up.
class _TailscaleCard extends StatelessWidget {
  final String? tailscaleIp;
  final int serverPort;

  const _TailscaleCard({
    required this.tailscaleIp,
    required this.serverPort,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasTs = tailscaleIp != null;

    return _SyncCard(
      icon: Icons.vpn_lock_outlined,
      title: 'Tailscale',
      children: [
        if (hasTs) ...[
          Text(
            'Tailscale is active. Remote devices on your Tailscale network '
            'can connect using the address below.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withOpacity(0.4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$tailscaleIp:$serverPort',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  tooltip: 'Copy address',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(
                        text: '$tailscaleIp:$serverPort'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Tailscale address copied')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter this in Manual Connect on the remote device along '
            'with your pairing code.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant, fontSize: 11),
          ),
        ] else ...[
          Text(
            'No Tailscale interface detected on this device.\n\n'
            'Install Tailscale to sync over the internet without port '
            'forwarding. Once Tailscale is running, restart the server '
            'to see your Tailscale address here.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QR Code card
// ─────────────────────────────────────────────────────────────────────────────

/// Displays a QR code encoding the server connection info so that another
/// device can scan it to auto-fill the Manual Connect fields.
///
/// QR payload format: `vetviona://<host>:<port>?secret=<sharedSecret>`
///
/// If the device has no paired devices yet, instructs the user to generate
/// a pairing code first.
class _QrCodeCard extends StatefulWidget {
  final SyncService sync;
  final TreeProvider tree;

  const _QrCodeCard({required this.sync, required this.tree});

  @override
  State<_QrCodeCard> createState() => _QrCodeCardState();
}

class _QrCodeCardState extends State<_QrCodeCard> {
  String? _selectedSecret;
  Map<String, List<String>>? _localIps;

  @override
  void initState() {
    super.initState();
    _loadIps();
    if (widget.tree.pairedDevices.isNotEmpty) {
      _selectedSecret = widget.tree.pairedDevices.first.sharedSecret;
    }
  }

  Future<void> _loadIps() async {
    final ips = await SyncService.getAllLocalIps();
    if (mounted) setState(() => _localIps = ips);
  }

  String? get _primaryIp {
    if (_localIps == null) return null;
    final ts = _localIps!['tailscale'] ?? [];
    if (ts.isNotEmpty) return ts.first;
    final lan = _localIps!['lan'] ?? [];
    if (lan.isNotEmpty) return lan.first;
    return null;
  }

  String? get _qrData {
    final ip = _primaryIp;
    final secret = _selectedSecret;
    if (ip == null || secret == null) return null;
    return 'vetviona://$ip:${widget.sync.serverPort}?secret=$secret';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final devices = widget.tree.pairedDevices;
    final qrData = _qrData;

    return _SyncCard(
      icon: Icons.qr_code,
      title: 'QR Code Pairing',
      children: [
        Text(
          'Scan this QR code on another device to auto-fill the connection '
          'details in Manual Connect.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        if (devices.isEmpty)
          Text(
            'Generate a pairing code first, then return here to get a QR code.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.error),
          )
        else ...[
          if (devices.length > 1) ...[
            DropdownButtonFormField<String>(
              value: _selectedSecret,
              decoration:
                  const InputDecoration(labelText: 'Pairing code to encode'),
              items: devices
                  .map((d) => DropdownMenuItem(
                        value: d.sharedSecret,
                        child: Text(
                          d.id.startsWith('pending_')
                              ? 'Pending — ${d.sharedSecret.substring(0, 8)}\u2026'
                              : '${d.id.substring(0, 8)}\u2026',
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedSecret = v),
            ),
            const SizedBox(height: 12),
          ],
          if (qrData != null) ...[
            Center(
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
                padding: const EdgeInsets.all(8),
              ),
            ),
            const SizedBox(height: 8),
            if (_primaryIp != null)
              Center(
                child: Text(
                  '$_primaryIp:${widget.sync.serverPort}',
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 12),
                ),
              ),
          ] else
            Text(
              _localIps == null
                  ? 'Detecting local IP address\u2026'
                  : 'Could not determine local IP address.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Medical consent request dialog (step 1 — receiver side, countdown timer)
// ─────────────────────────────────────────────────────────────────────────────

/// Shown on the **receiving** device when a peer requests bulk medical sync.
///
/// Displays a countdown from 15 → 0 seconds.  If the user does not respond,
/// the dialog auto-closes with `false` (deny) when the timer reaches zero.
class _MedicalConsentRequestDialog extends StatefulWidget {
  final String peerLabel;

  const _MedicalConsentRequestDialog({required this.peerLabel});

  @override
  State<_MedicalConsentRequestDialog> createState() =>
      _MedicalConsentRequestDialogState();
}

class _MedicalConsentRequestDialogState
    extends State<_MedicalConsentRequestDialog> {
  static const _timeoutSeconds = 15;
  int _remaining = _timeoutSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remaining--;
      });
      if (_remaining <= 0) {
        _timer?.cancel();
        if (mounted) Navigator.of(context).pop(false);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress = _remaining / _timeoutSeconds;

    return AlertDialog(
      icon: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              value: progress,
              backgroundColor: cs.surfaceContainerHighest,
              color: progress > 0.4 ? cs.primary : cs.error,
              strokeWidth: 4,
            ),
          ),
          const Icon(Icons.medical_services_outlined, size: 28),
        ],
      ),
      title: const Text('Medical History Sync Request'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyMedium,
              children: [
                TextSpan(
                  text: widget.peerLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                  ),
                ),
                const TextSpan(
                  text:
                      ' is requesting access to the full medical history of '
                      'all non-private family members in your tree.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Auto-denying in $_remaining s…',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _remaining <= 5 ? cs.error : cs.onSurfaceVariant,
                ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _timer?.cancel();
            Navigator.of(context).pop(false);
          },
          child: const Text('Deny'),
        ),
        FilledButton(
          onPressed: () {
            _timer?.cancel();
            Navigator.of(context).pop(true);
          },
          child: const Text('Allow'),
        ),
      ],
    );
  }
}
