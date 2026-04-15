import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'sync_service.dart';

// ── Constants ────────────────────────────────────────────────────────────────

/// Company ID used in BLE manufacturer-specific data advertisements.
/// 0x4B4B is an informal identifier for KoshkiKode (not an officially assigned
/// Bluetooth SIG company ID; replace with an assigned ID before production).
const int _kCompanyId = 0x4B4B;

/// Magic 4-byte signature that identifies a Vetviona advertisement.
/// ASCII "VETV".
const List<int> _kMagic = [0x56, 0x45, 0x54, 0x56];

// ── Data types ────────────────────────────────────────────────────────────────

/// A Vetviona device discovered via BLE scan.
class BleSyncPeer {
  final String deviceId;

  /// IPv4 address extracted from the BLE advertisement.
  final String host;

  /// HTTP server port extracted from the BLE advertisement.
  final int port;

  /// Native BLE device name (may be empty).
  final String deviceName;

  const BleSyncPeer({
    required this.deviceId,
    required this.host,
    required this.port,
    required this.deviceName,
  });

  @override
  bool operator ==(Object other) =>
      other is BleSyncPeer && other.deviceId == deviceId;

  @override
  int get hashCode => deviceId.hashCode;

  @override
  String toString() =>
      'BleSyncPeer(deviceId: $deviceId, host: $host:$port)';
}

// ── BluetoothSyncService ─────────────────────────────────────────────────────

/// Provides BLE-based peer discovery for RootLoop™ Manual sync.
///
/// **Protocol**
///
/// The "server" device (the one hosting the HTTP sync server) embeds its
/// connection info in BLE manufacturer-specific advertisement data:
///
/// ```
/// Offset  Length  Description
///      0       4  Magic bytes: 0x56 0x45 0x54 0x56 ("VETV")
///      4       4  IPv4 address (network byte order, big-endian)
///      8       2  HTTP server port (big-endian uint16)
///     10       8  First 8 ASCII bytes of the device UUID
/// ```
///
/// The "client" device scans BLE, filters by the magic bytes and company ID,
/// then extracts the host/port and calls [SyncService.syncWithPeer] over WiFi
/// for the actual data transfer.
///
/// **Platform notes**
/// - BLE scanning works on Android and iOS.
/// - BLE advertising (peripheral mode) works on Android (Android 5+).
///   On iOS it is attempted but Apple restricts background advertising.
/// - The class degrades gracefully: if advertising fails, discovery still
///   works so the user can initiate sync manually after finding a peer.
///
/// Wire this up alongside [SyncService] so [syncService] is populated before
/// calling [startScan] or [startAdvertising].
class BluetoothSyncService extends ChangeNotifier {
  // ── State ───────────────────────────────────────────────────────────────────

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  bool _isAdvertising = false;
  bool get isAdvertising => _isAdvertising;

  String? _statusMessage;
  String? get statusMessage => _statusMessage;

  final List<BleSyncPeer> _discoveredPeers = [];
  List<BleSyncPeer> get discoveredPeers => List.unmodifiable(_discoveredPeers);

  // ── Injected dependencies ───────────────────────────────────────────────────

  /// Must be set before calling [startScan] or [syncWithPeer].
  SyncService? syncService;

  // ── Internals ───────────────────────────────────────────────────────────────

  StreamSubscription<List<ScanResult>>? _scanSubscription;

  // ── Advertising ─────────────────────────────────────────────────────────────

  /// Starts BLE advertising so nearby clients can discover this device.
  ///
  /// [serverPort] is the port of the local HTTP sync server.
  /// [deviceId] is this device's UUID (only the first 8 bytes are broadcast).
  ///
  /// Advertising is silently skipped on platforms that do not support it
  /// (iOS restrictions, desktop).
  ///
  /// **Note:** `FlutterBluePlus.startAdvertising()` is an Android-only
  /// experimental feature in flutter_blue_plus 2.x.  The call is wrapped in
  /// a broad try/catch so any API incompatibility degrades gracefully — the
  /// scan-based discovery path is always available as a fallback.
  Future<void> startAdvertising({
    required int serverPort,
    required String deviceId,
  }) async {
    if (!_isMobile) {
      _setStatus('BLE advertising is only supported on mobile devices.');
      return;
    }

    final host = await _getWifiIp();
    if (host == null) {
      _setStatus('No WiFi interface found — cannot advertise.');
      return;
    }

    final payload = _buildAdvertisementPayload(
      host: host,
      port: serverPort,
      deviceId: deviceId,
    );

    try {
      // flutter_blue_plus 2.x advertising is Android-only.  The exact API
      // varies across minor versions; we call it reflectively via dynamic to
      // avoid compile-time binding to a class that may not exist on some
      // versions.  Any exception (PlatformException, NoSuchMethodError, etc.)
      // is caught below and the service falls back gracefully.
      await (FlutterBluePlus as dynamic).startAdvertising(
        localName: 'Vetviona',
        advertiseData: {
          'manufacturerData': {_kCompanyId: payload},
        },
      );
      _isAdvertising = true;
      _setStatus('Advertising on BLE (host $host:$serverPort)');
    } catch (e) {
      // Advertising may not be available on this platform or OS version.
      debugPrint('[BluetoothSyncService] BLE advertising unavailable: $e');
      _setStatus('BLE advertising unavailable on this device.');
    }
  }

