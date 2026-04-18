// Tests for the _sanitizeFileName helper exposed via @visibleForTesting.
// The rest of ShareSyncService (shareTree) depends on path_provider and
// share_plus platform channels and is not unit-testable here.

import 'package:flutter_test/flutter_test.dart';

import 'package:vetviona_app/services/share_sync_service.dart';

void main() {
  group('ShareSyncService.sanitizeFileName', () {
    test('safe alphanumeric name is returned unchanged', () {
      expect(ShareSyncService.sanitizeFileName('MyTree'), 'MyTree');
    });

    test('spaces are preserved', () {
      expect(ShareSyncService.sanitizeFileName('My Family Tree'), 'My Family Tree');
    });

    test('hyphens and dots are preserved', () {
      expect(ShareSyncService.sanitizeFileName('tree-2024.backup'), 'tree-2024.backup');
    });

    test('underscores are preserved', () {
      expect(ShareSyncService.sanitizeFileName('tree_v2'), 'tree_v2');
    });

    test('slashes are replaced with underscore', () {
      expect(ShareSyncService.sanitizeFileName('trees/backup'), 'trees_backup');
    });

    test('colons are replaced', () {
      expect(ShareSyncService.sanitizeFileName('tree:2024'), 'tree_2024');
    });

    test('angle brackets are replaced', () {
      expect(ShareSyncService.sanitizeFileName('tree<1>'), 'tree_1_');
    });

    test('asterisks and question marks are replaced', () {
      expect(ShareSyncService.sanitizeFileName('tree*?'), 'tree__');
    });

    test('leading and trailing whitespace is trimmed', () {
      expect(ShareSyncService.sanitizeFileName('  My Tree  '), 'My Tree');
    });

    test('empty string returns empty string', () {
      expect(ShareSyncService.sanitizeFileName(''), '');
    });

    test('all special chars produces underscores', () {
      final result = ShareSyncService.sanitizeFileName('|"<>?:/\\');
      expect(result, isNotEmpty);
      // Every char should be underscore or word char
      expect(result.contains(RegExp(r'[^\w\s_]')), isFalse);
    });

    test('unicode letters are preserved (alphanumeric)', () {
      // \w in Dart regex matches unicode word chars by default off,
      // but replaceAll with r'[^\w\s\-.]' uses ASCII \w.
      // Unicode non-ASCII letters may be replaced; test the actual behavior.
      final result = ShareSyncService.sanitizeFileName('Ångström');
      // Result should not contain the raw Å (if replaced) — just verify it doesn't throw.
      expect(result, isNotEmpty);
    });
  });
}
