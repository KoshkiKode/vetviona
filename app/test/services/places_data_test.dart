// app/test/services/places_data_test.dart
//
// Data-integrity tests for the compiled-in places dataset (`allPlaces`).
// Every assertion here acts as an ongoing contract: if a data-entry mistake
// is made in any of the regional places_*.dart files these tests will fail
// immediately rather than surfacing as a runtime crash or silent bad data.

import 'package:flutter_test/flutter_test.dart';
import 'package:vetviona_app/models/place.dart';
import 'package:vetviona_app/services/places_data.dart';

void main() {
  // Pre-compute once so individual tests don't repeat the iteration work.
  final List<Place> places = allPlaces;

  // ── Basic non-empty checks ────────────────────────────────────────────────

  group('allPlaces — basic', () {
    test('list is non-empty', () {
      expect(places, isNotEmpty);
    });

    test('contains a large number of entries (sanity check)', () {
      // The dataset has several thousand entries from all regional files.
      expect(places.length, greaterThan(500));
    });
  });

  // ── Required-field presence ───────────────────────────────────────────────

  group('allPlaces — required fields are non-empty', () {
    test('every place has a non-empty name', () {
      final bad = places.where((p) => p.name.trim().isEmpty).toList();
      expect(bad, isEmpty, reason: 'Places with empty name: ${bad.length}');
    });

    test('every place has a non-empty modernCountry', () {
      final bad = places.where((p) => p.modernCountry.trim().isEmpty).toList();
      expect(
        bad,
        isEmpty,
        reason: 'Places with empty modernCountry: ${bad.length}',
      );
    });

    test('every place has a non-empty continent', () {
      final bad = places.where((p) => p.continent.trim().isEmpty).toList();
      expect(bad, isEmpty, reason: 'Places with empty continent: ${bad.length}');
    });
  });

  // ── Continent coverage ────────────────────────────────────────────────────

  group('allPlaces — all continents represented', () {
    final continents = places.map((p) => p.continent.trim()).toSet();

    for (final expected in [
      'Africa',
      'Americas',
      'Asia',
      'Europe',
      'Oceania',
    ]) {
      test('contains at least one place in $expected', () {
        expect(
          continents.any((c) => c.toLowerCase() == expected.toLowerCase()),
          isTrue,
          reason: 'No places found for continent "$expected"',
        );
      });
    }
  });

  // ── Date bounds are parseable ISO-8601 strings ────────────────────────────

  group('allPlaces — validFrom / validTo are parseable when present', () {
    test('all non-null validFrom values parse as valid dates', () {
      final bad = <String>[];
      for (final p in places) {
        if (p.validFrom != null) {
          if (DateTime.tryParse(p.validFrom!) == null) {
            bad.add('${p.name} (validFrom="${p.validFrom}")');
          }
        }
      }
      expect(bad, isEmpty, reason: 'Unparseable validFrom: $bad');
    });

    test('all non-null validTo values parse as valid dates', () {
      final bad = <String>[];
      for (final p in places) {
        if (p.validTo != null) {
          if (DateTime.tryParse(p.validTo!) == null) {
            bad.add('${p.name} (validTo="${p.validTo}")');
          }
        }
      }
      expect(bad, isEmpty, reason: 'Unparseable validTo: $bad');
    });

    test('validFrom is before validTo when both are set', () {
      final bad = <String>[];
      for (final p in places) {
        if (p.validFrom != null && p.validTo != null) {
          final from = DateTime.tryParse(p.validFrom!);
          final to = DateTime.tryParse(p.validTo!);
          if (from != null && to != null && !from.isBefore(to)) {
            bad.add('${p.name} (${p.validFrom} to ${p.validTo})');
          }
        }
      }
      expect(
        bad,
        isEmpty,
        reason: 'Places where validFrom >= validTo: $bad',
      );
    });
  });

  // ── Historical entries have at least one temporal bound ──────────────────

  group('allPlaces — content plausibility', () {
    test('at least some places have a validTo date (historical entries exist)',
        () {
      final historical = places.where((p) => p.validTo != null).toList();
      expect(
        historical,
        isNotEmpty,
        reason: 'No historical places with validTo found',
      );
    });

    test('most places have no temporal bounds (they are current)', () {
      final unbounded = places.where(
        (p) => p.validFrom == null && p.validTo == null,
      );
      expect(
        unbounded.length,
        greaterThan(places.length ~/ 2),
        reason: 'Expected more than half of places to have no date bounds',
      );
    });
  });

  // ── Place model methods work correctly on real data ───────────────────────

  group('allPlaces — isValidFor behaves correctly on real data', () {
    test('all unbounded places are valid for any date', () {
      final testDate = DateTime(1850, 6, 1);
      final bad = places
          .where((p) => p.validFrom == null && p.validTo == null)
          .where((p) => !p.isValidFor(testDate))
          .toList();
      expect(bad, isEmpty);
    });

    test('all places are valid when no date is provided', () {
      final bad = places.where((p) => !p.isValidFor(null)).toList();
      expect(bad, isEmpty);
    });
  });

  // ── Known landmark entries ────────────────────────────────────────────────

  group('allPlaces — known landmark entries are present', () {
    test('United Kingdom is present as a country', () {
      final uk = places.where(
        (p) => p.modernCountry.contains('United Kingdom') ||
            p.modernCountry.contains('UK') ||
            p.modernCountry.contains('Britain'),
      );
      expect(uk, isNotEmpty, reason: 'No United Kingdom entries found');
    });

    test('United States is present as a country', () {
      final us = places.where(
        (p) => p.modernCountry.contains('United States'),
      );
      expect(us, isNotEmpty, reason: 'No United States entries found');
    });

    test('a European country entry is present', () {
      final europe = places.where((p) => p.continent == 'Europe');
      expect(europe, isNotEmpty, reason: 'No European places found');
    });
  });

  // ── Matches / relevance consistency ──────────────────────────────────────

  group('allPlaces — Place.matches and relevanceFor are consistent', () {
    test('every place matches its own name', () {
      // Spot-check the first 100 entries to avoid an O(n) test.
      final sample = places.take(100);
      for (final p in sample) {
        expect(
          p.matches(p.name.toLowerCase()),
          isTrue,
          reason: '${p.name} does not match its own lower-cased name',
        );
      }
    });

    test('relevanceFor returns 0 for an empty query on any place', () {
      final sample = places.take(50);
      for (final p in sample) {
        expect(
          p.relevanceFor(''),
          equals(0),
          reason: '${p.name} did not return 0 relevance for empty query',
        );
      }
    });

    test('exact name match returns relevance 0 or 1', () {
      final sample = places.take(50);
      for (final p in sample) {
        expect(
          p.relevanceFor(p.name.toLowerCase()),
          lessThanOrEqualTo(1),
          reason: '${p.name} relevance for exact name should be 0 or 1',
        );
      }
    });
  });
}
