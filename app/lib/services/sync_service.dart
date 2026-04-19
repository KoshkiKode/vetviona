import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bonsoir/bonsoir.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../config/app_config.dart';
import '../models/device.dart';
import '../providers/tree_provider.dart';
import 'sound_service.dart';

// ── Public types ─────────────────────────────────────────────────────────────

/// Overall state of the RootLoop™ sync service.
enum SyncStatus { idle, advertising, discovering, syncing, success, error }

/// Result returned from [SyncService.requestMedicalConsent].
enum MedicalConsentResult {
  /// Both devices completed all three consent steps — medical sync is live.
  granted,

  /// The remote device denied the request or the 15-second countdown expired.
  denied,

  /// The local user cancelled at the confirmation step.
  cancelledLocally,

  /// A network error prevented the handshake from completing.
  networkError,
}

/// Incoming medical-consent event pushed to [SyncService.medicalConsentEvents].
///
/// The UI should display a countdown dialog and call either
/// [SyncService.respondToMedicalRequest] (step 1) or
/// [SyncService.respondToMedicalConfirm] (step 3) depending on [step].
class MedicalConsentEvent {
  /// `1` = step-1 request  (receiver side, 15 s countdown)
  /// `3` = step-3 confirm  (receiver side, quick confirmation)
  final int step;

  /// Human-readable name / display label for the requesting peer.
  final String peerLabel;

  const MedicalConsentEvent({required this.step, required this.peerLabel});
}

/// A Vetviona device discovered on the local network via mDNS.
class DiscoveredPeer {
  final String name;
  final String host;
  final int port;
  final String? deviceId;
  final String? tier;

  const DiscoveredPeer({
    required this.name,
    required this.host,
    required this.port,
    this.deviceId,
    this.tier,
  });

  @override
  bool operator ==(Object other) =>
      other is DiscoveredPeer && other.name == name;

  @override
  int get hashCode => name.hashCode;
}

// ── SyncService ───────────────────────────────────────────────────────────────

/// An active peer — a remote device that has successfully completed at least
/// one full sync with this device and is currently reachable on the network.
/// Edits made locally are pushed to all active peers automatically.
class _ActivePeer {
  final String host;
  final int port;
  final String sharedSecret;

  const _ActivePeer({
    required this.host,
    required this.port,
    required this.sharedSecret,
  });

  String get key => '$host:$port';
}

/// RootLoop™ local-network sync service.
///
/// Wire this up in `app.dart` using `ChangeNotifierProxyProvider<TreeProvider,
/// SyncService>` so [treeProvider] is kept up to date automatically.
///
/// Typical usage:
/// 1. [startServer] — starts the shelf HTTP server + mDNS advertisement.
/// 2. [startDiscovery] — scans for nearby Vetviona devices via mDNS.
/// 3. [syncWithPeer] — pushes/pulls tree data to/from a discovered or manually
///    entered peer.  After a successful sync the peer is added to the *active*
///    peer set and subsequent local edits are automatically pushed to it.
/// 4. [stopAll] — tears everything down.
class SyncService extends ChangeNotifier {
  static const _serviceType = '_vetviona._tcp';

  // ── State ───────────────────────────────────────────────────────────────────

  bool _disposed = false;

  SyncStatus _status = SyncStatus.idle;
  SyncStatus get status => _status;

  String? _lastMessage;
  String? get lastMessage => _lastMessage;

  bool _isServerRunning = false;
  bool get isServerRunning => _isServerRunning;

  bool _isDiscovering = false;
  bool get isDiscovering => _isDiscovering;

  bool _wifiSyncEnabled = true;
  bool get wifiSyncEnabled => _wifiSyncEnabled;

  bool _bluetoothSyncEnabled = false;
  bool get bluetoothSyncEnabled => _bluetoothSyncEnabled;

  final List<DiscoveredPeer> _discoveredPeers = [];
  List<DiscoveredPeer> get discoveredPeers =>
      List.unmodifiable(_discoveredPeers);

  // ── Active peers (live sync circle) ─────────────────────────────────────────

  /// Peers with which a full sync has succeeded and to which delta pushes are
  /// sent automatically on every local edit.
  final Map<String, _ActivePeer> _activePeers = {};

  /// Number of currently active (live) peers.
  int get activePeerCount => _activePeers.length;

  /// `true` when the local server is running and at least one peer is active.
  bool get isLiveSyncActive => _isServerRunning && _activePeers.isNotEmpty;

  // ── Internals ───────────────────────────────────────────────────────────────

  HttpServer? _httpServer;
  int _serverPort = 0;
  int get serverPort => _serverPort;

  /// Cached Tailscale IP (100.x.x.x), populated when the server starts.
  String? _tailscaleIp;
  String? get tailscaleIp => _tailscaleIp;

  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _discoverySubscription;

  /// Subscription to [TreeProvider.liveChanges] for auto-push.
  StreamSubscription<Map<String, dynamic>>? _liveChangeSub;

  /// Pending delta records accumulated while the debounce timer is running.
  Map<String, dynamic>? _pendingDelta;

  /// Debounce timer: fires after 400 ms of edit silence and flushes the delta.
  Timer? _pushTimer;

  // ── Triple-consent medical sync ───────────────────────────────────────────