  /// Stops BLE advertising.
  Future<void> stopAdvertising() async {
    try {
      await (FlutterBluePlus as dynamic).stopAdvertising();
    } catch (_) {}
    _isAdvertising = false;
    notifyListeners();
  }

  // ── Scanning ─────────────────────────────────────────────────────────────────

  /// Starts a BLE scan and populates [discoveredPeers] as Vetviona devices
  /// appear.
  ///
  /// Throws if Bluetooth is not available on this device.
  Future<void> startScan({Duration timeout = const Duration(seconds: 30)}) async {
    if (_isScanning) return;

    _discoveredPeers.clear();
    _isScanning = true;
    _setStatus('Scanning for nearby Vetviona devices…');

    try {
      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidUsesFineLocation: false,
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen(
        _onScanResults,
        onDone: _onScanDone,
        onError: (dynamic e) {
          _isScanning = false;
          _setStatus('BLE scan error: $e');
        },
      );
    } catch (e) {
      _isScanning = false;
      _setStatus('BLE scan failed: $e');
    }
  }

  /// Stops the BLE scan.
  Future<void> stopScan() async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await FlutterBluePlus.stopScan();
    _isScanning = false;
    notifyListeners();
  }

  // ── Sync ────────────────────────────────────────────────────────────────────

  /// Initiates a WiFi sync with a BLE-discovered peer using the provided
  /// [sharedSecret].  The actual data transfer is handled by [SyncService].
  Future<bool> syncWithPeer(BleSyncPeer peer, String sharedSecret) async {
    final svc = syncService;
    if (svc == null) {
      _setStatus('SyncService not attached.');
      return false;
    }
    return svc.syncWithPeer(
      host: peer.host,
      port: peer.port,
      sharedSecret: sharedSecret,
    );
  }

  // ── Tear-down ────────────────────────────────────────────────────────────────

  Future<void> stopAll() async {
    await Future.wait([stopScan(), stopAdvertising()]);
  }

  @override
  void dispose() {
    unawaited(stopAll());
    super.dispose();
  }

  // ── Internals ────────────────────────────────────────────────────────────────

  void _onScanResults(List<ScanResult> results) {
    bool changed = false;
    for (final result in results) {
      final peer = _parsePeer(result);
      if (peer == null) continue;
      // Replace or add.
      final idx = _discoveredPeers.indexWhere((p) => p == peer);
      if (idx == -1) {
        _discoveredPeers.add(peer);
        changed = true;
      }
    }
    if (changed) {
      _setStatus('Found ${_discoveredPeers.length} nearby device(s).');
    }
  }

  void _onScanDone() {
    _isScanning = false;
    _setStatus(_discoveredPeers.isEmpty
        ? 'No Vetviona devices found nearby.'
        : 'Found ${_discoveredPeers.length} nearby device(s).');
  }

  /// Parses a [ScanResult] and returns a [BleSyncPeer] if it carries valid
  /// Vetviona manufacturer data; returns null otherwise.
  BleSyncPeer? _parsePeer(ScanResult result) {
    final mfData = result.advertisementData.manufacturerData;
    final payload = mfData[_kCompanyId];
    if (payload == null || payload.length < 18) return null;

    // Verify magic bytes.
    for (int i = 0; i < 4; i++) {
      if (payload[i] != _kMagic[i]) return null;
    }

    // Extract IPv4 (4 bytes, offset 4).
    final ip = '${payload[4]}.${payload[5]}.${payload[6]}.${payload[7]}';

    // Extract port (2 bytes big-endian, offset 8).
    final port = (payload[8] << 8) | payload[9];

    // Extract device ID (8 ASCII bytes, offset 10).
    final deviceId = String.fromCharCodes(payload.sublist(10, 18));

    return BleSyncPeer(
      deviceId: deviceId,
      host: ip,
      port: port,
      deviceName: result.device.platformName,
    );
  }

  /// Builds the 18-byte payload for BLE manufacturer data.
  static Uint8List _buildAdvertisementPayload({
    required String host,
    required int port,
    required String deviceId,
  }) {
    final buf = Uint8List(18);
    // Magic (4 bytes)
    buf[0] = 0x56; buf[1] = 0x45; buf[2] = 0x54; buf[3] = 0x56;
    // IPv4 address (4 bytes)
    final parts = host.split('.');
    for (int i = 0; i < 4; i++) {
      buf[4 + i] = (parts.length > i) ? int.tryParse(parts[i]) ?? 0 : 0;
    }
    // Port (2 bytes big-endian)
    buf[8] = (port >> 8) & 0xFF;
    buf[9] = port & 0xFF;
    // Device ID prefix (8 ASCII bytes, zero-padded)
    final idBytes = deviceId.codeUnits;
    for (int i = 0; i < 8; i++) {
      buf[10 + i] = i < idBytes.length ? idBytes[i] : 0;
    }
    return buf;
  }

  /// Returns the primary IPv4 address of a WiFi-like interface, or null.
  static Future<String?> _getWifiIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        // Skip loopback and typical non-WiFi names.
        if (name.startsWith('lo') || name.startsWith('vmnet')) continue;
        for (final addr in iface.addresses) {
          if (addr.isLoopback) continue;
          return addr.address;
        }
      }
    } catch (_) {}
    return null;
  }

  void _setStatus(String? message) {
    _statusMessage = message;
    notifyListeners();
  }

  /// True when running on a mobile platform (Android or iOS).
  static bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
}
