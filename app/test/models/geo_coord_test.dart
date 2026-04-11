import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vetviona_app/models/geo_coord.dart';

void main() {
  group('GeoCoord', () {
    group('constructor', () {
      test('required lat/lng are stored', () {
        const g = GeoCoord(lat: 51.5074, lng: -0.1278);
        expect(g.lat, 51.5074);
        expect(g.lng, -0.1278);
      });

      test('optional fields default to null', () {
        const g = GeoCoord(lat: 0.0, lng: 0.0);
        expect(g.displayName, isNull);
        expect(g.postalCode, isNull);
        expect(g.city, isNull);
        expect(g.county, isNull);
        expect(g.state, isNull);
        expect(g.country, isNull);
        expect(g.countryCode, isNull);
      });
    });

    group('toJson / fromJson', () {
      test('full roundtrip preserves all fields', () {
        const original = GeoCoord(
          lat: 48.8566,
          lng: 2.3522,
          displayName: 'Paris, Île-de-France, France',
          postalCode: '75001',
          city: 'Paris',
          county: 'Paris',
          state: 'Île-de-France',
          country: 'France',
          countryCode: 'FR',
        );
        final restored = GeoCoord.fromJson(original.toJson());

        expect(restored.lat, original.lat);
        expect(restored.lng, original.lng);
        expect(restored.displayName, original.displayName);
        expect(restored.postalCode, original.postalCode);
        expect(restored.city, original.city);
        expect(restored.county, original.county);
        expect(restored.state, original.state);
        expect(restored.country, original.country);
        expect(restored.countryCode, original.countryCode);
      });

      test('null optional fields are omitted from toJson output', () {
        const g = GeoCoord(lat: 1.0, lng: 2.0);
        final json = g.toJson();
        expect(json.containsKey('displayName'), false);
        expect(json.containsKey('city'), false);
        expect(json.containsKey('country'), false);
      });

      test('lat and lng always present in toJson', () {
        const g = GeoCoord(lat: -33.8688, lng: 151.2093);
        final json = g.toJson();
        expect(json['lat'], -33.8688);
        expect(json['lng'], 151.2093);
      });

      test('fromJson accepts integer lat/lng values', () {
        final json = <String, dynamic>{'lat': 40, 'lng': -74};
        final g = GeoCoord.fromJson(json);
        expect(g.lat, 40.0);
        expect(g.lng, -74.0);
      });
    });

    group('toDbString / fromDbString', () {
      test('roundtrip via database string preserves all fields', () {
        const original = GeoCoord(
          lat: 55.7558,
          lng: 37.6173,
          city: 'Moscow',
          country: 'Russia',
          countryCode: 'RU',
        );
        final dbStr = original.toDbString();
        final restored = GeoCoord.fromDbString(dbStr);

        expect(restored, isNotNull);
        expect(restored!.lat, original.lat);
        expect(restored.lng, original.lng);
        expect(restored.city, original.city);
        expect(restored.country, original.country);
        expect(restored.countryCode, original.countryCode);
      });

      test('toDbString produces valid JSON', () {
        const g = GeoCoord(lat: 1.0, lng: 2.0);
        expect(() => jsonDecode(g.toDbString()), returnsNormally);
      });

      test('fromDbString with null returns null', () {
        expect(GeoCoord.fromDbString(null), isNull);
      });

      test('fromDbString with empty string returns null', () {
        expect(GeoCoord.fromDbString(''), isNull);
      });

      test('fromDbString with invalid JSON returns null', () {
        expect(GeoCoord.fromDbString('not valid json'), isNull);
      });

      test('fromDbString with malformed JSON returns null', () {
        expect(GeoCoord.fromDbString('{bad: json}'), isNull);
      });
    });

    group('shortLabel', () {
      test('returns city, state, country when all present', () {
        const g = GeoCoord(
          lat: 0,
          lng: 0,
          city: 'Boston',
          state: 'Massachusetts',
          country: 'United States',
        );
        expect(g.shortLabel, 'Boston, Massachusetts, United States');
      });

      test('returns country alone when only country present', () {
        const g = GeoCoord(lat: 0, lng: 0, country: 'Germany');
        expect(g.shortLabel, 'Germany');
      });

      test('returns coordinate fallback when no location fields set', () {
        const g = GeoCoord(lat: 12.3456, lng: -98.7654);
        expect(g.shortLabel, '12.3456, -98.7654');
      });

      test('skips empty city', () {
        const g = GeoCoord(lat: 0, lng: 0, city: '', country: 'France');
        expect(g.shortLabel, 'France');
      });

      test('returns city and country when state is absent', () {
        const g = GeoCoord(lat: 0, lng: 0, city: 'Lyon', country: 'France');
        expect(g.shortLabel, 'Lyon, France');
      });
    });

    group('politicalBoundaries', () {
      test('returns full hierarchy when all fields present', () {
        const g = GeoCoord(
          lat: 0,
          lng: 0,
          city: 'Warsaw',
          county: 'Warsaw County',
          state: 'Masovian Voivodeship',
          country: 'Poland',
        );
        expect(
          g.politicalBoundaries,
          'Warsaw, Warsaw County, Masovian Voivodeship, Poland',
        );
      });

      test('returns empty string when no fields set', () {
        const g = GeoCoord(lat: 0, lng: 0);
        expect(g.politicalBoundaries, isEmpty);
      });

      test('skips empty parts', () {
        const g = GeoCoord(lat: 0, lng: 0, city: '', country: 'Italy');
        expect(g.politicalBoundaries, 'Italy');
      });
    });

    group('coordinateLabel', () {
      test('northern / eastern hemisphere uses N and E suffixes', () {
        const g = GeoCoord(lat: 51.5074, lng: 0.1278);
        expect(g.coordinateLabel, contains('N'));
        expect(g.coordinateLabel, contains('E'));
      });

      test('southern / western hemisphere uses S and W suffixes', () {
        const g = GeoCoord(lat: -33.8688, lng: -70.6693);
        expect(g.coordinateLabel, contains('S'));
        expect(g.coordinateLabel, contains('W'));
      });

      test('zero latitude is treated as N (non-negative)', () {
        const g = GeoCoord(lat: 0.0, lng: 0.0);
        expect(g.coordinateLabel, contains('N'));
        expect(g.coordinateLabel, contains('E'));
      });

      test('label has expected format (degree symbol and comma)', () {
        const g = GeoCoord(lat: 55.7558, lng: 37.6173);
        final label = g.coordinateLabel;
        expect(label, contains('°'));
        expect(label, contains(','));
      });

      test('absolute values are used in the label (no minus sign)', () {
        const g = GeoCoord(lat: -10.0, lng: -20.0);
        expect(g.coordinateLabel, isNot(contains('-')));
      });
    });
  });
}