  /// Peers (identified by `host:port`) that have completed the full
  /// triple-consent handshake.  While a peer is in this set, bulk medical
  /// data (all non-private persons regardless of `syncMedical` toggle) is
  /// included in exports to / imports from that peer.
  ///
  /// The set is ephemeral — it is cleared when [stopServer] is called.
  final Set<String> _medicalConsentedPeers = {};

  /// Whether [peerKey] (`host:port`) has completed triple medical consent.
  bool isMedicalConsentedPeer(String peerKey) =>
      _medicalConsentedPeers.contains(peerKey);

  /// Stream emitting incoming consent requests that the UI must react to.
  final _consentEventController =
      StreamController<MedicalConsentEvent>.broadcast();

  /// UI should listen to this stream and show the appropriate countdown /
  /// confirmation dialogs.
  Stream<MedicalConsentEvent> get medicalConsentEvents =>
      _consentEventController.stream;

  /// Completer for the step-1 long-poll on the *receiver* side.
  /// Completed by [respondToMedicalRequest].
  Completer<bool>? _pendingConsentCompleter;

  /// Completer for the step-3 long-poll on the *receiver* side.
  /// Completed by [respondToMedicalConfirm].
  Completer<bool>? _pendingConfirmCompleter;

  /// Sender device label cached during an in-progress step-1 wait so the
  /// UI can display it in subsequent dialogs.
  String? _inboundConsentPeerLabel;

  // ── TreeProvider injection ───────────────────────────────────────────────────

  TreeProvider? _treeProvider;

  /// Injected by [ChangeNotifierProxyProvider] every time TreeProvider changes.
  TreeProvider? get treeProvider => _treeProvider;
  set treeProvider(TreeProvider? value) {
    if (value == _treeProvider) return;
    // Re-subscribe to the new provider's live-change stream.
    _liveChangeSub?.cancel();
    _treeProvider = value;
    if (value != null) {
      _liveChangeSub =
          value.liveChanges.listen(_onLiveChange);
    }
  }

