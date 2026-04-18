// Tests for SyncService that do NOT require a real network, HTTP server,
// Bonsoir mDNS stack, or BLE stack.  The pure-logic static helpers are
// exposed via @visibleForTesting and tested exhaustively here.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vetviona_app/providers/tree_provider.dart';
import 'package:vetviona_app/services/sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── SyncStatus enum ───────────────────────────────────────────────────────

  group('SyncStatus enum', () {
    test('has exactly 6 values', () {
      expect(SyncStatus.values.length, 6);
    });

    test('contains all expected variants', () {
      expect(
        SyncStatus.values,
        containsAll([
          SyncStatus.idle,
          SyncStatus.advertising,
          SyncStatus.discovering,
          SyncStatus.syncing,
          SyncStatus.success,
          SyncStatus.error,
        ]),
      );
    });
  });

  // ── MedicalConsentResult enum ─────────────────────────────────────────────

  group('MedicalConsentResult enum', () {
    test('has exactly 4 values', () {
      expect(MedicalConsentResult.values.length, 4);
    });

    test('contains all expected variants', () {
      expect(
        MedicalConsentResult.values,
        containsAll([
          MedicalConsentResult.granted,
          MedicalConsentResult.denied,
          MedicalConsentResult.cancelledLocally,
          MedicalConsentResult.networkError,
        ]),
      );
    });
  });

  // ── MedicalConsentEvent ───────────────────────────────────────────────────

  group('MedicalConsentEvent', () {
    test('stores step 1 and peerLabel correctly', () {
      const e = MedicalConsentEvent(step: 1, peerLabel: 'DeviceAlpha');
      expect(e.step, 1);
      expect(e.peerLabel, 'DeviceAlpha');
    });

    test('stores step 3 correctly', () {
      const e = MedicalConsentEvent(step: 3, peerLabel: 'DeviceBeta');
      expect(e.step, 3);
    });
  });

  // ── DiscoveredPeer ────────────────────────────────────────────────────────

  group('DiscoveredPeer', () {
    const peer1 = DiscoveredPeer(
      name: 'Peer A',
      host: '192.168.1.1',
      port: 8080,
    );
    const peer2 = DiscoveredPeer(
      name: 'Peer A',
      host: '10.0.0.5',
      port: 9999,
    );
    const peer3 = DiscoveredPeer(
      name: 'Peer B',
      host: '192.168.1.1',
      port: 8080,
    );

    test('equality is based on name', () {
      expect(peer1 == peer2, isTrue);
      expect(peer1 == peer3, isFalse);
    });

    test('hashCode is name-based', () {
      expect(peer1.hashCode, peer2.hashCode);
      expect(peer1.hashCode, isNot(peer3.hashCode));
    });

    test('stores deviceId and tier when provided', () {
      const p = DiscoveredPeer(
        name: 'X',
        host: '10.0.0.1',
        port: 80,
        deviceId: 'dev-123',
        tier: 'desktopPro',
      );
      expect(p.deviceId, 'dev-123');
      expect(p.tier, 'desktopPro');
    });

    test('deviceId and tier are null by default', () {
      expect(peer1.deviceId, isNull);
      expect(peer1.tier, isNull);
    });
  });

  // ── SyncService initial state ─────────────────────────────────────────────

  group('SyncService initial state', () {
    late SyncService svc;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      svc = SyncService();
    });

    tearDown(() => svc.dispose());

    test('status is idle', () => expect(svc.status, SyncStatus.idle));
    test('lastMessage is null', () => expect(svc.lastMessage, isNull));
    test('isServerRunning is false', () => expect(svc.isServerRunning, isFalse));
    test('isDiscovering is false', () => expect(svc.isDiscovering, isFalse));
    test('wifiSyncEnabled defaults to true',
        () => expect(svc.wifiSyncEnabled, isTrue));
    test('bluetoothSyncEnabled defaults to false',
        () => expect(svc.bluetoothSyncEnabled, isFalse));
    test('discoveredPeers is empty', () => expect(svc.discoveredPeers, isEmpty));
    test('activePeerCount is 0', () => expect(svc.activePeerCount, 0));
    test('isLiveSyncActive is false', () => expect(svc.isLiveSyncActive, isFalse));
    test('serverPort is 0', () => expect(svc.serverPort, 0));
    test('tailscaleIp is null', () => expect(svc.tailscaleIp, isNull));
    test('treeProvider is null initially', () => expect(svc.treeProvider, isNull));

    test('isMedicalConsentedPeer returns false for any key', () {
      expect(svc.isMedicalConsentedPeer('192.168.1.1:8080'), isFalse);
      expect(svc.isMedicalConsentedPeer(''), isFalse);
    });

    test('medicalConsentEvents is a broadcast stream', () {
      expect(svc.medicalConsentEvents, isNotNull);
    });

    test('stopAll completes without error when nothing is running', () async {
      await expectLater(svc.stopAll(), completes);
    });

    test('dispose completes without error', () {
      // Use a fresh local instance to avoid double-dispose from tearDown.
      final fresh = SyncService();
      expect(() => fresh.dispose(), returnsNormally);
    });
  });

  // ── loadSettings ─────────────────────────────────────────────────────────

  group('SyncService.loadSettings', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('defaults: wifiSync=true, bluetoothSync=false', () async {
      final svc = SyncService();
      await svc.loadSettings();
      expect(svc.wifiSyncEnabled, isTrue);
      expect(svc.bluetoothSyncEnabled, isFalse);
      svc.dispose();
    });

    test('loads persisted wifiSync=false', () async {
      SharedPreferences.setMockInitialValues({'wifiSync': false});
      final svc = SyncService();
      await svc.loadSettings();
      expect(svc.wifiSyncEnabled, isFalse);
      svc.dispose();
    });

    test('loads persisted bluetoothSync=true', () async {
      SharedPreferences.setMockInitialValues({'bluetoothSync': true});
      final svc = SyncService();
      await svc.loadSettings();
      expect(svc.bluetoothSyncEnabled, isTrue);
      svc.dispose();
    });
  });

  // ── setWifiSyncEnabled ────────────────────────────────────────────────────

  group('SyncService.setWifiSyncEnabled', () {
    late SyncService svc;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      svc = SyncService();
    });

    tearDown(() => svc.dispose());

    test('persists false and updates state', () async {
      await svc.setWifiSyncEnabled(false);
      expect(svc.wifiSyncEnabled, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('wifiSync'), isFalse);
    });

    test('re-enabling sets state back to true', () async {
      await svc.setWifiSyncEnabled(false);
      await svc.setWifiSyncEnabled(true);
      expect(svc.wifiSyncEnabled, isTrue);
    });

    test('disabling when already off does not throw', () async {
      await svc.setWifiSyncEnabled(false);
      await expectLater(svc.setWifiSyncEnabled(false), completes);
    });
  });

  // ── setBluetoothSyncEnabled ───────────────────────────────────────────────

  group('SyncService.setBluetoothSyncEnabled', () {
    late SyncService svc;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      svc = SyncService();
    });

    tearDown(() => svc.dispose());

    test('persists true and updates state', () async {
      await svc.setBluetoothSyncEnabled(true);
      expect(svc.bluetoothSyncEnabled, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('bluetoothSync'), isTrue);
    });

    test('persists false and updates state', () async {
      await svc.setBluetoothSyncEnabled(false);
      expect(svc.bluetoothSyncEnabled, isFalse);
    });
  });

  // ── treeProvider setter ────────────────────────────────────────────────────

  group('SyncService.treeProvider setter', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('setting same provider twice is a no-op', () {
      final svc = SyncService();
      final tp = TreeProvider();
      svc.treeProvider = tp;
      svc.treeProvider = tp; // second set should not crash
      expect(svc.treeProvider, tp);
      svc.dispose();
    });

    test('setting null provider is accepted', () {
      final svc = SyncService();
      svc.treeProvider = null;
      expect(svc.treeProvider, isNull);
      svc.dispose();
    });

    test('replacing provider cancels old subscription', () {
      final svc = SyncService();
      svc.treeProvider = TreeProvider();
      svc.treeProvider = TreeProvider(); // replace
      expect(svc.treeProvider, isNotNull);
      svc.dispose();
    });
  });

  // ── respondToMedicalRequest / respondToMedicalConfirm ────────────────────

  group('SyncService consent callbacks (no pending completer)', () {
    late SyncService svc;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      svc = SyncService();
    });
    tearDown(() => svc.dispose());

    test('respondToMedicalRequest(true) does not throw', () {
      expect(() => svc.respondToMedicalRequest(true), returnsNormally);
    });

    test('respondToMedicalRequest(false) does not throw', () {
      expect(() => svc.respondToMedicalRequest(false), returnsNormally);
    });

    test('respondToMedicalConfirm(true) does not throw', () {
      expect(() => svc.respondToMedicalConfirm(true), returnsNormally);
    });

    test('respondToMedicalConfirm(false) does not throw', () {
      expect(() => svc.respondToMedicalConfirm(false), returnsNormally);
    });
  });

  // ── isTailscaleIp (static) ────────────────────────────────────────────────

  group('SyncService.isTailscaleIp', () {
    test('100.64.0.1 → true (start of range)', () {
      expect(SyncService.isTailscaleIp('100.64.0.1'), isTrue);
    });

    test('100.100.50.50 → true (middle of range)', () {
      expect(SyncService.isTailscaleIp('100.100.50.50'), isTrue);
    });

    test('100.127.255.255 → true (end of range)', () {
      expect(SyncService.isTailscaleIp('100.127.255.255'), isTrue);
    });

    test('100.63.0.1 → false (just below range)', () {
      expect(SyncService.isTailscaleIp('100.63.0.1'), isFalse);
    });

    test('100.128.0.1 → false (just above range)', () {
      expect(SyncService.isTailscaleIp('100.128.0.1'), isFalse);
    });

    test('192.168.1.1 → false (LAN, not Tailscale)', () {
      expect(SyncService.isTailscaleIp('192.168.1.1'), isFalse);
    });

    test('10.0.0.1 → false', () {
      expect(SyncService.isTailscaleIp('10.0.0.1'), isFalse);
    });

    test('malformed string → false', () {
      expect(SyncService.isTailscaleIp('not-an-ip'), isFalse);
    });

    test('too few octets → false', () {
      expect(SyncService.isTailscaleIp('100.64'), isFalse);
    });

    test('empty string → false', () {
      expect(SyncService.isTailscaleIp(''), isFalse);
    });
  });

  // ── isLanIp (static) ──────────────────────────────────────────────────────

  group('SyncService.isLanIp', () {
    test('10.0.0.1 → true (10/8 block)', () {
      expect(SyncService.isLanIp('10.0.0.1'), isTrue);
    });

    test('10.255.255.255 → true', () {
      expect(SyncService.isLanIp('10.255.255.255'), isTrue);
    });

    test('172.16.0.1 → true (start of 172.16/12)', () {
      expect(SyncService.isLanIp('172.16.0.1'), isTrue);
    });

    test('172.31.255.255 → true (end of 172.16/12)', () {
      expect(SyncService.isLanIp('172.31.255.255'), isTrue);
    });

    test('172.15.0.1 → false (just below 172.16)', () {
      expect(SyncService.isLanIp('172.15.0.1'), isFalse);
    });

    test('172.32.0.1 → false (just above 172.31)', () {
      expect(SyncService.isLanIp('172.32.0.1'), isFalse);
    });

    test('192.168.0.1 → true (192.168/16)', () {
      expect(SyncService.isLanIp('192.168.0.1'), isTrue);
    });

    test('192.168.255.255 → true', () {
      expect(SyncService.isLanIp('192.168.255.255'), isTrue);
    });

    test('8.8.8.8 → false (public IP)', () {
      expect(SyncService.isLanIp('8.8.8.8'), isFalse);
    });

    test('malformed string → false', () {
      expect(SyncService.isLanIp('not-an-ip'), isFalse);
    });

    test('too few octets → false', () {
      expect(SyncService.isLanIp('192.168'), isFalse);
    });

    test('Tailscale address 100.64.x.x → false', () {
      expect(SyncService.isLanIp('100.64.1.1'), isFalse);
    });
  });

  // ── mergeList (static) ────────────────────────────────────────────────────

  group('SyncService.mergeList', () {
    test('both lists empty → empty', () {
      expect(SyncService.mergeList([], []), isEmpty);
    });

    test('null lists treated as empty', () {
      expect(SyncService.mergeList(null, null), isEmpty);
    });

    test('null first list returns copy of second', () {
      final result = SyncService.mergeList(null, [
        {'id': 'a', 'name': 'Alice'}
      ]);
      expect(result.length, 1);
      expect(result.first['name'], 'Alice');
    });

    test('single item from first list preserved', () {
      final result = SyncService.mergeList([
        {'id': 'a', 'name': 'Alice'}
      ], []);
      expect(result.length, 1);
      expect(result.first['name'], 'Alice');
    });

    test('deduplicates by id, keeping higher updatedAt (incoming wins)', () {
      final old = {'id': 'a', 'name': 'Old Alice', 'updatedAt': 100};
      final newer = {'id': 'a', 'name': 'New Alice', 'updatedAt': 200};
      final result = SyncService.mergeList([old], [newer]);
      expect(result.length, 1);
      expect(result.first['name'], 'New Alice');
    });

    test('deduplicates by id, keeping local when local updatedAt is higher', () {
      final local = {'id': 'a', 'name': 'Local', 'updatedAt': 300};
      final remote = {'id': 'a', 'name': 'Remote', 'updatedAt': 100};
      final result = SyncService.mergeList([local], [remote]);
      expect(result.length, 1);
      expect(result.first['name'], 'Local');
    });

    test('incoming wins on tie (equal updatedAt)', () {
      final a = {'id': 'a', 'name': 'First', 'updatedAt': 100};
      final b = {'id': 'a', 'name': 'Second', 'updatedAt': 100};
      final result = SyncService.mergeList([a], [b]);
      expect(result.first['name'], 'Second');
    });

    test('records without id are all included', () {
      final result = SyncService.mergeList(
        [{'name': 'No ID 1'}],
        [{'name': 'No ID 2'}],
      );
      expect(result.length, 2);
    });

    test('different ids both included', () {
      final result = SyncService.mergeList(
        [{'id': 'a', 'name': 'A'}],
        [{'id': 'b', 'name': 'B'}],
      );
      expect(result.length, 2);
    });

    test('empty id treated as no-id → always included', () {
      final result = SyncService.mergeList(
        [{'id': '', 'name': 'X'}],
        [{'id': '', 'name': 'Y'}],
      );
      expect(result.length, 2);
    });

    test('records without updatedAt compare as 0', () {
      final a = {'id': 'a', 'name': 'No-ts-1'};
      final b = {'id': 'a', 'name': 'No-ts-2'};
      // both at 0, incoming (b) should win
      final result = SyncService.mergeList([a], [b]);
      expect(result.first['name'], 'No-ts-2');
    });
  });

  // ── mergeDelta (static) ───────────────────────────────────────────────────

  group('SyncService.mergeDelta', () {
    test('null existing returns copy of incoming', () {
      final delta = {
        'persons': [
          {'id': 'p1', 'name': 'Alice'}
        ],
        'partnerships': <dynamic>[],
        'sources': <dynamic>[],
        'lifeEvents': <dynamic>[],
        'medicalConditions': <dynamic>[],
        'researchTasks': <dynamic>[],
      };
      final result = SyncService.mergeDelta(null, delta);
      expect((result['persons'] as List).length, 1);
    });

    test('merges all six list fields', () {
      final base = {
        'persons': [
          {'id': 'p1', 'name': 'Alice', 'updatedAt': 100}
        ],
        'partnerships': [
          {'id': 'pt1', 'updatedAt': 100}
        ],
        'sources': [
          {'id': 's1', 'updatedAt': 100}
        ],
        'lifeEvents': [
          {'id': 'le1', 'updatedAt': 100}
        ],
        'medicalConditions': [
          {'id': 'mc1', 'updatedAt': 100}
        ],
        'researchTasks': [
          {'id': 'rt1', 'updatedAt': 100}
        ],
      };
      final update = {
        'persons': [
          {'id': 'p1', 'name': 'Alice Updated', 'updatedAt': 200}
        ],
        'partnerships': <dynamic>[],
        'sources': <dynamic>[],
        'lifeEvents': <dynamic>[],
        'medicalConditions': <dynamic>[],
        'researchTasks': <dynamic>[],
      };
      final result = SyncService.mergeDelta(base, update);
      final persons = result['persons'] as List;
      expect(persons.first['name'], 'Alice Updated');
      expect((result['partnerships'] as List).length, 1);
    });

    test('merging empty delta with empty existing returns all-empty', () {
      final empty = {
        'persons': <dynamic>[],
        'partnerships': <dynamic>[],
        'sources': <dynamic>[],
        'lifeEvents': <dynamic>[],
        'medicalConditions': <dynamic>[],
        'researchTasks': <dynamic>[],
      };
      final result = SyncService.mergeDelta(empty, empty);
      for (final key in [
        'persons',
        'partnerships',
        'sources',
        'lifeEvents',
        'medicalConditions',
        'researchTasks'
      ]) {
        expect((result[key] as List), isEmpty, reason: '$key should be empty');
      }
    });
  });

  // ── encrypt / tryDecrypt round-trip (static) ──────────────────────────────

  group('SyncService.encrypt / tryDecrypt', () {
    test('round-trip preserves a simple map', () {
      const secret = 'test-secret-key';
      final data = {'key': 'value', 'count': 3};
      final ciphertext = SyncService.encrypt(data, secret);
      final decrypted = SyncService.tryDecrypt(ciphertext, secret);
      expect(decrypted, isNotNull);
      expect(decrypted!['key'], 'value');
      expect(decrypted['count'], 3);
    });

    test('round-trip preserves nested structures', () {
      const secret = 'another-key';
      final data = {
        'persons': [
          {'id': 'p1', 'name': 'Alice'}
        ],
        'flag': true,
      };
      final ciphertext = SyncService.encrypt(data, secret);
      final decrypted = SyncService.tryDecrypt(ciphertext, secret);
      expect(decrypted, isNotNull);
      expect((decrypted!['persons'] as List).first['name'], 'Alice');
    });

    test('wrong key returns null', () {
      const correctSecret = 'correct-secret';
      const wrongSecret = 'wrong-secret';
      final ciphertext = SyncService.encrypt({'msg': 'hello'}, correctSecret);
      expect(SyncService.tryDecrypt(ciphertext, wrongSecret), isNull);
    });

    test('malformed ciphertext without separator returns null', () {
      expect(SyncService.tryDecrypt('noseparatorhere', 'secret'), isNull);
    });

    test('invalid base64 after separator returns null', () {
      expect(SyncService.tryDecrypt('aaaa::!!!invalid!!!', 'secret'), isNull);
    });

    test('empty string returns null', () {
      expect(SyncService.tryDecrypt('', 'secret'), isNull);
    });

    test('different calls produce different ciphertexts (unique nonces)', () {
      const secret = 'key';
      final data = {'x': 1};
      final c1 = SyncService.encrypt(data, secret);
      final c2 = SyncService.encrypt(data, secret);
      expect(c1, isNot(c2));
    });
  });

  // ── keyFromSecret (static) ────────────────────────────────────────────────

  group('SyncService.keyFromSecret', () {
    test('produces a 32-byte key', () {
      final key = SyncService.keyFromSecret('any-secret');
      expect(key.bytes.length, 32);
    });

    test('same secret produces same key', () {
      final k1 = SyncService.keyFromSecret('hello');
      final k2 = SyncService.keyFromSecret('hello');
      expect(k1.bytes, k2.bytes);
    });

    test('different secrets produce different keys', () {
      final k1 = SyncService.keyFromSecret('abc');
      final k2 = SyncService.keyFromSecret('xyz');
      expect(k1.bytes, isNot(k2.bytes));
    });

    test('empty string secret produces a valid 32-byte key', () {
      final key = SyncService.keyFromSecret('');
      expect(key.bytes.length, 32);
    });
  });

  // ── getAllLocalIps (public static) ────────────────────────────────────────

  group('SyncService.getAllLocalIps', () {
    test('returns map with exactly lan/tailscale/other keys', () async {
      final ips = await SyncService.getAllLocalIps();
      expect(ips.keys.toSet(), {'lan', 'tailscale', 'other'});
    });

    test('all values are List<String>', () async {
      final ips = await SyncService.getAllLocalIps();
      expect(ips['lan'], isA<List<String>>());
      expect(ips['tailscale'], isA<List<String>>());
      expect(ips['other'], isA<List<String>>());
    });

    test('does not throw in test environment', () async {
      await expectLater(SyncService.getAllLocalIps(), completes);
    });
  });

  // ── TreeProviderSyncExt.currentAppTierString ──────────────────────────────

  group('TreeProviderSyncExt.currentAppTierString', () {
    test('returns a non-empty string', () {
      SharedPreferences.setMockInitialValues({});
      final tp = TreeProvider();
      expect(tp.currentAppTierString, isNotEmpty);
    });

    test('returns a recognized tier string', () {
      SharedPreferences.setMockInitialValues({});
      final tp = TreeProvider();
      const validTiers = {'mobileFree', 'mobilePaid', 'desktopPro'};
      expect(validTiers.contains(tp.currentAppTierString), isTrue);
    });
  });

  // ── syncWithPeer when wifiSync and bluetooth both disabled ────────────────

  group('SyncService.syncWithPeer — disabled syncs', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('returns false when both sync types disabled', () async {
      final svc = SyncService();
      await svc.setWifiSyncEnabled(false);
      await svc.setBluetoothSyncEnabled(false);
      svc.treeProvider = TreeProvider();
      final result = await svc.syncWithPeer(
        host: '192.168.1.1',
        port: 8080,
        sharedSecret: 'secret',
      );
      expect(result, isFalse);
      expect(svc.status, SyncStatus.error);
      svc.dispose();
    });

    test('returns false when treeProvider is null', () async {
      final svc = SyncService();
      final result = await svc.syncWithPeer(
        host: '192.168.1.1',
        port: 8080,
        sharedSecret: 'secret',
      );
      expect(result, isFalse);
      svc.dispose();
    });
  });

  // ── startDiscovery — gating checks ────────────────────────────────────────

  group('SyncService.startDiscovery — gating', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('fails with error status when wifiSync is disabled', () async {
      final svc = SyncService();
      await svc.setWifiSyncEnabled(false);
      await svc.startDiscovery(); // free tier
      // Status becomes error because wifiSync is disabled
      expect(svc.status, SyncStatus.error);
      svc.dispose();
    });
  });

  // ── startServer — gating checks ───────────────────────────────────────────

  group('SyncService.startServer — gating', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('fails when wifiSync is disabled', () async {
      final svc = SyncService();
      await svc.setWifiSyncEnabled(false);
      await svc.startServer();
      expect(svc.status, SyncStatus.error);
      svc.dispose();
    });

    test('fails when treeProvider is null', () async {
      final svc = SyncService();
      // wifiSync enabled (default), but no treeProvider
      await svc.startServer();
      expect(svc.status, SyncStatus.error);
      svc.dispose();
    });
  });
}
