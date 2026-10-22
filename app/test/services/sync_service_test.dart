import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vetviona_app/services/sync_service.dart';
import 'package:vetviona_app/providers/tree_provider.dart';

void main() {
  group('SyncService Network Failure Tests', () {
    late SyncService syncService;
    late TreeProvider treeProvider;

    setUp(() {
      treeProvider = TreeProvider();
      syncService = SyncService();
      syncService.treeProvider = treeProvider;
    });

    test('syncWithPeer fails gracefully on HTTP error', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });
      syncService.client = mockClient;

      final success = await syncService.syncWithPeer(
        host: '192.168.1.100',
        port: 8080,
        sharedSecret: 'secret',
      );

      expect(success, false);
      expect(syncService.lastMessage, contains('failed'));
    });

    test('syncWithPeer fails gracefully on TimeoutException', () async {
      final mockClient = MockClient((request) async {
        throw TimeoutException('Connection timed out');
      });
      syncService.client = mockClient;

      final success = await syncService.syncWithPeer(
        host: '192.168.1.100',
        port: 8080,
        sharedSecret: 'secret',
      );

      expect(success, false);
      expect(syncService.lastMessage, contains('timed out'));
    });

    test('syncWithPeer fails gracefully on SocketException', () async {
      final mockClient = MockClient((request) async {
        throw const SocketException('Connection refused');
      });
      syncService.client = mockClient;

      final success = await syncService.syncWithPeer(
        host: '192.168.1.100',
        port: 8080,
        sharedSecret: 'secret',
      );

      expect(success, false);
      expect(syncService.lastMessage, contains('Connection refused'));
    });

    test('syncWithPeer fails gracefully on invalid JSON response', () async {
      final mockClient = MockClient((request) async {
        return http.Response('invalid json', 200);
      });
      syncService.client = mockClient;

      final success = await syncService.syncWithPeer(
        host: '192.168.1.100',
        port: 8080,
        sharedSecret: 'secret',
      );

      // Decryption will fail because 'invalid json' isn't valid encrypted data.
      expect(success, false);
    });
  });
}
