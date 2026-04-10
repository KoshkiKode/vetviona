import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/device.dart';
import '../providers/tree_provider.dart';
import '../services/sync_service.dart';

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

  @override
  void initState() {
    super.initState();
    // Rebuild when the secret field changes so the Pair button enables/disables.
    _secretController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();
    final tree = context.watch<TreeProvider>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('RootLoop\u2122 Sync'),
        actions: [
          if (sync.isServerRunning)
            TextButton.icon(
              icon: Icon(Icons.stop_circle_outlined, color: cs.onPrimary),
              label: Text('Stop', style: TextStyle(color: cs.onPrimary)),
              onPressed: () => sync.stopServer(),
            )
          else
            TextButton.icon(
              icon: Icon(Icons.play_circle_outlined, color: cs.onPrimary),
              label: Text('Go Online', style: TextStyle(color: cs.onPrimary)),
              onPressed: () => sync.startServer(),
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
                'To pair a new device, generate a pairing code here and enter it on the other device.',
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

          // ── Nearby devices (mDNS) ────────────────────────────────────
          _SyncCard(
            icon: Icons.wifi_find_outlined,
            title: 'Nearby Devices',
            trailing: sync.isDiscovering
                ? TextButton(
                    onPressed: () => sync.stopDiscovery(),
                    child: const Text('Stop'),
                  )
                : TextButton(
                    onPressed: () => sync.startDiscovery(),
                    child: const Text('Scan'),
                  ),
            children: [
              if (sync.discoveredPeers.isEmpty)
                Text(
                  sync.isDiscovering
                      ? 'Scanning for Vetviona devices on this network\u2026'
                      : 'No devices found. Tap Scan to start.',
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

          // ── Manual connect ───────────────────────────────────────────
          _SyncCard(
            icon: Icons.lan_outlined,
            title: 'Manual Connect',
            children: [
              Text(
                'Connect directly if mDNS discovery does not work on your network.',
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
                onPressed: () => _manualSync(context, sync),
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
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

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
      id: 'pending_${DateTime.now().millisecondsSinceEpoch}',
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
          ? FilledButton.tonalIcon(
              icon: const Icon(Icons.sync, size: 16),
              label: const Text('Sync'),
              onPressed: () => syncService.syncWithPeer(
                host: peer.host,
                port: peer.port,
                sharedSecret: pairedDevice.sharedSecret,
              ),
            )
          : OutlinedButton.icon(
              icon: const Icon(Icons.handshake_outlined, size: 16),
              label: const Text('Pair'),
              onPressed: () => _showPairDialog(context),
            ),
    );
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
        id: peer.deviceId ??
            'pending_${DateTime.now().millisecondsSinceEpoch}',
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
          if (discovered != null)
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
            icon: Icon(Icons.delete_outline, color: cs.error),
            tooltip: 'Remove',
            onPressed: () => treeProvider.removeDevice(device.id),
          ),
        ],
      ),
    );
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
          Colors.green,
          sync.lastMessage ?? 'Sync complete'
        ),
      SyncStatus.error => (
          Icons.error_outline,
          cs.error,
          sync.lastMessage ?? 'Error'
        ),
    };

    return Container(
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
