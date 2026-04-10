import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

/// RootLoop™ local-network sync service.
///
/// Wire this up in `app.dart` using `ChangeNotifierProxyProvider<TreeProvider,
/// SyncService>` so [treeProvider] is kept up to date automatically.
///
/// Typical usage:
/// 1. [startServer] — starts the shelf HTTP server + mDNS advertisement.
/// 2. [startDiscovery] — scans for nearby Vetviona devices via mDNS.
/// 3. [syncWithPeer] — pushes/pulls tree data to/from a discovered or manually
///    entered peer.
/// 4. [stopAll] — tears everything down.
class SyncService extends ChangeNotifier {
  static const _serviceType = '_vetviona._tcp';

  // ── State ───────────────────────────────────────────────────────────────────

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

  // ── Internals ───────────────────────────────────────────────────────────────

  HttpServer? _httpServer;
  int _serverPort = 0;
  int get serverPort => _serverPort;

  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _discoverySubscription;

  /// Injected by [ChangeNotifierProxyProvider] every time TreeProvider changes.
  TreeProvider? treeProvider;

  // ── User settings ────────────────────────────────────────────────────────────

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _wifiSyncEnabled = prefs.getBool('wifiSync') ?? true;
    _bluetoothSyncEnabled = prefs.getBool('bluetoothSync') ?? false;
    notifyListeners();
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
      notifyListeners();
    }
  }

  Future<void> setBluetoothSyncEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bluetoothSync', enabled);
    _bluetoothSyncEnabled = enabled;
    notifyListeners();
  }

  // ── Server lifecycle ────────────────────────────────────────────────────────

  /// Starts the shelf HTTP server on a random port and begins mDNS advertisement.
  Future<void> startServer() async {
    if (_isServerRunning) return;
    if (!_wifiSyncEnabled) {
      _setStatus(SyncStatus.error, 'WiFi sync is disabled in Settings.');
      return;
    }

    final tp = treeProvider;
    if (tp == null) {
      _setStatus(SyncStatus.error, 'TreeProvider not attached.');
      return;
    }

    try {
      final router = Router();
      router.get('/info', _handleInfo);
      router.post('/sync', _handleSync);

      final handler = const Pipeline().addHandler(router.call);
      _httpServer =
          await shelf_io.serve(handler, InternetAddress.anyIPv4, 0);
      _serverPort = _httpServer!.port;
      _isServerRunning = true;

      await _startBroadcast(tp.localDeviceId, tp.currentAppTierString);
      _setStatus(SyncStatus.advertising,
          'Accepting connections on port $_serverPort');
    } catch (e) {
      _setStatus(SyncStatus.error, 'Failed to start server: $e');
    }
  }

  /// Stops the HTTP server and mDNS advertisement.
  Future<void> stopServer() async {
    await _broadcast?.stop();
    _broadcast = null;
    await _httpServer?.close(force: true);
    _httpServer = null;
    _serverPort = 0;
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
  Future<void> startDiscovery() async {
    if (_isDiscovering) return;
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
      final myId = treeProvider?.localDeviceId;
      if (deviceId != null && deviceId == myId) return; // skip ourselves

      _discoveredPeers.removeWhere((p) => p.name == svc.name);
      _discoveredPeers.add(DiscoveredPeer(
        name: svc.name,
        host: host,
        port: svc.port,
        deviceId: deviceId,
        tier: attrs['tier'],
      ));
      notifyListeners();
    } else if (event is BonsoirDiscoveryServiceLostEvent) {
      final name = event.service.name;
      _discoveredPeers.removeWhere((p) => p.name == name);
      notifyListeners();
    }
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
      notifyListeners();
    }
  }

  /// Convenience — stops both server and discovery.
  Future<void> stopAll() async {
    await Future.wait([stopServer(), stopDiscovery()]);
  }

  // ── HTTP request handlers ───────────────────────────────────────────────────

  Response _handleInfo(Request request) {
    final tp = treeProvider;
    return Response.ok(
      jsonEncode({
        'deviceId': tp?.localDeviceId ?? '',
        'tier': tp?.currentAppTierString ?? 'mobileFree',
      }),
      headers: {'content-type': 'application/json'},
    );
  }

  Future<Response> _handleSync(Request request) async {
    final tp = treeProvider;
    if (tp == null) return Response.internalServerError(body: 'Not ready');

    try {
      final body = await request.readAsString();

      // Try all paired device secrets to find one that decrypts the payload.
      Map<String, dynamic>? incoming;
      Device? matchedDevice;
      for (final device in tp.pairedDevices) {
        incoming = _tryDecrypt(body, device.sharedSecret);
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

      // Respond with our own tree data, encrypted with the same secret.
      final ourData = tp.exportForSync();
      ourData['senderId'] = tp.localDeviceId;
      ourData['senderTier'] = tp.currentAppTierString;
      final encrypted = _encrypt(ourData, matchedDevice.sharedSecret);
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
    final tp = treeProvider;
    if (tp == null) return false;
    if (!_wifiSyncEnabled && !_bluetoothSyncEnabled) {
      _setStatus(SyncStatus.error, 'Enable WiFi or Bluetooth sync in Settings.');
      return false;
    }

    _setStatus(SyncStatus.syncing, 'Syncing…');
    try {
      final ourData = tp.exportForSync();
      ourData['senderId'] = tp.localDeviceId;
      ourData['senderTier'] = tp.currentAppTierString;

      final encrypted = _encrypt(ourData, sharedSecret);
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
          final theirData = _tryDecrypt(response.body, sharedSecret);
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

  // ── Encryption ──────────────────────────────────────────────────────────────

  /// Derives a 32-byte AES-256 key from a shared secret using SHA-256.
  ///
  /// SHA-256 produces 32 bytes of uniformly distributed key material from
  /// any-length input, making it safe regardless of secret format.
  static enc.Key _keyFromSecret(String sharedSecret) {
    final digest = sha256.convert(utf8.encode(sharedSecret));
    return enc.Key(Uint8List.fromList(digest.bytes));
  }

  /// Encrypts [data] as JSON with AES-256-CBC and returns
  /// `<iv-base64>::<ciphertext-base64>`.
  static String _encrypt(Map<String, dynamic> data, String sharedSecret) {
    final key = _keyFromSecret(sharedSecret);
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(jsonEncode(data), iv: iv);
    return '${iv.base64}::${encrypted.base64}';
  }

  /// Tries to decrypt an `<iv-base64>::<ciphertext-base64>` payload.
  /// Returns `null` if decryption or JSON parsing fails.
  static Map<String, dynamic>? _tryDecrypt(String raw, String sharedSecret) {
    try {
      final parts = raw.split('::');
      if (parts.length != 2) return null;
      final key = _keyFromSecret(sharedSecret);
      final iv = enc.IV.fromBase64(parts[0]);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
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
    notifyListeners();
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
    stopAll();
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
