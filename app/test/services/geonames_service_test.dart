// app/test/services/geonames_service_test.dart
//
// Unit tests for GeonamesService that do NOT require the bundled SQLite asset.
//
// In the test environment, the `rootBundle` / `getDatabasesPath` calls inside
// `init()` will fail (no asset bindings), causing the service to mark itself
// as unavailable (`_unavailable = true`).  We test the public contract around
// that behaviour: pre-init state, post-failed-init state, and close().

import 'package:flutter_test/flutter_test.dart';
import 'package:vetviona_app/services/geonames_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── isAvailable before any init ───────────────────────────────────────────

  group('GeonamesService — initial state', () {
    // A fresh `GeonamesService._()` has _initialised = false and _db = null,
    // so isAvailable must be false.
    test('isAvailable is false on a fresh instance before init', () {
      // We access the singleton which has not been initialised in tests.
      // If another test already called init() and failed, _unavailable is true
      // and isAvailable is still false — which is the same expectation.
      expect(GeonamesService.instance.isAvailable, isFalse);
    });
  });

  // ── search before init ────────────────────────────────────────────────────

  group('GeonamesService — search before / without init', () {
    test('search returns an empty list when the service is not available',
        () async {
      // In the test environment init() will throw (no asset bundle), setting
      // _unavailable = true.  Subsequent searches return [].
      final results = await GeonamesService.instance.search('London');
      expect(results, isEmpty);
    });

    test('search with empty query returns empty list when not available',
        () async {
      final results = await GeonamesService.instance.search('');
      expect(results, isEmpty);
    });

    test('search with whitespace-only query returns empty list', () async {
      final results = await GeonamesService.instance.search('   ');
      expect(results, isEmpty);
    });

    test('search does not throw regardless of the query string', () async {
      expect(
        () async => GeonamesService.instance.search('Tokyo'),
        returnsNormally,
      );
    });
  });

  // ── close() ───────────────────────────────────────────────────────────────

  group('GeonamesService — close()', () {
    test('close() completes without throwing', () async {
      await expectLater(
        GeonamesService.instance.close(),
        completes,
      );
    });

    test('isAvailable is false after close()', () async {
      await GeonamesService.instance.close();
      expect(GeonamesService.instance.isAvailable, isFalse);
    });

    test('search still returns empty list after close()', () async {
      await GeonamesService.instance.close();
      final results = await GeonamesService.instance.search('Paris');
      expect(results, isEmpty);
    });

    test('calling close() multiple times does not throw', () async {
      await GeonamesService.instance.close();
      await expectLater(GeonamesService.instance.close(), completes);
    });
  });
}
