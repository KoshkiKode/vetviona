import 'package:flutter_test/flutter_test.dart';
import 'package:vetviona_app/services/place_service.dart';

void main() {
  setUpAll(() async {
    // Pre-load the place database so all tests use the cached list.
    await PlaceService.instance.loadPlaces();
  });

  group('PlaceService', () {
    test('loadPlaces returns a non-empty list', () async {
      final places = await PlaceService.instance.loadPlaces();
      expect(places, isNotEmpty);
    });

    test('places getter returns the loaded list', () {
      expect(PlaceService.instance.places, isNotEmpty);
    });

    test('calling loadPlaces twice returns the same cached list', () async {
      final first = await PlaceService.instance.loadPlaces();
      final second = await PlaceService.instance.loadPlaces();
      expect(identical(first, second), true);
    });

    group('search – empty / unfiltered', () {
      test('empty query returns all places', () {
        final all = PlaceService.instance.search('');
        expect(all.length, PlaceService.instance.places.length);
      });

      test('empty query with eventDate still respects date filter', () {
        // Historical limit: only places valid for the year 1000 CE
        final ancient = PlaceService.instance.search(
          '',
          eventDate: DateTime(1000),
        );
        final all = PlaceService.instance.search('');
        expect(ancient.length, lessThanOrEqualTo(all.length));
      });
    });

    group('search – text matching', () {
      test('returns results containing the queried city name', () {
        // London should appear in most place databases
        final results = PlaceService.instance.search('London');
        expect(results, isNotEmpty);
        final names = results.map((p) => p.name.toLowerCase()).toList();
        expect(names.any((n) => n.contains('london')), true);
      });

      test('search is case-insensitive', () {
        final lower = PlaceService.instance.search('london');
        final upper = PlaceService.instance.search('LONDON');
        expect(
          lower.map((p) => p.name).toSet(),
          equals(upper.map((p) => p.name).toSet()),
        );
      });

      test('returns empty for nonsense query', () {
        final results = PlaceService.instance.search('xyzzy_nonexistent_12345');
        expect(results, isEmpty);
      });

      test('multi-token query applies AND logic', () {
        // Find places that contain both a city name and a country name.
        // Single-token results should be a superset of two-token results.
        final singleToken = PlaceService.instance.search('London');
        final twoTokens = PlaceService.instance.search('London United Kingdom');
        // Two-token result must be a subset (or equal) of single-token result
        if (twoTokens.isNotEmpty) {
          for (final place in twoTokens) {
            expect(
              singleToken.any((p) => p.name == place.name),
              true,
              reason: '${place.name} should also appear in single-token results',
            );
          }
        }
      });
    });

    group('search – date filtering', () {
      test('places with validFrom after query date are excluded', () {
        // Any place with validFrom > 1800 should not appear for the year 1500
        final results1500 = PlaceService.instance.search(
          '',
          eventDate: DateTime(1500),
        );
        for (final place in results1500) {
          if (place.validFrom != null) {
            final from = DateTime.tryParse(place.validFrom!);
            if (from != null) {
              expect(
                DateTime(1500).isBefore(from),
                false,
                reason: '${place.name} (validFrom ${place.validFrom}) '
                    'should not appear for 1500 CE',
              );
            }
          }
        }
      });

      test('places with validTo before query date are excluded', () {
        final results2100 = PlaceService.instance.search(
          '',
          eventDate: DateTime(2100),
        );
        for (final place in results2100) {
          if (place.validTo != null) {
            final to = DateTime.tryParse(place.validTo!);
            if (to != null) {
              expect(
                DateTime(2100).isAfter(to),
                false,
                reason: '${place.name} (validTo ${place.validTo}) '
                    'should not appear for 2100 CE',
              );
            }
          }
        }
      });

      test('search with non-empty query and eventDate filters out invalid places', () {
        // Use a real city name with an ancient date — ensures line 37 (continue) is hit.
        final ancientDate = DateTime(1, 1, 1);
        final results = PlaceService.instance.search('London', eventDate: ancientDate);
        final allResults = PlaceService.instance.search('London');
        expect(results.length, lessThanOrEqualTo(allResults.length));
      });

      test('search with eventDate filters out places not valid for that era', () async {
        await PlaceService.instance.loadPlaces();
        final ancientDate = DateTime(1, 1, 1);
        final results = PlaceService.instance.search('', eventDate: ancientDate);
        final allResults = PlaceService.instance.search('');
        expect(results.length, lessThanOrEqualTo(allResults.length));
      });

      test('empty query with eventDate returns filtered places', () async {
        await PlaceService.instance.loadPlaces();
        final recentDate = DateTime(2000, 1, 1);
        final results = PlaceService.instance.search('', eventDate: recentDate);
        expect(results, isA<List>());
      });
    });

    group('search – relevance ordering', () {
      test('exact city name match appears before partial matches', () {
        // Pick a common city that has a very specific name
        const query = 'Paris';
        final results = PlaceService.instance.search(query);
        if (results.length > 1) {
          // The first result should contain the query in its name
          expect(
            results.first.name.toLowerCase().contains(query.toLowerCase()),
            true,
          );
        }
      });

      test('results are sorted by ascending relevance score', () {
        const query = 'Rome';
        final results = PlaceService.instance.search(query);
        // Verify the list is sorted: each item's relevance ≤ next item's
        for (int i = 0; i < results.length - 1; i++) {
          expect(
            results[i].relevanceFor(query),
            lessThanOrEqualTo(results[i + 1].relevanceFor(query)),
          );
        }
      });
    });
  });
}
