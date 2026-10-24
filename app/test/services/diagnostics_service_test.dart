import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vetviona_app/config/versions.dart';
import 'package:vetviona_app/services/diagnostics_service.dart';

void main() {
  group('DiagnosticsService', () {
    test('keeps only the newest entries', () {
      final log = DiagnosticsService(maxEntries: 3);
      for (var i = 1; i <= 5; i++) {
        log.info('test', 'event $i');
      }
      expect(log.entries.map((e) => e.message), [
        'event 3',
        'event 4',
        'event 5',
      ]);
    });

    test('redacts user names from file paths', () {
      expect(
        DiagnosticsService.redact(r'C:\Users\alice\Documents\x.db'),
        r'C:\Users\<user>\Documents\x.db',
      );
      expect(
        DiagnosticsService.redact('/Users/bob/Library/x.db'),
        '/Users/<user>/Library/x.db',
      );
      expect(
        DiagnosticsService.redact('/home/carol/tree.db'),
        '/home/<user>/tree.db',
      );
    });

    test('redacts e-mail addresses, record identifiers and IP addresses', () {
      expect(
        DiagnosticsService.redact('mail jane.doe@example.com'),
        'mail <email>',
      );
      expect(
        DiagnosticsService.redact('id 3f2504e0-4f89-11d3-9a0c-0305e82c3301'),
        'id <id>',
      );
      expect(DiagnosticsService.redact('host 192.168.1.20'), 'host <ip>');
    });

    test('redacts long tokens', () {
      final token = 'Abc123_-' * 5;
      expect(DiagnosticsService.redact('token $token'), 'token <token>');
    });

    test('error() records a shortened, redacted stack trace', () {
      final log = DiagnosticsService();
      final stack = StackTrace.fromString(
        '#0 load (/Users/eve/app/lib/x.dart:1:1)\n#1 main\n',
      );
      log.error('load', Exception('failed for eve@example.com'), stack);
      final message = log.entries.single.message;
      expect(message, contains('<email>'));
      expect(message, contains('/Users/<user>/app/lib/x.dart'));
      expect(message, isNot(contains('eve')));
    });

    test('exportReport has a header and the entries', () {
      final log = DiagnosticsService()..info('db', 'opened');
      final report = log.exportReport(appVersion: '1.0.0');
      expect(report, contains('Vetviona diagnostics'));
      expect(report, contains('App version: 1.0.0'));
      expect(report, contains('[db] opened'));
    });

    test('mirrors entries to a log file that rotates when it grows', () async {
      final dir = Directory.systemTemp.createTempSync('vetviona_diag_test');
      try {
        final log = DiagnosticsService(maxEntries: 10, maxFileBytes: 200);
        await log.attachFile(dir);
        for (var i = 0; i < 30; i++) {
          log.info('test', 'entry number $i with some padding text');
        }
        expect(File('${dir.path}/diagnostics.log').existsSync(), isTrue);
        expect(File('${dir.path}/diagnostics.log.1').existsSync(), isTrue);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });
  });

  group('versions', () {
    test('compareVersions orders dotted numbers numerically', () {
      expect(compareVersions('1.10.0', '1.9.3'), greaterThan(0));
      expect(compareVersions('1.2.0', '1.10.0'), lessThan(0));
    });

    test('build numbers and pre-release suffixes are ignored', () {
      expect(compareVersions('1.2.3+4', '1.2.3'), 0);
      expect(compareVersions('2.0-beta', '2.0.0'), 0);
      expect(compareVersions('2.0', '2.0.0'), 0);
    });

    test('backup and RootLoop compatibility windows', () {
      expect(AppVersions.canRestoreBackup(AppVersions.backupFormat), isTrue);
      expect(AppVersions.canRestoreBackup(AppVersions.backupFormat + 1), isFalse);
      expect(AppVersions.canSpeakRootLoop(AppVersions.rootLoopProtocol), isTrue);
      expect(AppVersions.canSpeakRootLoop(0), isFalse);
    });

    test('schema version (bump together with a migration and fixture test)', () {
      expect(AppVersions.schema, 14);
    });
  });
}