  // ── User settings ────────────────────────────────────────────────────────────

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _wifiSyncEnabled = prefs.getBool('wifiSync') ?? true;
    _bluetoothSyncEnabled = prefs.getBool('bluetoothSync') ?? false;
    if (!_disposed) notifyListeners();
  }

  Future<void> setWifiSyncEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('wifiSync', enabled);
    _wifiSyncEnabled = enabled;
    if (!enabled) {
      await stopServer();
      await stopDiscovery();
      _setStatus(SyncStatus.idle, 'WiFi sync is off');
    } else if (_status == SyncStatus.idle && _lastMessage == 'WiFi sync is off') {
      _setStatus(SyncStatus.idle, null);
    } else {
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> setBluetoothSyncEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bluetoothSync', enabled);
    _bluetoothSyncEnabled = enabled;
    if (!_disposed) notifyListeners();
  }

  // ── Server lifecycle ────────────────────────────────────────────────────────

  /// Starts the shelf HTTP server on a random port.
  ///
  /// All tiers may start the server for manual / QR-code-based sync.
  /// mDNS advertisement (auto-discovery) is only started for paid tiers
  /// ([isProTier]).  Free-tier mobile users get QR-code pairing and manual
  /// connect; Pro users additionally get automatic peer discovery.
  Future<void> startServer() async {
    if (_isServerRunning) return;
    if (!_wifiSyncEnabled) {
      _setStatus(SyncStatus.error, 'WiFi sync is disabled in Settings.');
      return;
    }

    final tp = _treeProvider;
    if (tp == null) {
      _setStatus(SyncStatus.error, 'TreeProvider not attached.');
      return;
    }

    try {
      final router = Router();
      router.get('/info', _handleInfo);
      router.post('/sync', _handleSync);
      router.post('/push', _handlePush);
      // Triple-consent medical-history sync endpoints.
      router.post('/medical/request', _handleMedicalRequest);
      router.post('/medical/confirm', _handleMedicalConfirm);

      final handler = const Pipeline().addHandler(router.call);
      _httpServer =
          await shelf_io.serve(handler, InternetAddress.anyIPv4, 0);
      _serverPort = _httpServer!.port;
      _isServerRunning = true;

      // Detect Tailscale IP now so it's available in the UI.
      _tailscaleIp = await _detectTailscaleIp();

      // mDNS auto-broadcast is a Pro feature; free tier uses QR / manual.
      if (isProTier) {
        await _startBroadcast(tp.localDeviceId, tp.currentAppTierString);
        _setStatus(SyncStatus.advertising,
            'Accepting connections on port $_serverPort');
      } else {
        _setStatus(SyncStatus.advertising,
            'Ready for QR / manual sync on port $_serverPort');
      }
    } catch (e) {
      _setStatus(SyncStatus.error, 'Failed to start server: $e');
    }
  }

  /// Stops the HTTP server and mDNS advertisement.
  Future<void> stopServer() async {
    _pushTimer?.cancel();
    _pushTimer = null;
    _pendingDelta = null;
    _activePeers.clear();
    // Cancel any in-flight consent handshakes.
    _pendingConsentCompleter?.complete(false);
    _pendingConsentCompleter = null;
    _pendingConfirmCompleter?.complete(false);
    _pendingConfirmCompleter = null;
    _medicalConsentedPeers.clear();
    await _broadcast?.stop();
    _broadcast = null;
    await _httpServer?.close(force: true);
    _httpServer = null;
    _serverPort = 0;
    _tailscaleIp = null;
    _isServerRunning = false;
    if (_status == SyncStatus.advertising) {
      _setStatus(SyncStatus.idle, null);
    }
  }

  // ── mDNS broadcast ──────────────────────────────────────────────────────────

  Future<void> _startBroadcast(String deviceId, String tier) async {
    try {
      final service = BonsoirService(
        name: 'Vetviona-${deviceId.substring(0, 8)}',
        type: _serviceType,
        port: _serverPort,
        attributes: {'deviceId': deviceId, 'tier': tier},
      );
      _broadcast = BonsoirBroadcast(service: service);
      await _broadcast!.initialize();
      await _broadcast!.start();
    } catch (e) {
      // mDNS broadcast is best-effort; the HTTP server still works without it.
      // Update the status message but keep the server running.
      debugPrint('[SyncService] mDNS broadcast error: $e');
      _setStatus(SyncStatus.advertising,
          'Ready on port $_serverPort (mDNS unavailable)');
    }
  }

  // ── mDNS discovery ──────────────────────────────────────────────────────────

  /// Starts mDNS discovery; populates [discoveredPeers] as devices appear.
  ///
  /// Requires a paid tier ([isProTier]).
  Future<void> startDiscovery() async {
    if (_isDiscovering) return;
    if (!isProTier) {
      _setStatus(SyncStatus.error,
          'WiFi Auto-Sync discovery requires the Pro or Paid Mobile tier.');
      return;
    }
    if (!_wifiSyncEnabled) {
      _setStatus(SyncStatus.error, 'WiFi sync is disabled in Settings.');
      return;
    }
    _isDiscovering = true;
    _setStatus(SyncStatus.discovering, 'Scanning for nearby devices…');

    try {
      _discovery = BonsoirDiscovery(type: _serviceType);
      await _discovery!.initialize();
      _discoverySubscription =
          _discovery!.eventStream?.listen(_onDiscoveryEvent);
      await _discovery!.start();
    } catch (e) {
      _isDiscovering = false;
      _setStatus(SyncStatus.error, 'Discovery failed: $e');
    }
  }

  void _onDiscoveryEvent(BonsoirDiscoveryEvent event) {
    if (event is BonsoirDiscoveryServiceFoundEvent) {
      // Trigger resolution so we get the IP address.
      final disc = _discovery;
      if (disc != null) {
        disc.serviceResolver.resolveService(event.service);
      }
    } else if (event is BonsoirDiscoveryServiceResolvedEvent) {
      final svc = event.service;
      final host = svc.host ?? '';
      if (host.isEmpty) return;

      final attrs = svc.attributes;
      final deviceId = attrs['deviceId'];
      final myId = _treeProvider?.localDeviceId;
      if (deviceId != null && deviceId == myId) return; // skip ourselves

      _discoveredPeers.removeWhere((p) => p.name == svc.name);
      final peer = DiscoveredPeer(
        name: svc.name,
        host: host,
        port: svc.port,
        deviceId: deviceId,
        tier: attrs['tier'],
      );
      _discoveredPeers.add(peer);
      if (!_disposed) notifyListeners();

      // Auto-connect: if this peer is a paired device, kick off a full
      // bidirectional sync now and add it to the active peer set so
      // future local edits are pushed to it automatically.
      _autoSyncWithResolvedPeer(peer);
    } else if (event is BonsoirDiscoveryServiceLostEvent) {
      final name = event.service.name;
      // Evict from active peers too — peer has left the network.
      final lost = _discoveredPeers.where((p) => p.name == name).toList();
      for (final p in lost) {
        _activePeers.remove('${p.host}:${p.port}');
      }
      _discoveredPeers.removeWhere((p) => p.name == name);
      if (!_disposed) notifyListeners();
    }
  }

  /// Attempts a full sync with a newly-resolved mDNS peer if it is already
  /// a paired device.  On success the peer is promoted to the active set.
  void _autoSyncWithResolvedPeer(DiscoveredPeer peer) {
    final tp = _treeProvider;
    if (tp == null) return;
    final device = tp.pairedDevices
        .where((d) => d.id == peer.deviceId)
        .firstOrNull;
    if (device == null) return; // not paired — ignore

    // Fire-and-forget; errors are swallowed (best-effort auto-connect).
    syncWithPeer(
      host: peer.host,
      port: peer.port,
      sharedSecret: device.sharedSecret,
    ).ignore();
  }

  /// Stops mDNS discovery and clears [discoveredPeers].
  Future<void> stopDiscovery() async {
    _isDiscovering = false;
    await _discoverySubscription?.cancel();
    _discoverySubscription = null;
    await _discovery?.stop();
    _discovery = null;
    _discoveredPeers.clear();
    if (_status == SyncStatus.discovering) {
      _setStatus(SyncStatus.idle, null);
    } else {
      if (!_disposed) notifyListeners();
    }
  }

  /// Convenience — stops both server and discovery.
  Future<void> stopAll() async {
    await Future.wait([stopServer(), stopDiscovery()]);
  }

  // ── HTTP request handlers ───────────────────────────────────────────────────

  // The /info endpoint intentionally returns no device-identifying data.
  // Device ID and tier are exchanged only inside encrypted /sync payloads.
  Response _handleInfo(Request request) {
    return Response.ok(
      jsonEncode({'app': 'vetviona'}),
      headers: {'content-type': 'application/json'},
    );
  }

  Future<Response> _handleSync(Request request) async {
    final tp = _treeProvider;
    if (tp == null) return Response.internalServerError(body: 'Not ready');

    try {
      final body = await request.readAsString();

      // Try all paired device secrets to find one that decrypts the payload.
      Map<String, dynamic>? incoming;
      Device? matchedDevice;
      for (final device in tp.pairedDevices) {
        incoming = tryDecrypt(body, device.sharedSecret);
        if (incoming != null) {
          matchedDevice = device;
          break;
        }
      }

      if (incoming == null || matchedDevice == null) {
        return Response(401, body: 'Unauthorized');
      }

      // If the sender's real ID differs from what we stored, update it.
      final senderId = incoming['senderId'] as String?;
      final senderTier = incoming['senderTier'] as String?;
      if (senderId != null &&
          senderId.isNotEmpty &&
          matchedDevice.id != senderId) {
        final updated = Device(
          id: senderId,
          sharedSecret: matchedDevice.sharedSecret,
          tier: senderTier ?? matchedDevice.tier,
        );
        await tp.updateDevice(matchedDevice.id, updated);
        matchedDevice = updated;
      }

      // Merge incoming tree data.
      await tp.importFromSync(incoming);

      // Use the sender's device ID as the medical-consent key so it survives
      // IP address changes.  Fall back to false (no medical) if unknown.
      final consentKey = senderId ?? '';
      final includeAllMedical = consentKey.isNotEmpty &&
          _medicalConsentedPeers.contains(consentKey);

      // Respond with our own tree data, encrypted with the same secret.
      final ourData = tp.exportForSync(includeAllMedical: includeAllMedical);
      ourData['senderId'] = tp.localDeviceId;
      ourData['senderTier'] = tp.currentAppTierString;
      final encrypted = encrypt(ourData, matchedDevice.sharedSecret);
      return Response.ok(encrypted,
          headers: {'content-type': 'text/plain'});
    } catch (e) {
      return Response.internalServerError(body: 'Error: $e');
    }
  }

  // ── Client sync ─────────────────────────────────────────────────────────────

  /// Connects to [host]:[port] and performs a bidirectional sync using
  /// [sharedSecret].  Returns `true` on success.
  Future<bool> syncWithPeer({
    required String host,
    required int port,
    required String sharedSecret,
  }) async {
    final tp = _treeProvider;
    if (tp == null) return false;
    if (!_wifiSyncEnabled && !_bluetoothSyncEnabled) {
      _setStatus(SyncStatus.error, 'Enable WiFi or Bluetooth sync in Settings.');
      return false;
    }

    _setStatus(SyncStatus.syncing, 'Syncing…');
    try {
      final peerKey = '$host:$port';
      // Check if this peer has completed the triple medical consent handshake.
      // Also check by device ID in case the IP changed.
      final consentedDeviceId = tp.pairedDevices
          .where((d) => d.sharedSecret == sharedSecret)
          .firstOrNull
          ?.id;
      final includeAllMedical = _medicalConsentedPeers.contains(peerKey) ||
          (consentedDeviceId != null &&
              _medicalConsentedPeers.contains(consentedDeviceId));

      final ourData = tp.exportForSync(includeAllMedical: includeAllMedical);
      ourData['senderId'] = tp.localDeviceId;
      ourData['senderTier'] = tp.currentAppTierString;

      final encrypted = encrypt(ourData, sharedSecret);
      final url = Uri(scheme: 'http', host: host, port: port, path: '/sync');

      final response = await http
          .post(
            url,
            headers: {'content-type': 'text/plain'},
            body: encrypted,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        if (response.body.isNotEmpty) {
          final theirData = tryDecrypt(response.body, sharedSecret);
          if (theirData != null) {
            // Update the stored device ID if the peer introduced itself.
            final senderId = theirData['senderId'] as String?;
            final senderTier = theirData['senderTier'] as String?;
            if (senderId != null && senderId.isNotEmpty) {
              final existing = tp.pairedDevices
                  .where((d) => d.sharedSecret == sharedSecret)
                  .firstOrNull;
              if (existing != null && existing.id != senderId) {
                await tp.updateDevice(
                  existing.id,
                  Device(
                    id: senderId,
                    sharedSecret: sharedSecret,
                    tier: senderTier ?? existing.tier,
                  ),
                );
              }
            }
            await tp.importFromSync(theirData);
          }
        }
        _setStatus(SyncStatus.success, 'Sync complete ✓');
        // Promote this peer to the active set so future edits are pushed live.
        _activePeers['$host:$port'] = _ActivePeer(
          host: host,
          port: port,
          sharedSecret: sharedSecret,
        );
        if (!_disposed) notifyListeners();
        return true;
      } else if (response.statusCode == 401) {
        _setStatus(SyncStatus.error, 'Wrong pairing code');
        return false;
      } else {
        _setStatus(
            SyncStatus.error, 'Sync failed: HTTP ${response.statusCode}');
        return false;
      }
    } on TimeoutException {
      _setStatus(SyncStatus.error, 'Connection timed out');
      return false;
    } catch (e) {
      _setStatus(SyncStatus.error, 'Sync error: $e');
      return false;
    }
  }

  // ── Triple-consent medical sync ─────────────────────────────────────────────

  // ── Server side: receive consent request (step 1) ────────────────────────

  /// Step 1 (receiver): A peer wants to bulk-sync all medical history.
  ///
  /// This handler **long-polls** for up to 15 seconds waiting for the local
  /// user to respond.  If the user accepts the [SyncService.respondToMedicalRequest]
  /// call completes the completer; if they deny or the timer fires we return
  /// `{"accepted": false}`.
  Future<Response> _handleMedicalRequest(Request request) async {
    final tp = _treeProvider;
    if (tp == null) return Response.internalServerError(body: 'Not ready');

    try {
      final body = await request.readAsString();
      Map<String, dynamic>? payload;
      Device? matchedDevice;
      for (final device in tp.pairedDevices) {
        payload = tryDecrypt(body, device.sharedSecret);
        if (payload != null) {
          matchedDevice = device;
          break;
        }
      }
      if (payload == null || matchedDevice == null) {
        return Response(401, body: 'Unauthorized');
      }

      final senderId = payload['senderId'] as String? ?? matchedDevice.id;
      final peerLabel =
          '${senderId.substring(0, senderId.length < 8 ? senderId.length : 8)}…';

      // If there is already a pending consent request in progress, reject the
      // new one immediately rather than stacking concurrent requests.
      if (_pendingConsentCompleter != null &&
          !_pendingConsentCompleter!.isCompleted) {
        final resp = encrypt({'accepted': false}, matchedDevice.sharedSecret);
        return Response.ok(resp, headers: {'content-type': 'text/plain'});
      }

      _inboundConsentPeerLabel = peerLabel;
      _pendingConsentCompleter = Completer<bool>();

      // Notify UI — it should show a dialog with a ≤15 s countdown.
      _consentEventController
          .add(MedicalConsentEvent(step: 1, peerLabel: peerLabel));

      // Auto-deny after 15 seconds regardless of UI interaction.
      final timeout = Timer(const Duration(seconds: 15), () {
        if (_pendingConsentCompleter != null &&
            !_pendingConsentCompleter!.isCompleted) {
          _pendingConsentCompleter!.complete(false);
        }
      });

      bool accepted = false;
      try {
        accepted = await _pendingConsentCompleter!.future;
      } finally {
        timeout.cancel();
        _pendingConsentCompleter = null;
      }

      final resp = encrypt({'accepted': accepted}, matchedDevice.sharedSecret);
      return Response.ok(resp, headers: {'content-type': 'text/plain'});
    } catch (e) {
      return Response.internalServerError(body: 'Error: $e');
    }
  }

  // ── Server side: receive confirmation (step 3) ────────────────────────────

  /// Step 3 (receiver): The initiating device confirmed the sync.
  ///
  /// We notify the UI one last time for a quick final confirmation, then
  /// register the peer as medically consented on acceptance.
  Future<Response> _handleMedicalConfirm(Request request) async {
    final tp = _treeProvider;
    if (tp == null) return Response.internalServerError(body: 'Not ready');

    try {
      final body = await request.readAsString();
      Map<String, dynamic>? payload;
      Device? matchedDevice;
      for (final device in tp.pairedDevices) {
        payload = tryDecrypt(body, device.sharedSecret);
        if (payload != null) {
          matchedDevice = device;
          break;
        }
      }
      if (payload == null || matchedDevice == null) {
        return Response(401, body: 'Unauthorized');
      }

      final senderId = payload['senderId'] as String? ?? matchedDevice.id;
      final peerLabel = _inboundConsentPeerLabel ??
          '${senderId.substring(0, senderId.length < 8 ? senderId.length : 8)}…';

      // If there is already a pending confirm in progress, reject.
      if (_pendingConfirmCompleter != null &&
          !_pendingConfirmCompleter!.isCompleted) {
        final resp = encrypt({'ready': false}, matchedDevice.sharedSecret);
        return Response.ok(resp, headers: {'content-type': 'text/plain'});
      }

      _pendingConfirmCompleter = Completer<bool>();

      // Notify UI for the final (step 3) confirmation.
      _consentEventController
          .add(MedicalConsentEvent(step: 3, peerLabel: peerLabel));

      // Auto-deny after 30 seconds (step 3 has a longer window — no hurry).
      final timeout = Timer(const Duration(seconds: 30), () {
        if (_pendingConfirmCompleter != null &&
            !_pendingConfirmCompleter!.isCompleted) {
          _pendingConfirmCompleter!.complete(false);
        }
      });

      bool ready = false;
      try {
        ready = await _pendingConfirmCompleter!.future;
      } finally {
        timeout.cancel();
        _pendingConfirmCompleter = null;
        _inboundConsentPeerLabel = null;
      }

      if (ready) {
        // Register the peer by device ID so the consent survives IP changes.
        _medicalConsentedPeers.add(senderId);
        if (!_disposed) notifyListeners();
      }

      final resp = encrypt({'ready': ready}, matchedDevice.sharedSecret);
      return Response.ok(resp, headers: {'content-type': 'text/plain'});
    } catch (e) {
      return Response.internalServerError(body: 'Error: $e');
    }
  }

  // ── UI response callbacks ─────────────────────────────────────────────────

  /// Called by the UI when the local user responds to a step-1 medical
  /// consent request.  [accepted] = `true` means the user tapped "Allow".
  void respondToMedicalRequest(bool accepted) {
    if (_pendingConsentCompleter != null &&
        !_pendingConsentCompleter!.isCompleted) {
      _pendingConsentCompleter!.complete(accepted);
    }
  }

  /// Called by the UI when the local user responds to the step-3 final
  /// confirmation.  [ready] = `true` means the user tapped "Confirm".
  void respondToMedicalConfirm(bool ready) {
    if (_pendingConfirmCompleter != null &&
        !_pendingConfirmCompleter!.isCompleted) {
      _pendingConfirmCompleter!.complete(ready);
    }
  }

  // ── Client side: initiate triple-consent handshake ────────────────────────

  /// Initiates the three-step medical-consent handshake with a remote peer.
  ///
  /// Steps:
  /// 1. Send `POST /medical/request` — peer shows 15 s countdown dialog.
  /// 2. If peer accepts, show a local confirmation dialog.
  /// 3. Send `POST /medical/confirm` — peer shows final approval dialog.
  /// 4. If peer approves, register the peer in [_medicalConsentedPeers] and
  ///    trigger an immediate full sync (with all medical data).
  ///
  /// Returns a [MedicalConsentResult] describing the outcome.
  Future<MedicalConsentResult> requestMedicalConsent({
    required String host,
    required int port,
    required String sharedSecret,
    /// Optional callback to ask the local user for step-2 confirmation.
    /// Return `true` to proceed.  If `null`, the local step is auto-approved.
    Future<bool> Function()? localConfirmCallback,
  }) async {
    final tp = _treeProvider;
    if (tp == null) return MedicalConsentResult.networkError;

    // ── Step 1: ask the remote peer ──────────────────────────────────────────
    try {
      final step1Payload = encrypt(
        {'senderId': tp.localDeviceId, 'step': 1},
        sharedSecret,
      );
      final url =
          Uri(scheme: 'http', host: host, port: port, path: '/medical/request');
      final resp = await http
          .post(url,
              headers: {'content-type': 'text/plain'}, body: step1Payload)
          .timeout(const Duration(seconds: 25)); // > peer's 15 s UI timeout

      if (resp.statusCode != 200) return MedicalConsentResult.networkError;

      final result = tryDecrypt(resp.body, sharedSecret);
      if (result == null) return MedicalConsentResult.networkError;
      if (result['accepted'] != true) return MedicalConsentResult.denied;
    } on TimeoutException {
      return MedicalConsentResult.networkError;
    } catch (_) {
      return MedicalConsentResult.networkError;
    }

    // ── Step 2: local confirmation ───────────────────────────────────────────
    if (localConfirmCallback != null) {
      final localOk = await localConfirmCallback();
      if (!localOk) return MedicalConsentResult.cancelledLocally;
    }

    // ── Step 3: send confirmation, wait for peer's final approval ────────────
    try {
      final step3Payload = encrypt(
        {'senderId': tp.localDeviceId, 'step': 3},
        sharedSecret,
      );
      final url =
          Uri(scheme: 'http', host: host, port: port, path: '/medical/confirm');
      final resp = await http
          .post(url,
              headers: {'content-type': 'text/plain'}, body: step3Payload)
          .timeout(const Duration(seconds: 40));

      if (resp.statusCode != 200) return MedicalConsentResult.networkError;

      final result = tryDecrypt(resp.body, sharedSecret);
      if (result == null) return MedicalConsentResult.networkError;
      if (result['ready'] != true) return MedicalConsentResult.denied;
    } on TimeoutException {
      return MedicalConsentResult.networkError;
    } catch (_) {
      return MedicalConsentResult.networkError;
    }

    // ── All three steps succeeded ─────────────────────────────────────────────
    // Register by both peer key and device ID for robustness.
    final peerKey = '$host:$port';
    _medicalConsentedPeers.add(peerKey);
    final deviceId = tp.pairedDevices
        .where((d) => d.sharedSecret == sharedSecret)
        .firstOrNull
        ?.id;
    if (deviceId != null) _medicalConsentedPeers.add(deviceId);
    if (!_disposed) notifyListeners();

    // Immediately trigger a full sync so medical data flows right away.
    await syncWithPeer(host: host, port: port, sharedSecret: sharedSecret);

    return MedicalConsentResult.granted;
  }

  // ── Live-sync push (server side) ────────────────────────────────────────────

  /// Receives a delta from a peer that has changed some records.
  /// Applies the delta via the timestamp-based merge in [TreeProvider.importFromSync]
  /// and returns 200 OK.  No response body is sent (unlike `/sync`).
  Future<Response> _handlePush(Request request) async {
    final tp = _treeProvider;
    if (tp == null) return Response.internalServerError(body: 'Not ready');

    try {
      final body = await request.readAsString();
      Map<String, dynamic>? incoming;
      for (final device in tp.pairedDevices) {
        incoming = tryDecrypt(body, device.sharedSecret);
        if (incoming != null) break;
      }
      if (incoming == null) return Response(401, body: 'Unauthorized');

      await tp.importFromSync(incoming);
      return Response.ok('ok');
    } catch (e) {
      return Response.internalServerError(body: 'Error: $e');
    }
  }

  // ── Live-sync push (client side) ─────────────────────────────────────────────

  /// Called by the [TreeProvider.liveChanges] subscription on every local write.
  /// Accumulates the delta and schedules a batched push after a short debounce.
  void _onLiveChange(Map<String, dynamic> delta) {
    if (!_isServerRunning || _activePeers.isEmpty) return;
    _pendingDelta = mergeDelta(_pendingDelta, delta);
    _pushTimer?.cancel();
    _pushTimer = Timer(const Duration(milliseconds: 400), _flushPendingDelta);
  }

  /// Merges two delta payloads.
  ///
  /// Records with the same `id` are deduplicated by keeping the one with the
  /// higher `updatedAt` timestamp (or the incoming record when timestamps are
  /// absent / equal, matching the last-write-wins convention used elsewhere).
  // ignore: invalid_use_of_visible_for_testing_member
  @visibleForTesting
  static Map<String, dynamic> mergeDelta(
    Map<String, dynamic>? existing,
    Map<String, dynamic> incoming,
  ) {
    if (existing == null) return Map<String, dynamic>.from(incoming);
    return {
      'persons': mergeList(
          existing['persons'] as List?, incoming['persons'] as List?),
      'partnerships': mergeList(
          existing['partnerships'] as List?, incoming['partnerships'] as List?),
      'sources': mergeList(
          existing['sources'] as List?, incoming['sources'] as List?),
      'lifeEvents': mergeList(
          existing['lifeEvents'] as List?, incoming['lifeEvents'] as List?),
      'medicalConditions': mergeList(existing['medicalConditions'] as List?,
          incoming['medicalConditions'] as List?),
      'researchTasks': mergeList(
          existing['researchTasks'] as List?, incoming['researchTasks'] as List?),
    };
  }

  /// Deduplicates two record lists by `id`, keeping the record with the higher
  /// `updatedAt` value (or the latest-seen record when timestamps are absent).
  @visibleForTesting
  static List<Map<String, dynamic>> mergeList(List? a, List? b) {
    final result = <String, Map<String, dynamic>>{};
    for (final item in [...(a ?? []), ...(b ?? [])]) {
      final map = item as Map<String, dynamic>;
      final id = map['id'] as String? ?? '';
      if (id.isEmpty) {
        // No ID — just include; can't deduplicate.
        result[Object.hash(map, result.length).toString()] = map;
        continue;
      }
      final existing = result[id];
      if (existing == null) {
        result[id] = map;
      } else {
        // Keep the record with the higher updatedAt (incoming wins on tie).
        final existTs = existing['updatedAt'] as int? ?? 0;
        final inTs = map['updatedAt'] as int? ?? 0;
        if (inTs >= existTs) result[id] = map;
      }
    }
    return result.values.toList();
  }

  /// Pushes the accumulated delta to all active peers and clears the buffer.
  ///
  /// Medical conditions in the delta are filtered per-peer: they are only
  /// included if the peer has either completed triple-consent or the originating
  /// person has `syncMedical = true`.  This ensures TreeProvider can always
  /// emit deltas (without needing to know about consent state) while still
  /// enforcing per-peer medical privacy.
  Future<void> _flushPendingDelta() async {
    final delta = _pendingDelta;
    _pendingDelta = null;
    if (delta == null || _activePeers.isEmpty) return;

    final tp = _treeProvider;
    if (tp == null) return;

    // Pre-compute the set of person IDs that have syncMedical enabled.
    final syncMedicalIds = tp.persons
        .where((p) => !p.isPrivate && p.syncMedical)
        .map((p) => p.id)
        .toSet();

    final peersToRemove = <String>[];
    for (final entry in _activePeers.entries) {
      final peer = entry.value;
      try {
        // Determine whether this peer has triple-consent for medical data.
        final peerKey = peer.key;
        final device = tp.pairedDevices
            .where((d) => d.sharedSecret == peer.sharedSecret)
            .firstOrNull;
        final hasConsent = _medicalConsentedPeers.contains(peerKey) ||
            (device != null && _medicalConsentedPeers.contains(device.id));

        // Build a per-peer payload filtering medical conditions appropriately.
        final rawMedical =
            (delta['medicalConditions'] as List? ?? [])
                .cast<Map<String, dynamic>>();
        final filteredMedical = hasConsent
            ? rawMedical
            : rawMedical
                .where((mc) =>
                    syncMedicalIds.contains(mc['personId'] as String? ?? ''))
                .toList();

        final peerDelta = Map<String, dynamic>.from(delta);
        peerDelta['medicalConditions'] = filteredMedical;
        peerDelta['senderId'] = tp.localDeviceId;
        peerDelta['senderTier'] = tp.currentAppTierString;

        final encrypted = encrypt(peerDelta, peer.sharedSecret);
        final url = Uri(
            scheme: 'http', host: peer.host, port: peer.port, path: '/push');
        await http
            .post(
              url,
              headers: {'content-type': 'text/plain'},
              body: encrypted,
            )
            .timeout(const Duration(seconds: 8));
      } catch (e) {
        // Peer is unreachable — evict from the active set.
        debugPrint('[SyncService] live push failed for ${peer.host}:${peer.port}: $e');
        peersToRemove.add(entry.key);
      }
    }

    if (peersToRemove.isNotEmpty) {
      for (final key in peersToRemove) {
        _activePeers.remove(key);
      }
      if (!_disposed) notifyListeners();
    }
  }

  // ── Tailscale detection ──────────────────────────────────────────────────────

  /// Returns all local IPv4 addresses grouped by type.
  ///
  /// Keys:
  /// - `'lan'`       — standard private-range addresses (192.168.x.x, 10.x.x.x,
  ///                   172.16-31.x.x)
  /// - `'tailscale'` — Tailscale virtual addresses (100.64.0.0/10 range)
  /// - `'other'`     — everything else (e.g. bridge/VM adapters)
  static Future<Map<String, List<String>>> getAllLocalIps() async {
    final result = <String, List<String>>{
      'lan': [],
      'tailscale': [],
      'other': [],
    };
    if (kIsWeb) return result;
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        // Skip interfaces named 'lo' (Unix loopback) or 'loopback' before
        // iterating their addresses; addr.isLoopback catches the rest.
        if (name.startsWith('lo') || name == 'loopback') continue;
        for (final addr in iface.addresses) {
          if (addr.isLoopback) continue;
          final ip = addr.address;
          if (isTailscaleIp(ip)) {
            result['tailscale']!.add(ip);
          } else if (isLanIp(ip)) {
            result['lan']!.add(ip);
          } else {
            result['other']!.add(ip);
          }
        }
      }
    } catch (_) {}
    return result;
  }

  /// Returns `true` if [ip] falls in the Tailscale CGNAT range 100.64.0.0/10.
  @visibleForTesting
  static bool isTailscaleIp(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    final first = int.tryParse(parts[0]) ?? 0;
    final second = int.tryParse(parts[1]) ?? 0;
    // 100.64.0.0/10 covers 100.64.x.x – 100.127.x.x
    return first == 100 && second >= 64 && second <= 127;
  }

  /// Returns `true` if [ip] is a typical private LAN address.
  @visibleForTesting
  static bool isLanIp(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    final a = int.tryParse(parts[0]) ?? 0;
    final b = int.tryParse(parts[1]) ?? 0;
    if (a == 10) return true;
    if (a == 172 && b >= 16 && b <= 31) return true;
    if (a == 192 && b == 168) return true;
    return false;
  }

  /// Detects the primary Tailscale IP address, if any.
  static Future<String?> _detectTailscaleIp() async {
    final ips = await getAllLocalIps();
    final tailscale = ips['tailscale'] ?? [];
    return tailscale.isNotEmpty ? tailscale.first : null;
  }

  // ── Encryption ──────────────────────────────────────────────────────────────

  /// Derives a 32-byte AES-256 key from a shared secret using SHA-256.
  ///
  /// SHA-256 produces 32 bytes of uniformly distributed key material from
  /// any-length input, making it safe regardless of secret format.
  @visibleForTesting
  static enc.Key keyFromSecret(String sharedSecret) {
    final digest = sha256.convert(utf8.encode(sharedSecret));
    return enc.Key(Uint8List.fromList(digest.bytes));
  }

  /// Encrypts [data] as JSON with AES-256-GCM (AEAD) and returns
  /// `<nonce-base64>::<ciphertext+tag-base64>`.
  ///
  /// AES-GCM provides both confidentiality **and** authentication (the
  /// 16-byte GHASH tag is appended to the ciphertext by the `encrypt`
  /// package).  Any attempt to tamper with the ciphertext is detected at
  /// decryption time, making padding-oracle and bit-flipping attacks
  /// impossible.
  ///
  /// A fresh 12-byte (96-bit) nonce is generated for every message, which is
  /// the NIST-recommended nonce size for GCM and provides strong security
  /// guarantees for typical message volumes.
  @visibleForTesting
  static String encrypt(Map<String, dynamic> data, String sharedSecret) {
    final key = keyFromSecret(sharedSecret);
    final iv = enc.IV.fromSecureRandom(12); // 12-byte nonce (NIST GCM std)
    final encrypter =
        enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm, padding: null));
    final encrypted = encrypter.encrypt(jsonEncode(data), iv: iv);
    return '${iv.base64}::${encrypted.base64}';
  }

  /// Tries to decrypt an `<nonce-base64>::<ciphertext+tag-base64>` payload.
  ///
  /// Returns `null` if decryption fails **for any reason** — wrong key,
  /// corrupted ciphertext, failed GCM authentication tag verification, or
  /// invalid JSON.  Callers should treat `null` as "unauthorized".
  @visibleForTesting
  static Map<String, dynamic>? tryDecrypt(String raw, String sharedSecret) {
    try {
      final parts = raw.split('::');
      if (parts.length != 2) return null;
      final key = keyFromSecret(sharedSecret);
      final iv = enc.IV.fromBase64(parts[0]);
      final encrypter =
          enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm, padding: null));
      final decrypted = encrypter.decrypt64(parts[1], iv: iv);
      return jsonDecode(decrypted) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  void _setStatus(SyncStatus status, String? message) {
    _status = status;
    _lastMessage = message;
    if (!_disposed) notifyListeners();
    _playSound(status);
  }

  void _playSound(SyncStatus status) {
    final snd = SoundService.instance;
    switch (status) {
      case SyncStatus.syncing:
        snd.playSyncStart();
      case SyncStatus.success:
        snd.playSyncComplete();
      case SyncStatus.error:
        snd.playFailure();
      case SyncStatus.advertising:
      case SyncStatus.discovering:
      case SyncStatus.idle:
        break;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    // Schedule async resource teardown; stopAll() stops the HTTP server and
    // mDNS broadcast.  unawaited signals the intent to fire-and-forget.
    unawaited(stopAll());
    _consentEventController.close();
    super.dispose();
  }
}

// ── TreeProvider extension for SyncService ────────────────────────────────────

extension TreeProviderSyncExt on TreeProvider {
  /// Returns the AppTier as a plain string matching [Device.tier] values.
  String get currentAppTierString {
    switch (currentAppTier) {
      case AppTier.mobilePaid:
        return 'mobilePaid';
      case AppTier.desktopPro:
        return 'desktopPro';
      case AppTier.mobileFree:
        return 'mobileFree';
    }
  }
}
