import 'package:flutter_test/flutter_test.dart';
import 'package:vetviona_app/services/bluetooth_sync_service.dart';

void main() {
  // ── BleSyncPeer ─────────────────────────────────────────────────────────────

  group('BleSyncPeer', () {
    const peer1 = BleSyncPeer(
      deviceId: 'device-abc',
      host: '192.168.1.10',
      port: 8080,
      deviceName: 'Phone A',
    );

    const peer2 = BleSyncPeer(
      deviceId: 'device-abc',
      host: '10.0.0.1',
      port: 9090,
      deviceName: 'Phone B',
    );

    const peer3 = BleSyncPeer(
      deviceId: 'device-xyz',
      host: '192.168.1.10',
      port: 8080,
      deviceName: 'Phone A',
    );

    test('equality is based on deviceId', () {
      expect(peer1, equals(peer2));
      expect(peer1, isNot(equals(peer3)));
    });

    test('hashCode is based on deviceId', () {
      expect(peer1.hashCode, equals(peer2.hashCode));
      expect(peer1.hashCode, isNot(equals(peer3.hashCode)));
    });

    test('toString contains deviceId, host, and port', () {
      final s = peer1.toString();
      expect(s, contains('device-abc'));
      expect(s, contains('192.168.1.10'));
      expect(s, contains('8080'));
    });
  });

  // ── buildAdvertisementPayload ───────────────────────────────────────────────

  group('BluetoothSyncService.buildAdvertisementPayload', () {
    test('output is 18 bytes', () {
      final buf = BluetoothSyncService.buildAdvertisementPayload(
        host: '192.168.1.1',
        port: 8080,
        deviceId: 'abc',
      );
      expect(buf.length, 18);
    });

    test('first 4 bytes are magic [0x56, 0x45, 0x54, 0x56]', () {
      final buf = BluetoothSyncService.buildAdvertisementPayload(
        host: '192.168.1.1',
        port: 8080,
        deviceId: 'abc',
      );
      expect(buf[0], 0x56);
      expect(buf[1], 0x45);
      expect(buf[2], 0x54);
      expect(buf[3], 0x56);
    });

    test('IP 192.168.1.100 → bytes [192, 168, 1, 100] at offset 4', () {
      final buf = BluetoothSyncService.buildAdvertisementPayload(
        host: '192.168.1.100',
        port: 8080,
        deviceId: 'abc',
      );
      expect(buf[4], 192);
      expect(buf[5], 168);
      expect(buf[6], 1);
      expect(buf[7], 100);
    });

    test('port 8080 = 0x1F90 → byte[8]=0x1F, byte[9]=0x90', () {
      final buf = BluetoothSyncService.buildAdvertisementPayload(
        host: '10.0.0.1',
        port: 8080,
        deviceId: 'abc',
      );
      expect(buf[8], 0x1F);
      expect(buf[9], 0x90);
    });

    test('deviceId "abc" → ASCII bytes at offset 10, zero-padded', () {
      final buf = BluetoothSyncService.buildAdvertisementPayload(
        host: '10.0.0.1',
        port: 1234,
        deviceId: 'abc',
      );
      expect(buf[10], 'a'.codeUnitAt(0));
      expect(buf[11], 'b'.codeUnitAt(0));
      expect(buf[12], 'c'.codeUnitAt(0));
      expect(buf[13], 0); // zero-padded
      expect(buf[17], 0);
    });

    test('deviceId exactly 8 chars → all 8 bytes populated', () {
      final buf = BluetoothSyncService.buildAdvertisementPayload(
        host: '10.0.0.1',
        port: 1234,
        deviceId: 'abcdefgh',
      );
      for (int i = 0; i < 8; i++) {
        expect(buf[10 + i], 'abcdefgh'.codeUnitAt(i));
      }
    });

    test('deviceId longer than 8 chars → only first 8 bytes used', () {
      final buf = BluetoothSyncService.buildAdvertisementPayload(
        host: '10.0.0.1',
        port: 1234,
        deviceId: 'abcdefghijklmnop',
      );
      for (int i = 0; i < 8; i++) {
        expect(buf[10 + i], 'abcdefgh'.codeUnitAt(i));
      }
    });

    test('IP with fewer than 4 parts → pads with 0', () {
      final buf = BluetoothSyncService.buildAdvertisementPayload(
        host: '10.0',
        port: 80,
        deviceId: 'x',
      );
      expect(buf[4], 10);
      expect(buf[5], 0);
      expect(buf[6], 0); // padded
      expect(buf[7], 0); // padded
    });
  });

  // ── BluetoothSyncService state ──────────────────────────────────────────────

  group('BluetoothSyncService initial state', () {
    late BluetoothSyncService service;

    setUp(() {
      service = BluetoothSyncService();
      addTearDown(() async => service.stopAll());
    });

    test('isScanning is false initially', () {
      expect(service.isScanning, isFalse);
    });

    test('isAdvertising is false initially', () {
      expect(service.isAdvertising, isFalse);
    });

    test('statusMessage is null initially', () {
      expect(service.statusMessage, isNull);
    });

    test('discoveredPeers is empty initially', () {
      expect(service.discoveredPeers, isEmpty);
    });

    test('syncWithPeer returns false when syncService is null', () async {
      const peer = BleSyncPeer(
        deviceId: 'test',
        host: '192.168.1.1',
        port: 8080,
        deviceName: 'Test',
      );
      final result = await service.syncWithPeer(peer, 'secret');
      expect(result, isFalse);
    });

    test('statusMessage is set after syncWithPeer (syncService=null)', () async {
      const peer = BleSyncPeer(
        deviceId: 'test',
        host: '192.168.1.1',
        port: 8080,
        deviceName: 'Test',
      );
      await service.syncWithPeer(peer, 'secret');
      expect(service.statusMessage, isNotNull);
      expect(service.statusMessage, contains('SyncService'));
    });

    test('stopAdvertising completes without throwing', () async {
      await expectLater(service.stopAdvertising(), completes);
      expect(service.isAdvertising, isFalse);
    });
  });

  // ── BluetoothSyncService.parseAdvertisementPayload round-trip ───────────────

  group('BluetoothSyncService.buildAdvertisementPayload round-trip', () {
    test('port max value 65535 → correct byte encoding', () {
      final buf = BluetoothSyncService.buildAdvertisementPayload(
        host: '255.255.255.255',
        port: 65535,
        deviceId: 'test1234',
      );
      expect(buf[4], 255);
      expect(buf[5], 255);
      expect(buf[6], 255);
      expect(buf[7], 255);
      expect(buf[8], 0xFF);
      expect(buf[9], 0xFF);
    });

    test('port 0 → bytes [0, 0]', () {
      final buf = BluetoothSyncService.buildAdvertisementPayload(
        host: '10.0.0.1',
        port: 0,
        deviceId: 'x',
      );
      expect(buf[8], 0);
      expect(buf[9], 0);
    });

    test('empty deviceId → all zero-padded id bytes', () {
      final buf = BluetoothSyncService.buildAdvertisementPayload(
        host: '10.0.0.1',
        port: 80,
        deviceId: '',
      );
      for (int i = 10; i < 18; i++) {
        expect(buf[i], 0);
      }
    });
  });
}
